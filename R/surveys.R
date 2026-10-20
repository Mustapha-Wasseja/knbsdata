# Survey catalogue: public interface ------------------------------------------

#' Search official survey and census studies
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Searches the study catalogue of a supported survey archive and returns one
#' row per study.
#'
#' @details
#' Some catalogue fields — `acronym`, `geographic_coverage` and
#' `unit_of_analysis` — are not carried in search results and come back as `NA`.
#' They are held in the study record, which [knbs_survey_metadata()] retrieves.
#' Filling them here would mean one extra request per row.
#'
#' @param query Free-text search. `NULL` returns the whole catalogue.
#' @param year A single year, or `c(from, to)` for a range. Matched against the
#'   study's reference years; a study spanning several years matches if any of
#'   them falls in the range. Studies the source records no reference year for
#'   cannot match, so they are excluded with a `knbs_warning_missing_metadata`
#'   warning that says how many, and names them in its `excluded` field.
#' @param producer Keep only studies whose producing entity contains this text.
#' @param access Keep only these access types; see the `access_type` column.
#' @param limit Maximum number of studies to return, counted after the
#'   `year`, `producer` and `access` filters.
#' @param source Source id. Defaults to the first verified source that supports
#'   survey search.
#' @param cache Whether to use the local cache.
#' @param refresh Whether to bypass any cached response.
#'
#' @return A `knbs_catalogue` tibble with columns `survey_id`, `title`,
#'   `acronym`, `reference_years`, `country`, `producer`,
#'   `geographic_coverage`, `unit_of_analysis`, `access_type`, `catalogue_url`,
#'   `metadata_updated` and `source_id`.
#'
#' @seealso [knbs_survey_metadata()], [knbs_variables()], [knbs_survey_files()]
#'
#' @examplesIf interactive()
#' knbs_search_surveys("household budget")
#' knbs_search_surveys(year = c(2015, 2020), access = "public_use")
#' @export
knbs_search_surveys <- function(query = NULL,
                                year = NULL,
                                producer = NULL,
                                access = NULL,
                                limit = 100,
                                source = NULL,
                                cache = knbs_option("cache"),
                                refresh = FALSE) {
  if (!is.null(query)) check_string(query, "query")
  if (!is.null(producer)) check_string(producer, "producer")
  if (!is.null(access)) check_values(access, "access", knbs_access_types())
  check_number(limit, "limit", min = 1)

  years <- normalise_year_range(year)
  src <- resolve_source("search_surveys", source)

  knbs_query <- new_knbs_query(
    "survey",
    filters = compact_list(list(
      search = query,
      year_from = years$from,
      year_to = years$to,
      limit = as.integer(limit)
    )),
    source = src$source_id
  )

  results <- cached_search(src, knbs_query, cache, refresh)

  # Filters the source cannot apply are applied here, on the standardised
  # columns, so that their meaning is the package's rather than the source's.
  # They need every match, not the page `limit` sized: filtering one page would
  # silently return fewer studies than exist.
  if (!is.null(producer) || !is.null(access) || !is.null(years$from)) {
    results <- search_every_match(src, knbs_query, results, cache, refresh)
  }
  keep <- rep(TRUE, nrow(results))
  if (!is.null(producer)) {
    keep <- keep & grepl(producer, results$producer, ignore.case = TRUE)
  }
  if (!is.null(access)) {
    keep <- keep & results$access_type %in% access
  }
  if (!is.null(years$from)) {
    # The source's year filter also returns every study it holds no year for,
    # so the filter is applied again here. A study without a recorded year
    # cannot be shown to match, so it is excluded, and the user is told.
    in_range <- survey_years_overlap(results$reference_years, years$from, years$to)
    unrecorded <- keep & is.na(in_range)
    keep <- keep & in_range %in% TRUE
    if (any(unrecorded)) {
      knbs_warn(
        c(
          "Excluded {sum(unrecorded)} stud{?y/ies} with no recorded reference year.",
          "i" = "The source returns such studies for any {.arg year}; their years are not guessed from titles.",
          "i" = "Search without {.arg year} to see them; their {.field reference_years} is {.code NA}."
        ),
        class = "knbs_warning_missing_metadata",
        excluded = results$survey_id[unrecorded]
      )
    }
  }
  results <- results[keep, ]
  if (nrow(results) > limit) {
    results <- results[seq_len(limit), ]
  }
  results
}

