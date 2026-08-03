# Fake adapter ----------------------------------------------------------------
#
# An offline adapter serving fixtures from inst/extdata/fake (plan section 28,
# step 4). Its purpose is to prove that the public interface, the query object,
# the cache, the metadata classes and the citation builder work together before
# any real source is wired in — and to keep proving it in tests that must never
# touch the network.
#
# It is registered as a normal source so that it exercises the same registry and
# contract enforcement as everything else.

fake_file <- function(name) {
  system.file("extdata", "fake", name, package = "knbsdata", mustWork = FALSE)
}

fake_catalogue <- function(source_id = "fake_source") {
  parse_json_file(fake_file("catalogue.json"), source_id = source_id)$resources
}

fake_resource <- function(resource_id, source_id = "fake_source",
                          call = rlang::caller_env()) {
  hit <- Filter(
    function(r) identical(r$resource_id, resource_id),
    fake_catalogue(source_id)
  )
  if (length(hit) == 0L) {
    knbs_abort(
      c(
        "No resource {.val {resource_id}} in source {.val {source_id}}.",
        "i" = "Available: {.val {vapply(fake_catalogue(source_id), function(r) r$resource_id, character(1))}}."
      ),
      class = "knbs_error_resource_not_found",
      call = call
    )
  }
  hit[[1]]
}

# Access is refused on the package side before anything is read, so a restricted
# resource behaves the same way a real gated one would.
fake_check_access <- function(resource, call = rlang::caller_env()) {
  if (!identical(resource$access, "restricted")) {
    return(invisible(resource))
  }
  knbs_abort(
    c(
      "{.val {resource$resource_id}} is not available for direct download.",
      "i" = "Access type: {.val {resource$access}}.",
      "i" = "Complete the official access process at {.url {resource$source_url}}."
    ),
    class = "knbs_error_access_restricted",
    call = call
  )
}

#' @export
source_search.knbs_source_fake <- function(source, query, ...) {
  check_supported_filters(query, c("search", "type", "topic", "access"))
  resources <- fake_catalogue(source$source_id)

  keep <- rep(TRUE, length(resources))
  filters <- query$filters
  if (!is.null(filters$search)) {
    pattern <- tolower(filters$search)
    haystack <- tolower(vapply(
      resources,
      function(r) paste(json_chr(r, "title", ""), json_chr(r, "description", "")),
      character(1)
    ))
    keep <- keep & vapply(haystack, function(h) any(grepl(pattern, h, fixed = TRUE)), logical(1))
  }
  for (field in c("type", "topic", "access")) {
    if (is.null(filters[[field]])) next
    lookup <- if (field == "type") "resource_type" else field
    values <- vapply(resources, function(r) json_chr(r, lookup, ""), character(1))
    keep <- keep & values %in% as.character(filters[[field]])
  }
  resources <- resources[keep]

  out <- tibble::tibble(
    resource_id = vapply(resources, json_chr, character(1), "resource_id"),
    resource_type = vapply(resources, json_chr, character(1), "resource_type"),
    title = vapply(resources, json_chr, character(1), "title"),
    description = vapply(resources, json_chr, character(1), "description"),
    topic = vapply(resources, json_chr, character(1), "topic"),
    frequency = vapply(resources, json_chr, character(1), "frequency"),
    geography = vapply(resources, json_chr, character(1), "geography"),
    reference_start = do.call(c, c(list(as.Date(character(0))),
                                   lapply(resources, json_date, "reference_start"))),
    reference_end = do.call(c, c(list(as.Date(character(0))),
                                 lapply(resources, json_date, "reference_end"))),
    release_date = do.call(c, c(list(as.Date(character(0))),
                                lapply(resources, json_date, "release_date"))),
    access = vapply(resources, json_chr, character(1), "access"),
    source_id = rep(source$source_id, length(resources)),
    source_url = vapply(resources, json_chr, character(1), "source_url")
  )

  new_knbs_catalogue(
    out,
    new_knbs_metadata(
      title = "Offline fixture catalogue",
      resource_type = "catalogue",
      source_id = source$source_id,
      source_name = source$source_name,
      producer = source$owner,
      access = "public"
    )
  )
}

#' @export
source_metadata.knbs_source_fake <- function(source, resource_id, ...) {
  check_operation(source, "survey_metadata")
  resource <- fake_resource(resource_id, source$source_id)

  path <- fake_file(paste0("study-", resource_id, ".json"))
  if (!file.exists(path)) {
    knbs_abort(
      c(
        "No detailed metadata fixture for {.val {resource_id}}.",
        "i" = "The catalogue lists it, but the source exposes no study record."
      ),
      class = "knbs_error_resource_not_found"
    )
  }
  record <- parse_json_file(path, source_id = source$source_id)

  new_knbs_metadata(
    title = json_chr(record, "title"),
    resource_id = json_chr(record, "resource_id"),
    resource_type = json_chr(record, "resource_type"),
    source_id = source$source_id,
    source_name = source$source_name,
    source_url = json_chr(resource, "source_url"),
    producer = json_chr(record, "producer"),
    release_date = json_date(record, "release_date"),
    reference_period = json_chr(record, "reference_period"),
    version = json_chr(record, "version"),
    revision_status = json_chr(record, "revision_status"),
    geographic_level = json_chr(record, "geographic_level"),
    licence = json_chr(record, "licence"),
    access = json_chr(record, "access"),
    citation = json_chr(record, "citation"),
    notes = json_chr_vec(record, "notes"),
    raw = record
  )
}

