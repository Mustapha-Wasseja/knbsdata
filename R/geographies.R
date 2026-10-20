# Geographic reference codes --------------------------------------------------
#
# The reference comes from the census API's Territory dimension (audit F-20):
# every census table carries the full coded, named hierarchy, so the codes are
# read from a designated table's dimension rather than shipped as a snapshot
# that could drift from the source.

# The table whose Territory dimension is read. Any census table carries the
# same dimension; this one is the smallest with full coverage.
census_geo_reference_dataset <- function() "POPCEN0001"

knbs_geography_columns <- function() {
  c("geo_code", "geo_name", "geo_level", "parent_code", "parent_name",
    "vintage", "source_id")
}

#' Standardise a territory code list into the geography schema
#'
#' Parenthood is structural, not inferred: a sub-county code embeds its county
#' in its first two digits, and counties belong to the nation. Codes whose
#' level is unrecognised get `NA` parents rather than a guess.
#'
#' @param codes Character territory codes, in source order.
#' @param labels Named character map of code -> name.
#' @noRd
standardise_census_geographies <- function(codes, labels, source_id,
                                           call = rlang::caller_env()) {
  if (anyDuplicated(codes) > 0L) {
    knbs_abort(
      c("The source's territory codes contain duplicates.",
        "i" = "This means the dimension changed shape; please report it."),
      class = "knbs_error_validation_failed",
      call = call
    )
  }

  level <- census_geo_level(codes)
  name <- unname(labels[codes])
  name[is.na(name)] <- codes[is.na(name)]

  parent_code <- rep(NA_character_, length(codes))
  parent_code[level == "county"] <- "00"
  parent_code[level == "subcounty"] <- substr(codes[level == "subcounty"], 1L, 2L)

  lookup <- stats::setNames(name, codes)
  parent_name <- unname(lookup[parent_code])

  out <- tibble::tibble(
    geo_code = as.character(codes),
    geo_name = name,
    geo_level = level,
    parent_code = parent_code,
    parent_name = parent_name,
    vintage = rep(2019L, length(codes)),
    source_id = rep(source_id, length(codes))
  )

  # A sub-county whose county is missing means the hierarchy is broken at the
  # source, and joins built on it would quietly drop rows.
  orphaned <- out$geo_level == "subcounty" & is.na(out$parent_name)
  if (any(orphaned, na.rm = TRUE)) {
    knbs_abort(
      c(
        "{sum(orphaned)} sub-count{?y/ies} reference a county the source did not list.",
        "x" = "For example {.val {utils::head(out$geo_code[orphaned], 3)}}.",
        "i" = "This means the dimension changed shape; please report it."
      ),
      class = "knbs_error_validation_failed",
      call = call
    )
  }
  out
}

#' @export
source_geographies.knbs_source_indicators <- function(source, ...) {
  check_operation(source, "geographies")
  check_source_verified(source)

  payload <- indicators_get(
    source, "getDataset",
    list(id = census_geo_reference_dataset(), type = "jsonstat")
  )
  # Only the Territory dimension is needed; the values are not expanded.
  if (!identical(payload[["class"]], "dataset") || is.null(payload$dimension)) {
    knbs_abort(
      c("The geography reference table is not a JSON-stat dataset any more.",
        "i" = "The endpoint has probably changed; please report it."),
      class = "knbs_error_schema_changed"
    )
  }

  dim_ids <- as.character(unlist(payload$id))
  dim_labels <- vapply(
    dim_ids,
    function(d) json_chr(payload$dimension[[d]], "label", default = d),
    character(1)
  )
  geo_dim <- dim_ids[tolower(dim_labels) %in% c("territory", "geography", "area")]
  if (length(geo_dim) != 1L) {
    knbs_abort(
      c("The reference table no longer carries a Territory dimension.",
        "i" = "The endpoint has probably changed; please report it."),
      class = "knbs_error_schema_changed"
    )
  }

  sizes <- as.integer(unlist(payload$size))
  codes <- jsonstat_codes(
    payload$dimension[[geo_dim]], geo_dim,
    expected = sizes[[match(geo_dim, dim_ids)]]
  )
  labels <- jsonstat_labels(payload$dimension[[geo_dim]])

  new_knbs_data(
    standardise_census_geographies(codes, labels, source$source_id),
    new_knbs_metadata(
      title = "Kenya territorial codes, 2019 census frame",
      resource_id = census_geo_reference_dataset(),
      resource_type = "geography",
      source_id = source$source_id,
      source_name = source$source_name,
      source_url = source$landing_page %||% source$base_url,
      producer = source$owner,
      release_date = json_date(payload, "updated"),
      reference_period = json_chr(payload, "source"),
      licence = "CC BY 4.0 (stated on the portal)",
      access = "open",
      notes = paste(
        "Codes and names read from the Territory dimension of census table",
        census_geo_reference_dataset()
      )
    ),
    class = "knbs_geography"
  )
}

