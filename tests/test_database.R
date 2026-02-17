# =============================================
# ARTI-2026: Verilənlər Bazası Testləri
# testthat çərçivəsi
# =============================================

library(testthat)

# Köməkçi funksiyaları yüklə
source("R/constants.R", local = TRUE)
source("R/utils.R", local = TRUE)

context("Verilənlər Bazası və Köməkçi Funksiya Testləri")

# =============================================
# Qiymət Etiketi Testləri
# =============================================

test_that("Qiymət etiketləri düzgün qaytarılır", {
  expect_equal(get_grade_label(95), "Əla")
  expect_equal(get_grade_label(86), "Əla")
  expect_equal(get_grade_label(80), "Yaxşı")
  expect_equal(get_grade_label(71), "Yaxşı")
  expect_equal(get_grade_label(60), "Kafi")
  expect_equal(get_grade_label(51), "Kafi")
  expect_equal(get_grade_label(50), "Qeyri-kafi")
  expect_equal(get_grade_label(0), "Qeyri-kafi")
})

test_that("Qiymət rəngləri düzgün qaytarılır", {
  expect_equal(get_grade_color(90), "#27ae60")  # Əla - yaşıl
  expect_equal(get_grade_color(75), "#2980b9")  # Yaxşı - göy
  expect_equal(get_grade_color(55), "#f39c12")  # Kafi - sarı
  expect_equal(get_grade_color(30), "#e74c3c")  # Qeyri-kafi - qırmızı
})

# =============================================
# Validasiya Testləri
# =============================================

test_that("E-poçt validasiyası düzgün işləyir", {
  expect_true(validate_email("test@example.com"))
  expect_true(validate_email("user.name@domain.az"))
  expect_false(validate_email("invalid-email"))
  expect_false(validate_email("@domain.com"))
  expect_false(validate_email("user@"))
  expect_false(validate_email(""))
})

test_that("Telefon validasiyası düzgün işləyir", {
  expect_true(validate_phone_az("+994501234567"))
  expect_true(validate_phone_az("+994701234567"))
  expect_false(validate_phone_az("1234567"))
  expect_false(validate_phone_az("+1234567890"))
  expect_false(validate_phone_az(""))
})

test_that("FIN validasiyası düzgün işləyir", {
  expect_true(validate_fin("1AB2CD3"))
  expect_true(validate_fin("ABC1234"))
  expect_false(validate_fin("12345"))      # Çox qısa
  expect_false(validate_fin("12345678"))   # Çox uzun
  expect_false(validate_fin("abc!@#$"))    # Xüsusi simvollar
  expect_false(validate_fin(""))
})

test_that("Şifrə gücü validasiyası işləyir", {
  expect_true(validate_password_strength("Str0ngP@ss"))
  expect_false(validate_password_strength("weak"))
  expect_false(validate_password_strength("12345678"))
  expect_false(validate_password_strength(""))
})

# =============================================
# Utilit Funksiya Testləri
# =============================================

test_that("is_empty düzgün işləyir", {
  expect_true(is_empty(NULL))
  expect_true(is_empty(""))
  expect_true(is_empty(NA))
  expect_true(is_empty(character(0)))
  expect_false(is_empty("test"))
  expect_false(is_empty(42))
  expect_false(is_empty(c(1, 2, 3)))
})

test_that("%||% operatoru düzgün işləyir", {
  expect_equal(NULL %||% "default", "default")
  expect_equal("value" %||% "default", "value")
  expect_equal(42 %||% 0, 42)
})

test_that("UUID generasiyası düzgün işləyir", {
  uuid1 <- generate_uuid()
  uuid2 <- generate_uuid()

  # UUID formatı yoxla (8-4-4-4-12)
  expect_match(uuid1, "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")

  # Hər UUID unikal olmalıdır
  expect_false(uuid1 == uuid2)
})

test_that("Tarix formatlaması düzgün işləyir", {
  date <- as.Date("2026-02-15")
  formatted <- format_date_az(date)
  expect_equal(formatted, "15.02.2026")
})

test_that("Rəqəm formatlaması düzgün işləyir", {
  expect_equal(format_number_az(1234567), "1.234.567")
})

# =============================================
# Yaş Hesablama Testləri
# =============================================

