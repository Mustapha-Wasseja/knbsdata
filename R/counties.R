# County matching --------------------------------------------------------------

#' Official county codes for county names written any way
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Turns county names — or county numbers — as they appear in anyone's data
#' into the official two-digit codes of the 2019 census frame, the codes
#' [knbs_geographies()] and the census tables use. Built for `mutate()`:
#'
#' ```r
#' my_data |> mutate(geo_code = knbs_county_code(county))
#' ```
#'
#' KNBS's own sources disagree on names: the census writes "Murang'a",
#' "Tharaka-Nithi" and "Nairobi City", the Data Portal "MURANGA", "THARAKA
#' NITHI" and "NAIROBI". Both, and the usual variants elsewhere, resolve to
#' the same codes.
#'
#' @details
#' A name matches when it is the official name once case, punctuation,
#' spacing and apostrophes are set aside and the words "County", "City",
#' "Government", "of" and "the" are dropped: "Taita Taveta", "TAITA/TAVETA"
#' and "Taita-Taveta County" are all `"06"`, "Nairobi" and "Nairobi City
#' County" both `"47"`. A number from 1 to 47, written `1`, `"1"` or
#' `"01"`, is taken as the county number. "Kenya" and "National" give the
#' census code for the whole country, `"00"`.
#'
#' Nothing else is matched. There is no list of alternative names, so a
#' misspelling stays unmatched rather than being guessed at; the warning
#' names each unmatched value and, where one official name is close, says
#' which. [knbs_match_counties()] shows how every value was matched.
#'
#' The official names are read from the census frame through
#' [knbs_geographies()], once, and cached. If the census service cannot be
#' reached, the 47 counties' statutory names and numbers built into the
#' package are used instead; they are the census frame's own, and the
#' package's tests hold them identical.
#'
#' @param x County names or numbers: a character, numeric or factor vector.
#' @param vintage The census frame to match against. Only 2019 is available.
#' @param cache Whether to use the local cache for the reference names.
#' @param refresh Whether to re-read the reference names.
#'
#' @return A character vector the length of `x`, holding two-digit codes, and
#'   `NA` where a value did not match.
#'
#' @seealso [knbs_match_counties()], [knbs_geographies()]
#'
#' @examples
#' \dontrun{
#' knbs_county_code(c("Murang'a", "MURANGA", "Nairobi", "taita/taveta", "47"))
#' #> [1] "21" "21" "47" "06" "47"
#' }
#' @export
knbs_county_code <- function(x, vintage = 2019L,
                             cache = knbs_option("cache"), refresh = FALSE) {
  matched <- county_match(x, vintage = vintage, cache = cache,
                          refresh = refresh)
  county_warn_unmatched(matched)
  unname(matched$geo_code[match(county_input_key(x), matched$key_input)])
}

#' See how county names were matched
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' The diagnostic companion to [knbs_county_code()]: one row per distinct
#' value of `x`, saying which county it matched, how, and — for a value that
#' matched nothing — the official name it most resembles, if any.
#'
#' @inheritParams knbs_county_code
#'
#' @return A tibble with columns `input`, `geo_code`, `geo_name` (the
#'   official name), `matched_by` (`"name"`, `"number"`, `"national"`, or
#'   `NA`) and `suggestion` (for unmatched values only).
#'
#' @seealso [knbs_county_code()]
#'
#' @examples
#' \dontrun{
#' knbs_match_counties(c("Nairobi City County", "Kakamenga", "12"))
#' }
#' @export
knbs_match_counties <- function(x, vintage = 2019L,
                                cache = knbs_option("cache"), refresh = FALSE) {
  matched <- county_match(x, vintage = vintage, cache = cache,
                          refresh = refresh)
  matched[, c("input", "geo_code", "geo_name", "matched_by", "suggestion")]
}

# Internals --------------------------------------------------------------------

