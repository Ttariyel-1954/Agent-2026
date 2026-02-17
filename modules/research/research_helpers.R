# =============================================
# Tədqiqat Modulu - Köməkçi Funksiyalar
# =============================================

#' Tədqiqat məlumatlarını yoxla
#' @param data Tədqiqat formu məlumatları
#' @return Xəta mesajları vektoru
validate_research_data <- function(data) {
  errors <- character(0)

  if (is_empty(data$title)) {
    errors <- c(errors, "Tədqiqat adı daxil edilməlidir")
  }

  if (is_empty(data$research_type)) {
    errors <- c(errors, "Tədqiqat növü seçilməlidir")
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

  if (!is.null(data$progress) && !is.na(data$progress)) {
    if (data$progress < 0 || data$progress > 100) {
      errors <- c(errors, "İrəliləyiş 0-100 arasında olmalıdır")
    }
  }

  errors
}

#' Nəşr məlumatlarını yoxla
#' @param data Nəşr formu məlumatları
#' @return Xəta mesajları vektoru
validate_publication_data <- function(data) {
  errors <- character(0)

  if (is_empty(data$title)) {
    errors <- c(errors, "Nəşr adı daxil edilməlidir")
  }

  if (is_empty(data$authors)) {
    errors <- c(errors, "Müəllif(lər) daxil edilməlidir")
  }

  if (!is_empty(data$doi) && !grepl("^10\\.", data$doi)) {
    errors <- c(errors, "DOI formatı düzgün deyil (10.xxxxx ilə başlamalıdır)")
  }

  errors
}

#' Doktorant məlumatlarını yoxla
#' @param data Doktorant formu məlumatları
#' @return Xəta mesajları vektoru
validate_doctoral_data <- function(data) {
  errors <- character(0)

  if (is_empty(data$program_id)) {
    errors <- c(errors, "Proqram seçilməlidir")
  }

  if (is_empty(data$user_id)) {
    errors <- c(errors, "Doktorant seçilməlidir")
  }

  if (is_empty(data$dissertation_title)) {
    errors <- c(errors, "Dissertasiya mövzusu daxil edilməlidir")
  }

  errors
}

#' Tədqiqat metrikalarını hesabla
#' @param db_pool Verilənlər bazası pool
#' @param filters Filtr parametrləri (optional)
#' @return Metrikalar siyahısı
calculate_research_metrics <- function(db_pool, filters = NULL) {
  # Ümumi tədqiqat statistikası
  total_projects <- db_get_one(db_pool,
    "SELECT COUNT(*) as cnt FROM research_projects")

  active_projects <- db_get_one(db_pool,
    "SELECT COUNT(*) as cnt FROM research_projects WHERE status = 'active'")

  completed_projects <- db_get_one(db_pool,
    "SELECT COUNT(*) as cnt FROM research_projects WHERE status = 'completed'")

  total_publications <- db_get_one(db_pool,
    "SELECT COUNT(*) as cnt FROM research_publications")

  total_citations <- db_get_one(db_pool,
    "SELECT COALESCE(SUM(citation_count), 0) as total FROM research_publications")

  total_budget <- db_get_one(db_pool,
    "SELECT COALESCE(SUM(budget), 0) as total FROM research_projects WHERE status IN ('active', 'completed')")

  avg_progress <- db_get_one(db_pool,
    "SELECT COALESCE(AVG(progress), 0) as avg_p FROM research_projects WHERE status = 'active'")

  total_doctoral <- db_get_one(db_pool,
    "SELECT COUNT(*) as cnt FROM doctoral_students WHERE status = 'active'")

  list(
    total_projects = total_projects$cnt,
    active_projects = active_projects$cnt,
    completed_projects = completed_projects$cnt,
    total_publications = total_publications$cnt,
    total_citations = total_citations$total,
    total_budget = total_budget$total,
    avg_progress = round(avg_progress$avg_p, 1),
    total_doctoral = total_doctoral$cnt
  )
}

#' Tədqiqatçı üzrə nəşr saylarını hesabla
#' @param db_pool Verilənlər bazası pool
#' @param researcher_id Tədqiqatçı ID
#' @return Nəşr statistikası
get_researcher_stats <- function(db_pool, researcher_id) {
  db_query(db_pool,
    "SELECT rp.publication_type,
            COUNT(*) as count,
            COALESCE(SUM(rp.citation_count), 0) as citations
     FROM research_publications rp
     JOIN research_projects rj ON rp.project_id = rj.id
     WHERE rj.lead_researcher_id = $1
     GROUP BY rp.publication_type",
    params = list(researcher_id))
}
