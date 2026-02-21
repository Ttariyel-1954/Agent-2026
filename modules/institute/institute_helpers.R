# =============================================
# İnstitut Strukturu: Köməkçi Funksiyalar
# =============================================

# === Validasiya Funksiyaları ===

validate_unit_data <- function(data) {
  errors <- character()

  if (is.null(data$name) || nchar(trimws(data$name)) == 0) {
    errors <- c(errors, "Vahid adı boş ola bilməz")
  }
  if (is.null(data$unit_type) || !(data$unit_type %in% names(UNIT_TYPES))) {
    errors <- c(errors, "Düzgün vahid növü seçilməlidir")
  }

  list(valid = length(errors) == 0, errors = errors)
}

validate_resource_data <- function(data) {
  errors <- character()

  if (is.null(data$name) || nchar(trimws(data$name)) == 0) {
    errors <- c(errors, "Resurs adı boş ola bilməz")
  }
  if (is.null(data$resource_type) || !(data$resource_type %in% names(INST_RESOURCE_TYPES))) {
    errors <- c(errors, "Düzgün resurs növü seçilməlidir")
  }
  if (is.null(data$unit_id) || nchar(trimws(data$unit_id)) == 0) {
    errors <- c(errors, "Vahid seçilməlidir")
  }
  if (!is.null(data$budget_amount) && !is.na(data$budget_amount) && data$budget_amount < 0) {
    errors <- c(errors, "Büdcə məbləği mənfi ola bilməz")
  }

  list(valid = length(errors) == 0, errors = errors)
}

validate_personnel_data <- function(data) {
  errors <- character()

  if (is.null(data$full_name) || nchar(trimws(data$full_name)) == 0) {
    errors <- c(errors, "Ad və soyad boş ola bilməz")
  }
  if (is.null(data$personnel_type) || !(data$personnel_type %in% names(PERSONNEL_TYPES))) {
    errors <- c(errors, "Düzgün personal növü seçilməlidir")
  }
  if (is.null(data$unit_id) || nchar(trimws(data$unit_id)) == 0) {
    errors <- c(errors, "Vahid seçilməlidir")
  }

  list(valid = length(errors) == 0, errors = errors)
}

validate_kpi_data <- function(data) {
  errors <- character()

  if (is.null(data$name) || nchar(trimws(data$name)) == 0) {
    errors <- c(errors, "KPI adı boş ola bilməz")
  }
  if (is.null(data$target_value) || is.na(data$target_value) || data$target_value <= 0) {
    errors <- c(errors, "Hədəf dəyər müsbət olmalıdır")
  }
  if (is.null(data$activity_id) || nchar(trimws(data$activity_id)) == 0) {
    errors <- c(errors, "Fəaliyyət sahəsi seçilməlidir")
  }

  list(valid = length(errors) == 0, errors = errors)
}

validate_project_data <- function(data) {
  errors <- character()

  if (is.null(data$name) || nchar(trimws(data$name)) == 0) {
    errors <- c(errors, "Layihə adı boş ola bilməz")
  }
  if (is.null(data$unit_id) || nchar(trimws(data$unit_id)) == 0) {
    errors <- c(errors, "Vahid seçilməlidir")
  }
  if (!is.null(data$budget) && !is.na(data$budget) && data$budget < 0) {
    errors <- c(errors, "Büdcə mənfi ola bilməz")
  }

  list(valid = length(errors) == 0, errors = errors)
}

# === Hesablama Funksiyaları ===

calculate_institute_metrics <- function(db_pool) {
  if (is.null(db_pool)) return(list(units = 0, personnel = 0, projects = 0, areas = 0))
  tryCatch({
    units_count <- safe_query(db_pool, "SELECT COUNT(*) as n FROM org_units WHERE is_active = TRUE")$n %||% 0
    personnel_count <- safe_query(db_pool, "SELECT COUNT(*) as n FROM unit_personnel WHERE is_active = TRUE")$n %||% 0
    active_projects <- safe_query(db_pool, "SELECT COUNT(*) as n FROM unit_projects WHERE status = 'aktiv' AND is_active = TRUE")$n %||% 0
    active_areas <- safe_query(db_pool, "SELECT COUNT(*) as n FROM activity_areas WHERE status = 'aktiv' AND is_active = TRUE")$n %||% 0

    list(
      units = units_count,
      personnel = personnel_count,
      projects = active_projects,
      areas = active_areas
    )
  }, error = function(e) {
    log_error("İnstitut metrikası xətası: {e$message}")
    list(units = 0, personnel = 0, projects = 0, areas = 0)
  })
}

