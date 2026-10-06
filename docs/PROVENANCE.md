# Provenance and reconstruction notes

This repository is a cleaned reconstruction of the analytical workflow behind Ciro Mainella's MSc dissertation, *Regime-Switching Dynamics in E-commerce Inventory: Evidence from Amazon FBA Daily Ledger Data*.

## Historical sequence

1. A standalone R script was developed for data preparation, model estimation, rolling-origin validation, Diebold-Mariano tests, Model Confidence Sets, and Monte Carlo low-stock analysis.
2. The June 2026 R Markdown evolved from that script and became the more complete V1 analytical document.
3. Final evaluation outputs were frozen in `thesis_results_locked.rds` for stable thesis compilation.
4. During the July/August post-dissertation revision, the existing R environment was reused. Tables and figures were reformatted through presentation scripts and console commands rather than by building a second estimation pipeline.
5. The Tsay nonlinearity test was added during this revision. The original interactive console code that assembled `tsay_table` was not preserved. The documented procedure was `NTS::Tsay(y, p = 2)`; the final reported values are retained separately as a historical reference.

## Reconstruction policy

- Raw company data are excluded and should never be committed.
- The reconstructed data-preparation script reads only `IL_AWD`; `Map_SKU` and `Map_Loc` are deliberately ignored.
- `R/01`–`R/05` reconstruct the analytical pipeline from the mature V1 R Markdown and surviving standalone code.
- `R/06` is an integration/export layer for machine-readable outputs and selected figures.
- `R/07` is presentation-only.
- `results/reference/thesis_results_locked.rds` is a historical reference snapshot and must never be overwritten.
- The locked snapshot has been checked to contain only five anonymized result tables: `cv_clean`, `dm_table`, `mcs_table`, `mcs_summary`, and `lowstock_robustness_table`.
- `reproduce_public_results.R` validates that snapshot, rejects a set of obvious raw/account field names, and exports public CSVs without requiring the proprietary workbook.
- Any future full rerun should be compared against the locked snapshot and final dissertation outputs before numerical differences are accepted.
