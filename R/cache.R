# Cache -----------------------------------------------------------------------
#
# A two-file cache: `<key>.rds` holds the value, `<key>.json` holds the metadata
# describing what it is and when it expires (plan section 20). Keeping metadata
# in plain JSON means a stale or corrupt cache can be inspected with a text
# editor rather than an R session.
#
# The key mixes parser and schema version, so upgrading the package invalidates
# entries that a new parser would read differently, rather than silently
# returning yesterday's shape.

knbs_parser_version <- function() 1L
knbs_schema_version <- function() 1L

# Suggested defaults from plan section 20.1.
knbs_cache_ttl <- function(kind = c("catalogue", "data", "immutable")) {
  kind <- match.arg(kind)
  switch(kind,
    catalogue = 24 * 60 * 60,
    data = 7 * 24 * 60 * 60,
    immutable = Inf
  )
}

#' Where knbsdata stores cached responses
#'
#' The cache lives in [tools::R_user_dir()] unless the `knbsdata.cache_dir`
#' option points elsewhere. Nothing is written until something is cached.
#'
#' @param create Whether to create the directory if it does not exist.
#'
#' @return The cache directory path, invisibly when `create = TRUE`.
#'
#' @seealso [knbs_cache_info()], [knbs_cache_clear()], [knbs_cache_prune()]
#'
#' @examples
#' knbs_cache_dir(create = FALSE)
#' @export
knbs_cache_dir <- function(create = FALSE) {
  check_bool(create, "create")
  dir <- knbs_option("cache_dir") %||% tools::R_user_dir("knbsdata", "cache")
  if (create && !dir.exists(dir)) {
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  }
  dir
}

#' Build a cache key
#'
#' @param source_id Source id.
#' @param operation Operation name.
#' @param query A `knbs_query`, or `NULL`.
#' @param resource_id Optional resource id when there is no query.
#' @noRd
cache_key <- function(source_id, operation, query = NULL, resource_id = NULL) {
  check_string(source_id, "source_id")
  check_string(operation, "operation")
  rlang::hash(list(
    source_id = source_id,
    operation = operation,
    resource_id = resource_id %||% query$resource_id %||% "",
    query = if (is.null(query)) NULL else query_canonical(query),
    release = query$release %||% "latest",
    parser_version = knbs_parser_version(),
    schema_version = knbs_schema_version()
  ))
}

cache_paths <- function(key, dir = knbs_cache_dir()) {
  list(
    value = file.path(dir, paste0(key, ".rds")),
    meta = file.path(dir, paste0(key, ".json"))
  )
}

#' Write a value to the cache
#'
#' @param key Cache key.
#' @param value Value to store.
#' @param ttl Time to live in seconds; `Inf` never expires.
#' @param info Named list of extra metadata (source_id, operation, etag, ...).
#'
#' @return The cache key, invisibly.
#' @noRd
cache_write <- function(key, value, ttl = knbs_cache_ttl("catalogue"), info = list()) {
  dir <- knbs_cache_dir(create = TRUE)
  paths <- cache_paths(key, dir)

  now <- Sys.time()
  meta <- c(
    list(
      cache_key = key,
      retrieved_at = format(now, "%Y-%m-%dT%H:%M:%S%z"),
      expires_at = if (is.finite(ttl)) {
        format(now + ttl, "%Y-%m-%dT%H:%M:%S%z")
      } else {
        NA_character_
      },
      hash = rlang::hash(value),
      parser_version = knbs_parser_version(),
      schema_version = knbs_schema_version(),
      package_version = as.character(utils::packageVersion("knbsdata"))
    ),
    info
  )

  # Write to a temporary file and rename, so an interrupted write cannot leave a
  # half-written entry that looks valid.
  tmp <- paste0(paths$value, ".tmp")
  saveRDS(value, tmp)
  file.rename(tmp, paths$value)
  jsonlite::write_json(meta, paths$meta, auto_unbox = TRUE, null = "null")

  invisible(key)
}

#' Read a value from the cache
#'
#' Returns `NULL` when the entry is missing, expired or damaged. A damaged entry
#' is deleted so that the caller simply refetches (plan section 20.3); an error
#' is raised only if the entry cannot be removed.
#'
#' @return The cached value, or `NULL`.
#' @noRd
cache_read <- function(key, dir = knbs_cache_dir()) {
  paths <- cache_paths(key, dir)
  if (!file.exists(paths$value) || !file.exists(paths$meta)) {
    return(NULL)
  }

  meta <- tryCatch(
    jsonlite::fromJSON(paths$meta, simplifyVector = TRUE),
    error = function(cnd) NULL
  )
  if (is.null(meta)) {
    return(cache_discard(key, dir, "metadata could not be read"))
  }

  if (!identical(as.integer(meta$parser_version), knbs_parser_version()) ||
    !identical(as.integer(meta$schema_version), knbs_schema_version())) {
    return(cache_discard(key, dir, "it was written by a different parser or schema version"))
  }

  expires <- meta$expires_at
  if (!is.null(expires) && !is.na(expires)) {
    expiry <- suppressWarnings(as.POSIXct(expires, format = "%Y-%m-%dT%H:%M:%S%z"))
    if (!is.na(expiry) && Sys.time() > expiry) {
      return(NULL)
    }
  }

  value <- tryCatch(readRDS(paths$value), error = function(cnd) NULL)
  if (is.null(value)) {
    return(cache_discard(key, dir, "the stored value could not be read"))
  }
  if (!is.null(meta$hash) && !identical(rlang::hash(value), meta$hash)) {
    return(cache_discard(key, dir, "its checksum did not match"))
  }

  value
}

