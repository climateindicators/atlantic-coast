# Readers for EPA "Climate Change Indicators" figure-data CSVs.
#
# Every indicator's published download CSV shares one layout, so this file is
# indicator-agnostic and is meant to be reused verbatim across indicators:
#
#   line 1  figure title
#   line 2  "Source: EPA's Climate Change Indicators in the United States: ..."
#   line 3  "Data source: <agency>, <year>"
#   line 4  "Web update: <Month Year>"
#   line 5  "Units: <units>"
#   line 6  blank
#   line 7  column header
#   line 8+ data
#
# Three traps this file exists to absorb:
#
# 1. The files are not all one encoding. Most are windows-1252, but EPA also
#    publishes some as UTF-8 with a byte-order mark (drought_fig-3.csv is one).
#    Assuming windows-1252 mojibakes those silently rather than erroring, so the
#    encoding is sniffed from the bytes. On Windows, readLines(encoding=) only
#    *tags* a string, it does not convert it, so the conversion still has to be
#    an explicit iconv() or every degree sign and en dash turns to mojibake.
# 2. Reading values as anything but character loses precision. Source values
#    carry up to 10 significant digits and must survive to the output byte for
#    byte, so nothing here ever calls as.numeric().
# 3. "Data source:" is sometimes "Data sources:" and "Unit:" sometimes "Units:".
#    The label patterns below are plural-tolerant.

EPA_CSV_SKIP <- 6L # rows before the header; header is line 7

#' Sniff the encoding of an EPA figure CSV from its bytes.
#'
#' Returns one of "UTF-8-BOM", "UTF-8", or "windows-1252".
#'
#' Pure ASCII is valid UTF-8 and identical under windows-1252, so it resolves to
#' "UTF-8" and reads the same either way. A windows-1252 file carrying a high
#' byte (0x96 en dash, 0xB0 degree sign) is not valid UTF-8, which is what
#' separates the two cases without a guess.
epa_csv_encoding <- function(path) {
  bytes <- readBin(path, "raw", n = file.size(path))
  if (length(bytes) >= 3L && identical(bytes[1:3], as.raw(c(0xEF, 0xBB, 0xBF)))) {
    return("UTF-8-BOM")
  }
  ok <- tryCatch(
    {
      s <- rawToChar(bytes[bytes != as.raw(0L)])
      Encoding(s) <- "UTF-8"
      validUTF8(s)
    },
    error = function(e) FALSE
  )
  if (isTRUE(ok)) "UTF-8" else "windows-1252"
}

# iconv() has no "UTF-8-BOM"; the mark is stripped separately after conversion.
epa_iconv_from <- function(encoding) {
  if (identical(encoding, "windows-1252")) "windows-1252" else "UTF-8"
}

#' Read the 5-line metadata preamble of an EPA figure CSV.
#'
#' @return list(title, source, data_source, web_update, units, encoding)
read_epa_preamble <- function(path, encoding = epa_csv_encoding(path)) {
  raw <- readLines(path, n = 5L, warn = FALSE)
  txt <- iconv(raw, from = epa_iconv_from(encoding), to = "UTF-8")
  if (anyNA(txt)) {
    stop("Preamble of ", basename(path), " is not valid ", encoding, ".", call. = FALSE)
  }
  txt[1] <- sub("^﻿", "", txt[1])

  # Each line is a 1-field CSV row padded with empty fields: strip the padding,
  # then unquote if the surviving field was quoted.
  clean <- function(x) {
    x <- sub(",+$", "", x)
    if (grepl('^".*"$', x)) {
      x <- gsub('""', '"', substr(x, 2L, nchar(x) - 1L), fixed = TRUE)
    }
    trimws(x)
  }
  txt <- vapply(txt, clean, character(1), USE.NAMES = FALSE)

  drop_label <- function(x, label) trimws(sub(paste0("^", label, ":\\s*"), "", x))

  list(
    title       = txt[1],
    source      = drop_label(txt[2], "Sources?"),
    data_source = drop_label(txt[3], "Data sources?"),
    web_update  = drop_label(txt[4], "Web updates?"),
    units       = drop_label(txt[5], "Units?"),
    encoding    = encoding
  )
}

