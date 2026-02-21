# =============================================
# ARTI-2026: Ümumi Utilit Funksiyaları
# =============================================

#' Asılılıqları quraşdır
install_dependencies <- function() {
  packages <- c(
    "shiny", "shinydashboard", "shinydashboardPlus", "bslib",
    "DBI", "RPostgres", "pool", "config", "dotenv",
    "shinyjs", "DT", "plotly", "ggplot2",
    "dplyr", "tidyr", "lubridate", "purrr", "stringr",
    "jsonlite", "httr2", "openssl", "jose",
    "logger", "waiter", "rmarkdown", "openxlsx",
    "randomForest", "caret", "pROC",
    "testthat", "shinytest2"
  )
  new_packages <- packages[!(packages %in% installed.packages()[, "Package"])]
  if (length(new_packages) > 0) {
    install.packages(new_packages, repos = "https://cran.r-project.org")
  }
  invisible(TRUE)
}

#' NULL əvəzləmə operatoru
`%||%` <- function(x, y) if (is.null(x)) y else x

#' Boş string yoxlaması
is_empty <- function(x) {
  is.null(x) || length(x) == 0 || (is.character(x) && nchar(trimws(x)) == 0)
}

#' Tarixi Azərbaycan formatında göstər
format_date_az <- function(date, format = "%d.%m.%Y") {
  if (is.null(date) || is.na(date)) return("")
  format(as.Date(date), format)
}

#' Tarix-vaxtı Azərbaycan formatında göstər
format_datetime_az <- function(datetime, format = "%d.%m.%Y %H:%M") {
  if (is.null(datetime) || is.na(datetime)) return("")
  format(as.POSIXct(datetime), format)
}

#' Rəqəmi format et (min ayırıcısı ilə)
format_number_az <- function(x, digits = 0) {
  formatC(round(x, digits), format = "f", big.mark = ".", decimal.mark = ",", digits = digits)
}

#' Faizi format et
format_percent <- function(x, digits = 1) {
  paste0(formatC(round(x, digits), format = "f", digits = digits), "%")
}

#' Qiymət etiketini al
get_grade_label <- function(score) {
  if (is.na(score)) return("N/A")
  if (score >= 86) return("Əla")
  if (score >= 71) return("Yaxşı")
  if (score >= 51) return("Kafi")
  return("Qeyri-kafi")
}

#' Qiymət rəngini al
get_grade_color <- function(score) {
  if (is.na(score)) return("#95a5a6")
  if (score >= 86) return("#27ae60")
  if (score >= 71) return("#2980b9")
  if (score >= 51) return("#f39c12")
  return("#e74c3c")
}

#' Qiymət badge HTML
grade_badge <- function(score) {
  label <- get_grade_label(score)
  color <- get_grade_color(score)
  sprintf('<span class="badge" style="background-color:%s;color:white;padding:4px 8px;">%s (%s)</span>',
          color, score, label)
}

#' Təhlükəsiz HTML çıxışı (XSS qorunması)
safe_html <- function(text) {
  htmltools::htmlEscape(text)
}

#' E-poçt validasiyası
validate_email <- function(email) {
  grepl("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", email)
}

#' Telefon nömrəsi validasiyası (Azərbaycan)
validate_phone_az <- function(phone) {
  grepl("^\\+994(50|51|55|70|77|99)[0-9]{7}$", gsub("[\\s-]", "", phone))
}

#' FIN kod validasiyası (7 simvol)
validate_fin <- function(fin) {
  grepl("^[A-Z0-9]{7}$", toupper(fin))
}

#' Şifrə gücünü yoxla
validate_password_strength <- function(password) {
  checks <- list(
    length  = nchar(password) >= 8,
    upper   = grepl("[A-Z]", password),
    lower   = grepl("[a-z]", password),
    digit   = grepl("[0-9]", password),
    special = grepl("[^A-Za-z0-9]", password)
  )
  strength <- sum(unlist(checks))
  list(
    valid = checks$length && strength >= 3,
    strength = strength,
    checks = checks,
    label = switch(as.character(strength),
      "5" = "Çox güclü", "4" = "Güclü", "3" = "Orta", "2" = "Zəif", "Çox zəif")
  )
}

