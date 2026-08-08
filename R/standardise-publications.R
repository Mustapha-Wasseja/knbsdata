# Publication standardisation -------------------------------------------------
#
# WordPress media records are translated into the canonical publication schema
# (plan section 9.5) here, so the adapter stays thin.

knbs_publication_columns <- function() {
  c(
    "publication_id", "title", "year", "release_date", "modified", "description",
    "format", "file_size", "file_name", "download_url", "landing_page",
    "source_id", "checksum", "access"
  )
}

# Formats users name -> the mime types WordPress stores.
knbs_publication_formats <- function() {
  c(
    pdf = "application/pdf",
    xlsx = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    xls = "application/vnd.ms-excel",
    docx = "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    csv = "text/csv",
    zip = "application/zip"
  )
}

mime_to_format <- function(mime) {
  formats <- knbs_publication_formats()
  hit <- names(formats)[match(mime, formats)]
  ifelse(is.na(hit), mime, hit)
}

# WordPress renders titles with HTML entities (&#8211; and friends) and wraps
# descriptions in markup. Decode the handful of entities that actually occur;
# a full HTML parser is not warranted for this.
wp_text <- function(x) {
  text <- json_chr(x, "rendered")
  if (is.na(text)) {
    return(NA_character_)
  }
  text <- gsub("<[^>]+>", "", text)
  entities <- c(
    "&#8211;" = "-", "&#8212;" = "-", "&#8216;" = "'", "&#8217;" = "'",
    "&#8220;" = "\"", "&#8221;" = "\"", "&amp;" = "&", "&nbsp;" = " ",
    "&#038;" = "&", "&#8230;" = "..."
  )
  for (entity in names(entities)) {
    text <- gsub(entity, entities[[entity]], text, fixed = TRUE)
  }
  trimws(text)
}

# The reference year is taken from the title, where KNBS conventionally leads
# with it ("2026 Economic Survey", "2025/26 ..."). The upload date is NOT used:
# a re-uploaded older report carries a recent date (audit F-13). No year in the
# title means NA, not a guess.
title_year <- function(title) {
  out <- rep(NA_integer_, length(title))
  searchable <- !is.na(title)
  match_at <- regexpr("(19|20)[0-9]{2}", title[searchable])
  hits <- match_at != -1L
  out[searchable][hits] <- as.integer(regmatches(title[searchable], match_at))
  out
}

#' Standardise WordPress media records into the publication schema
#' @noRd
standardise_wp_publications <- function(records, source_id) {
  n <- length(records)
  titles <- vapply(records, function(r) wp_text(r$title), character(1))

  tibble::tibble(
    publication_id = vapply(records, function(r) as.character(r$id), character(1)),
    title = titles,
    year = title_year(titles),
    release_date = do.call(c, c(list(as.Date(character(0))),
                                lapply(records, json_date, "date"))),
    modified = do.call(c, c(list(as.Date(character(0))),
                            lapply(records, json_date, "modified"))),
    description = vapply(records, function(r) wp_text(r$description), character(1)),
    format = mime_to_format(vapply(records, json_chr, character(1), "mime_type")),
    file_size = vapply(records, function(r) {
      v <- r$filesize
      if (is.null(v)) NA_real_ else as.numeric(v)
    }, numeric(1)),
    file_name = vapply(records, json_chr, character(1), "filename"),
    download_url = vapply(records, json_chr, character(1), "source_url"),
    landing_page = vapply(records, json_chr, character(1), "link"),
    source_id = rep(source_id, n),
    checksum = rep(NA_character_, n),
    access = rep("open", n)
  )
}
