# 04 — Forecast evaluation
# Reconstructed thesis pipeline — October 2026
# Provenance: Copied from final V1 Rmd: rolling-origin CV, SETAR stability filter, DM tests and MCS.
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

n_init  <- 80
h_list  <- c(1, 7, 14)

rmse_fn <- function(e)        sqrt(mean(e^2, na.rm = TRUE))
mase_fn <- function(e, train) mean(abs(e), na.rm = TRUE) /
                               mean(abs(diff(train)), na.rm = TRUE)

err_list   <- list()
cv_results <- list()

for (sku in selected_skus) {
  x <- as.numeric(ts_list[[sku]])
  n <- length(x)

  for (h in h_list) {
    origs <- seq(n_init, n - h)
    ne    <- length(origs)

    err <- matrix(NA, ne, 5,
                  dimnames = list(NULL, c("ARIMA", "ETS", "SETAR", "MSAR", "NAIVE")))

    for (i in seq_along(origs)) {
      orig   <- origs[i]
      train  <- ts(x[1:orig], frequency = 7)
      actual <- x[orig + h]

      err[i, "NAIVE"] <- x[orig] - actual

      tryCatch({
        m <- auto.arima(train, max.p = 2, max.q = 1, max.d = 1,
                        seasonal = FALSE, stepwise = TRUE)
        err[i, "ARIMA"] <- forecast(m, h = h)$mean[h] - actual
      }, error = function(e) NULL)

      tryCatch({
        m <- ets(train)
        err[i, "ETS"] <- forecast(m, h = h)$mean[h] - actual
      }, error = function(e) NULL)

      tryCatch({
        m <- setar(train, nthresh = 1, m = 2, d = 1)
        err[i, "SETAR"] <- predict(m, n.ahead = h)[h] - actual
      }, error = function(e) NULL)

      tryCatch({
        base  <- lm(train ~ 1)
        m     <- msmFit(base, k = 2, p = 1, sw = rep(TRUE, 3),
                        control = list(parallel = FALSE))
        p     <- as.numeric(tail(m@Fit@smoProb, 1))
        alpha <- m@Coef[, 1]
        phi   <- m@Coef[, 2]
        x_fc  <- tail(as.numeric(train), 1)
        trans <- m@transMat
        for (step in 1:h) {
          p    <- as.numeric(trans %*% p)
          x_fc <- sum(p * (alpha + phi * x_fc))
        }
        err[i, "MSAR"] <- x_fc - actual
      }, error = function(e) NULL)
    }

    train_ref <- x[1:n_init]
    key       <- paste(sku, h, sep = "_")

    cv_results[[key]] <- tibble(
      SKU          = sku,
      h            = h,
      RMSE_ARIMA   = rmse_fn(err[, "ARIMA"]),
      RMSE_ETS     = rmse_fn(err[, "ETS"]),
      RMSE_SETAR   = rmse_fn(err[, "SETAR"]),
      RMSE_MSAR    = rmse_fn(err[, "MSAR"]),
      RMSE_NAIVE   = rmse_fn(err[, "NAIVE"]),
      MASE_ARIMA   = mase_fn(err[, "ARIMA"],  train_ref),
      MASE_ETS     = mase_fn(err[, "ETS"],    train_ref),
      MASE_SETAR   = mase_fn(err[, "SETAR"],  train_ref),
      MASE_MSAR    = mase_fn(err[, "MSAR"],   train_ref),
      MASE_NAIVE   = mase_fn(err[, "NAIVE"],  train_ref),
      n_forecasts  = ne,
      n_msar_valid = sum(!is.na(err[, "MSAR"]))
    )

    err_list[[key]] <- err
  }
}

cv_table <- bind_rows(cv_results)

cv_clean <- cv_table |>
  mutate(
    RMSE_SETAR = ifelse(RMSE_SETAR > 3 * RMSE_NAIVE, NA, RMSE_SETAR),
    MASE_SETAR = ifelse(MASE_SETAR > 3 * MASE_NAIVE, NA, MASE_SETAR)
  )

cv_clean <- cv_clean |>
  rowwise() |>
  mutate(
    best_RMSE = c("ARIMA", "ETS", "SETAR", "MSAR", "NAIVE")[
      which.min(c(RMSE_ARIMA, RMSE_ETS, RMSE_SETAR, RMSE_MSAR, RMSE_NAIVE))],
    best_MASE = c("ARIMA", "ETS", "SETAR", "MSAR", "NAIVE")[
      which.min(c(MASE_ARIMA, MASE_ETS, MASE_SETAR, MASE_MSAR, MASE_NAIVE))]
  ) |>
  ungroup()

dm_full <- list()

