# 02 — Diagnostics
# Reconstructed thesis pipeline — October 2026
# Provenance: Stationarity code copied from V1 Rmd. Tsay block reconstructed from the August 2026 console workflow documented in the Thesis project.
# Original historical files remain untouched.

suppressPackageStartupMessages({
  library(readxl)
  library(dplyr)
  library(lubridate)
  library(purrr)
  library(tibble)
  library(tidyr)
  library(ggplot2)
  library(forecast)
  library(tseries)
  library(urca)
  library(tsDyn)
  library(MSwM)
  library(MCS)
})

set.seed(42)

obj <- readRDS("outputs/01_prepared_data.rds")
list2env(obj, envir = environment())

run_tests <- function(sku) {
  x <- as.numeric(ts_list[[sku]])

  adf_res  <- tryCatch(adf.test(x),  error = function(e) NULL)
  kpss_res <- tryCatch(kpss.test(x), error = function(e) NULL)
  pp_res   <- tryCatch(ur.pp(x, type = "Z-tau", model = "constant"),
                       error = function(e) NULL)

  pp_stat <- if (!is.null(pp_res)) as.numeric(pp_res@teststat) else NA_real_
  pp_cv5  <- if (!is.null(pp_res)) as.numeric(pp_res@cval[2]) else NA_real_

  tibble(
    SKU       = sku,
    ADF_p     = if (!is.null(adf_res))  round(adf_res$p.value, 4)  else NA_real_,
    KPSS_p    = if (!is.null(kpss_res)) round(kpss_res$p.value, 4) else NA_real_,
    PP_stat   = round(pp_stat, 2),
    PP_cv5    = round(pp_cv5, 2),
    PP_reject = ifelse(!is.na(pp_stat) & !is.na(pp_cv5) & pp_stat < pp_cv5, "Yes", "No")
  )
}

stat_table <- map_dfr(selected_skus, run_tests)

# ---- V2 ADDITION / RECONSTRUCTED ----
# In August 2026 the Tsay test was run interactively with NTS::Tsay(y, p = 2).
# NTS::Tsay() prints its result rather than returning a convenient table, so the
# original tsay_table assembly was not preserved. We retain the exact V2 values
# as a historical validation target and keep the interactive test call explicit.
if (!requireNamespace("NTS", quietly = TRUE)) {
  warning("Package 'NTS' is not installed; Tsay tests were not rerun.")
}

tsays_v2_reported <- tibble::tribble(
  ~SKU,  ~`F statistic`, ~`p-value`,
  "AA00", 3.355, 0.0218,
  "AG00", 5.252, 0.0021,
  "AA03", 1.930, 0.1295,
  "AA04", 3.480, 0.0187,
  "AG03", 1.747, 0.1621,
  "AG04", 4.404, 0.0059,
  "AJ00", 0.560, 0.6427,
  "AG01", 2.979, 0.0350
)

# Optional verification: prints the package output for comparison with the V2 table.
if (requireNamespace("NTS", quietly = TRUE)) {
  invisible(lapply(selected_skus, function(sku) {
    cat("\n--- Tsay test:", sku, "---\n")
    NTS::Tsay(as.numeric(ts_list[[sku]]), p = 2)
  }))
}

# The historical table is kept as a reference output, not presented as a value
# programmatically extracted from NTS::Tsay().
tsay_reference_v2 <- tsays_v2_reported

saveRDS(
  list(stat_table = stat_table, tsay_reference_v2 = tsay_reference_v2),
  "outputs/02_diagnostics.rds"
)