#' Kenya's geographic reference codes
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Returns the coded territorial hierarchy used by the 2019 Population and
#' Housing Census: Kenya, its 47 counties, and their sub-counties, with names
#' and parent codes. These are the join keys the census tables themselves use,
#' read live from the same source (CC BY 4.0), never shipped as a snapshot
#' that could drift from it.
#'
#' @details
#' Codes are character and keep their leading zeros: `"00"` is Kenya, two
#' digits are counties, four digits are sub-counties, and a sub-county's first
#' two digits are its county. `vintage` is `2019` throughout — these are the
#' census-frame units, and boundaries or units may have changed since. No
#' other vintage, and no crosswalk to other coding systems, is offered,
#' because none has been verified.
#'
#' @param level Keep only these levels: `"national"`, `"county"`,
#'   `"subcounty"`.
#' @param vintage Reference frame year. Only `2019` is available; the argument
#'   exists so that code written today keeps meaning the same thing if other
#'   vintages arrive later.
#' @param parent Keep only units whose `parent_code` is one of these, for
#'   example `"01"` for Mombasa's sub-counties.
#' @param source Source id.
#' @param cache Whether to use the local cache.
#' @param refresh Whether to bypass any cached response.
#'
#' @return A `knbs_geography` tibble with columns `geo_code`, `geo_name`,
#'   `geo_level`, `parent_code`, `parent_name`, `vintage` and `source_id`.
#'
#' @seealso [knbs_get_indicator()], whose observations carry the same codes.
#'
#' @examplesIf interactive()
#' counties <- knbs_geographies(level = "county")
#' knbs_geographies(parent = "01")
#' @export
knbs_geographies <- function(level = NULL,
                             vintage = NULL,
                             parent = NULL,
                             source = NULL,
                             cache = knbs_option("cache"),
                             refresh = FALSE) {
  if (!is.null(level)) {
    check_values(level, "level", c("national", "county", "subcounty"))
  }
  if (!is.null(vintage) && !identical(as.integer(vintage), 2019L)) {
    knbs_abort(
      c(
        "Only the 2019 census frame is available.",
        "x" = "Asked for vintage {.val {vintage}}.",
        "i" = "No other vintage has a verified source; see the county-data vignette."
      ),
      class = "knbs_error_resource_not_found"
    )
  }
  if (!is.null(parent)) check_character(parent, "parent")

  src <- resolve_source("geographies", source)
  out <- cache_fetch(
    cache_key(src$source_id, "geographies",
              resource_id = census_geo_reference_dataset()),
    fetch = function() source_geographies(src),
    cache = cache,
    refresh = refresh,
    ttl = knbs_cache_ttl("data"),
    info = list(source_id = src$source_id, operation = "geographies",
                resource_id = census_geo_reference_dataset())
  )

  if (!is.null(level)) {
    out <- out[out$geo_level %in% level, ]
  }
  if (!is.null(parent)) {
    out <- out[!is.na(out$parent_code) & out$parent_code %in% as.character(parent), ]
  }
  out
}
