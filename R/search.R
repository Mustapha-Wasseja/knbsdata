# Search across every catalogue -----------------------------------------------

#' Search everything the package can retrieve
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' One search across the indicator catalogues of every verified source, the
#' survey catalogue of the Kenya National Data Archive, the open FinAccess
#' survey microdata, the publications in the KNBS website's media library,
#' and the curated Statistical Abstract tables. Results come back ranked, in
#' one schema, each with the exact call
#' that retrieves it — so finding something and getting it are one copy and
#' paste apart.
#'
#' @details
#' Matching is done by the package, over each catalogue in full, so that it
#' means the same thing everywhere: every word of `query` must appear in a
#' result's title, id or topic. Words match by stem — "index" finds
#' "Indices", "prices" finds "Price" — and a word of four letters or more
#' also matches as the start of a longer one ("agric" finds "Agriculture").
#' A few acronyms common in Kenyan statistics are understood both ways:
#' CPI, GDP, GCP, GVA, PPI, BOP, KDHS, KIHBS and LEI. Common words such as
#' "of" and "the" are ignored.
#'
#' Results are ranked in tiers: an exact id, then an exact title, then the
#' query as a phrase in the title ("consumer price index" is the phrase in
#' "Consumer Price Indices and Inflation Rates"), then every word somewhere
#' in the title, then a match elsewhere. Within a tier, data comes before
#' documents and newer releases before older ones.
#'
#' Catalogues are cached for a day. The first search of the day lists the
#' whole publications library, around 16 requests at the site's polite
#' rate; later searches are instant. If a source cannot be reached its
#' results are missing and a warning names it; the error comes only when no
#' catalogue answers.
#'
#' Geographic codes are not searched here; see [knbs_geographies()].
#'
#' @param query Words to search for.
#' @param type Which kinds of resource to search: any of `"indicator"`,
#'   `"table"`, `"survey"`, `"microdata"` and `"publication"`. All by
#'   default. A `"microdata"` result is one survey round whose data can be
#'   downloaded openly; its `get` call downloads and reads it.
#' @param limit Maximum number of results.
#' @param cache Whether to use the local cache.
#' @param refresh Whether to bypass any cached catalogue.
#'
#' @return A `knbs_catalogue` tibble with one row per result:
#'   `resource_type`, `resource_id`, `title`, `topic`, `period`,
#'   `release_date`, `access`, `source_id`, `url`, and `get` — the R call
#'   that retrieves the resource.
#'
#' @seealso [knbs_indicators()], [knbs_search_surveys()],
#'   [knbs_finaccess_files()], [knbs_publications()], [knbs_abstract_tables()]
#'
#' @examples
#' # The microdata and table catalogues ship with the package: no request
#' knbs_search("financial inclusion", type = "microdata")
#' knbs_search("capital formation", type = "table")
#' @examplesIf interactive()
#' knbs_search("consumer price index")
#' knbs_search("gdp", type = c("indicator", "table"))
#' hits <- knbs_search("county population")
#' hits$get[[1]] # the call that fetches the top result
#' @export
knbs_search <- function(query,
                        type = c("indicator", "table", "survey", "microdata",
                                 "publication"),
                        limit = 50,
                        cache = knbs_option("cache"),
                        refresh = FALSE) {
  check_string(query, "query")
  terms <- search_terms(query)
  if (length(terms) == 0L) {
    knbs_abort(
      c(
        "{.arg query} has no words to search for.",
        "x" = "Got {.val {query}}."
      ),
      class = "knbs_error_invalid_argument"
    )
  }
  type <- unique(as.character(type))
  check_values(type, "type",
               c("indicator", "table", "survey", "microdata", "publication"))
  check_number(limit, "limit", min = 1)

  collectors <- list(
    indicator = function() search_rows_indicators(cache, refresh),
    table = function() search_rows_tables(),
    survey = function() search_rows_surveys(cache, refresh),
    microdata = function() search_rows_microdata(),
    publication = function() search_rows_publications(cache, refresh)
  )

  rows <- list()
  failures <- character(0)
  for (t in type) {
    outcome <- tryCatch(
      withCallingHandlers(
        collectors[[t]](),
        # A partially reachable catalogue (one indicator source down) still
        # answers; its warning is folded into the one this function gives.
        knbs_warning_partial_failure = function(cnd) {
          failures <<- c(failures, search_failed_sources(cnd))
          rlang::cnd_muffle(cnd)
        }
      ),
      knbs_error = function(cnd) cnd
    )
    if (inherits(outcome, "knbs_error")) {
      failures <- c(failures, t)
    } else {
      rows[[t]] <- outcome
    }
  }

  if (length(rows) == 0L) {
    knbs_abort(
      c(
        "No catalogue could be searched.",
        "x" = "Did not answer: {.val {unique(failures)}}."
      ),
      class = "knbs_error_source_unavailable"
    )
  }
  if (length(failures) > 0L) {
    knbs_warn(
      c(
        "Could not search: {.val {unique(failures)}}.",
        "i" = "Results from those catalogues are missing."
      ),
      class = "knbs_warning_partial_failure"
    )
  }

  all_rows <- do.call(rbind, unname(rows))
  scored <- search_score(all_rows, query, terms)
  hits <- scored[!is.na(scored$score), ]
  ord <- order(-hits$score, -search_type_weight(hits$resource_type),
               -as.numeric(hits$release_date), nchar(hits$title),
               na.last = TRUE)
  hits <- hits[ord, ]
  if (nrow(hits) > limit) {
    hits <- hits[seq_len(limit), ]
  }
  hits$score <- NULL
  hits$text <- NULL

  new_knbs_catalogue(
    hits,
    new_knbs_metadata(
      title = paste0("KNBS search results for \"", query, "\""),
      resource_type = "search",
      producer = "Kenya National Bureau of Statistics",
      access = "open",
      notes = c(
        paste0("Searched: ", paste(names(rows), collapse = ", "), "."),
        if (length(failures) > 0L) {
          paste0("Unreachable: ", paste(unique(failures), collapse = ", "), ".")
        },
        "The get column holds the call that retrieves each result."
      )
    )
  )
}