calculate_resource_summary <- function(db_pool, unit_id = NULL) {
  tryCatch({
    where_clause <- "WHERE ur.is_active = TRUE"
    params <- list()
    if (!is.null(unit_id) && nchar(unit_id) > 0) {
      where_clause <- paste(where_clause, "AND ur.unit_id = $1")
      params <- list(unit_id)
    }

    sql <- sprintf("
      SELECT ur.resource_type,
             COUNT(*) as count,
             COALESCE(SUM(ur.budget_amount), 0) as total_budget
      FROM unit_resources ur
      %s
      GROUP BY ur.resource_type
      ORDER BY total_budget DESC
    ", where_clause)

    if (length(params) > 0) {
      safe_query(db_pool, sql, params = params)
    } else {
      safe_query(db_pool, sql)
    }
  }, error = function(e) {
    log_error("Resurs xülasəsi xətası: {e$message}")
    data.frame(resource_type = character(), count = integer(), total_budget = numeric())
  })
}

calculate_personnel_summary <- function(db_pool, unit_id = NULL) {
  tryCatch({
    where_clause <- "WHERE up.is_active = TRUE"
    params <- list()
    if (!is.null(unit_id) && nchar(unit_id) > 0) {
      where_clause <- paste(where_clause, "AND up.unit_id = $1")
      params <- list(unit_id)
    }

    sql <- sprintf("
      SELECT up.personnel_type,
             COUNT(*) as count,
             up.employment_type
      FROM unit_personnel up
      %s
      GROUP BY up.personnel_type, up.employment_type
      ORDER BY count DESC
    ", where_clause)

    if (length(params) > 0) {
      safe_query(db_pool, sql, params = params)
    } else {
      safe_query(db_pool, sql)
    }
  }, error = function(e) {
    log_error("Personal xülasəsi xətası: {e$message}")
    data.frame(personnel_type = character(), count = integer(), employment_type = character())
  })
}

calculate_kpi_completion <- function(db_pool, activity_id = NULL) {
  tryCatch({
    where_clause <- "WHERE ak.is_active = TRUE"
    params <- list()
    if (!is.null(activity_id) && nchar(activity_id) > 0) {
      where_clause <- paste(where_clause, "AND ak.activity_id = $1")
      params <- list(activity_id)
    }

    sql <- sprintf("
      SELECT ak.id, ak.name, ak.target_value, ak.baseline_value, ak.weight,
             COALESCE(
               (SELECT ap.actual_value FROM activity_progress ap
                WHERE ap.kpi_id = ak.id ORDER BY ap.period_end DESC LIMIT 1),
               ak.baseline_value
             ) as current_value
      FROM activity_kpis ak
      %s
      ORDER BY ak.name
    ", where_clause)

    result <- if (length(params) > 0) {
      safe_query(db_pool, sql, params = params)
    } else {
      safe_query(db_pool, sql)
    }

    if (nrow(result) > 0) {
      result$completion_pct <- ifelse(
        result$target_value > 0,
        round((result$current_value / result$target_value) * 100, 1),
        0
      )
    }

    result
  }, error = function(e) {
    log_error("KPI tamamlanma xətası: {e$message}")
    data.frame()
  })
}

# === Ağac və Vizual Funksiyalar ===

build_org_tree <- function(db_pool) {
  tryCatch({
    units <- safe_query(db_pool, "
      SELECT id, parent_id, name, short_name, unit_type, head_name, head_position, is_active
      FROM org_units
      WHERE is_active = TRUE
      ORDER BY sort_order, name
    ")
    units
  }, error = function(e) {
    log_error("Org tree xətası: {e$message}")
    data.frame()
  })
}

render_org_tree_html <- function(units, parent_id = NA) {
  if (nrow(units) == 0) return("")

  if (is.na(parent_id)) {
    children <- units[is.na(units$parent_id), ]
  } else {
    children <- units[!is.na(units$parent_id) & units$parent_id == parent_id, ]
  }

  if (nrow(children) == 0) return("")

  html <- '<ul class="org-tree">'
  for (i in seq_len(nrow(children))) {
    node <- children[i, ]
    type_class <- paste0("org-node-", node$unit_type)
    type_label <- UNIT_TYPES[node$unit_type]
    if (is.na(type_label)) type_label <- node$unit_type

    head_info <- ""
    if (!is.na(node$head_name) && nchar(node$head_name) > 0) {
      head_info <- paste0('<div class="org-node-head">', htmltools::htmlEscape(node$head_name), '</div>')
    }

    html <- paste0(html,
      '<li>',
        '<div class="org-node ', type_class, '">',
          '<div class="org-node-type">', htmltools::htmlEscape(type_label), '</div>',
          '<div class="org-node-name">', htmltools::htmlEscape(node$name), '</div>',
          head_info,
        '</div>',
        render_org_tree_html(units, node$id),
      '</li>'
    )
  }
  html <- paste0(html, '</ul>')
  html
}

# === Format Funksiyaları ===

format_budget_azn <- function(amount) {
  if (is.null(amount) || is.na(amount)) return("0,00 ₼")
  formatted <- formatC(amount, format = "f", digits = 2, big.mark = ".", decimal.mark = ",")
  paste0(formatted, " ₼")
}
