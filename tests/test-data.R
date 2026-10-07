# Regression checks on the generated data for the A Closer Look: Land Loss Along the Atlantic Coast indicator.
#
#   Rscript tests/test-data.R
#
# The checks below are shape-independent: they hold whatever the reshape in
# R/build_data.R turns each figure into. Value snapshots, which pin the actual
# numbers so a data update fails loudly instead of passing silently, are the
# TODO at the bottom.

setwd(here::here())
source("R/utils/write_stable.R")

# Keeps the dictionary check readable when a meta.yml field is absent altogether.
`%||%` <- function(a, b) if (is.null(a)) b else a

failures <- character()
check <- function(label, ok) {
  ok <- isTRUE(ok)
  cat(sprintf("  [%s] %s\n", if (ok) "PASS" else "FAIL", label))
  if (!ok) failures <<- c(failures, label)
  invisible(ok)
}

rd <- function(f) {
  readr::read_csv(file.path("data", f),
                  col_types = readr::cols(.default = readr::col_character()),
                  na = character(), progress = FALSE)
}

meta <- yaml::read_yaml("data/meta.yml")

cat("\nData dictionary\n")
check("meta.yml documents 2 dataset(s)", length(meta$datasets) == 2L)
check("meta.yml has no timestamp",
      !any(grepl("\\d{4}-\\d{2}-\\d{2}T|Sys\\.time|generated_at",
                 readLines("data/meta.yml", warn = FALSE))))

for (ds in meta$datasets) {
  df   <- rd(ds$file)
  cols <- vapply(ds$columns, function(x) x$name, character(1))
  check(sprintf("%s: meta.yml lists the columns the file actually has", ds$file),
        identical(cols, names(df)))
  check(sprintf("%s: meta.yml row count matches the file", ds$file),
        identical(as.integer(ds$rows), nrow(df)))
  check(sprintf("%s: every column has a type and a description", ds$file),
        all(vapply(ds$columns, function(x) nzchar(x$type %||% "") && nzchar(x$description %||% ""), logical(1))))
  check(sprintf("%s: source file is still present and unchanged", ds$file),
        identical(file_sha256(file.path("data-raw", ds$source_file)), ds$source_sha256))
  check(sprintf("%s: no blank rows", ds$file), nrow(df) > 0L)
}

cat("\nFile hygiene\n")
for (f in list.files("data", pattern = "[.](csv|yml)$", full.names = TRUE)) {
  check(sprintf("%s is UTF-8, LF, no BOM, no mojibake", basename(f)),
        tryCatch({ assert_clean_output(f); TRUE },
                 error = function(e) { cat("      ", conditionMessage(e), "\n"); FALSE }))
}

cat("\nValue snapshots\n")
# Compared as strings so the source's 10 significant digits are pinned exactly.
row_is <- function(df, i, expected) identical(unname(unlist(df[i, ])), expected)
min_max <- function(df) {
  v <- as.numeric(df$value)
  c(df$value[which.min(v)], df$value[which.max(v)])
}

f1 <- rd("atlantic_coast_land_loss.csv")
check("land_loss: 6 rows (2 regions x 3 periods)", nrow(f1) == 6L)
check("land_loss: first row Mid-Atlantic 1996-2001 = -1.560934114",
      row_is(f1, 1, c("Mid-Atlantic", "1996-2001", "-1.560934114")))
check("land_loss: last row Southeast 1996-2011 = 16.43185473",
      row_is(f1, 6, c("Southeast", "1996-2011", "16.43185473")))
check("land_loss: min -1.560934114, max 16.43185473",
      identical(min_max(f1), c("-1.560934114", "16.43185473")))
check("land_loss: Mid-Atlantic 1996-2011 = 3.545808482",
      identical(f1$value[f1$region == "Mid-Atlantic" & f1$period == "1996-2011"], "3.545808482"))

f2 <- rd("atlantic_coast_land_submergence.csv")
check("land_submergence: 9 rows (3 transitions x 3 periods)", nrow(f2) == 9L)
check("land_submergence: first row Dry land 1996-2001 = 2.06306007",
      row_is(f2, 1, c("Dry land --> Open water", "1996-2001", "2.06306007")))
check("land_submergence: last row Tidal wetland 1996-2011 = 10.69684658",
      row_is(f2, 9, c("Tidal wetland --> Open water", "1996-2011", "10.69684658")))
check("land_submergence: min 0.155328929, max 12.20878432",
      identical(min_max(f2), c("0.155328929", "12.20878432")))

cat("\n")
if (length(failures)) {
  cat(sprintf("%d FAILED:\n", length(failures)))
  for (f in failures) cat("  -", f, "\n")
  quit(status = 1L)
}
cat("All data checks passed.\n")