#' Retrieve the full metadata record for a study
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Retrieves the archive's full descriptive record for one study.
#'
#' @param survey A study identifier, or enough of its title to identify it
#'   unambiguously.
#' @param include Which descriptive sections to keep. The underlying records are
#'   DDI documents, in which sampling, collection and processing all live in one
#'   `method` section, so asking for any of them returns that section.
#' @param source Source id.
#' @param cache Whether to use the local cache.
#' @param refresh Whether to bypass any cached response.
#'
#' @return A `knbs_survey` metadata object. Use [knbs_metadata()] to inspect it
#'   and [knbs_cite()] to cite it.
#'
#' @seealso [knbs_search_surveys()], [knbs_variables()], [knbs_survey_files()]
#'
#' @examplesIf interactive()
#' meta <- knbs_survey_metadata("KEN-KNBS-KIHBS-2015-2016-v01")
#' knbs_cite(meta)
#' @export
knbs_survey_metadata <- function(survey,
                                 include = c("overview", "scope", "sampling",
                                             "collection", "processing",
                                             "access", "citation"),
                                 source = NULL,
                                 cache = knbs_option("cache"),
                                 refresh = FALSE) {
  check_string(survey, "survey")
  include <- match.arg(include, several.ok = TRUE)
  src <- resolve_source("survey_metadata", source)

  meta <- resolve_survey(src, survey, cache = cache, refresh = refresh)

  wanted <- unique(unlist(survey_section_map()[include], use.names = FALSE))
  meta$sections <- meta$sections[intersect(names(meta$sections), wanted)]
  meta
}

#' Search the variables described by a study
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Returns variable metadata only. No microdata are downloaded, and none can be:
#' the package does not fetch gated files.
#'
#' @details
#' Question text, universe, concept and value labels each require one request
#' per variable, so they are `NA` unless `details = TRUE`.
#'
#' @param survey A study identifier, or enough of its title to identify it.
#' @param search Free text matched against variable names and labels.
#' @param file Keep only variables from this file, by file id or file name.
#' @param name Exact variable name.
#' @param concept Keep only variables with this concept. Requires
#'   `details = TRUE`, since concepts are only in the per-variable records.
#' @param limit Maximum number of variables to return.
#' @param details Whether to retrieve the full record for each variable. This
#'   costs one request per variable, so it is capped at 100 rows.
#' @param source Source id.
#' @param cache Whether to use the local cache.
#' @param refresh Whether to bypass any cached response.
#'
#' @return A tibble of variable metadata. A study catalogued without variable
#'   documentation returns zero rows, which is a normal answer rather than an
#'   error.
#'
#' @seealso [knbs_survey_files()], [knbs_survey_metadata()]
#'
#' @examplesIf interactive()
#' knbs_variables("KEN-KNBS-KIHBS-2015-2016-v01", search = "consumption")
#' @export
knbs_variables <- function(survey,
                           search = NULL,
                           file = NULL,
                           name = NULL,
                           concept = NULL,
                           limit = Inf,
                           details = FALSE,
                           source = NULL,
                           cache = knbs_option("cache"),
                           refresh = FALSE) {
  check_string(survey, "survey")
  if (!is.null(search)) check_string(search, "search")
  if (!is.null(file)) check_string(file, "file")
  if (!is.null(name)) check_string(name, "name")
  if (!is.null(concept)) check_string(concept, "concept")
  check_bool(details, "details")
  if (!is.null(concept) && !details) {
    knbs_abort(
      c(
        "Filtering by {.arg concept} needs the full variable records.",
        "i" = "Set {.code details = TRUE}, narrowing with {.arg search} or {.arg file} first."
      ),
      class = "knbs_error_invalid_query"
    )
  }

  src <- resolve_source("variables", source)
  survey_id <- resolve_survey(src, survey, cache = cache, refresh = refresh)$resource_id

  variables <- cached_operation(src, "variables", survey_id, cache, refresh,
                                function() source_variables(src, survey_id))
  if (nrow(variables) == 0L) {
    return(variables)
  }

  # File names live in the file listing, not the variable listing.
  files <- try_files(src, survey_id, cache = cache, refresh = refresh)
  if (nrow(files) > 0L) {
    variables$file_name <- files$file_name[match(variables$file_id, files$file_id)]
  }

  keep <- rep(TRUE, nrow(variables))
  if (!is.null(search)) {
    haystack <- paste(variables$variable_name, variables$variable_label)
    keep <- keep & grepl(search, haystack, ignore.case = TRUE)
  }
  if (!is.null(name)) {
    keep <- keep & tolower(variables$variable_name) == tolower(name)
  }
  if (!is.null(file)) {
    keep <- keep & (variables$file_id == file |
                      (!is.na(variables$file_name) & variables$file_name == file))
  }
  variables <- variables[keep, ]

  if (is.finite(limit) && nrow(variables) > limit) {
    variables <- variables[seq_len(limit), ]
  }

  if (details && nrow(variables) > 0L) {
    variables <- add_variable_details(src, survey_id, variables)
    if (!is.null(concept)) {
      variables <- variables[!is.na(variables$concept) &
                               grepl(concept, variables$concept, ignore.case = TRUE), ]
    }
  }
  variables
}

