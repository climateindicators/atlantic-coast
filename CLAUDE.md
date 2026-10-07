# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**This file is the only place project rules live.** Code comments explain the
specific line or block they sit above, why *this* header is asserted, why *this*
value is rounded, and nothing broader. If a comment would apply to more than one
file, it belongs here instead.

## Project Overview

This repository is the **data and narrative pipeline for a single EPA climate
indicator, A Closer Look: Land Loss Along the Atlantic Coast**. It takes EPA's published per-figure CSV downloads, in
`data-raw/`, and turns them into two products:

1. `data/` for tidy long-format CSVs plus `data/meta.yml`, a machine-readable
   data dictionary
2. `narrative.qmd` for EPA's own published prose, captions, and references

Both are consumed by the website repository, `../climateindicators.us`
(published at [climateindicators.us](https://climateindicators.us)): `data/` is
fetched off `raw.githubusercontent.com` at render time, and the prose in
`narrative.qmd` is lifted into `indicators/atlantic-coast.qmd` there.

**This repository is not a website and draws no figures.** All chart code lives
in the site repository, in `R/atlantic-coast.R`. Nothing here should produce a plot, a
theme, a palette, or an htmlwidget, and nothing here should be rendered.

Source of the indicator, and the canonical reference for any wording question:
<https://19january2025snapshot.epa.gov/climate-indicators/atlantic-coast/index.html>

## Common Commands

```sh
Rscript R/build_data.R      # data-raw/*.csv -> data/*.csv + data/meta.yml
Rscript tests/test-data.R   # regression checks on the generated data
```

On this machine `Rscript` is not on PATH. Use the full path:
`"C:\Program Files\R\R-4.6.1\bin\Rscript.exe"`.

There is no test runner and no `testthat`: each file under `tests/` is a
standalone script run with `Rscript` from the repository root, printing
PASS/FAIL lines and exiting non-zero on failure. To run one check, edit or
comment within that script; there is no selector.

`R/build_data.R` never touches the network. Rerunning it with unchanged inputs
must produce byte-identical output.

## Architecture

### One pipeline, one way

`data-raw/*.csv`, EPA's published per-figure downloads, go to `R/build_data.R`,
which writes the tidy CSVs and `data/meta.yml`.

Both figures appear on EPA's published indicator page. Each source file is wide
(one row per category, one column per cumulative period: 1996-2001, 1996-2006,
1996-2011) and is pivoted to one row per category and period.

- `atlantic_coast_land_loss.csv` (Figure 1): `region`, `period`, `value`.
  Cumulative net land loss for the Mid-Atlantic and Southeast regions, square
  miles. A negative value is a net gain.
- `atlantic_coast_land_submergence.csv` (Figure 2): `transition`, `period`,
  `value`. Cumulative area converted to open water from dry land, non-tidal
  wetland, and tidal wetland, square miles. EPA's `-->` labels are kept verbatim.

`data/meta.yml` is generated, never hand-edited. It is assembled inside
`R/build_data.R` from each source file's own five-line preamble, so figure
titles, data-source lines, web-update dates, and units cannot drift from the
build. It is what the site repository reads for those values, so a caption on
the website cannot drift either.

### `narrative.qmd`

Generated once from EPA's published page by the `build-indicator` skill. The
page as fetched is archived at `data-raw/source-page.html`.

**The prose is EPA's, verbatim.** Wording that differs from the archived page is
a bug. This file is yours to edit for structure and for site-internal links, but
never to reword EPA's sentences. A deliberate editorial change belongs on the
page in the site repository, not here.

Regenerating would discard those edits, which is why the skill's script refuses
to overwrite an existing repository without `--force`.

Reference markers are plain Quarto superscripts (`^2,3^`) pointing at the
numbered list under `## References`. Cross-indicator links EPA had in its prose
were flattened to plain text and reported at generation time, because they
pointed at epa.gov; add site-internal links in their place.

### `R/utils/` for shared, indicator-agnostic readers

- `epa_csv.R` is the reader for EPA's per-figure CSV downloads (five-line
  preamble), plus the generic `assert_headers()`, `assert_conservation()`, and
  `split_value_flag()` helpers. It sniffs each file's encoding rather than
  assuming: most are windows-1252, some are UTF-8 with a BOM, and assuming the
  wrong one mojibakes silently instead of erroring.
- `write_stable.R` holds byte-stable CSV/YAML/lines writers plus
  `assert_clean_output()` and `file_sha256()`.

### Hard rules

- **`data-raw/` is immutable input.** Files there are reproduced unmodified and
  hashed in `data-raw/PROVENANCE.md`. To update the data, replace the source
  file and rerun the build.
- **Never record a local filesystem path.** A vendored file is identified in
  `PROVENANCE.md` by its sha256 and its own public URL, never by the folder it
  was copied from. The same applies in code, where every script resolves its
  inputs relative to `here::here()` and none accepts a path outside the
  repository.
- **Read source columns by their header cells, never by position.** A renamed or
  reordered column must stop the build rather than silently swap two series.
- **Never re-derive a published number outside `R/build_data.R`.** If something
  downstream needs a value `data/` does not carry, add it to the build and
  regenerate, so it is tested and reproducible.
- **Generated output must be byte-identical across reruns and machines.** No
  timestamps in generated files (provenance is the source checksum), no
  locale-dependent sorting (order rows with `match()` against an explicit level
  vector), LF endings and UTF-8 without BOM.
- **Structural invariants belong in the build; value snapshots belong in the
  tests.** `R/build_data.R` asserts what should survive a data update.
  `tests/test-data.R` pins the actual numbers, so a legitimate data update fails
  loudly there and tells you exactly what changed.
- **No em dashes in prose you write.** Use commas, periods, parentheses,
  semicolons, or colons. This applies to your own words only: EPA's quoted prose
  in `narrative.qmd` keeps its punctuation exactly as published.

### Tests

`tests/` holds data-quality checks and nothing else: schema, coverage,
documented invariants, value snapshots, file hygiene (UTF-8/LF/no BOM), and
agreement between `data/meta.yml` and the CSVs it documents.

## What must never appear here

Each indicator was once a standalone Quarto website. That scaffolding is gone.
Do not add `_quarto.yml`, `css/`, `images/`, `404.qmd`, `index.qmd`, a
"Data & Downloads" page, `R/figures.R`, `R/_common.R`, or
`R/utils/pick_chart.R`. The figures live in the site repository. Do not
reintroduce a rendered page here.

Word documents are not part of this workflow. There is no `R/gen_narrative.R`
and no `R/utils/read_docx.R`: the narrative comes from EPA's published HTML
page, which is the same text.

## Rights

EPA text, captions, and data are U.S. Government works, not subject to domestic
copyright (17 U.S.C. 105). Code and the derived data schema are CC-BY-SA. This
is an independent project, not affiliated with or endorsed by EPA or
NOAA. See `NOTICE.md` and `data-raw/PROVENANCE.md`.
