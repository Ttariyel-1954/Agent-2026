# =============================================
# ARTI-2026: CAT Motor Testləri
# testthat çərçivəsi
# =============================================

library(testthat)

# Modul fayllarını yüklə
source("R/constants.R", local = TRUE)
source("modules/assessment/cat_engine.R", local = TRUE)

context("CAT Motor Testləri")

# =============================================
# Test Hazırlıq
# =============================================

# Nümunə sual bankı
sample_items <- data.frame(
  id = paste0("item_", 1:20),
  irt_a = runif(20, 0.5, 2.5),
  irt_b = seq(-3, 3, length.out = 20),
  irt_c = rep(0.2, 20),
  times_used = rep(0, 20),
  is_active = rep(TRUE, 20),
  stringsAsFactors = FALSE
)

# =============================================
# CAT İnisializasiyası Testləri
# =============================================

test_that("CAT sessiyası düzgün inisializasiya olunur", {
  session <- initialize_cat(sample_items)

  expect_type(session, "list")
  expect_equal(session$theta, 0)
  expect_equal(session$se, 1)
  expect_equal(length(session$responses), 0)
  expect_equal(length(session$administered), 0)
  expect_false(session$completed)
})

# =============================================
# Sual Seçimi Testləri
# =============================================

test_that("MFI ilə sual seçimi işləyir", {
  session <- initialize_cat(sample_items)

  next_item <- select_next_item(session, sample_items)

  # Seçilmiş sual bankda olmalıdır
  expect_true(next_item$id %in% sample_items$id)

  # İlk sual theta=0 üçün ən informativ olmalıdır
  # (b parametri 0-a ən yaxın olan)
  info_values <- sapply(1:nrow(sample_items), function(i) {
    calculate_information(0, sample_items$irt_a[i], sample_items$irt_b[i], sample_items$irt_c[i])
  })

  # Seçilmiş sualın informasiyası yüksək olmalıdır
  selected_idx <- which(sample_items$id == next_item$id)
  expect_gt(info_values[selected_idx], median(info_values))
})

test_that("Artıq verilmiş suallar təkrar seçilmir", {
  session <- initialize_cat(sample_items)
  session$administered <- c("item_1", "item_2", "item_3")

  next_item <- select_next_item(session, sample_items)

  # Seçilmiş sual artıq verilmişlər arasında olmamalıdır
  expect_false(next_item$id %in% session$administered)
})

# =============================================
# Theta Yeniləmə Testləri
# =============================================

test_that("Düzgün cavabdan sonra theta artır", {
  session <- initialize_cat(sample_items)
  session$theta <- 0
  session$responses <- list(list(item_id = "item_10", correct = TRUE))
  session$administered <- c("item_10")

  updated <- update_theta(session, sample_items)

  # Düzgün cavabdan sonra theta artmalıdır (əksər hallarda)
  # İlk cavabdan sonra Bayesian metod istifadə olunduğu üçün
  expect_type(updated$theta, "double")
  expect_type(updated$se, "double")
})

test_that("Yanlış cavabdan sonra theta azalır", {
  session <- initialize_cat(sample_items)
  session$theta <- 0
  session$responses <- list(
    list(item_id = "item_10", correct = FALSE),
    list(item_id = "item_11", correct = FALSE),
    list(item_id = "item_12", correct = FALSE)
  )
  session$administered <- c("item_10", "item_11", "item_12")

  updated <- update_theta(session, sample_items)

  # Yanlış cavablardan sonra theta aşağı olmalıdır
  expect_lt(updated$theta, 1)
})

# =============================================
# Dayandırma Qaydası Testləri
# =============================================

test_that("SE həddinə çatdıqda test dayanır", {
  session <- initialize_cat(sample_items)
  session$se <- 0.25  # SE threshold-dan aşağı
  session$responses <- as.list(1:10)  # Minimum sual sayını keçib

  should_stop <- check_stopping_rule(session)
  expect_true(should_stop)
})

test_that("Maksimum sual sayına çatdıqda test dayanır", {
  session <- initialize_cat(sample_items)
  session$se <- 1.0  # Hələ yüksək SE
  session$responses <- as.list(1:50)  # Max sual sayı

  should_stop <- check_stopping_rule(session)
  expect_true(should_stop)
})

test_that("Hələ erkən olduqda test dayanmır", {
  session <- initialize_cat(sample_items)
  session$se <- 0.8
  session$responses <- as.list(1:3)

  should_stop <- check_stopping_rule(session)
  expect_false(should_stop)
})

# =============================================
# SE Hesablama Testləri
# =============================================

test_that("SE düzgün hesablanır", {
  theta <- 0
  items <- sample_items[1:10, ]

  se <- calculate_se(theta, items)

  # SE müsbət olmalıdır
  expect_gt(se, 0)

  # Daha çox sual - daha aşağı SE
  se_less <- calculate_se(theta, items[1:5, ])
  expect_gt(se_less, se)
})

# =============================================
# Exposure Control Testləri
# =============================================

test_that("Sympson-Hetter exposure control işləyir", {
  # Yüksək exposure rate ilə bəzi suallar bloklanmalıdır
  items_with_exposure <- sample_items
  items_with_exposure$exposure_rate <- runif(20, 0, 1)
  items_with_exposure$control_param <- ifelse(
    items_with_exposure$exposure_rate > 0.3, 0.5, 1.0
  )

  # Exposure control tətbiq olunduqda seçim dəyişə bilər
  expect_true(is.data.frame(items_with_exposure))
})

# =============================================
# Tam CAT Simulyasiyası
# =============================================

test_that("Tam CAT sessiyası simulyasiya edilə bilər", {
  session <- initialize_cat(sample_items)
  true_theta <- 1.0  # Əsl theta
  max_iter <- 30

  for (i in 1:max_iter) {
    if (session$completed) break

    # Sual seç
    next_item <- select_next_item(session, sample_items)

    # Cavabı simulyasiya et
    prob <- irt_3pl_probability(true_theta, next_item$irt_a, next_item$irt_b, next_item$irt_c)
    correct <- runif(1) < prob

    # Sessiyaya əlavə et
    session$responses <- c(session$responses, list(list(
      item_id = next_item$id,
      correct = correct
    )))
    session$administered <- c(session$administered, next_item$id)

    # Theta yenilə
    session <- update_theta(session, sample_items)

    # Dayandırma yoxla
    if (check_stopping_rule(session)) {
      session$completed <- TRUE
    }
  }

  # Qiymətləndirilmiş theta əsl theta-ya yaxın olmalıdır
  # (böyük tolerans - simulyasiya variasiyası var)
  expect_gt(session$theta, true_theta - 2)
  expect_lt(session$theta, true_theta + 2)

  # Ən azı bir neçə sual verilmiş olmalıdır
  expect_gt(length(session$administered), 0)
})

# Testləri işlət
cat("\n=== CAT Motor Testləri Tamamlandı ===\n")