#' Read the data block of an EPA figure CSV.
#'
#' Every column comes back as character, deliberately. See the note at the top.
#' Empty cells arrive as "" rather than NA so the caller decides what a blank
#' means instead of readr guessing. A UTF-8 BOM sits on line 1, six lines above
#' the header, so it never reaches this reader.
read_epa_csv <- function(path, encoding = epa_csv_encoding(path)) {
  readr::read_csv(
    path,
    skip        = EPA_CSV_SKIP,
    locale      = readr::locale(encoding = epa_iconv_from(encoding)),
    col_types   = readr::cols(.default = readr::col_character()),
    na          = character(),
    name_repair = "minimal",
    progress    = FALSE
  )
}

#' Separate suppression markers from numeric values.
#'
#' CDC WONDER (and several other federal sources) replaces a value with a word
#' when the underlying count is too small to publish. "Suppressed" means "fewer
#' than the disclosure threshold", which is emphatically not zero and not
#' missing at random, so it is preserved as a flag rather than coerced away.
#'
#' @return list(value, flag) of equal length; `value` is "" wherever `flag` is set.
EPA_VALUE_FLAGS <- c(
  "suppressed"    = "suppressed",
  "unreliable"    = "unreliable",
  "not available" = "not_available",
  "n/a"           = "not_available"
)

split_value_flag <- function(x) {
  x    <- trimws(x)
  hit  <- match(tolower(x), names(EPA_VALUE_FLAGS))
  flag <- ifelse(is.na(hit), "", unname(EPA_VALUE_FLAGS[hit]))
  value <- ifelse(flag == "", x, "")

  # Whatever survives as a value must parse as a number. An unrecognised word
  # stops the build rather than becoming a silent NA.
  present <- value[value != ""]
  bad <- unique(present[is.na(suppressWarnings(as.numeric(present)))])
  if (length(bad)) {
    stop(
      "Unrecognised non-numeric value(s): ", paste(sQuote(bad), collapse = ", "),
      "\nIf this is a new suppression marker, add it to EPA_VALUE_FLAGS in R/utils/epa_csv.R.",
      call. = FALSE
    )
  }
  list(value = value, flag = flag)
}

#' Assert that a data block's value columns are exactly the expected set.
#'
#' Series are matched by header string, never by position, so that adding years
#' to a source file is invisible while a renamed or reordered column stops the
#' build. `id_cols` are the leading identifier columns (e.g. "Year").
assert_headers <- function(df, id_cols, expected_headers, what) {
  actual <- setdiff(names(df), id_cols)
  missing <- setdiff(expected_headers, actual)
  unknown <- setdiff(actual, expected_headers)
  if (length(missing) || length(unknown)) {
    stop(
      "Column headers in ", what, " are not what this build expects.\n",
      if (length(missing)) paste0("  expected but absent: ", paste(sQuote(missing), collapse = ", "), "\n"),
      if (length(unknown)) paste0("  present but unknown: ", paste(sQuote(unknown), collapse = ", "), "\n"),
      "If EPA changed the file, update the series lookup table in R/build_data.R.",
      call. = FALSE
    )
  }
  invisible(TRUE)
}

#' Conservation invariant: every populated source cell becomes exactly one
#' output row, and no output row is invented.
#'
#' This is the check that survives a data update, where a hard-coded row count
#' would not.
assert_conservation <- function(df, value_cols, n_out, what) {
  n_cells <- sum(vapply(
    df[value_cols],
    function(col) sum(!is.na(col) & trimws(col) != ""),
    integer(1)
  ))
  if (n_cells != n_out) {
    stop(
      "Conservation check failed for ", what, ": ", n_cells,
      " populated source cells produced ", n_out, " output rows.",
      call. = FALSE
    )
  }
  invisible(n_cells)
}
