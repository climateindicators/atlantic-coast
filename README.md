# atlantic-coast

Data and narrative for the U.S. EPA climate indicator **A Closer Look: Land Loss Along the Atlantic Coast**.

This repository holds EPA's published source files, the pipeline that turns them
into analysis-ready data, and EPA's own published prose. It produces two things:

- `data/` for tidy long-format CSVs plus `meta.yml`, a machine-readable data
  dictionary
- `narrative.qmd` for EPA's indicator text, figure captions, and references

Both are read over the network by the website repository,
[climateindicators.us](https://github.com/climateindicators/climateindicators.us),
which is where the figures for this indicator are drawn. **No chart code lives
here.**

Part of the [climateindicators.us](https://climateindicators.us) project, which
rebuilds the EPA *Climate Change Indicators* preserved in the
[January 19, 2025 snapshot](https://19january2025snapshot.epa.gov/climate-indicators/view-indicators/index.html).

Original page: <https://19january2025snapshot.epa.gov/climate-indicators/atlantic-coast/index.html>

## Rebuilding

```sh
Rscript R/build_data.R      # data-raw/*.csv -> data/*.csv + data/meta.yml
Rscript tests/test-data.R   # data-quality checks
```

Nothing touches the network, and rerunning with unchanged inputs produces
byte-identical output.

`narrative.qmd` and `data-raw/` were generated once by the `build-indicator`
skill from EPA's published page, archived here as `data-raw/source-page.html`.

## Rights

EPA text and data are U.S. Government works, not subject to domestic copyright.
Code and the derived data schema are CC-BY-SA. See `NOTICE.md`.