#' List the data files belonging to a study
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Reports what the archive holds and whether the package may retrieve it. At
#' present no supported source permits programmatic download of microdata, so
#' `downloadable` is `FALSE` throughout; use `catalogue_url` from
#' [knbs_search_surveys()] to reach the official access process.
#'
#' @details
#' This lists data files only. Questionnaires, reports and technical documents
#' are out of scope: the archive publishes no machine-readable listing of them,
#' and retrieving them would mean parsing a web page. They are linked from the
#' study's page on the archive, which `catalogue_url` points to.
#'
#' @param survey A study identifier, or enough of its title to identify it.
#' @param type Keep only files of this type.
#' @param access Keep only files with these access types.
#' @param source Source id.
#' @param cache Whether to use the local cache.
#' @param refresh Whether to bypass any cached response.
#'
#' @return A tibble with columns `survey_id`, `file_id`, `file_name`,
#'   `file_type`, `format`, `size`, `case_count`, `var_count`, `access_type`,
#'   `downloadable`, `download_url`, `checksum` and `source_id`.
#'
#' @seealso [knbs_variables()], [knbs_download_microdata()]
#'
#' @examplesIf interactive()
#' knbs_survey_files("KEN-KNBS-KIHBS-2015-2016-v01")
#' @export
knbs_survey_files <- function(survey,
                              type = NULL,
                              access = NULL,
                              source = NULL,
                              cache = knbs_option("cache"),
                              refresh = FALSE) {
  check_string(survey, "survey")
  if (!is.null(type)) check_string(type, "type")
  if (!is.null(access)) check_values(access, "access", knbs_access_types())

  src <- resolve_source("files", source)
  meta <- resolve_survey(src, survey, cache = cache, refresh = refresh)

  files <- cached_operation(src, "files", meta$resource_id, cache, refresh,
                            function() source_files(src, meta$resource_id))
  if (nrow(files) > 0L) {
    files$access_type <- meta$access %||% NA_character_
  }

  if (!is.null(type)) {
    files <- files[files$file_type == type, ]
  }
  if (!is.null(access)) {
    files <- files[files$access_type %in% access, ]
  }
  files
}

