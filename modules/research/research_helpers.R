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

# =============================================
# Tədqiqat AI Asistent — Köməkçi Funksiyalar
# =============================================

# --- Tədqiqat sahəsi etiketləri ---
RESEARCH_FIELD_LABELS <- c(
  education = "Təhsil",
  pedagogy = "Pedaqogika",
  psychology = "Psixologiya",
  curriculum = "Kurikulum",
  assessment = "Qiymətləndirmə",
  edtech = "Təhsil Texnologiyası",
  special_education = "Xüsusi Təhsil",
  education_management = "Təhsil İdarəetməsi",
  other = "Digər"
)

# --- Sessiya növü etiketləri ---
SESSION_TYPE_LABELS <- c(
  literature_review = "Ədəbiyyat İcmalı",
  methodology = "Metodologiya",
  analysis_plan = "Analiz Planı",
  results_draft = "Nəticə Qaralama",
  full_pipeline = "Tam Proses"
)

# --- İstinad format etiketləri ---
CITATION_FORMAT_LABELS <- c(
  apa = "APA (7-ci nəşr)",
  harvard = "Harvard",
  vancouver = "Vancouver",
  chicago = "Chicago"
)

# --- Layihə siyahısı (dropdown) ---
get_research_project_choices <- function(db_pool, user_id = NULL) {
  if (!is.null(user_id) && user_id != "") {
    projects <- db_query(db_pool,
      "SELECT id, title FROM research_projects
       WHERE lead_researcher_id = $1 OR status = 'active'
       ORDER BY title",
      params = list(user_id))
  } else {
    projects <- db_query(db_pool,
      "SELECT id, title FROM research_projects WHERE status = 'active' ORDER BY title")
  }
  if (is.null(projects) || nrow(projects) == 0) return(c("Layihə yoxdur" = ""))
  c("Layihə seçin (istəyə bağlı)" = "", setNames(projects$id, projects$title))
}

# --- Sessiya statusu badge ---
session_status_badge <- function(status) {
  colors <- c(active = "info", completed = "success", archived = "default")
  labels <- c(active = "Aktiv", completed = "Tamamlanmış", archived = "Arxivlənmiş")
  color <- colors[status] %||% "default"
  label <- labels[status] %||% status
  sprintf('<span class="label label-%s">%s</span>', color, label)
}

# --- Sessiya növü badge ---
session_type_badge <- function(type) {
  colors <- c(
    literature_review = "primary",
    methodology = "success",
    analysis_plan = "warning",
    results_draft = "info",
    full_pipeline = "danger"
  )
  label <- SESSION_TYPE_LABELS[type] %||% type
  color <- colors[type] %||% "default"
  sprintf('<span class="label label-%s">%s</span>', color, label)
}

# --- Mövcud layihə kontekstini al ---
get_project_context <- function(db_pool, project_id) {
  if (is.null(project_id) || project_id == "") return("")

  project <- db_get_one(db_pool,
    "SELECT title, description, objectives, methodology, research_type
     FROM research_projects WHERE id = $1",
    params = list(project_id))

  if (is.null(project)) return("")

  paste(
    sprintf("Layihə: %s", project$title %||% ""),
    sprintf("Növ: %s", project$research_type %||% ""),
    sprintf("Təsvir: %s", project$description %||% ""),
    sprintf("Məqsədlər: %s", project$objectives %||% ""),
    sprintf("Metodologiya: %s", project$methodology %||% ""),
    sep = "\n"
  )
}

# --- Ədəbiyyat icmalını mətn olaraq formatla ---
format_literature_summary <- function(sources) {
  if (is.null(sources) || length(sources) == 0) return("")
  summaries <- sapply(sources, function(s) {
    sprintf("- %s (%s): %s", s$authors %||% "N/A", s$year %||% "n.d.", s$key_findings %||% "")
  })
  paste(summaries, collapse = "\n")
}

# --- Metodologiyanı mətn olaraq xülasə et ---
format_methodology_summary <- function(methodology_results) {
  if (is.null(methodology_results)) return("")
  parts <- c()
  if (!is.null(methodology_results$research_design)) {
    parts <- c(parts, sprintf("Dizayn: %s - %s",
      methodology_results$research_design$type %||% "",
      methodology_results$research_design$approach %||% ""))
  }
  if (!is.null(methodology_results$methodology)) {
    parts <- c(parts, sprintf("Metod: %s", methodology_results$methodology$primary_method %||% ""))
  }
  if (!is.null(methodology_results$sampling)) {
    parts <- c(parts, sprintf("Seçmə: %s, həcm: %s",
      methodology_results$sampling$strategy %||% "",
      methodology_results$sampling$recommended_size %||% ""))
  }
  paste(parts, collapse = "\n")
}

# --- Analiz planını mətn olaraq xülasə et ---
format_analysis_plan_summary <- function(analysis_results) {
  if (is.null(analysis_results)) return("")
  parts <- c()
  if (!is.null(analysis_results$hypotheses)) {
    for (h in analysis_results$hypotheses) {
      parts <- c(parts, sprintf("%s: %s", h$id %||% "H", h$alternative_hypothesis %||% ""))
    }
  }
  if (!is.null(analysis_results$statistical_tests)) {
    tests <- sapply(analysis_results$statistical_tests, function(t) t$test_name %||% "")
    parts <- c(parts, sprintf("Testlər: %s", paste(tests, collapse = ", ")))
  }
  paste(parts, collapse = "\n")
}

# --- Dəyişənləri formatla ---
format_variables_description <- function(variables_text) {
  if (is.null(variables_text) || nchar(trimws(variables_text)) == 0) return("")
  variables_text
}

# --- Token istifadəsini formatla ---
format_token_usage <- function(tokens) {
  if (is.null(tokens) || is.na(tokens)) return("0")
  format(as.integer(tokens), big.mark = ".", decimal.mark = ",")
}
