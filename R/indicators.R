# Indicators: public interface ------------------------------------------------

#' List available aggregate datasets
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Lists the datasets published by the KNBS census data service, grouped by
#' theme. These are 2019 Population and Housing Census tables — population,
#' health, ICT and household characteristics — released under CC BY 4.0.
#'
#' @details
#' `frequency` and `unit` are `NA` throughout: a census table is not a
#' recurring series, and the source does not state units, so the package does
#' not invent them.
#'
#' @param topic Keep only these themes, for example `"Population"`.
#' @param search Free text matched against dataset names.
#' @param source Source id. Defaults to the first verified source that supports
#'   indicator listing.
#' @param cache Whether to use the local cache.
#' @param refresh Whether to bypass any cached response.
#'
#' @return A `knbs_catalogue` tibble with columns `indicator_id`,
#'   `indicator_name`, `topic`, `frequency`, `unit` and `source_id`.
#'
#' @seealso [knbs_get_indicator()]
#'
#' @examples
#' \dontrun{
#' knbs_indicators()
#' knbs_indicators(topic = "Population")
#' knbs_indicators(search = "marital")
#' }
#' @export
knbs_indicators <- function(topic = NULL,
                            search = NULL,
                            source = NULL,
                            cache = knbs_option("cache"),
                            refresh = FALSE) {
  if (!is.null(topic)) check_character(topic, "topic")
  if (!is.null(search)) check_string(search, "search")

  src <- resolve_source("list_indicators", source)
  query <- new_knbs_query(
    "indicator",
    filters = compact_list(list(topic = topic, search = search)),
    source = src$source_id
  )

  cache_fetch(
    cache_key(src$source_id, "list_indicators", query),
    fetch = function() source_search(src, query),
    cache = cache,
    refresh = refresh,
    ttl = knbs_cache_ttl("catalogue"),
    info = list(source_id = src$source_id, operation = "list_indicators")
  )
}

#' Retrieve an aggregate dataset as tidy observations
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Downloads one census dataset and returns it as one row per cell: geography
#' and sex where the table has them, the table's other dimensions as columns
#' named by their source ids, and the census reference year as `period`.
#'
#' @details
#' The stable core columns are `indicator_id`, `indicator_name`, `period` and
#' `value`. Geographic columns (`geo_code`, `geo_name`, `geo_level`) appear
#' when the table has a Territory dimension; codes keep their leading zeros,
#' and `geo_level` is `"national"`, `"county"` or `"subcounty"`. A dimension
#' labelled Sex becomes `sex`, using the source's own categories. Every other
#' dimension contributes a `<dim_id>` code column and a `<dim_id>_label`
#' column, exactly as the source names them.
#'
#' @param indicator A dataset id (see [knbs_indicators()]), or enough of a
#'   dataset name to identify one unambiguously.
#' @param geo_level Keep only these levels: `"national"`, `"county"`,
#'   `"subcounty"`.
#' @param geo_code Keep only these territory codes, as character.
#' @param source Source id.
#' @param cache Whether to use the local cache.
#' @param refresh Whether to bypass any cached response.
#'
#' @return A `knbs_indicator` tibble. [knbs_metadata()] returns its provenance,
#'   including the CC BY 4.0 licence statement; [knbs_cite()] cites it.
#'
#' @seealso [knbs_indicators()]
#'
#' @examples
#' \dontrun{
#' pop <- knbs_get_indicator("POPCEN0001", geo_level = "county")
#' knbs_metadata(pop)
#' knbs_cite(pop)
#' }
#' @export
knbs_get_indicator <- function(indicator,
                               geo_level = NULL,
                               geo_code = NULL,
                               source = NULL,
                               cache = knbs_option("cache"),
                               refresh = FALSE) {
  check_string(indicator, "indicator")
  if (!is.null(geo_level)) {
    check_values(geo_level, "geo_level", c("national", "county", "subcounty"))
  }
  if (!is.null(geo_code)) check_character(geo_code, "geo_code")

  src <- resolve_source("get_indicator", source)
  indicator_id <- resolve_indicator(src, indicator, cache = cache, refresh = refresh)

  query <- new_knbs_query(
    "indicator",
    resource_id = indicator_id,
    filters = compact_list(list(geo_level = geo_level, geo_code = geo_code)),
    source = src$source_id
  )

  cache_fetch(
    cache_key(src$source_id, "get_indicator", query),
    fetch = function() source_fetch(src, query),
    cache = cache,
    refresh = refresh,
    ttl = knbs_cache_ttl("data"),
    info = list(source_id = src$source_id, operation = "get_indicator",
                resource_id = indicator_id)
  )
}

#' Resolve a user-supplied indicator reference to a dataset id
#'
#' The id as given if the catalogue knows it; otherwise a name search. One
#' match is used, several are reported, none is a plain not-found.
#'
#' @noRd
resolve_indicator <- function(src, indicator, cache = TRUE, refresh = FALSE,
                              call = rlang::caller_env()) {
  catalogue <- knbs_indicators(source = src$source_id, cache = cache, refresh = refresh)

  if (indicator %in% catalogue$indicator_id) {
    return(indicator)
  }

  hits <- catalogue[grepl(indicator, catalogue$indicator_name, ignore.case = TRUE), ]
  if (nrow(hits) == 0L) {
    knbs_abort(
      c(
        "No dataset matches {.val {indicator}}.",
        "i" = "List what exists with {.fn knbs_indicators}."
      ),
      class = "knbs_error_resource_not_found",
      call = call
    )
  }
  if (nrow(hits) > 1L) {
    knbs_abort(
      c(
        "{.val {indicator}} matches {nrow(hits)} datasets.",
        "i" = "Use an exact {.field indicator_id}:",
        "*" = "{paste(hits$indicator_id, ' - ', substr(hits$indicator_name, 1, 55))}"
      ),
      class = "knbs_error_ambiguous_resource",
      call = call,
      matches = hits$indicator_id
    )
  }
  hits$indicator_id[[1]]
}
