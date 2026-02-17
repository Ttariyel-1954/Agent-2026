# =============================================
# Tədris Resursları Modulu - Köməkçi Funksiyalar
# =============================================

#' Resurs məlumatlarını yoxla
#' @param data Resurs formu məlumatları
#' @return Xəta mesajları vektoru
validate_resource <- function(data) {
  errors <- character(0)

  if (is_empty(data$title)) {
    errors <- c(errors, "Resurs adı daxil edilməlidir")
  }

  if (is_empty(data$resource_type)) {
    errors <- c(errors, "Resurs növü seçilməlidir")
  }

  if (!is.null(data$file_size) && !is.na(data$file_size)) {
    max_bytes <- SYSTEM_LIMITS$max_upload_mb * 1024 * 1024
    if (data$file_size > max_bytes) {
      errors <- c(errors, paste0("Fayl ölçüsü ", SYSTEM_LIMITS$max_upload_mb, " MB-dan böyük ola bilməz"))
    }
  }

  if (!is_empty(data$url) && !grepl("^https?://", data$url)) {
    errors <- c(errors, "URL düzgün formatda olmalıdır (http:// və ya https://)")
  }

  if (!is.null(data$publish_year) && !is.na(data$publish_year)) {
    current_year <- as.integer(format(Sys.Date(), "%Y"))
    if (data$publish_year < 1900 || data$publish_year > current_year + 1) {
      errors <- c(errors, "Nəşr ili düzgün deyil")
    }
  }

  errors
}

#' Dərslik məlumatlarını yoxla
#' @param data Dərslik formu məlumatları
#' @return Xəta mesajları vektoru
validate_textbook <- function(data) {
  errors <- character(0)

  if (is_empty(data$title)) {
    errors <- c(errors, "Dərslik adı daxil edilməlidir")
  }

  if (is_empty(data$author)) {
    errors <- c(errors, "Müəllif daxil edilməlidir")
  }

  if (!is.null(data$isbn) && !is_empty(data$isbn)) {
    isbn_clean <- gsub("[- ]", "", data$isbn)
    if (!grepl("^\\d{10}(\\d{3})?$", isbn_clean)) {
      errors <- c(errors, "ISBN formatı düzgün deyil")
    }
  }

  errors
}

#' Resurs metadata-sını formatla
#' @param resource Resurs məlumatları
#' @return Formatlanmış metadata siyahısı
format_resource_metadata <- function(resource) {
  meta <- list()

  if (!is_empty(resource$author)) {
    meta$author <- resource$author
  }
  if (!is_empty(resource$publisher)) {
    meta$publisher <- resource$publisher
  }
  if (!is.null(resource$publish_year) && !is.na(resource$publish_year)) {
    meta$year <- resource$publish_year
  }
  if (!is_empty(resource$language)) {
    meta$language <- switch(resource$language,
      "az" = "Azərbaycan dili",
      "en" = "İngilis dili",
      "ru" = "Rus dili",
      resource$language
    )
  }
  if (!is.null(resource$file_size) && !is.na(resource$file_size)) {
    meta$file_size <- format_file_size(resource$file_size)
  }

  meta
}

#' Fayl ölçüsünü formatla
#' @param bytes Bayt sayı
#' @return Formatlanmış ölçü
format_file_size <- function(bytes) {
  if (is.null(bytes) || is.na(bytes)) return("")
  if (bytes < 1024) return(paste0(bytes, " B"))
  if (bytes < 1024^2) return(paste0(round(bytes / 1024, 1), " KB"))
  if (bytes < 1024^3) return(paste0(round(bytes / 1024^2, 1), " MB"))
  paste0(round(bytes / 1024^3, 1), " GB")
}

#' Resurs axtar
#' @param db_pool Verilənlər bazası pool
#' @param search_term Axtarış sözü
#' @param resource_type Resurs növü (optional)
#' @param subject_id Fənn ID (optional)
#' @return Nəticə data.frame
search_resources <- function(db_pool, search_term, resource_type = NULL, subject_id = NULL) {
  query <- "SELECT tr.*, s.name AS subject_name, rc.name AS category_name
            FROM teaching_resources tr
            LEFT JOIN subjects s ON tr.subject_id = s.id
            LEFT JOIN resource_categories rc ON tr.category_id = rc.id
            WHERE tr.status = 'active'"
  params <- list()
  param_idx <- 1

  if (!is_empty(search_term)) {
    query <- paste0(query, " AND (tr.title ILIKE $", param_idx,
                    " OR tr.description ILIKE $", param_idx, ")")
    params[[param_idx]] <- paste0("%", search_term, "%")
    param_idx <- param_idx + 1
  }

  if (!is.null(resource_type) && !is_empty(resource_type)) {
    query <- paste0(query, " AND tr.resource_type = $", param_idx)
    params[[param_idx]] <- resource_type
    param_idx <- param_idx + 1
  }

  if (!is.null(subject_id) && !is_empty(subject_id)) {
    query <- paste0(query, " AND tr.subject_id = $", param_idx)
    params[[param_idx]] <- subject_id
    param_idx <- param_idx + 1
  }

  query <- paste0(query, " ORDER BY tr.created_at DESC LIMIT 100")

  if (length(params) > 0) db_query(db_pool, query, params = params)
  else db_query(db_pool, query)
}