#' The official counties of a census frame
#'
#' Read through knbs_geographies() so that the reference is the census
#' frame's own, with the same vintage handling. When the census service
#' cannot be reached, the 47 counties' statutory names and numbers stand in:
#' the 2019 frame codes its counties by the Constitution's First Schedule,
#' and a test holds the two lists identical. A source that answers wrongly
#' still raises its own error; only unavailability falls back. Mocked in
#' tests.
#'
#' @noRd
county_reference <- function(vintage, cache, refresh) {
  tryCatch(
    {
      geo <- knbs_geographies(level = "county", vintage = vintage,
                              cache = cache, refresh = refresh)
      tibble::tibble(geo_code = geo$geo_code, geo_name = geo$geo_name)
    },
    knbs_error_source_unavailable = function(cnd) {
      if (!identical(as.integer(vintage), 2019L)) {
        rlang::cnd_signal(cnd)
      }
      county_statutory()
    }
  )
}

#' The 47 counties as the 2019 census frame names and numbers them
#'
#' Numbered by the First Schedule of the Constitution of Kenya, as the census
#' frame codes them; spelled as the census API spells them.
#'
#' @noRd
county_statutory <- function() {
  tibble::tibble(
    geo_code = sprintf("%02d", 1:47),
    geo_name = c(
      "Mombasa", "Kwale", "Kilifi", "Tana River", "Lamu", "Taita/Taveta",
      "Garissa", "Wajir", "Mandera", "Marsabit", "Isiolo", "Meru",
      "Tharaka-Nithi", "Embu", "Kitui", "Machakos", "Makueni", "Nyandarua",
      "Nyeri", "Kirinyaga", "Murang'a", "Kiambu", "Turkana", "West Pokot",
      "Samburu", "Trans Nzoia", "Uasin Gishu", "Elgeyo/Marakwet", "Nandi",
      "Baringo", "Laikipia", "Nakuru", "Narok", "Kajiado", "Kericho", "Bomet",
      "Kakamega", "Vihiga", "Bungoma", "Busia", "Siaya", "Kisumu", "Homa Bay",
      "Migori", "Kisii", "Nyamira", "Nairobi City"
    )
  )
}

#' Reduce a county name to its matching key
#'
#' Lower case; apostrophes, straight or curly, removed (Murang'a, Muranga); every other
#' non-alphanumeric run a word break; the words county, city, government,
#' of and the dropped; what remains joined without spaces, so spacing,
#' hyphens and slashes cannot matter.
#'
#' @noRd
county_key <- function(x) {
  x <- tolower(as.character(x))
  # Curly apostrophes by code point, so the source stays ASCII.
  apostrophes <- paste0("[", intToUtf8(c(0x2018, 0x2019), multiple = FALSE), "'`]")
  x <- gsub(apostrophes, "", x)
  x <- gsub("&", " and ", x, fixed = TRUE)
  x <- gsub("[^a-z0-9]+", " ", x)
  drop <- c("county", "city", "government", "of", "the")
  vapply(strsplit(trimws(x), " +"), function(w) {
    paste(w[!w %in% drop], collapse = "")
  }, character(1))
}

#' The key an input value is looked up by
#'
#' Kept distinct from county_key() so that NA stays NA, and a number keeps
#' its numeric reading: 1, "1" and "01" are one key.
#'
#' @noRd
county_input_key <- function(x) {
  if (is.factor(x)) {
    x <- as.character(x)
  }
  out <- county_key(x)
  number <- suppressWarnings(as.integer(trimws(as.character(x))))
  is_number <- !is.na(number) & grepl("^\\s*[0-9]+\\s*$", as.character(x))
  out[is_number] <- sprintf("#%d", number[is_number])
  out[is.na(x)] <- NA_character_
  out
}

