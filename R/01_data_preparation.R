# 01 — Data preparation
# Reconstructed thesis pipeline — October 2026
# Provenance: computation reconstructed from the final V1 Rmd (30 June 2026).
#
# The raw workbook contains proprietary data and is not distributed
# with this repository. Only the four columns required by the analysis
# are imported from the IL_AWD sheet.

suppressPackageStartupMessages({
  library(readxl)
  library(dplyr)
  library(purrr)
})


# -------------------------------------------------------------------------
# Raw data location
# -------------------------------------------------------------------------

data_path <- Sys.getenv(
  "THESIS_DATA_PATH",
  unset = "data/SP-API_NEATS_APR_2026.xlsx"
)

if (!file.exists(data_path)) {
  stop(
    "Raw workbook not found. The source data are proprietary and are not distributed. ",
    "Set THESIS_DATA_PATH to an authorized local copy."
  )
}


# -------------------------------------------------------------------------
# Import
# -------------------------------------------------------------------------

# Only four columns from IL_AWD are required by the analysis.
# All remaining workbook columns are skipped during import.
#
# Column positions in the original workbook:
#   6  = Disposition
#   29 = LedgerDayUTC
#   30 = Master SKU
#   40 = Final_OnHand_Effective
#
# LedgerDayUTC is stored as YYYY-MM-DD text in the source workbook
# and is converted to Date after import.

col_types <- rep("skip", 41)

col_types[c(6, 29, 30, 40)] <- c(
  "text",     # Disposition
  "text",     # LedgerDayUTC
  "text",     # Master SKU
  "numeric"   # Final_OnHand_Effective
)

il_awd <- read_excel(
  data_path,
  sheet = "IL_AWD",
  col_types = col_types
)


# -------------------------------------------------------------------------
# Input validation
# -------------------------------------------------------------------------

required_columns <- c(
  "Disposition",
  "LedgerDayUTC",
  "Master SKU",
  "Final_OnHand_Effective"
)

missing_columns <- setdiff(required_columns, names(il_awd))

if (length(missing_columns) > 0) {
  stop(
    "Missing required IL_AWD columns: ",
    paste(missing_columns, collapse = ", ")
  )
}


# -------------------------------------------------------------------------
# Daily stock aggregation
# -------------------------------------------------------------------------

df_sku <- il_awd |>
  filter(Disposition == "SELLABLE") |>
  mutate(date = as.Date(LedgerDayUTC)) |>
  group_by(`Master SKU`, date) |>
  summarise(
    stock = sum(Final_OnHand_Effective, na.rm = TRUE),
    .groups = "drop"
  )


# -------------------------------------------------------------------------
# Thesis sample
# -------------------------------------------------------------------------

selected_skus <- c(
  "AA00",
  "AG00",
  "AA03",
  "AA04",
  "AG03",
  "AG04",
  "AJ00",
  "AG01"
)

df_main <- df_sku |>
  filter(`Master SKU` %in% selected_skus)


# -------------------------------------------------------------------------
# Descriptive statistics
# -------------------------------------------------------------------------

desc_stats <- df_main |>
  group_by(`Master SKU`) |>
  summarise(
    n    = n(),
    Mean = round(mean(stock, na.rm = TRUE), 1),
    SD   = round(sd(stock, na.rm = TRUE), 1),
    Min  = round(min(stock, na.rm = TRUE), 0),
    Max  = round(max(stock, na.rm = TRUE), 0),
    CV   = round(
      sd(stock, na.rm = TRUE) / mean(stock, na.rm = TRUE),
      3
    ),
    .groups = "drop"
  ) |>
  arrange(`Master SKU`)


# -------------------------------------------------------------------------
# Time-series objects
# -------------------------------------------------------------------------

# Daily observations with weekly seasonality (frequency = 7).

ts_list <- selected_skus |>
  set_names() |>
  map(function(sku) {
    
    x <- df_main |>
      filter(`Master SKU` == sku) |>
      arrange(date) |>
      pull(stock)
    
    ts(x, frequency = 7)
  })


# Data frame retained for figures.

plot_df <- df_main |>
  arrange(`Master SKU`, date)


# -------------------------------------------------------------------------
# Save prepared analytical data
# -------------------------------------------------------------------------

dir.create(
  "outputs",
  showWarnings = FALSE,
  recursive = TRUE
)

saveRDS(
  list(
    df_main = df_main,
    selected_skus = selected_skus,
    desc_stats = desc_stats,
    ts_list = ts_list,
    plot_df = plot_df
  ),
  "outputs/01_prepared_data.rds"
)