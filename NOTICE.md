# Rights and attribution

## EPA content

The indicator text, figure captions, and underlying data reproduced in this
repository are works of the U.S. Environmental Protection Agency, prepared by
officers or employees of the U.S. Government as part of their official duties.
Under 17 U.S.C. 105 such works are not subject to copyright protection in the
United States.

Source: *Climate Change Indicators in the United States: A Closer Look: Land Loss Along the Atlantic Coast*,
U.S. EPA, as preserved in the January 19, 2025 snapshot of epa.gov.

<https://19january2025snapshot.epa.gov/climate-indicators/atlantic-coast/index.html>

The underlying data are from NOAA. See the indicator's technical
documentation for details:

<https://19january2025snapshot.epa.gov/sites/default/files/2021-04/documents/land-loss_td.pdf>

Files in `data-raw/` are reproduced unmodified from EPA's published per-figure
CSV downloads and are hashed in `data-raw/PROVENANCE.md`. Files in `data/` are
reformatted, not altered: values are preserved as source text byte for byte.
Every transformation is in `R/build_data.R` and is checked by
`tests/test-data.R`.

`narrative.qmd` is EPA's published wording, extracted from the indicator page
archived at `data-raw/source-page.html`.

## This rebuild

Code and the derived data schema are licensed CC-BY-SA.

This is an independent project. It is **not** affiliated with, endorsed by, or
approved by the U.S. Environmental Protection Agency or NOAA (the
underlying data source agency).

<!-- TODO: if this rebuild departs from EPA's published presentation in any way,
     name the departure here and document it in data-raw/PROVENANCE.md. Delete
     this comment once resolved either way. -->
