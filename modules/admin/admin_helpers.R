# =============================================
# ARTI-2026: Admin Köməkçi Funksiyaları
# İstifadəçi, parametr və audit log əməliyyatları
# =============================================

#' Bütün istifadəçiləri al (filtrli)
get_all_users <- function(db_pool, search = NULL, role = NULL, status = NULL) {
  query <- "SELECT id, username, email, first_name, last_name, role,
                   phone, is_active, last_login, failed_attempts, created_at
            FROM users WHERE 1=1"
  params <- list()
  idx <- 1

  if (!is_empty(search)) {
    query <- paste0(query, " AND (first_name ILIKE $", idx,
                    " OR last_name ILIKE $", idx,
                    " OR email ILIKE $", idx,
                    " OR username ILIKE $", idx, ")")
    params[[idx]] <- paste0("%", search, "%")
    idx <- idx + 1
  }

  if (!is_empty(role)) {
    query <- paste0(query, " AND role = $", idx)
    params[[idx]] <- role
    idx <- idx + 1
  }

  if (!is_empty(status)) {
    if (status == "active") {
      query <- paste0(query, " AND is_active = TRUE")
    } else if (status == "inactive") {
      query <- paste0(query, " AND is_active = FALSE")
    }
  }

  query <- paste0(query, " ORDER BY created_at DESC")

  if (length(params) > 0) {
    db_query(db_pool, query, params = params)
  } else {
    db_query(db_pool, query)
  }
}

#' Yeni istifadəçi yarat
create_user <- function(db_pool, full_name, email, username, password, role, school_id = NULL) {
  # Ad/soyad ayır
  name_parts <- strsplit(trimws(full_name), "\\s+")[[1]]
  first_name <- name_parts[1]
  last_name <- if (length(name_parts) > 1) paste(name_parts[-1], collapse = " ") else ""

  # Dublikat yoxla
  existing <- db_get_one(db_pool,
    "SELECT id FROM users WHERE username = $1 OR email = $2",
    params = list(username, email)
  )
  if (!is.null(existing)) {
    return(list(success = FALSE, error = "Bu istifadəçi adı və ya e-poçt artıq mövcuddur"))
  }

  password_hash <- hash_password(password)
  user_id <- generate_uuid()

  result <- db_execute(db_pool,
    "INSERT INTO users (id, username, email, password_hash, first_name, last_name, role, is_active, created_at, updated_at)
     VALUES ($1, $2, $3, $4, $5, $6, $7, TRUE, NOW(), NOW())",
    params = list(user_id, username, email, password_hash, first_name, last_name, role)
  )

  if (result > 0) {
    list(success = TRUE, user_id = user_id)
  } else {
    list(success = FALSE, error = "İstifadəçi yaradıla bilmədi")
  }
}

#' İstifadəçi yenilə
update_user <- function(db_pool, user_id, first_name = NULL, last_name = NULL,
                        email = NULL, role = NULL, phone = NULL) {
  sets <- c()
  params <- list()
  idx <- 1

  if (!is.null(first_name)) {
    sets <- c(sets, paste0("first_name = $", idx))
    params[[idx]] <- first_name; idx <- idx + 1
  }
  if (!is.null(last_name)) {
    sets <- c(sets, paste0("last_name = $", idx))
    params[[idx]] <- last_name; idx <- idx + 1
  }
  if (!is.null(email)) {
    sets <- c(sets, paste0("email = $", idx))
    params[[idx]] <- email; idx <- idx + 1
  }
  if (!is.null(role)) {
    sets <- c(sets, paste0("role = $", idx))
    params[[idx]] <- role; idx <- idx + 1
  }
  if (!is.null(phone)) {
    sets <- c(sets, paste0("phone = $", idx))
    params[[idx]] <- phone; idx <- idx + 1
  }

  if (length(sets) == 0) return(list(success = FALSE, error = "Dəyişiklik yoxdur"))

  sets <- c(sets, "updated_at = NOW()")

  query <- paste0("UPDATE users SET ", paste(sets, collapse = ", "),
                  " WHERE id = $", idx)
  params[[idx]] <- user_id

  result <- db_execute(db_pool, query, params = params)
  list(success = result > 0)
}

