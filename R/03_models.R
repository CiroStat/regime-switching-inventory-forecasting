# 03 — Model estimation
# Reconstructed thesis pipeline — October 2026
# Provenance: Copied from final V1 Rmd; no V2 re-estimation logic added.
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

arima_models <- ts_list |>
  map(\(x) auto.arima(x,
                       max.p    = 2,
                       max.q    = 1,
                       max.d    = 1,
                       seasonal = FALSE,
                       stepwise = FALSE))

arima_orders <- map_dfr(selected_skus, function(sku) {
  m <- arima_models[[sku]]
  o <- arimaorder(m)
  tibble(SKU = sku, p = o["p"], d = o["d"], q = o["q"],
         AIC = round(m$aic, 2), BIC = round(m$bic, 2))
})

ets_models <- ts_list |> map(\(x) ets(x))

ets_specs <- map_dfr(selected_skus, function(sku) {
  m <- ets_models[[sku]]
  tibble(SKU = sku, Model = m$method,
         AIC = round(m$aic, 2), BIC = round(m$bic, 2))
})

setar_models <- ts_list |>
  map(\(x) setar(x, nthresh = 1, m = 2, d = 1))

get_setar_th <- function(model) {
  out     <- capture.output(summary(model))
  th_line <- grep("^\\s*-?Value:", out, value = TRUE)[1]
  as.numeric(trimws(gsub("^\\s*-?Value:\\s*", "", th_line)))
}

setar_summary <- selected_skus |>
  set_names() |>
  map_dfr(\(sku) {
    m  <- setar_models[[sku]]
    ms <- m$model.specific

    fit <- as.numeric(m$fitted.values)
    act <- tail(as.numeric(ts_list[[sku]]), length(fit))

    mape <- mean(abs((act - fit) / act), na.rm = TRUE) * 100

    tibble(
      SKU       = sku,
      threshold = get_setar_th(m),
      pct_low   = round(ms$RegProp[1] * 100, 1),
      pct_high  = round(ms$RegProp[2] * 100, 1),
      MAPE      = round(mape, 2)
    )
  })



msar_models <- ts_list |>
  map(\(x) {
    base <- lm(x ~ 1)
    msmFit(base, k = 2, p = 1, sw = rep(TRUE, 3),
           control = list(parallel = FALSE))
  })

msar_summary_full <- selected_skus |>
  set_names() |>
  map_dfr(\(sku) {
    m <- msar_models[[sku]]
    tibble(
      SKU    = sku,
      alpha1 = round(m@Coef[1, 1], 1),
      phi1   = round(m@Coef[1, 2], 3),
      sd1    = round(m@std[1],     1),
      p11    = round(m@transMat[1, 1], 3),
      dur1   = round(1 / (1 - m@transMat[1, 1]), 1),
      alpha2 = round(m@Coef[2, 1], 1),
      phi2   = round(m@Coef[2, 2], 3),
      sd2    = round(m@std[2],     1),
      p22    = round(m@transMat[2, 2], 3),
      dur2   = round(1 / (1 - m@transMat[2, 2]), 1)
    )
  })

saveRDS(list(arima_models=arima_models, arima_orders=arima_orders, ets_models=ets_models, ets_specs=ets_specs, setar_models=setar_models, setar_summary=setar_summary, msar_models=msar_models, msar_summary_full=msar_summary_full), "outputs/03_models.rds")