#' UUID generasiya et
generate_uuid <- function() {
  paste(
    paste0(sample(c(0:9, letters[1:6]), 8, replace = TRUE), collapse = ""),
    paste0(sample(c(0:9, letters[1:6]), 4, replace = TRUE), collapse = ""),
    paste0("4", paste0(sample(c(0:9, letters[1:6]), 3, replace = TRUE), collapse = "")),
    paste0(sample(c("8","9","a","b"), 1),
           paste0(sample(c(0:9, letters[1:6]), 3, replace = TRUE), collapse = "")),
    paste0(sample(c(0:9, letters[1:6]), 12, replace = TRUE), collapse = ""),
    sep = "-"
  )
}

#' Şifrəni hash et
hash_password <- function(password) {
  openssl::sha256(paste0(password, Sys.getenv("APP_SECRET_KEY")))
}

#' Şifrəni yoxla
verify_password <- function(password, hash) {
  hash_password(password) == hash
}

#' Bildiriş yarat
create_notification <- function(type = "info", message, duration = 5) {
  showNotification(message, type = type, duration = duration)
}

notify_success <- function(message) create_notification("message", message)
notify_error   <- function(message) create_notification("error", message)
notify_warning <- function(message) create_notification("warning", message)

#' Data frame-i Excel-ə ixrac et
export_to_excel <- function(data, filename, sheet_name = "Data") {
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, sheet_name)
  openxlsx::writeData(wb, sheet_name, data)
  header_style <- openxlsx::createStyle(
    fontColour = "#FFFFFF", fgFill = "#2c3e50", halign = "center", textDecoration = "bold"
  )
  openxlsx::addStyle(wb, sheet_name, header_style, rows = 1, cols = 1:ncol(data))
  openxlsx::setColWidths(wb, sheet_name, cols = 1:ncol(data), widths = "auto")
  openxlsx::saveWorkbook(wb, filename, overwrite = TRUE)
}

#' Cədvəl üçün DataTable seçimləri
default_dt_options <- function(page_length = 25) {
  list(
    pageLength = page_length,
    language = list(
      search = "Axtar:", lengthMenu = "_MENU_ sətir göstər",
      info = "_TOTAL_ nəticədən _START_ - _END_ göstərilir",
      paginate = list(first = "İlk", last = "Son", `next` = "Növbəti", previous = "Əvvəlki"),
      emptyTable = "Məlumat tapılmadı", zeroRecords = "Uyğun nəticə yoxdur"
    ),
    dom = "Bfrtip", buttons = c("copy", "csv", "excel", "pdf"), scrollX = TRUE
  )
}

#' Yaş hesabla
calculate_age <- function(birth_date) {
  if (is.null(birth_date) || is.na(birth_date)) return(NA)
  as.integer(difftime(Sys.Date(), as.Date(birth_date), units = "days") / 365.25)
}

#' Akademik ili al
get_academic_year <- function(date = Sys.Date()) {
  year <- as.integer(format(date, "%Y"))
  month <- as.integer(format(date, "%m"))
  if (month >= 9) paste0(year, "-", year + 1) else paste0(year - 1, "-", year)
}

#' Cari semestri al
get_current_semester <- function(date = Sys.Date()) {
  month <- as.integer(format(date, "%m"))
  if (month >= 9 || month <= 1) "I yarımil" else "II yarımil"
}

#' Log yaz
log_action <- function(db_pool, user_id, action, entity_type = NULL, entity_id = NULL, details = NULL) {
  if (is.null(db_pool)) return(invisible(NULL))
  tryCatch({
    DBI::dbExecute(db_pool,
      "INSERT INTO activity_log (user_id, action, entity_type, entity_id, details_json, created_at)
       VALUES ($1, $2, $3, $4, $5, NOW())",
      params = list(user_id, action, entity_type, entity_id,
                    jsonlite::toJSON(details, auto_unbox = TRUE))
    )
  }, error = function(e) {
    logger::log_error("Log yazma xətası: {e$message}")
  })
}

# === UUID Validasiyası ===
is_valid_uuid <- function(x) {
  if (is.null(x) || length(x) == 0) return(FALSE)
  grepl("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", tolower(x))
}

# === İstifadəçi ID-ni DB üçün hazırla (NULL qaytarır əgər yanlışdırsa) ===
safe_user_id <- function(user_data_reactive) {
  uid <- tryCatch(user_data_reactive()$id, error = function(e) NULL)
  if (is_valid_uuid(uid)) uid else NULL
}