# Internals --------------------------------------------------------------------

#' The columns of a search result, before ranking
#' @noRd
knbs_search_columns <- function() {
  c("resource_type", "resource_id", "title", "topic", "period",
    "release_date", "access", "source_id", "url", "get")
}

#' Words too common to search for
#' @noRd
search_stop_words <- function() {
  c("a", "an", "and", "as", "at", "by", "for", "from", "in", "into", "is",
    "of", "on", "or", "the", "to", "with")
}

#' Acronyms understood both ways
#'
#' Each acronym is equivalent to the phrase it stands for: searching "CPI"
#' finds titles spelling out "Consumer Price Indices", and the reverse.
#' Curated, and kept to terms in everyday use in Kenyan official statistics.
#'
#' @noRd
search_acronyms <- function() {
  c(
    bop = "balance of payments",
    cpi = "consumer price index",
    gcp = "gross county product",
    gdp = "gross domestic product",
    gva = "gross value added",
    kdhs = "demographic and health survey",
    kihbs = "integrated household budget survey",
    lei = "leading economic indicators",
    ppi = "producer price index"
  )
}

#' Reduce a word to a stem for matching
#'
#' Deliberately small: plural endings, irregular plurals that matter in
#' statistical titles, and -ing and -ed. Enough that "index" finds
#' "Indices", "prices" finds "Price" and "stunting" finds "Children
#' stunted", without the surprises of a full stemmer. -ing and -ed come off
#' only where at least four letters remain, and -ed not after another e, so
#' "during", "spring" and "exceed" are left alone.
#'
#' @noRd
search_stem <- function(words) {
  irregular <- c(indices = "index", matrices = "matrix", analyses = "analysis",
                 data = "data", statistics = "statistic")
  out <- words
  hit <- out %in% names(irregular)
  out[hit] <- unname(irregular[out[hit]])
  rest <- !hit & nchar(out) > 3L
  ies <- rest & grepl("ies$", out)
  out[ies] <- sub("ies$", "y", out[ies])
  es <- rest & !ies & grepl("(sh|ch|x|z|ss)es$", out)
  out[es] <- sub("es$", "", out[es])
  # Not -ss (business), -us (census) or -is (analysis).
  s <- rest & !ies & !es & grepl("[^sui]s$", out)
  out[s] <- sub("s$", "", out[s])
  ing <- rest & grepl("^.{4,}ing$", out)
  out[ing] <- sub("ing$", "", out[ing])
  ed <- rest & !ing & grepl("^.{4,}[^e]ed$", out)
  out[ed] <- sub("ed$", "", out[ed])
  out
}

#' Lower-case words of a text, punctuation and hyphens as separators
#' @noRd
search_words <- function(text) {
  text <- tolower(ifelse(is.na(text), "", text))
  lapply(strsplit(gsub("[^a-z0-9]+", " ", text), " ", fixed = TRUE),
         function(w) w[nzchar(w)])
}