#' Download public-use microdata
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' The Kenya National Data Archive gates every download behind an account,
#' and this package does not automate sign-in, licence acceptance or approval
#' workflows, so the function reports what is required and stops.
#'
#' @details
#' It exists so that the refusal is explicit and points at the official process,
#' rather than the operation appearing to be unsupported by oversight.
#'
#' Microdata that their producers publish for anyone are another matter: the
#' FinAccess household and MSE Tracker surveys are listed by
#' [knbs_finaccess_files()] and downloaded by [knbs_download_finaccess()].
#' Files obtained through the archive's own process can be read with
#' [knbs_read_microdata()].
#'
#' @param survey A study identifier.
#' @param files Files to download.
#' @param destination Directory to write to. Unused: nothing is downloaded.
#' @param overwrite Whether to overwrite existing files.
#' @param verify Whether to verify downloads.
#' @param manifest Whether to write a download manifest.
#' @param quiet Whether to suppress progress messages.
#'
#' @return Never returns; raises `knbs_error_authentication_required`.
#'
#' @seealso [knbs_survey_files()] to see what a study holds and on what terms;
#'   [knbs_finaccess_files()] for open microdata.
#'
#' @examples
#' # Raises an error explaining the official access process; contacts nothing.
#' try(knbs_download_microdata("KEN-KNBS-KIHBS-2015-2016-v01"))
#' @export
knbs_download_microdata <- function(survey,
                                    files = NULL,
                                    destination,
                                    overwrite = FALSE,
                                    verify = TRUE,
                                    manifest = TRUE,
                                    quiet = FALSE) {
  check_string(survey, "survey")
  src <- resolve_source("survey_metadata", NULL)
  access_url <- src$landing_page %||% src$base_url

  knbs_abort(
    c(
      "Microdata from {.val {src$source_id}} cannot be downloaded programmatically.",
      "x" = "Every download requires an account with the archive.",
      "i" = "Register and request access at {.url {access_url}}.",
      "i" = "knbsdata does not automate sign-in, licence acceptance or approval workflows.",
      "i" = "Use {.fn knbs_survey_files} to see what the study holds and on what terms.",
      "i" = "Open microdata, the FinAccess surveys, are listed by {.fn knbs_finaccess_files}."
    ),
    class = "knbs_error_authentication_required",
    access_url = access_url,
    survey = survey
  )
}

# Internals -------------------------------------------------------------------

#' Map documentation sections onto the source's own section names
#' @noRd
survey_section_map <- function() {
  list(
    overview = c("title_statement", "authoring_entity", "production_statement",
                 "version_statement", "series_statement"),
    scope = "study_info",
    sampling = "method",
    collection = "method",
    processing = "method",
    access = c("data_access", "distribution_statement"),
    citation = "data_access"
  )
}

#' Turn a user-supplied year or range into from/to
#' @noRd
normalise_year_range <- function(year, call = rlang::caller_env()) {
  if (is.null(year)) {
    return(list(from = NULL, to = NULL))
  }
  if (!is.numeric(year) || length(year) > 2L || anyNA(year)) {
    knbs_abort(
      c(
        "{.arg year} must be a year or a range {.code c(from, to)}.",
        "x" = "Got {.obj_type_friendly {year}} of length {length(year)}."
      ),
      class = "knbs_error_invalid_argument",
      call = call
    )
  }
  list(from = as.integer(min(year)), to = as.integer(max(year)))
}

#' Whether each study's reference years overlap a requested range
#'
#' Reads the standardised `reference_years` (`"2015"` or `"2015-2016"`). A study
#' spanning the range's edge matches, as it does at the source. `NA` where the
#' years are not recorded: such a study cannot be shown to match or not.
#'
#' @noRd
survey_years_overlap <- function(reference_years, from, to) {
  bounds <- strsplit(reference_years, "-", fixed = TRUE)
  first <- suppressWarnings(as.integer(vapply(bounds, `[`, character(1), 1L)))
  last <- suppressWarnings(as.integer(vapply(bounds, function(b) b[[length(b)]], character(1))))
  out <- first <= to & last >= from
  out[is.na(first) | is.na(last)] <- NA
  out
}

#' A catalogue search, through the cache
#' @noRd
cached_search <- function(src, query, cache, refresh) {
  cache_fetch(
    cache_key(src$source_id, "search_surveys", query),
    fetch = function() source_search(src, query),
    cache = cache,
    refresh = refresh,
    ttl = knbs_cache_ttl("catalogue"),
    info = list(source_id = src$source_id, operation = "search_surveys")
  )
}

#' Every study the source matched, when one page did not hold them all
#'
#' The producer, access and year filters are applied client-side, and the
#' page is sized by `limit`. When the source matched more studies than fit,
#' filtering that page would miss matches beyond it: `producer = "Ministry of
#' Health", limit = 20` once returned 2 of 48 studies. It would also
#' undercount the studies a year filter drops for having no year (see
#' `nada_year()`). So every match is asked for in one page, and `limit` is
#' applied afterwards. The archive honours page sizes well beyond its
#' catalogue (observed 2026-10-05).
#'
#' The wider page is cached under its own query. `producer` and `access` are
#' not part of the cache key, so caching it under the caller's query would let
#' an unfiltered search later find a different page there.
#'
#' @noRd
search_every_match <- function(src, query, first, cache, refresh) {
  found <- json_int(knbs_metadata(first)$raw, "found")
  if (is.na(found) || found <= nrow(first)) {
    return(first)
  }
  query$filters$limit <- found
  cached_search(src, query, cache, refresh)
}