#' İstifadəçini deaktiv et (soft delete)
deactivate_user <- function(db_pool, user_id) {
  result <- db_execute(db_pool,
    "UPDATE users SET is_active = FALSE, updated_at = NOW() WHERE id = $1",
    params = list(user_id)
  )
  list(success = result > 0)
}

#' İstifadəçini aktiv et
activate_user <- function(db_pool, user_id) {
  result <- db_execute(db_pool,
    "UPDATE users SET is_active = TRUE, updated_at = NOW() WHERE id = $1",
    params = list(user_id)
  )
  list(success = result > 0)
}

#' Şifrəni sıfırla
reset_user_password <- function(db_pool, user_id, new_password) {
  password_hash <- hash_password(new_password)
  result <- db_execute(db_pool,
    "UPDATE users SET password_hash = $1, failed_attempts = 0, locked_until = NULL, updated_at = NOW()
     WHERE id = $2",
    params = list(password_hash, user_id)
  )
  list(success = result > 0)
}

# === Sistem Parametrləri ===

#' Bütün sistem parametrlərini al
get_system_settings <- function(db_pool) {
  db_query(db_pool,
    "SELECT key, value, description, updated_at FROM system_settings ORDER BY key"
  )
}

#' Tək parametr al
get_system_setting <- function(db_pool, key) {
  result <- db_get_one(db_pool,
    "SELECT value FROM system_settings WHERE key = $1",
    params = list(key)
  )
  if (!is.null(result)) result$value else NULL
}

#' Sistem parametrini yenilə (UPSERT)
update_system_setting <- function(db_pool, key, value, updated_by = NULL) {
  result <- db_execute(db_pool,
    "INSERT INTO system_settings (id, key, value, updated_by, updated_at)
     VALUES (gen_random_uuid(), $1, $2, $3, NOW())
     ON CONFLICT (key) DO UPDATE SET value = $2, updated_by = $3, updated_at = NOW()",
    params = list(key, as.character(value), updated_by)
  )
  list(success = result > 0)
}

# === Audit Logları ===

#' Audit loglarını al (filtrli)
get_audit_logs <- function(db_pool, limit = 100, user_id = NULL,
                           action = NULL, date_from = NULL, date_to = NULL) {
  query <- "SELECT al.*, u.first_name || ' ' || u.last_name as user_name, u.username
            FROM audit_logs al
            LEFT JOIN users u ON al.user_id = u.id
            WHERE 1=1"
  params <- list()
  idx <- 1

  if (!is_empty(user_id)) {
    query <- paste0(query, " AND al.user_id = $", idx)
    params[[idx]] <- user_id; idx <- idx + 1
  }

  if (!is_empty(action)) {
    query <- paste0(query, " AND al.action = $", idx)
    params[[idx]] <- action; idx <- idx + 1
  }

  if (!is.null(date_from)) {
    query <- paste0(query, " AND al.created_at >= $", idx)
    params[[idx]] <- as.character(date_from); idx <- idx + 1
  }

  if (!is.null(date_to)) {
    query <- paste0(query, " AND al.created_at <= $", idx, "::date + interval '1 day'")
    params[[idx]] <- as.character(date_to); idx <- idx + 1
  }

  query <- paste0(query, " ORDER BY al.created_at DESC LIMIT $", idx)
  params[[idx]] <- limit

  db_query(db_pool, query, params = params)
}

#' Audit log yaz
log_audit <- function(db_pool, user_id, action, details = NULL,
                      entity_type = NULL, entity_id = NULL, ip_address = NULL) {
  details_json <- if (!is.null(details)) {
    jsonlite::toJSON(details, auto_unbox = TRUE)
  } else {
    NULL
  }

  db_execute(db_pool,
    "INSERT INTO audit_logs (id, user_id, action, entity_type, entity_id, details, ip_address, created_at)
     VALUES (gen_random_uuid(), $1, $2, $3, $4, $5::jsonb, $6::inet, NOW())",
    params = list(user_id, action, entity_type, entity_id, details_json, ip_address)
  )
}

#' Audit log əməliyyat növlərini al
get_audit_action_types <- function(db_pool) {
  result <- db_query(db_pool,
    "SELECT DISTINCT action FROM audit_logs ORDER BY action"
  )
  if (nrow(result) > 0) result$action else c()
}