#' The query as search terms
#'
#' Each term is a list of alternatives, and each alternative a vector of
#' stems that must all appear. A plain word has one alternative, itself; an
#' acronym has two, itself and the words it stands for.
#'
#' @noRd
search_terms <- function(query) {
  words <- search_words(query)[[1]]
  words <- words[!words %in% search_stop_words()]
  acronyms <- search_acronyms()
  # A spelled-out acronym in the query becomes the acronym, so that "gross
  # domestic product" also finds rows saying only "GDP".
  phrase <- paste(words, collapse = " ")
  for (a in names(acronyms)) {
    spelled <- search_words(acronyms[[a]])[[1]]
    spelled <- spelled[!spelled %in% search_stop_words()]
    spelled_text <- paste(spelled, collapse = " ")
    # Word boundaries need the PCRE engine; the default one ignores \b.
    pattern <- paste0("\\b", spelled_text, "\\b")
    if (nzchar(spelled_text) && grepl(pattern, phrase, perl = TRUE)) {
      phrase <- sub(pattern, a, phrase, perl = TRUE)
    }
  }
  words <- strsplit(phrase, " ", fixed = TRUE)[[1]]
  words <- words[nzchar(words)]

  lapply(words, function(w) {
    alternatives <- list(search_stem(w))
    if (w %in% names(acronyms)) {
      spelled <- search_words(acronyms[[w]])[[1]]
      spelled <- spelled[!spelled %in% search_stop_words()]
      alternatives <- c(alternatives, list(search_stem(spelled)))
    }
    alternatives
  })
}

#' Does a set of stemmed words contain a stem?
#'
#' Exact stems match; a stem of four letters or more also matches as the
#' start of a longer word.
#'
#' @noRd
search_has <- function(stem, words) {
  if (stem %in% words) {
    return(TRUE)
  }
  nchar(stem) >= 4L && any(startsWith(words, stem))
}

#' Does a set of stemmed words satisfy every term?
#' @noRd
search_matches <- function(terms, words) {
  all(vapply(terms, function(alternatives) {
    any(vapply(alternatives, function(stems) {
      all(vapply(stems, search_has, logical(1), words = words))
    }, logical(1)))
  }, logical(1)))
}

#' The query's terms as the phrases they can be read as
#'
#' One phrase per combination of each term's alternatives, so "cpi" reads as
#' both "cpi" and "consumer price index".
#'
#' @noRd
search_phrases <- function(terms) {
  phrases <- ""
  for (alternatives in terms) {
    parts <- vapply(alternatives, paste, character(1), collapse = " ")
    phrases <- as.vector(outer(phrases, parts, function(a, b) trimws(paste(a, b))))
  }
  phrases
}

#' Score every candidate row; NA for rows that do not match
#'
#' Every term must appear in the row's searchable text (title, id, topic).
#' Matches fall into tiers: the exact id, the exact title, the query as a
#' phrase in the title, every term in the title, a match elsewhere. Phrases
#' compare stems with common words dropped, so "consumer price index" is the
#' phrase in "Consumer Price Indices and Inflation Rates". Within a tier the
#' caller orders data before documents and newer before older; nothing here
#' rewards a title for being short.
#'
#' @noRd
search_score <- function(rows, query, terms) {
  q <- tolower(trimws(query))
  stop <- search_stop_words()
  # Thousands of rows: every word is stemmed once, and each term is one
  # regular expression over all rows, rather than a loop over rows.
  title_text <- search_stem_texts(rows$title, drop = stop)
  all_text <- search_stem_texts(rows$text)
  phrases <- paste0(" ", search_phrases(terms), " ")
  query_words <- search_words(query)[[1]]
  query_stems <- paste(search_stem(query_words[!query_words %in% stop]), collapse = " ")

  padded <- paste0(" ", title_text, " ")
  in_phrase <- Reduce(`|`, lapply(phrases, function(p) grepl(p, padded, fixed = TRUE)))
  id <- tolower(rows$resource_id)
  score <- ifelse(!is.na(id) & id == q, 1000,
           ifelse(title_text == query_stems, 500,
           ifelse(in_phrase, 100,
           ifelse(search_matches_all(terms, title_text), 50, 10))))
  score[!search_matches_all(terms, all_text)] <- NA_real_
  rows$score <- as.numeric(score)
  rows
}

#' Each text's stemmed words, space-joined
#'
#' @param drop Words to leave out before stemming.
#' @noRd
search_stem_texts <- function(texts, drop = character(0)) {
  word_lists <- search_words(texts)
  flat <- unlist(word_lists, use.names = FALSE)
  row <- rep(seq_along(word_lists), lengths(word_lists))
  keep <- !flat %in% drop
  flat <- flat[keep]
  row <- row[keep]
  vocabulary <- unique(flat)
  stems <- search_stem(vocabulary)[match(flat, vocabulary)]
  groups <- split(stems, factor(row, levels = seq_along(texts)))
  unname(vapply(groups, paste, character(1), collapse = " "))
}