#' Resolve a user-supplied study reference to its metadata
#'
#' Tries the identifier as given. If the source does not recognise it, searches
#' the catalogue: one match is used, several are reported so the user can pick
#' (plan section 11.4), none is a plain not-found.
#'
#' @noRd
resolve_survey <- function(src, survey, cache = TRUE, refresh = FALSE,
                           call = rlang::caller_env()) {
  direct <- tryCatch(
    cached_operation(src, "survey_metadata", survey, cache, refresh,
                     function() source_metadata(src, survey)),
    knbs_error_resource_not_found = function(cnd) NULL
  )
  if (!is.null(direct)) {
    return(direct)
  }

  matches <- knbs_search_surveys(query = survey, limit = 25,
                                 source = src$source_id, cache = cache)
  if (nrow(matches) == 0L) {
    knbs_abort(
      c(
        "No study matches {.val {survey}}.",
        "i" = "Search the catalogue with {.fn knbs_search_surveys}."
      ),
      class = "knbs_error_resource_not_found",
      call = call
    )
  }
  if (nrow(matches) > 1L) {
    knbs_abort(
      c(
        "{.val {survey}} matches {nrow(matches)} studies.",
        "i" = "Use an exact {.field survey_id}:",
        "*" = "{matches$survey_id[seq_len(min(8, nrow(matches)))]}"
      ),
      class = "knbs_error_ambiguous_resource",
      call = call,
      matches = matches$survey_id
    )
  }

  cached_operation(src, "survey_metadata", matches$survey_id[[1]], cache, refresh,
                   function() source_metadata(src, matches$survey_id[[1]]))
}

#' Run an adapter operation through the cache
#' @noRd
cached_operation <- function(src, operation, resource_id, cache, refresh, fetch) {
  cache_fetch(
    cache_key(src$source_id, operation, resource_id = resource_id),
    fetch = fetch,
    cache = cache,
    refresh = refresh,
    ttl = knbs_cache_ttl("catalogue"),
    info = list(source_id = src$source_id, operation = operation,
                resource_id = resource_id)
  )
}

#' File listings are decoration when looking up variables, so a failure there
#' must not lose the variables themselves.
#' @noRd
try_files <- function(src, survey_id, cache, refresh) {
  tryCatch(
    cached_operation(src, "files", survey_id, cache, refresh,
                     function() source_files(src, survey_id)),
    knbs_error = function(cnd) {
      knbs_warn(
        c(
          "Could not list the study's files, so file names are missing.",
          "i" = "{conditionMessage(cnd)}"
        ),
        class = "knbs_warning_missing_metadata"
      )
      empty_tibble(knbs_file_columns())
    }
  )
}

#' Fill the per-variable fields, one request each
#' @noRd
add_variable_details <- function(src, survey_id, variables, call = rlang::caller_env()) {
  if (nrow(variables) > 100L) {
    knbs_abort(
      c(
        "{.code details = TRUE} needs one request per variable.",
        "x" = "That would be {nrow(variables)} requests.",
        "i" = "Narrow the selection with {.arg search}, {.arg file} or {.arg limit} (maximum 100)."
      ),
      class = "knbs_error_invalid_query",
      call = call
    )
  }

  for (i in seq_len(nrow(variables))) {
    detail <- source_variable_detail(src, survey_id, variables$variable_id[[i]])
    filled <- standardise_nada_var_detail(variables[i, ], detail)
    # Assign column by column: replacing a whole row would have to carry the
    # value_labels list-column through, which is easy to get subtly wrong.
    variables$question_text[[i]] <- filled$question_text
    variables$universe[[i]] <- filled$universe
    variables$concept[[i]] <- filled$concept
    variables$variable_type[[i]] <- filled$variable_type
    # Wrapped, because a variable with no value labels contributes NULL and
    # `[[<-` with NULL would delete the element rather than empty it.
    variables$value_labels[i] <- list(filled$value_labels[[1]])
  }
  variables
}