#' @export
source_files.knbs_source_fake <- function(source, resource_id, ...) {
  check_operation(source, "files")
  resource <- fake_resource(resource_id, source$source_id)
  fake_check_access(resource)

  path <- fake_file(paste0("files-", resource_id, ".json"))
  if (!file.exists(path)) {
    knbs_abort(
      c("No file listing for {.val {resource_id}}."),
      class = "knbs_error_resource_not_found"
    )
  }
  files <- parse_json_file(path, source_id = source$source_id)$files

  tibble::tibble(
    file_id = vapply(files, json_chr, character(1), "file_id"),
    file_name = vapply(files, json_chr, character(1), "file_name"),
    file_type = vapply(files, json_chr, character(1), "file_type"),
    format = vapply(files, json_chr, character(1), "format"),
    size = vapply(files, json_int, integer(1), "size"),
    access = vapply(files, json_chr, character(1), "access"),
    downloadable = vapply(files, function(f) isTRUE(f$downloadable), logical(1)),
    download_url = vapply(files, json_chr, character(1), "download_url"),
    checksum = vapply(files, json_chr, character(1), "checksum")
  )
}

#' @export
source_fetch.knbs_source_fake <- function(source, query, ...,
                                          cache = knbs_option("cache"),
                                          refresh = FALSE) {
  check_operation(source, "get_indicator")
  check_supported_filters(query, c("start", "end", "geo_code"))

  resource_id <- query$resource_id
  if (is.null(resource_id)) {
    knbs_abort(
      c("A resource id is required to fetch data.",
        "i" = "Set {.arg resource_id} on the query."),
      class = "knbs_error_invalid_query"
    )
  }
  resource <- fake_resource(resource_id, source$source_id)
  fake_check_access(resource)

  key <- cache_key(source$source_id, "fetch", query)
  payload <- cache_fetch(
    key,
    fetch = function() {
      path <- fake_file(paste0("data-", resource_id, ".json"))
      if (!file.exists(path)) {
        knbs_abort(
          c("No data fixture for {.val {resource_id}}."),
          class = "knbs_error_resource_not_found"
        )
      }
      parse_json_file(path, source_id = source$source_id)
    },
    cache = cache,
    refresh = refresh,
    ttl = knbs_cache_ttl("data"),
    info = list(
      source_id = source$source_id,
      operation = "fetch",
      resource_id = resource_id
    )
  )

  obs <- payload$observations
  out <- tibble::tibble(
    indicator_id = rep(json_chr(payload, "indicator_id"), length(obs)),
    indicator_name = rep(json_chr(payload, "indicator_name"), length(obs)),
    period = vapply(obs, json_chr, character(1), "period"),
    # A missing value keeps its meaning in observation_status rather than
    # collapsing to a bare NA (plan section 17.3).
    value = vapply(obs, function(o) {
      v <- o$value
      if (is.null(v)) NA_real_ else as.numeric(v)
    }, numeric(1)),
    observation_status = vapply(obs, json_chr, character(1), "status"),
    unit = rep(json_chr(payload, "unit"), length(obs)),
    frequency = rep(json_chr(payload, "frequency"), length(obs)),
    # Geographic codes are always character; 047 must never become 47.
    geo_code = vapply(obs, json_chr, character(1), "geo_code"),
    geo_name = vapply(obs, json_chr, character(1), "geo_name"),
    source_id = rep(source$source_id, length(obs)),
    release_date = rep(json_date(payload, "release_date"), length(obs))
  )

  filters <- query$filters
  if (!is.null(filters$start)) out <- out[out$period >= as.character(filters$start), ]
  if (!is.null(filters$end)) out <- out[out$period <= as.character(filters$end), ]
  if (!is.null(filters$geo_code)) out <- out[out$geo_code %in% as.character(filters$geo_code), ]

  new_knbs_data(
    out,
    new_knbs_metadata(
      title = json_chr(payload, "indicator_name"),
      resource_id = resource_id,
      resource_type = "indicator",
      source_id = source$source_id,
      source_name = source$source_name,
      source_url = json_chr(resource, "source_url"),
      producer = source$owner,
      release_date = json_date(payload, "release_date"),
      reference_period = paste(range(out$period), collapse = " to "),
      unit = json_chr(payload, "unit"),
      frequency = json_chr(payload, "frequency"),
      access = json_chr(resource, "access"),
      raw = payload
    ),
    class = "knbs_indicator"
  )
}

#' @export
source_health.knbs_source_fake <- function(source, ...) {
  tibble::tibble(
    source_id = source$source_id,
    operation = "fixtures",
    status = if (file.exists(fake_file("catalogue.json"))) "ok" else "unavailable",
    http_status = NA_integer_,
    response_time_ms = 0,
    checked_at = Sys.time(),
    message = "Offline fixtures; no request made."
  )
}
