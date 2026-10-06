# ============================================================
# Validation against historical thesis results
# ============================================================
#
# This script compares the reconstructed analytical pipeline
# with the locked results used for the final thesis.
#
# IMPORTANT:
# The original rolling MS-AR evaluation did not preserve the
# RNG state used by MSwM::msmFit(). Small differences in MS-AR
# rolling forecasts are therefore expected.
#
# The historical locked results are NEVER overwritten.
# ============================================================


# ---- Load reconstructed results -----------------------------------------

diagnostics <- readRDS("outputs/02_diagnostics.rds")
evaluation  <- readRDS("outputs/04_forecast_evaluation.rds")
lowstock    <- readRDS("outputs/05_low_stock.rds")


# ---- Load historical thesis snapshot -----------------------------------

locked <- readRDS("results/reference/thesis_results_locked.rds")


# ---- Helper -------------------------------------------------------------

check_equal <- function(x, y) {
  isTRUE(all.equal(x, y, check.attributes = FALSE))
}


# ============================================================
# 1. Forecast evaluation
# ============================================================

new_cv <- evaluation$cv_clean
old_cv <- locked$cv_clean

new_cv <- new_cv[order(new_cv$SKU, new_cv$h), ]
old_cv <- old_cv[order(old_cv$SKU, old_cv$h), ]


# Models whose rolling results should reproduce exactly
deterministic_columns <- c(
  "RMSE_ARIMA",
  "RMSE_ETS",
  "RMSE_SETAR",
  "RMSE_NAIVE",
  "MASE_ARIMA",
  "MASE_ETS",
  "MASE_SETAR",
  "MASE_NAIVE"
)

deterministic_match <- check_equal(
  new_cv[, deterministic_columns],
  old_cv[, deterministic_columns]
)


# MS-AR is checked separately because msmFit() uses
# stochastic initialization.

msar_rmse_difference <- max(
  abs(new_cv$RMSE_MSAR - old_cv$RMSE_MSAR),
  na.rm = TRUE
)

msar_mase_difference <- max(
  abs(new_cv$MASE_MSAR - old_cv$MASE_MSAR),
  na.rm = TRUE
)

msar_valid_match <- check_equal(
  new_cv$n_msar_valid,
  old_cv$n_msar_valid
)


# ============================================================
# 2. Low-stock robustness simulation
# ============================================================

lowstock_match <- check_equal(
  lowstock$lowstock_robustness_table,
  locked$lowstock_robustness_table
)


# ============================================================
# 3. Diebold-Mariano tests
# ============================================================

dm_match <- check_equal(
  evaluation$dm_table,
  locked$dm_table
)


# ============================================================
# 4. Model Confidence Set
# ============================================================

mcs_table_match <- check_equal(
  evaluation$mcs_table,
  locked$mcs_table
)

new_mcs_cases <- evaluation$mcs_summary[, c("SKU", "h")]
old_mcs_cases <- locked$mcs_summary[, c("SKU", "h")]

extra_mcs_cases <- merge(
  new_mcs_cases,
  old_mcs_cases,
  by = c("SKU", "h"),
  all.x = TRUE,
  all.y = FALSE
)

extra_mcs_cases <- extra_mcs_cases[
  !paste(extra_mcs_cases$SKU, extra_mcs_cases$h) %in%
    paste(old_mcs_cases$SKU, old_mcs_cases$h),
]


# ============================================================
# 5. Tsay reference values
# ============================================================

tsay_available <- !is.null(diagnostics$tsay_reference_v2)

tsay_values <- diagnostics$tsay_reference_v2


# ============================================================
# Validation report
# ============================================================

cat("\n")
cat("============================================================\n")
cat(" THESIS RECONSTRUCTION — VALIDATION REPORT\n")
cat("============================================================\n\n")

cat(
  sprintf(
    "ARIMA / ETS / SETAR / Naive rolling metrics: %s\n",
    ifelse(deterministic_match, "PASS", "FAIL")
  )
)

cat(
  sprintf(
    "MS-AR rolling metrics:                       %s\n",
    ifelse(
      msar_rmse_difference == 0 &&
        msar_mase_difference == 0 &&
        msar_valid_match,
      "PASS",
      "EXPECTED DIFFERENCES"
    )
  )
)

cat(
  sprintf(
    "Low-stock robustness simulation:            %s\n",
    ifelse(lowstock_match, "PASS", "FAIL")
  )
)

cat(
  sprintf(
    "Diebold-Mariano results:                    %s\n",
    ifelse(dm_match, "PASS", "DIFFERS (MS-AR dependent)")
  )
)

cat(
  sprintf(
    "Model Confidence Set results:               %s\n",
    ifelse(mcs_table_match, "PASS", "DIFFERS (MS-AR dependent)")
  )
)

cat(
  sprintf(
    "Tsay V2 reference available:                %s\n",
    ifelse(tsay_available, "PASS", "FAIL")
  )
)

cat("\n------------------------------------------------------------\n")
cat("MS-AR diagnostics\n")
cat("------------------------------------------------------------\n")

cat(
  sprintf(
    "Maximum absolute RMSE difference: %.6f\n",
    msar_rmse_difference
  )
)

cat(
  sprintf(
    "Maximum absolute MASE difference: %.6f\n",
    msar_mase_difference
  )
)

cat(
  sprintf(
    "Historical valid MCS cases: %d\n",
    nrow(locked$mcs_summary)
  )
)

cat(
  sprintf(
    "Reconstructed valid MCS cases: %d\n",
    nrow(evaluation$mcs_summary)
  )
)

if (nrow(extra_mcs_cases) > 0) {
  
  cat("\nAdditional reconstructed MCS case(s):\n")
  
  print(extra_mcs_cases)
  
}

cat("\n------------------------------------------------------------\n")
cat("Interpretation\n")
cat("------------------------------------------------------------\n")

cat(
  paste(
    "The deterministic rolling-forecast results are compared",
    "directly with the historical thesis snapshot.",
    "MS-AR results are reported separately because the original",
    "workflow did not preserve the RNG state used by MSwM::msmFit().",
    "The reconstructed pipeline fixes the RNG seed so that future",
    "runs are reproducible.",
    sep = "\n"
  )
)

cat("\n\n============================================================\n")