for (sku in selected_skus) {
  for (h in h_list) {
    key      <- paste(sku, h, sep = "_")
    e        <- err_list[[key]]
    e_MSAR   <- e[, "MSAR"]
    e_NAIVE  <- e[, "NAIVE"]
    e_SETAR  <- ifelse(abs(e[, "SETAR"]) > 3 * abs(e_NAIVE), NA, e[, "SETAR"])

    run_dm <- function(e1, e2, comp) {
      keep    <- !is.na(e1) & !is.na(e2)
      n_valid <- sum(keep)
      if (n_valid < 10)
        return(tibble(SKU = sku, h = h, comparison = comp,
                      DM_stat = NA_real_, p_value = NA_real_,
                      n = n_valid, sig = FALSE))
      tryCatch({
        test <- dm.test(e1[keep], e2[keep],
                        alternative  = "less",
                        h            = h,
                        power        = 2,
                        varestimator = "bartlett")
        tibble(SKU        = sku,
               h          = h,
               comparison = comp,
               DM_stat    = round(as.numeric(test$statistic), 3),
               p_value    = round(test$p.value, 4),
               n          = n_valid,
               sig        = test$p.value < 0.05)
      }, error = function(err)
        tibble(SKU = sku, h = h, comparison = comp,
               DM_stat = NA_real_, p_value = NA_real_,
               n = n_valid, sig = FALSE))
    }

    dm_full[[key]] <- bind_rows(
      run_dm(e_MSAR, e[, "ARIMA"], "MSAR vs ARIMA"),
      run_dm(e_MSAR, e[, "ETS"],   "MSAR vs ETS"),
      run_dm(e_MSAR, e_SETAR,      "MSAR vs SETAR"),
      run_dm(e_MSAR, e_NAIVE,      "MSAR vs NAIVE")
    )
  }
}

dm_table <- bind_rows(dm_full)

set.seed(123)

alpha_mcs <- 0.10
B_mcs     <- 5000
mcs_full  <- list()

for (sku in selected_skus) {
  for (h in h_list) {
    key     <- paste(sku, h, sep = "_")
    e       <- err_list[[key]]
    e_naive <- e[, "NAIVE"]
    e_setar <- ifelse(abs(e[, "SETAR"]) > 3 * abs(e_naive), NA, e[, "SETAR"])

    loss_mat <- cbind(
      ARIMA = e[, "ARIMA"]^2,
      ETS   = e[, "ETS"]^2,
      SETAR = e_setar^2,
      MSAR  = e[, "MSAR"]^2,
      NAIVE = e[, "NAIVE"]^2
    )

    if (sum(!is.na(e_setar)) < 10)
      loss_mat <- loss_mat[, c("ARIMA", "ETS", "MSAR", "NAIVE"), drop = FALSE]

    loss_clean <- loss_mat[complete.cases(loss_mat), , drop = FALSE]

    if (nrow(loss_clean) < 10) {
      mcs_full[[key]] <- tibble(SKU = sku, h = h,
                                MCS    = "insufficient data",
                                n      = nrow(loss_clean),
                                status = "insufficient data")
      next
    }

    mcs_result <- tryCatch({
      invisible(capture.output({
        mcs_out <- MCSprocedure(Loss      = loss_clean,
                                alpha     = alpha_mcs,
                                B         = B_mcs,
                                statistic = "Tmax")
      }))
      show_df   <- mcs_out@show
      surviving <- rownames(show_df)[
        show_df[, "p-Value for H_{0,M_k}"] >= alpha_mcs
      ]
      tibble(SKU    = sku,
             h      = h,
             MCS    = paste(sort(surviving), collapse = ", "),
             n      = nrow(loss_clean),
             status = "ok")
    }, error = function(err)
      tibble(SKU    = sku,
             h      = h,
             MCS    = paste("error:", err$message),
             n      = nrow(loss_clean),
             status = "error"))

    mcs_full[[key]] <- mcs_result
  }
}

mcs_table <- bind_rows(mcs_full)

mcs_summary <- mcs_table |>
  filter(MCS != "insufficient data", !grepl("^error:", MCS)) |>
  mutate(
    MSAR_in_MCS      = grepl("MSAR",  MCS),
    ARIMA_in_MCS     = grepl("ARIMA", MCS),
    ETS_in_MCS       = grepl("ETS",   MCS),
    SETAR_in_MCS     = grepl("SETAR", MCS),
    NAIVE_in_MCS     = grepl("NAIVE", MCS),
    n_models_in_MCS  = lengths(strsplit(MCS, ", "))
  )

saveRDS(list(cv_table=cv_table, cv_clean=cv_clean, err_list=err_list, dm_table=dm_table, mcs_table=mcs_table, mcs_summary=mcs_summary), "outputs/04_forecast_evaluation.rds")
