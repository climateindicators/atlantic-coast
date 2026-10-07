# Byte-stable writers. See CLAUDE.md for why generated output must be
# byte-identical across reruns and machines.
#
# Every write goes through a binary connection or an explicit eol, because a
# text connection translates "\n" to CRLF on Windows.

#' Write a CSV: UTF-8, no BOM, LF endings, quote only where needed.
write_csv_stable <- function(x, path) {
  readr::write_csv(x, path, na = "", eol = "\n", quote = "needed", progress = FALSE)
  invisible(path)
}

#' Write YAML through a binary connection so no CRLF translation happens.
write_yaml_stable <- function(x, path) {
  txt <- yaml::as.yaml(x, indent = 2L, line.sep = "\n")
  con <- file(path, open = "wb")
  on.exit(close(con), add = TRUE)
  writeChar(txt, con, eos = NULL)
  invisible(path)
}

#' Write character lines through a binary connection, LF-terminated.
write_lines_stable <- function(x, path) {
  con <- file(path, open = "wb")
  on.exit(close(con), add = TRUE)
  writeChar(paste0(paste(x, collapse = "\n"), "\n"), con, eos = NULL)
  invisible(path)
}

file_sha256 <- function(path) {
  digest::digest(path, algo = "sha256", file = TRUE)
}

#' Assert a written file is free of the things that break byte-stability or
#' signal an encoding failure.
assert_clean_output <- function(path) {
  bytes <- readBin(path, "raw", file.size(path))

  if (any(bytes == as.raw(13L))) {
    stop("CR byte found in ", basename(path), ": a text connection leaked CRLF.", call. = FALSE)
  }
  if (length(bytes) >= 3L && identical(bytes[1:3], as.raw(c(0xEF, 0xBB, 0xBF)))) {
    stop("UTF-8 BOM found in ", basename(path), ".", call. = FALSE)
  }

  txt <- readLines(path, warn = FALSE, encoding = "UTF-8")
  if (!all(validUTF8(txt))) {
    stop("Invalid UTF-8 in ", basename(path), ".", call. = FALSE)
  }
  # Signature of windows-1252 bytes that were read as UTF-8 somewhere upstream.
  bad <- grep("Â|â|Ã", txt, value = TRUE)
  if (length(bad)) {
    stop(
      "Mojibake in ", basename(path), ", first offending line:\n  ", bad[1],
      call. = FALSE
    )
  }
  invisible(TRUE)
}
