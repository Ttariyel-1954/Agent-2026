# =============================================
# Beynəlxalq Əməkdaşlıq Modulu - Köməkçi Funksiyalar
# =============================================

#' Olimpiada məlumatlarını yoxla
#' @param data Olimpiada formu məlumatları
#' @return Xəta mesajları vektoru
validate_olympiad_data <- function(data) {
  errors <- character(0)

  if (is_empty(data$name)) {
    errors <- c(errors, "Olimpiada adı daxil edilməlidir")
  }

  if (is_empty(data$subject)) {
    errors <- c(errors, "Fənn seçilməlidir")
  }

  if (is_empty(data$olympiad_level)) {
    errors <- c(errors, "Səviyyə seçilməlidir")
  }

  if (!is.null(data$event_date) && !is.na(data$event_date)) {
    if (as.Date(data$event_date) < Sys.Date()) {
      errors <- c(errors, "Olimpiada tarixi keçmiş ola bilməz")
    }
  }

  if (!is.null(data$registration_start) && !is.null(data$registration_end)) {
    if (!is.na(data$registration_start) && !is.na(data$registration_end)) {
      if (as.Date(data$registration_end) <= as.Date(data$registration_start)) {
        errors <- c(errors, "Qeydiyyat bitmə tarixi başlama tarixindən sonra olmalıdır")
      }
    }
  }

  if (!is.null(data$age_min) && !is.null(data$age_max)) {
    if (!is.na(data$age_min) && !is.na(data$age_max)) {
      if (data$age_min >= data$age_max) {
        errors <- c(errors, "Minimum yaş maksimum yaşdan kiçik olmalıdır")
      }
    }
  }

  errors
}

#' STEAM layihə məlumatlarını yoxla
#' @param data Layihə formu məlumatları
#' @return Xəta mesajları vektoru
validate_steam_project <- function(data) {
  errors <- character(0)

  if (is_empty(data$title)) {
    errors <- c(errors, "Layihə adı daxil edilməlidir")
  }

  if (is_empty(data$project_type)) {
    errors <- c(errors, "Layihə növü seçilməlidir")
  }

  if (!is.null(data$start_date) && !is.null(data$end_date)) {
    if (!is.na(data$start_date) && !is.na(data$end_date)) {
      if (as.Date(data$end_date) <= as.Date(data$start_date)) {
        errors <- c(errors, "Bitmə tarixi başlama tarixindən sonra olmalıdır")
      }
    }
  }

  if (!is.null(data$budget) && !is.na(data$budget)) {
    if (data$budget < 0) {
      errors <- c(errors, "Büdcə mənfi ola bilməz")
    }
  }

  errors
}

#' Partnyor proqram məlumatlarını yoxla
#' @param data Partnyor formu məlumatları
#' @return Xəta mesajları vektoru
validate_partner_program <- function(data) {
  errors <- character(0)

  if (is_empty(data$program_name)) {
    errors <- c(errors, "Proqram adı daxil edilməlidir")
  }

  if (is_empty(data$partner_name)) {
    errors <- c(errors, "Partnyor adı daxil edilməlidir")
  }

  if (!is_empty(data$contact_email) && !validate_email(data$contact_email)) {
    errors <- c(errors, "E-poçt formatı düzgün deyil")
  }

  errors
}

#' Yarışma statistikalarını hesabla
#' @param db_pool Verilənlər bazası pool
#' @param filters Filtr parametrləri (optional)
#' @return Statistika siyahısı
calculate_competition_stats <- function(db_pool, filters = NULL) {
  total_olympiads <- db_get_one(db_pool,
    "SELECT COUNT(*) as cnt FROM olympiads")

  total_participants <- db_get_one(db_pool,
    "SELECT COUNT(*) as cnt FROM olympiad_participants")

  medal_stats <- db_query(db_pool,
    "SELECT medal, COUNT(*) as cnt FROM olympiad_participants
     WHERE medal IS NOT NULL
     GROUP BY medal")

  gold <- if (nrow(medal_stats) > 0 && "gold" %in% medal_stats$medal) {
    medal_stats$cnt[medal_stats$medal == "gold"]
  } else 0

  silver <- if (nrow(medal_stats) > 0 && "silver" %in% medal_stats$medal) {
    medal_stats$cnt[medal_stats$medal == "silver"]
  } else 0

  bronze <- if (nrow(medal_stats) > 0 && "bronze" %in% medal_stats$medal) {
    medal_stats$cnt[medal_stats$medal == "bronze"]
  } else 0

  total_steam <- db_get_one(db_pool,
    "SELECT COUNT(*) as cnt FROM steam_projects")

  total_partners <- db_get_one(db_pool,
    "SELECT COUNT(*) as cnt FROM partner_programs WHERE status = 'active'")

  avg_score <- db_get_one(db_pool,
    "SELECT COALESCE(AVG(score), 0) as avg_s FROM olympiad_participants
     WHERE score IS NOT NULL")

  list(
    total_olympiads = total_olympiads$cnt,
    total_participants = total_participants$cnt,
    gold_medals = gold,
    silver_medals = silver,
    bronze_medals = bronze,
    total_medals = gold + silver + bronze,
    total_steam = total_steam$cnt,
    total_partners = total_partners$cnt,
    avg_score = round(avg_score$avg_s, 1)
  )
}

#' Olimpiada fənn üzrə statistika
#' @param db_pool Verilənlər bazası pool
#' @return Fənn üzrə statistika
get_olympiad_by_subject <- function(db_pool) {
  db_query(db_pool,
    "SELECT o.subject,
            COUNT(DISTINCT o.id) AS olympiad_count,
            COUNT(op.id) AS participant_count,
            COUNT(op.medal) FILTER (WHERE op.medal IS NOT NULL) AS medal_count,
            COALESCE(AVG(op.score), 0) AS avg_score
     FROM olympiads o
     LEFT JOIN olympiad_participants op ON op.olympiad_id = o.id
     GROUP BY o.subject
     ORDER BY participant_count DESC")
}
