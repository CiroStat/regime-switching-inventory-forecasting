# 05 — Low-stock simulation
# Reconstructed thesis pipeline — October 2026
# Provenance: Copied from final V1 Rmd. Monte Carlo results should be compared with the historical locked RDS because MS-AR estimation/simulation can be stochastic.
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
h_list <- c(1, 7, 14)

set.seed(42)
B <- 2000

lowstock_results <- list()

for (sku in selected_skus) {
  x    <- as.numeric(ts_list[[sku]])
  x_ts <- ts(x, frequency = 7)

  threshold <- quantile(x, 0.10)

  base   <- lm(x_ts ~ 1)
  m_full <- msmFit(base, k = 2, p = 1, sw = rep(TRUE, 3),
                   control = list(parallel = FALSE))

  alpha_coef <- m_full@Coef[, 1]
  phi        <- m_full@Coef[, 2]
  sigma      <- m_full@std
  trans      <- m_full@transMat

  p0     <- as.numeric(tail(m_full@Fit@smoProb, 1))
  x_last <- tail(x, 1)

  H     <- max(h_list)
  paths <- matrix(NA, B, H)

  for (b in 1:B) {
    p_b <- p0
    x_b <- x_last
    for (t in 1:H) {
      p_b    <- as.numeric(trans %*% p_b)
      regime <- sample(1:2, 1, prob = p_b)
      x_b    <- alpha_coef[regime] + phi[regime] * x_b +
                 rnorm(1, 0, sigma[regime])
      paths[b, t] <- x_b
    }
  }

  prob_low <- sapply(h_list, function(h)
    mean(paths[, h] < threshold, na.rm = TRUE))

  lowstock_results[[sku]] <- tibble(
    SKU       = sku,
    last_obs  = round(x_last),
    threshold = round(threshold),
    P_h1      = round(prob_low[1], 3),
    P_h7      = round(prob_low[2], 3),
    P_h14     = round(prob_low[3], 3)
  )
}

lowstock_table <- bind_rows(lowstock_results)

set.seed(42)
B_rob <- 2000

threshold_probs <- c(0.05, 0.10, 0.20)
lowstock_robustness <- list()

for (sku in selected_skus) {
  x    <- as.numeric(ts_list[[sku]])
  x_ts <- ts(x, frequency = 7)

  base   <- lm(x_ts ~ 1)
  m_full <- msmFit(base, k = 2, p = 1, sw = rep(TRUE, 3),
                   control = list(parallel = FALSE))

  alpha_coef <- m_full@Coef[, 1]
  phi        <- m_full@Coef[, 2]
  sigma      <- m_full@std
  trans      <- m_full@transMat

  p0     <- as.numeric(tail(m_full@Fit@smoProb, 1))
  x_last <- tail(x, 1)

  H     <- max(h_list)
  paths <- matrix(NA, B_rob, H)

  for (b in 1:B_rob) {
    p_b <- p0
    x_b <- x_last
    for (t in 1:H) {
      p_b    <- as.numeric(trans %*% p_b)
      regime <- sample(1:2, 1, prob = p_b)
      x_b    <- alpha_coef[regime] + phi[regime] * x_b +
                 rnorm(1, 0, sigma[regime])
      paths[b, t] <- x_b
    }
  }

  for (q in threshold_probs) {
    threshold <- quantile(x, q)
    prob_low  <- sapply(h_list, function(h)
      mean(paths[, h] < threshold, na.rm = TRUE))

    lowstock_robustness[[paste(sku, q, sep = "_")]] <- tibble(
      SKU       = sku,
      threshold_percentile = q,
      threshold = round(threshold),
      P_h1      = round(prob_low[1], 3),
      P_h7      = round(prob_low[2], 3),
      P_h14     = round(prob_low[3], 3)
    )
  }
}

lowstock_robustness_table <- bind_rows(lowstock_robustness)

saveRDS(list(lowstock_table=lowstock_table, lowstock_robustness_table=lowstock_robustness_table), "outputs/05_low_stock.rds")