#' Match the distinct values of x against the official counties
#' @noRd
county_match <- function(x, vintage, cache, refresh, call = rlang::caller_env()) {
  if (!(is.character(x) || is.numeric(x) || is.factor(x) || all(is.na(x)))) {
    knbs_abort(
      c(
        "{.arg x} must be county names or numbers.",
        "x" = "Got {.obj_type_friendly {x}}."
      ),
      class = "knbs_error_invalid_argument",
      call = call
    )
  }
  reference <- county_reference(vintage, cache, refresh)
  ref_key <- county_key(reference$geo_name)
  if (anyDuplicated(ref_key) > 0L) {
    knbs_abort(
      c(
        "Two official county names reduce to the same key.",
        "i" = "Matching would be ambiguous; please report it."
      ),
      class = "knbs_error_validation_failed",
      call = call
    )
  }
  ref_number <- as.integer(reference$geo_code)

  keys <- county_input_key(x)
  first <- !duplicated(keys)
  input <- as.character(x)[first]
  key <- keys[first]

  geo_code <- rep(NA_character_, length(key))
  matched_by <- rep(NA_character_, length(key))

  by_name <- match(key, ref_key)
  geo_code[!is.na(by_name)] <- reference$geo_code[by_name[!is.na(by_name)]]
  matched_by[!is.na(by_name)] <- "name"

  is_number <- !is.na(key) & startsWith(key, "#")
  by_number <- match(suppressWarnings(as.integer(sub("^#", "", key))), ref_number)
  hit <- is_number & !is.na(by_number)
  geo_code[hit] <- reference$geo_code[by_number[hit]]
  matched_by[hit] <- "number"

  national <- !is.na(key) & key %in% c("kenya", "national") & is.na(geo_code)
  geo_code[national] <- "00"
  matched_by[national] <- "national"

  geo_name <- reference$geo_name[match(geo_code, reference$geo_code)]
  geo_name[national] <- "Kenya"

  tibble::tibble(
    input = input,
    key_input = key,
    geo_code = geo_code,
    geo_name = geo_name,
    matched_by = matched_by,
    suggestion = county_suggest(key, is.na(geo_code) & !is.na(key) & !is_number,
                                ref_key, reference$geo_name)
  )
}

#' The official name an unmatched key most resembles, if one is close
#'
#' Close means within two edits, or a quarter of the name's length for
#' longer names, and nearer than any other county. Only ever a suggestion.
#'
#' @noRd
county_suggest <- function(key, unmatched, ref_key, ref_name) {
  out <- rep(NA_character_, length(key))
  for (i in which(unmatched)) {
    d <- as.vector(utils::adist(key[[i]], ref_key))
    best <- which(d == min(d))
    if (length(best) == 1L && d[[best]] <= max(2L, nchar(key[[i]]) %/% 4L)) {
      out[[i]] <- ref_name[[best]]
    }
  }
  out
}

#' Warn once about every value that matched nothing
#' @noRd
county_warn_unmatched <- function(matched, call = rlang::caller_env()) {
  missing <- matched[is.na(matched$geo_code) & !is.na(matched$key_input), ]
  if (nrow(missing) == 0L) {
    return(invisible(NULL))
  }
  # Values are the caller's data, not templates: braces are doubled so the
  # message formatter prints them rather than evaluating them.
  literal <- function(s) gsub("([{}])", "\\1\\1", s)
  shown <- ifelse(
    is.na(missing$suggestion),
    paste0("\"", literal(missing$input), "\""),
    paste0("\"", literal(missing$input), "\" (did you mean \"",
           literal(missing$suggestion), "\"?)")
  )
  knbs_warn(
    c(
      "{nrow(missing)} value{?s} matched no county and became {.code NA}:",
      stats::setNames(utils::head(shown, 10L), rep("*", min(10L, length(shown)))),
      if (length(shown) > 10L) c("i" = "... and {length(shown) - 10L} more."),
      "i" = "See every match with {.fn knbs_match_counties}."
    ),
    class = "knbs_warning_unmatched",
    unmatched = missing$input,
    call = call
  )
}