#' Which space-joined stem texts satisfy every term
#'
#' The vectorised form of `search_matches()`, with the same rule: a stem of
#' four letters or more matches a word it begins, a shorter one only a whole
#' word. Stems are lower-case letters and digits, so they are safe in a
#' pattern as they are.
#'
#' @noRd
search_matches_all <- function(terms, texts) {
  hits <- function(stem) {
    pattern <- if (nchar(stem) >= 4L) {
      paste0("(^| )", stem)
    } else {
      paste0("(^| )", stem, "( |$)")
    }
    grepl(pattern, texts, perl = TRUE)
  }
  Reduce(`&`, lapply(terms, function(alternatives) {
    Reduce(`|`, lapply(alternatives, function(stems) Reduce(`&`, lapply(stems, hits))))
  }))
}

#' Data before documents at equal relevance
#' @noRd
search_type_weight <- function(type) {
  unname(c(indicator = 3, table = 3, microdata = 2, survey = 2, publication = 1)[type])
}

#' The source ids a partial-failure warning names
#' @noRd
search_failed_sources <- function(cnd) {
  if (length(cnd$unreachable) > 0L) {
    return(as.character(cnd$unreachable))
  }
  message <- conditionMessage(cnd)
  found <- regmatches(message, regexpr("Could not reach: [^.]+", message))
  if (length(found) == 0L) {
    return("indicator")
  }
  trimws(strsplit(sub("^Could not reach: ", "", found), ",")[[1]])
}

#' Assemble candidate rows in the search schema
#' @noRd
search_rows <- function(resource_type, resource_id, title, topic = NA_character_,
                        period = NA_character_, release_date = as.Date(NA),
                        access = NA_character_, source_id, url = NA_character_,
                        get, text) {
  n <- length(resource_id)
  tibble::tibble(
    resource_type = rep(resource_type, n),
    resource_id = as.character(resource_id),
    title = as.character(title),
    topic = rep_len(as.character(topic), n),
    period = rep_len(as.character(period), n),
    release_date = rep_len(as.Date(release_date), n),
    access = rep_len(as.character(access), n),
    source_id = rep_len(as.character(source_id), n),
    url = rep_len(as.character(url), n),
    get = as.character(get),
    text = as.character(text)
  )
}

#' Every indicator from every verified source
#' @noRd
search_rows_indicators <- function(cache, refresh) {
  cat_ <- tibble::as_tibble(knbs_indicators(cache = cache, refresh = refresh))
  search_rows(
    "indicator",
    resource_id = cat_$indicator_id,
    title = cat_$indicator_name,
    topic = cat_$topic,
    # Catalogues state a frequency, not the period covered; that comes with
    # the data.
    access = "open",
    source_id = cat_$source_id,
    get = sprintf('knbs_get_indicator("%s", source = "%s")',
                  cat_$indicator_id, cat_$source_id),
    text = paste(cat_$indicator_name, cat_$indicator_id, cat_$topic,
                 search_source_words(cat_$source_id))
  )
}

#' Words naming the survey family a source's indicators come from
#'
#' A DHS indicator is labelled "Children stunted", never "Demographic and
#' Health Survey", so a search for KDHS would otherwise miss all of them. The
#' acronym alone suffices: the spelled-out query becomes it. Spelling the
#' family out here would make every DHS indicator match "health" or "survey".
#'
#' @noRd
search_source_words <- function(source_id) {
  words <- c(dhs_program = "dhs kdhs")
  out <- unname(words[source_id])
  out[is.na(out)] <- ""
  out
}

#' Every curated Statistical Abstract table
#' @noRd
search_rows_tables <- function() {
  cat_ <- tibble::as_tibble(knbs_abstract_tables())
  span <- regmatches(cat_$title, regexpr("[0-9]{4} ?- ?[0-9]{4}", cat_$title))
  period <- rep(NA_character_, nrow(cat_))
  period[grepl("[0-9]{4} ?- ?[0-9]{4}", cat_$title)] <- gsub(" ", "", span)
  search_rows(
    "table",
    resource_id = cat_$table_id,
    title = paste0("Table ", cat_$table_id, ": ", cat_$title),
    topic = cat_$chapter,
    period = period,
    access = "open",
    source_id = "knbs_publications",
    get = sprintf('knbs_abstract_table("%s")', cat_$table_id),
    text = paste(cat_$title, cat_$chapter, "statistical abstract", cat_$unit)
  )
}