cache_discard <- function(key, dir, why) {
  paths <- cache_paths(key, dir)
  removed <- suppressWarnings(file.remove(paths$value[file.exists(paths$value)],
                                          paths$meta[file.exists(paths$meta)]))
  if (length(removed) > 0L && !all(removed)) {
    knbs_abort(
      c(
        "A cache entry is damaged and could not be removed.",
        "x" = "Discarded because {why}.",
        "i" = "Delete it manually: {.path {dirname(paths$value)}}."
      ),
      class = "knbs_error_cache_corrupt"
    )
  }
  NULL
}

#' Fetch through the cache
#'
#' @param key Cache key.
#' @param fetch A function of no arguments returning the value.
#' @param cache Whether to use the cache at all.
#' @param refresh Whether to bypass any existing entry.
#' @noRd
cache_fetch <- function(key,
                        fetch,
                        cache = knbs_option("cache"),
                        refresh = FALSE,
                        ttl = knbs_cache_ttl("catalogue"),
                        info = list()) {
  if (!isTRUE(cache)) {
    return(fetch())
  }
  if (!isTRUE(refresh)) {
    hit <- cache_read(key)
    if (!is.null(hit)) {
      return(hit)
    }
  }
  value <- fetch()
  cache_write(key, value, ttl = ttl, info = info)
  value
}

#' What is in the cache
#'
#' @return A [tibble][tibble::tibble] with one row per cached entry: `cache_key`,
#'   `source_id`, `operation`, `resource_id`, `retrieved_at`, `expires_at`,
#'   `expired` and `size_bytes`. Zero rows if nothing is cached.
#'
#' @seealso [knbs_cache_dir()], [knbs_cache_clear()]
#'
#' @examples
#' knbs_cache_info()
#' @export
knbs_cache_info <- function() {
  dir <- knbs_cache_dir()
  metas <- if (dir.exists(dir)) {
    list.files(dir, pattern = "\\.json$", full.names = TRUE)
  } else {
    character(0)
  }

  empty <- tibble::tibble(
    cache_key = character(0), source_id = character(0), operation = character(0),
    resource_id = character(0), retrieved_at = character(0),
    expires_at = character(0), expired = logical(0), size_bytes = double(0)
  )
  if (length(metas) == 0L) {
    return(empty)
  }

  rows <- lapply(metas, function(path) {
    meta <- tryCatch(jsonlite::fromJSON(path, simplifyVector = TRUE),
                     error = function(cnd) NULL)
    if (is.null(meta)) {
      return(NULL)
    }
    value_path <- sub("\\.json$", ".rds", path)
    expiry <- suppressWarnings(
      as.POSIXct(meta$expires_at %||% NA_character_, format = "%Y-%m-%dT%H:%M:%S%z")
    )
    tibble::tibble(
      cache_key = meta$cache_key %||% NA_character_,
      source_id = meta$source_id %||% NA_character_,
      operation = meta$operation %||% NA_character_,
      resource_id = meta$resource_id %||% NA_character_,
      retrieved_at = meta$retrieved_at %||% NA_character_,
      expires_at = meta$expires_at %||% NA_character_,
      expired = !is.na(expiry) && Sys.time() > expiry,
      size_bytes = if (file.exists(value_path)) file.size(value_path) else NA_real_
    )
  })
  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (length(rows) == 0L) {
    return(empty)
  }
  do.call(rbind, rows)
}

#' Empty the cache
#'
#' @param quiet Suppress the summary message.
#'
#' @return The number of entries removed, invisibly.
#'
#' @seealso [knbs_cache_prune()] to remove only expired entries.
#'
#' @examples
#' \dontrun{
#' knbs_cache_clear()
#' }
#' @export
knbs_cache_clear <- function(quiet = knbs_option("quiet")) {
  check_bool(quiet, "quiet")
  dir <- knbs_cache_dir()
  if (!dir.exists(dir)) {
    return(invisible(0L))
  }
  files <- list.files(dir, pattern = "\\.(rds|json)$", full.names = TRUE)
  n <- length(files) %/% 2L
  file.remove(files)
  if (!quiet) {
    cli::cli_alert_success("Removed {n} cache entr{?y/ies} from {.path {dir}}.")
  }
  invisible(n)
}

#' Remove expired cache entries
#'
#' @param quiet Suppress the summary message.
#'
#' @return The number of entries removed, invisibly.
#'
#' @seealso [knbs_cache_clear()] to remove everything.
#'
#' @examples
#' \dontrun{
#' knbs_cache_prune()
#' }
#' @export
knbs_cache_prune <- function(quiet = knbs_option("quiet")) {
  check_bool(quiet, "quiet")
  info <- knbs_cache_info()
  stale <- info$cache_key[info$expired]
  dir <- knbs_cache_dir()
  for (key in stale) {
    paths <- cache_paths(key, dir)
    suppressWarnings(file.remove(paths$value, paths$meta))
  }
  if (!quiet) {
    cli::cli_alert_success("Removed {length(stale)} expired cache entr{?y/ies}.")
  }
  invisible(length(stale))
}
