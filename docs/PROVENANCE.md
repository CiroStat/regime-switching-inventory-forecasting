# Provenance and reconstruction notes

This repository is a cleaned reconstruction of the analytical workflow behind Ciro Mainella's MSc dissertation, *Regime-Switching Dynamics in E-commerce Inventory: Evidence from Amazon FBA Daily Ledger Data*.

The purpose of this document is to distinguish the historical dissertation workflow from the reconstructed repository and to document the numerical validation performed during reconstruction.

## Historical sequence

1. A standalone R script was developed for data preparation, model estimation, rolling-origin validation, Diebold-Mariano tests, Model Confidence Sets, and Monte Carlo low-stock analysis.
2. The June 2026 R Markdown evolved from that script and became the more complete V1 analytical document.
3. Final evaluation outputs were frozen in `thesis_results_locked.rds` for stable thesis compilation.
4. During the July/August post-dissertation revision, the existing R environment was reused. Tables and figures were reformatted through presentation scripts and console commands rather than by building a second estimation pipeline.
5. The Tsay nonlinearity test was added during this revision. The original interactive console code that assembled `tsay_table` was not preserved. The documented procedure was `NTS::Tsay(y, p = 2)`; the final reported values are retained separately as a historical reference.

## Reconstruction policy

- Raw company data are excluded and should never be committed.
- The reconstructed data-preparation script reads only the `IL_AWD` sheet and imports only the variables required for the analysis. `Map_SKU` and `Map_Loc` are deliberately ignored.
- `R/01`–`R/05` reconstruct the analytical pipeline from the mature V1 R Markdown and surviving standalone code.
- `R/06` is an integration/export layer for machine-readable outputs and selected figures.
- `R/07` is presentation-only.
- `results/reference/thesis_results_locked.rds` is a historical reference snapshot and must never be overwritten.
- The locked snapshot has been checked to contain only five anonymized result tables: `cv_clean`, `dm_table`, `mcs_table`, `mcs_summary`, and `lowstock_robustness_table`.
- `reproduce_public_results.R` validates that snapshot, rejects a set of obvious raw/account field names, and exports public CSVs without requiring the proprietary workbook.
- Any future full rerun should be compared against the locked snapshot and final dissertation outputs before numerical differences are accepted.

## Reconstruction validation

The reconstructed pipeline was run against an authorized local copy of the original source workbook and compared with the archived dissertation results.

The following components reproduce the historical results:

- ARIMA rolling-origin forecast metrics;
- ETS rolling-origin forecast metrics;
- SETAR rolling-origin forecast metrics;
- Naive rolling-origin forecast metrics;
- Monte Carlo low-stock robustness results;
- Tsay nonlinearity test results.

The Tsay test was reconstructed using the documented specification `NTS::Tsay(y, p = 2)`. The resulting p-values match those reported in the final post-dissertation version.

### MS-AR stochastic initialization

Rolling MS-AR estimates show small differences from the archived dissertation results.

The historical workflow estimated MS-AR models using `MSwM::msmFit()`. This procedure involves stochastic initialization, while the original rolling-validation workflow did not preserve the random-number-generator state associated with the historical fits.

Consequently, the exact historical sequence of MS-AR initializations cannot be reconstructed from the surviving source files.

This does not affect the deterministic ARIMA, ETS, SETAR or Naive results, and the low-stock robustness simulation reproduces the archived output exactly. The reconstructed pipeline now fixes the random seed so that future MS-AR reruns are deterministic.

In the validation run:

- the maximum absolute difference in MS-AR RMSE was approximately **25.19**;
- the maximum absolute difference in MS-AR MASE was approximately **0.524**.

Because the Diebold-Mariano and Model Confidence Set procedures depend on the rolling MS-AR forecasts, they can inherit these differences.

The historical snapshot contains **23 valid Model Confidence Set cases**. The deterministic reconstruction produces **24**, with `AG00` at the 14-day horizon becoming an additional valid case because the reconstructed MS-AR rolling fit contains one more valid forecast.

For this reason, dissertation-reported DM and MCS results should be taken from the archived historical snapshot when reproducing the published results, while the reconstructed pipeline should be used for deterministic future reruns.

## Historical reference snapshot

`results/reference/thesis_results_locked.rds` is treated as the authoritative machine-readable record of the final historical evaluation outputs used for the dissertation.

It contains:

- `cv_clean`
- `dm_table`
- `mcs_table`
- `mcs_summary`
- `lowstock_robustness_table`

The snapshot contains derived, anonymized analytical results rather than raw operational observations.

`reproduce_public_results.R` provides the public reproduction path from this snapshot without requiring access to the proprietary source workbook.

## Raw-data boundary

The original company workbook is intentionally excluded from the repository.

A full reconstruction from source data therefore requires an authorized local copy of the workbook. The public repository instead provides:

- the reconstructed analytical code;
- the anonymized historical result snapshot;
- selected dissertation tables and figures;
- the final dissertation;
- scripts for exporting and validating the public results.

This separation preserves the analytical workflow and its historical outputs without distributing the underlying proprietary operational data.