test_that("Yaş hesablaması düzgün işləyir", {
  # 10 il əvvəl doğulmuş
  birth_date <- Sys.Date() - 365.25 * 10
  age <- calculate_age(birth_date)
  expect_equal(age, 10)

  # Bugün doğulmuş
  age_today <- calculate_age(Sys.Date())
  expect_equal(age_today, 0)
})

# =============================================
# Akademik İl Testləri
# =============================================

test_that("Akademik il düzgün hesablanır", {
  year <- get_academic_year()
  expect_match(year, "^\\d{4}-\\d{4}$")

  # Formatı yoxla: YYYY-YYYY
  parts <- strsplit(year, "-")[[1]]
  expect_equal(as.integer(parts[2]) - as.integer(parts[1]), 1)
})

test_that("Cari yarımill düzgün təyin olunur", {
  semester <- get_current_semester()
  expect_true(semester %in% c(1, 2))
})

# =============================================
# Şifrə Hash Testləri
# =============================================

test_that("Şifrə hashing düzgün işləyir", {
  password <- "TestP@ssw0rd"
  hash <- hash_password(password)

  # Hash boş olmamalıdır
  expect_true(nchar(hash) > 0)

  # Eyni şifrə yoxlaması müvəffəqiyyətli olmalıdır
  expect_true(verify_password(password, hash))

  # Fərqli şifrə yoxlaması uğursuz olmalıdır
  expect_false(verify_password("WrongPassword", hash))
})

# =============================================
# Qiymət Badge Testləri
# =============================================

test_that("Grade badge HTML düzgün generasiya olunur", {
  badge <- grade_badge(95)
  expect_true(grepl("Əla", badge))
  expect_true(grepl("badge", badge))

  badge_low <- grade_badge(30)
  expect_true(grepl("Qeyri-kafi", badge_low))
})

# =============================================
# Konstant Testləri
# =============================================

test_that("Qiymət şkalası düzgün təyin olunub", {
  expect_equal(GRADE_SCALE$ela$min, 86)
  expect_equal(GRADE_SCALE$ela$max, 100)
  expect_equal(GRADE_SCALE$yaxsi$min, 71)
  expect_equal(GRADE_SCALE$kafi$min, 51)
  expect_equal(GRADE_SCALE$qeyri_kafi$min, 0)
  expect_equal(GRADE_SCALE$qeyri_kafi$max, 50)
})

test_that("Fənnlər siyahısı boş deyil", {
  expect_gt(length(SUBJECTS), 0)
  expect_true("Riyaziyyat" %in% SUBJECTS)
  expect_true("Fizika" %in% SUBJECTS)
})

test_that("IRT default-ları ağlabatandır", {
  expect_equal(IRT_DEFAULTS$D, 1.7)
  expect_equal(IRT_DEFAULTS$theta_range, c(-4, 4))
  expect_true(IRT_DEFAULTS$default_c >= 0 && IRT_DEFAULTS$default_c <= 0.5)
})

test_that("CAT default-ları ağlabatandır", {
  expect_gt(CAT_DEFAULTS$se_threshold, 0)
  expect_lt(CAT_DEFAULTS$se_threshold, 1)
  expect_gt(CAT_DEFAULTS$max_items, CAT_DEFAULTS$min_items)
})

# =============================================
# Şagird Helper Testləri
# =============================================

test_that("Şagird validasiyası işləyir", {
  source("modules/student/student_helpers.R", local = TRUE)

  # Düzgün data
  valid_data <- list(
    first_name = "Əli",
    last_name = "Həsənov",
    birth_date = as.Date("2010-05-15"),
    fin = "1AB2CD3"
  )
  result <- validate_student_data(valid_data)
  expect_true(result$valid)

  # Boş ad
  invalid_data <- list(first_name = "", last_name = "Test", birth_date = as.Date("2010-01-01"), fin = "1234567")
  result_invalid <- validate_student_data(invalid_data)
  expect_false(result_invalid$valid)
})

# =============================================
# Müəllim Helper Testləri
# =============================================

test_that("Müəllim validasiyası işləyir", {
  source("modules/teacher/teacher_helpers.R", local = TRUE)

  valid_teacher <- list(
    first_name = "Eldar",
    last_name = "Məmmədov",
    email = "eldar@test.com",
    phone = "+994501234567"
  )
  result <- validate_teacher_data(valid_teacher)
  expect_true(result$valid)
})

# Testləri işlət
cat("\n=== Verilənlər Bazası və Köməkçi Funksiya Testləri Tamamlandı ===\n")
