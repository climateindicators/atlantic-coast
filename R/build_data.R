# Build tidy long-format data for the A Closer Look: Land Loss Along the Atlantic Coast indicator.
#
#   Rscript R/build_data.R
#
# Reads EPA's published figure CSVs in data-raw/ and writes data/*.csv plus
# data/meta.yml. Rerunning with unchanged inputs produces byte-identical output.
# Nothing here touches the network.
#
# TO UPDATE THE DATA: drop replacement CSVs into data-raw/ and rerun. Headers
# are asserted, not assumed, so a renamed or reordered column stops the build.

suppressPackageStartupMessages({
  library(dplyr)
})

root <- here::here()
source(file.path(root, "R/utils/epa_csv.R"))
source(file.path(root, "R/utils/write_stable.R"))

raw_dir <- file.path(root, "data-raw")
out_dir <- file.path(root, "data")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# ---- Indicator constants -----------------------------------------------------

INDICATOR <- list(
  name                    = "A Closer Look: Land Loss Along the Atlantic Coast",
  slug                    = "atlantic-coast",
  publisher               = "U.S. Environmental Protection Agency",
  source_page             = "https://19january2025snapshot.epa.gov/climate-indicators/atlantic-coast/index.html",
  technical_documentation = "https://19january2025snapshot.epa.gov/sites/default/files/2021-04/documents/land-loss_td.pdf",
  rights                  = "Public domain, work of the U.S. Government (17 U.S.C. 105)"
)

# Cumulative periods, all starting in 1996. Matched by header, never position.
PERIODS <- c("1996-2001", "1996-2006", "1996-2011")

# Wide (one row per category, one column per period) to long (one row per
# category x period). Values stay character so the source digits survive byte
# for byte.
pivot_periods <- function(raw, id_name, what) {
  out <- tidyr::pivot_longer(raw, all_of(PERIODS), names_to = "period", values_to = "value")
  out <- rename(out, !!id_name := Area)
  assert_conservation(raw, PERIODS, nrow(out), what)
  out
}

# ---- Figure 1: Land Loss Along the Atlantic Coast, 1996-2011 ----

f1_path <- file.path(raw_dir, "land-loss_fig-1.csv")
f1_meta <- read_epa_preamble(f1_path)
f1_raw  <- read_epa_csv(f1_path)

assert_headers(
  f1_raw,
  id_cols          = "Area",
  expected_headers = PERIODS,
  what             = "land-loss_fig-1.csv"
)

# Net land loss per region; a negative value is a net gain. Units: square miles.
f1 <- pivot_periods(f1_raw, "region", "land-loss_fig-1.csv")

write_csv_stable(f1, file.path(out_dir, "atlantic_coast_land_loss.csv"))

# ---- Figure 2: Land Submergence Along the Atlantic Coast, 1996-2011 ----

f2_path <- file.path(raw_dir, "land-loss_fig-2.csv")
f2_meta <- read_epa_preamble(f2_path)
f2_raw  <- read_epa_csv(f2_path)

assert_headers(
  f2_raw,
  id_cols          = "Area",
  expected_headers = PERIODS,
  what             = "land-loss_fig-2.csv"
)

# Land converted to open water, by prior land type. EPA's labels are kept
# verbatim (e.g. "Dry land --> Open water"). Units: square miles.
f2 <- pivot_periods(f2_raw, "transition", "land-loss_fig-2.csv")

write_csv_stable(f2, file.path(out_dir, "atlantic_coast_land_submergence.csv"))

# ---- Data dictionary ---------------------------------------------------------

col <- function(name, type, description) {
  list(name = name, type = type, description = description)
}

# One entry per output column, in order. Names are checked against the data
# frame so the dictionary cannot drift from the file.
describe <- function(df, dict) {
  stopifnot(identical(names(df), names(dict)))
  unname(dict)
}

period_col <- col("period", "string", "Cumulative period of change, start year to end year (e.g. 1996-2011)")

meta <- list(
  indicator = INDICATOR,
  datasets = list(
    list(
      file            = "atlantic_coast_land_loss.csv",
      figure          = "Figure 1",
      figure_title    = f1_meta$title,
      source_file     = "land-loss_fig-1.csv",
      source_sha256   = file_sha256(f1_path),
      source_encoding = "UTF-8",
      data_source     = f1_meta$data_source,
      web_update      = f1_meta$web_update,
      unit            = f1_meta$units,
      rows            = nrow(f1),
      columns         = describe(f1, list(
        region = col("region", "string", "Atlantic coast region, as labelled by EPA (Mid-Atlantic or Southeast)"),
        period = period_col,
        value  = col("value", "number", "Cumulative net land loss over the period, square miles; negative values are a net gain")
      ))
    ),
    list(
      file            = "atlantic_coast_land_submergence.csv",
      figure          = "Figure 2",
      figure_title    = f2_meta$title,
      source_file     = "land-loss_fig-2.csv",
      source_sha256   = file_sha256(f2_path),
      source_encoding = "UTF-8",
      data_source     = f2_meta$data_source,
      web_update      = f2_meta$web_update,
      unit            = f2_meta$units,
      rows            = nrow(f2),
      columns         = describe(f2, list(
        transition = col("transition", "string", "Land-cover conversion to open water, as labelled by EPA"),
        period     = period_col,
        value      = col("value", "number", "Cumulative area converted to open water over the period, square miles")
      ))
    )
  )
)

write_yaml_stable(meta, file.path(out_dir, "meta.yml"))

# ---- Verify what was written -------------------------------------------------

written <- list.files(out_dir, pattern = "[.](csv|yml)$", full.names = TRUE)
invisible(lapply(written, assert_clean_output))

cat("\nWrote:\n")
for (p in written) {
  cat(sprintf("  %-34s %8d bytes  %s\n", basename(p), file.size(p), substr(file_sha256(p), 1, 12)))
}
