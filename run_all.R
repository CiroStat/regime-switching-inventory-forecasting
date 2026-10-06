# Full analytical pipeline.
# Requires an authorized local copy of the proprietary source workbook.

scripts <- c(
  "R/01_data_preparation.R",
  "R/02_diagnostics.R",
  "R/03_models.R",
  "R/04_forecast_evaluation.R",
  "R/05_low_stock_simulation.R",
  "R/06_figures_tables.R"
)

for (s in scripts) {
  message("\n=== Running ", s, " ===")
  source(s, local = new.env(parent = globalenv()))
}

message("\nAnalytical pipeline completed.")
message("The presentation-only workflow diagram can be regenerated separately with R/07_monte_carlo_workflow_diagram.R.")
