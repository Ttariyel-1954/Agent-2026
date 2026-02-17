# =============================================
# ARTI-2026: IRT Motor Testləri
# testthat çərçivəsi
# =============================================

library(testthat)

# Modul fayllarını yüklə
source("modules/assessment/irt_engine.R", local = TRUE)

context("IRT Motor Testləri")

# =============================================
# 1PL Model Testləri
# =============================================

test_that("1PL ehtimal hesablaması düzgün işləyir", {
  # theta = 0, b = 0 olduqda ehtimal 0.5 olmalıdır
  prob <- irt_1pl_probability(theta = 0, b = 0)
  expect_equal(prob, 0.5, tolerance = 0.01)

  # theta > b olduqda ehtimal > 0.5
  prob_high <- irt_1pl_probability(theta = 2, b = 0)
  expect_gt(prob_high, 0.5)

  # theta < b olduqda ehtimal < 0.5
  prob_low <- irt_1pl_probability(theta = -2, b = 0)
  expect_lt(prob_low, 0.5)

  # Ehtimal 0-1 arasında olmalıdır
  expect_gte(prob, 0)
  expect_lte(prob, 1)
})

# =============================================
# 2PL Model Testləri
# =============================================

test_that("2PL ehtimal hesablaması düzgün işləyir", {
  # Əsas ehtimal yoxlaması
  prob <- irt_2pl_probability(theta = 0, a = 1, b = 0)
  expect_equal(prob, 0.5, tolerance = 0.01)

  # Yüksək fərqləndirmə parametri ilə
  prob_high_a <- irt_2pl_probability(theta = 1, a = 2, b = 0)
  prob_low_a <- irt_2pl_probability(theta = 1, a = 0.5, b = 0)
  expect_gt(prob_high_a, prob_low_a)

  # a parametri müsbət olmalıdır
  expect_error(irt_2pl_probability(theta = 0, a = -1, b = 0))
})

# =============================================
# 3PL Model Testləri
# =============================================

test_that("3PL ehtimal hesablaması təxmin parametrini nəzərə alır", {
  # c=0.2 ilə minimum ehtimal 0.2 olmalıdır
  prob <- irt_3pl_probability(theta = -5, a = 1, b = 0, c = 0.2)
  expect_gte(prob, 0.19)  # c-yə yaxın olmalıdır

  # c=0 olduqda 2PL ilə eyni olmalıdır
  prob_3pl <- irt_3pl_probability(theta = 1, a = 1.5, b = 0.5, c = 0)
  prob_2pl <- irt_2pl_probability(theta = 1, a = 1.5, b = 0.5)
  expect_equal(prob_3pl, prob_2pl, tolerance = 0.001)

  # c parametri 0-1 arasında olmalıdır
  expect_error(irt_3pl_probability(theta = 0, a = 1, b = 0, c = -0.1))
  expect_error(irt_3pl_probability(theta = 0, a = 1, b = 0, c = 1.1))
})

# =============================================
# İnformasiya Funksiyası Testləri
# =============================================

test_that("Fisher informasiya funksiyası düzgün hesablanır", {
  # theta = b olduqda informasiya maksimum olmalıdır (3PL istisna)
  info_at_b <- calculate_information(theta = 0, a = 1.5, b = 0, c = 0)
  info_away <- calculate_information(theta = 2, a = 1.5, b = 0, c = 0)
  expect_gt(info_at_b, info_away)

  # İnformasiya həmişə müsbət olmalıdır
  expect_gt(info_at_b, 0)
  expect_gt(info_away, 0)

  # Yüksək fərqləndirmə - yüksək informasiya
  info_high_a <- calculate_information(theta = 0, a = 2, b = 0, c = 0)
  info_low_a <- calculate_information(theta = 0, a = 0.5, b = 0, c = 0)
  expect_gt(info_high_a, info_low_a)
})

test_that("Test informasiya funksiyası düzgün hesablanır", {
  items <- data.frame(
    irt_a = c(1.0, 1.5, 2.0),
    irt_b = c(-1, 0, 1),
    irt_c = c(0.2, 0.2, 0.2)
  )

  info <- test_information(theta = 0, items = items)

  # Test informasiyası individual informasiyaların cəmi olmalıdır
  individual_info <- sum(sapply(1:3, function(i) {
    calculate_information(0, items$irt_a[i], items$irt_b[i], items$irt_c[i])
  }))
  expect_equal(info, individual_info, tolerance = 0.001)
})

# =============================================
# MLE Theta Hesablama Testləri
# =============================================

test_that("MLE theta hesablaması konvergensiya edir", {
  # Bütün düzgün cavablar - yüksək theta
  items <- data.frame(irt_a = rep(1, 5), irt_b = c(-2, -1, 0, 1, 2), irt_c = rep(0.2, 5))
  responses <- c(1, 1, 1, 1, 1)
  theta <- estimate_theta_mle(responses, items)
  expect_gt(theta, 1)

  # Bütün yanlış cavablar - aşağı theta
  responses_wrong <- c(0, 0, 0, 0, 0)
  theta_low <- estimate_theta_mle(responses_wrong, items)
  expect_lt(theta_low, -1)

  # Theta -4 ilə 4 arasında olmalıdır
  expect_gte(theta, -4)
  expect_lte(theta, 4)
})

# =============================================
# EAP Theta Hesablama Testləri
# =============================================

test_that("EAP theta hesablaması ağlabatan nəticə verir", {
  items <- data.frame(irt_a = rep(1, 5), irt_b = c(-2, -1, 0, 1, 2), irt_c = rep(0.2, 5))
  responses <- c(1, 1, 1, 0, 0)

  theta <- estimate_theta_eap(responses, items)

  # EAP theta -4 ilə 4 arasında
  expect_gte(theta, -4)
  expect_lte(theta, 4)

  # Cavablar pattern-inə uyğun olmalıdır (orta çətinlikdə)
  expect_gt(theta, -2)
  expect_lt(theta, 2)
})

# =============================================
# Uyğunluq Statistikası Testləri
# =============================================

test_that("Item fit statistikaları hesablanır", {
  # Minimal data ilə test
  item <- list(irt_a = 1.0, irt_b = 0, irt_c = 0.2)
  responses <- c(1, 0, 1, 1, 0, 1, 0, 1, 1, 0)
  thetas <- rnorm(10, 0, 1)

  fit <- item_fit_statistics(item, responses, thetas)

  # Nəticə siyahı olmalıdır
  expect_type(fit, "list")
  expect_true("infit" %in% names(fit))
  expect_true("outfit" %in% names(fit))
})

# Testləri işlət
cat("\n=== IRT Motor Testləri Tamamlandı ===\n")
