# 06 — Figures and tables
# Reconstructed thesis pipeline — October 2026
# Provenance: Reconstructed integration layer. Uses V1 computed objects and V2 presentation choices; historical SKUs_plot.R and thesis_tables_export.R are preserved in archive/.
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

dir.create("outputs/figures", showWarnings = FALSE, recursive = TRUE)
dir.create("outputs/tables", showWarnings = FALSE, recursive = TRUE)
prep <- readRDS("outputs/01_prepared_data.rds"); list2env(prep, envir=environment())
diag <- readRDS("outputs/02_diagnostics.rds"); list2env(diag, envir=environment())
mods <- readRDS("outputs/03_models.rds"); list2env(mods, envir=environment())
eval <- readRDS("outputs/04_forecast_evaluation.rds"); list2env(eval, envir=environment())
risk <- readRDS("outputs/05_low_stock.rds"); list2env(risk, envir=environment())

# Machine-readable tables used for validation / portfolio output.
write.csv(desc_stats, "outputs/tables/descriptive_statistics.csv", row.names=FALSE)
write.csv(stat_table, "outputs/tables/stationarity_tests.csv", row.names=FALSE)
write.csv(tsay_reference_v2, "outputs/tables/tsay_reported_v2.csv", row.names=FALSE)
write.csv(arima_orders, "outputs/tables/arima_specifications.csv", row.names=FALSE)
write.csv(ets_specs, "outputs/tables/ets_specifications.csv", row.names=FALSE)
write.csv(setar_summary, "outputs/tables/setar_summary.csv", row.names=FALSE)
write.csv(msar_summary_full, "outputs/tables/msar_parameters.csv", row.names=FALSE)
write.csv(cv_clean, "outputs/tables/forecast_accuracy.csv", row.names=FALSE)
write.csv(dm_table, "outputs/tables/dm_tests.csv", row.names=FALSE)
write.csv(mcs_table, "outputs/tables/mcs.csv", row.names=FALSE)
write.csv(lowstock_robustness_table, "outputs/tables/low_stock_robustness.csv", row.names=FALSE)

# V2-style stock trajectories.
p_stock <- ggplot(plot_df, aes(date, stock)) +
  geom_line(linewidth=.6) + facet_wrap(~`Master SKU`, ncol=2, scales="free_y") +
  labs(x=NULL, y="SELLABLE stock (units)") + theme_bw() +
  theme(strip.background=element_blank(), strip.text=element_text(face="bold"), panel.grid.minor=element_blank())
ggsave("outputs/figures/stock_trajectories_all.png", p_stock, width=8, height=10, dpi=300)

# ACF/PACF are intentionally kept as a separate historical presentation script in archive/SKUs_plot_V2.R.
# That script can be folded in after the numerical pipeline has been validated.