#' Every study in the survey archive
#' @noRd
search_rows_surveys <- function(cache, refresh) {
  cat_ <- tibble::as_tibble(
    knbs_search_surveys(limit = 1000, cache = cache, refresh = refresh)
  )
  search_rows(
    "survey",
    resource_id = cat_$survey_id,
    title = cat_$title,
    topic = cat_$producer,
    period = cat_$reference_years,
    release_date = suppressWarnings(as.Date(cat_$metadata_updated)),
    access = cat_$access_type,
    source_id = cat_$source_id,
    url = cat_$catalogue_url,
    get = sprintf('knbs_survey_metadata("%s")', cat_$survey_id),
    text = paste(cat_$title, cat_$acronym, cat_$survey_id, cat_$producer)
  )
}

#' Every round of open survey microdata, one row each
#'
#' A round is offered in its best-labelled format, Stata before SPSS before
#' Excel; the others are a [knbs_finaccess_files()] away.
#'
#' @noRd
search_rows_microdata <- function() {
  cat_ <- finaccess_catalogue()
  data <- cat_[cat_$content == "data" & cat_$access == "open", ]
  data <- data[order(match(data$format, c("stata", "spss", "excel"))), ]
  data$round <- sub("-.*$", "", data$file_id)
  formats <- tapply(data$format, data$round, function(f) {
    paste(vapply(f, finaccess_format_label, character(1)), collapse = ", ")
  })
  best <- data[!duplicated(data$round), ]
  best <- best[order(best$survey, -best$year), ]
  search_rows(
    "microdata",
    resource_id = best$round,
    title = paste0(sub(":.*$", "", best$title), " (microdata)"),
    topic = "Financial inclusion",
    period = as.character(best$year),
    access = "open",
    source_id = "finaccess",
    url = finaccess_registry()$portal,
    get = sprintf('knbs_read_microdata(knbs_download_finaccess("%s", destination = "."))',
                  best$file_id),
    text = paste(best$title, best$round, "FinAccess financial inclusion survey microdata",
                 ifelse(best$survey == "mse_tracker", "micro small enterprises MSE", "household"),
                 formats[best$round])
  )
}

#' Every document in the publications library
#' @noRd
search_rows_publications <- function(cache, refresh) {
  cat_ <- publications_listing(cache = cache, refresh = refresh)
  search_rows(
    "publication",
    resource_id = cat_$publication_id,
    title = cat_$title,
    topic = cat_$format,
    period = ifelse(is.na(cat_$year), NA_character_, as.character(cat_$year)),
    release_date = cat_$release_date,
    access = cat_$access,
    source_id = cat_$source_id,
    url = cat_$landing_page,
    get = sprintf('knbs_download_publication("%s", destination = ".")', cat_$publication_id),
    text = paste(cat_$title, cat_$description, cat_$file_name)
  )
}

#' The whole publications library, page by page
#'
#' Pages share their cache entries with [knbs_publications()]. How far the
#' listing goes comes from the source's own page count, never from row
#' counts (the server returns short pages mid-listing), and a boundary record
#' repeated by an upload landing mid-scan is kept once.
#'
#' @noRd
publications_listing <- function(cache = TRUE, refresh = FALSE,
                                 call = rlang::caller_env()) {
  src <- resolve_source("search_publications", NULL, call = call)
  fetch_page <- function(page) {
    page_query <- new_knbs_query(
      "publication",
      filters = compact_list(list(
        limit = 100L,
        page = if (page > 1L) as.integer(page) else NULL
      )),
      source = src$source_id
    )
    cache_fetch(
      cache_key(src$source_id, "search_publications", page_query),
      fetch = function() source_search(src, page_query),
      cache = cache,
      refresh = refresh,
      ttl = knbs_cache_ttl("catalogue"),
      info = list(source_id = src$source_id, operation = "search_publications")
    )
  }

  first <- fetch_page(1L)
  total_pages <- knbs_metadata(first)$raw$wp_total_pages %||% NA_integer_
  page_cap <- 60L
  pages <- list(tibble::as_tibble(first))
  if (!is.na(total_pages) && total_pages > 1L) {
    last <- min(total_pages, page_cap)
    for (page in seq.int(2L, last)) {
      batch <- tryCatch(
        tibble::as_tibble(fetch_page(page)),
        # One page past the end answers 400: the listing is over.
        knbs_error_invalid_query = function(cnd) NULL
      )
      if (is.null(batch)) {
        break
      }
      pages[[length(pages) + 1L]] <- batch
    }
  }
  listing <- do.call(rbind, pages)
  listing[!duplicated(listing$publication_id), ]
}
