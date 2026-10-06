# Public reproduction entry point
# Does NOT require the proprietary raw workbook.
# It validates and exports the anonymized locked result snapshot used in the dissertation.

locked_path <- "results/reference/thesis_results_locked.rds"
if (!file.exists(locked_path)) stop("Missing locked result snapshot: ", locked_path)

locked <- readRDS(locked_path)
expected <- c("cv_clean", "dm_table", "mcs_table", "mcs_summary", "lowstock_robustness_table")
if (!identical(names(locked), expected)) {
  stop("Unexpected objects in locked RDS. Found: ", paste(names(locked), collapse = ", "))
}
if (!all(vapply(locked, is.data.frame, logical(1)))) stop("Every locked object should be a data frame/tibble.")

# Guard against accidentally publishing obvious raw-data/account fields.
forbidden <- c("FNSKU", "ASIN", "MSKU", "Product Name", "Account Name", "REFRESH_TOKEN",
               "Warehouse", "Location", "UPC", "Product Information URL")
found_forbidden <- unique(unlist(lapply(locked, function(x) intersect(names(x), forbidden))))
if (length(found_forbidden) > 0) {
  stop("Potentially sensitive fields detected: ", paste(found_forbidden, collapse = ", "))
}

dir.create("outputs/public", showWarnings = FALSE, recursive = TRUE)
for (nm in names(locked)) {
  write.csv(locked[[nm]], file.path("outputs/public", paste0(nm, ".csv")), row.names = FALSE)
}

cv <- locked$cv_clean
avg_rmse <- aggregate(
  cv[c("RMSE_ARIMA", "RMSE_ETS", "RMSE_SETAR", "RMSE_MSAR", "RMSE_NAIVE")],
  by = list(h = cv$h), FUN = function(x) mean(x, na.rm = TRUE)
)
write.csv(avg_rmse, "outputs/public/average_rmse_by_horizon.csv", row.names = FALSE)

rmse_wins <- sort(table(cv$best_RMSE), decreasing = TRUE)
mase_wins <- sort(table(cv$best_MASE), decreasing = TRUE)
write.csv(data.frame(model = names(rmse_wins), wins = as.integer(rmse_wins)),
          "outputs/public/rmse_win_counts.csv", row.names = FALSE)
write.csv(data.frame(model = names(mase_wins), wins = as.integer(mase_wins)),
          "outputs/public/mase_win_counts.csv", row.names = FALSE)

cat("Locked snapshot validated.\n")
cat("Objects:", paste(names(locked), collapse = ", "), "\n")
cat("Forecast cases:", nrow(cv), "\n")
cat("Public CSV outputs written to outputs/public/.\n")
