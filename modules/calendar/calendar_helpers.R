# =============================================
# ARTI-2026: Təqvim Köməkçi Funksiyaları
# Hadisə CRUD əməliyyatları
# =============================================

#' Təqvim hadisələrini al (aylıq)
get_calendar_events <- function(db_pool, month = NULL, year = NULL,
                                 event_type = NULL, school_id = NULL) {
  if (is.null(month)) month <- as.integer(format(Sys.Date(), "%m"))
  if (is.null(year)) year <- as.integer(format(Sys.Date(), "%Y"))

  query <- "SELECT ce.*, s.name as subject_name,
                   u.first_name || ' ' || u.last_name as creator_name
            FROM calendar_events ce
            LEFT JOIN subjects s ON ce.subject_id = s.id
            LEFT JOIN users u ON ce.created_by = u.id
            WHERE ce.is_active = TRUE
              AND EXTRACT(MONTH FROM ce.start_date) = $1
              AND EXTRACT(YEAR FROM ce.start_date) = $2"
  params <- list(month, year)
  idx <- 3

  if (!is_empty(event_type)) {
    query <- paste0(query, " AND ce.event_type = $", idx)
    params[[idx]] <- event_type
    idx <- idx + 1
  }

  if (!is_empty(school_id)) {
    query <- paste0(query, " AND ce.school_id = $", idx)
    params[[idx]] <- school_id
    idx <- idx + 1
  }

  query <- paste0(query, " ORDER BY ce.start_date, ce.start_time")
  db_query(db_pool, query, params = params)
}

#' Yeni hadisə yarat
create_event <- function(db_pool, title, event_type, start_date, end_date = NULL,
                          start_time = NULL, end_time = NULL, is_all_day = TRUE,
                          description = NULL, location = NULL, subject_id = NULL,
                          grade_level = NULL, created_by = NULL, school_id = NULL,
                          color = "#3498db") {
  event_id <- generate_uuid()

  result <- db_execute(db_pool,
    "INSERT INTO calendar_events
     (id, title, description, event_type, start_date, end_date, start_time, end_time,
      is_all_day, location, subject_id, grade_level, created_by, school_id, color, created_at, updated_at)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, NOW(), NOW())",
    params = list(
      event_id, title, description, event_type,
      as.character(start_date),
      if (!is.null(end_date)) as.character(end_date) else NULL,
      start_time, end_time, is_all_day, location,
      if (!is_empty(subject_id)) subject_id else NULL,
      if (!is.null(grade_level)) as.integer(grade_level) else NULL,
      created_by, school_id, color
    )
  )

  if (result > 0) {
    list(success = TRUE, event_id = event_id)
  } else {
    list(success = FALSE, error = "Hadisə yaradıla bilmədi")
  }
}

#' Hadisəni yenilə
update_event <- function(db_pool, event_id, title = NULL, event_type = NULL,
                          start_date = NULL, end_date = NULL, description = NULL,
                          location = NULL, color = NULL) {
  sets <- c()
  params <- list()
  idx <- 1

  if (!is.null(title)) {
    sets <- c(sets, paste0("title = $", idx))
    params[[idx]] <- title; idx <- idx + 1
  }
  if (!is.null(event_type)) {
    sets <- c(sets, paste0("event_type = $", idx))
    params[[idx]] <- event_type; idx <- idx + 1
  }
  if (!is.null(start_date)) {
    sets <- c(sets, paste0("start_date = $", idx))
    params[[idx]] <- as.character(start_date); idx <- idx + 1
  }
  if (!is.null(end_date)) {
    sets <- c(sets, paste0("end_date = $", idx))
    params[[idx]] <- as.character(end_date); idx <- idx + 1
  }
  if (!is.null(description)) {
    sets <- c(sets, paste0("description = $", idx))
    params[[idx]] <- description; idx <- idx + 1
  }
  if (!is.null(location)) {
    sets <- c(sets, paste0("location = $", idx))
    params[[idx]] <- location; idx <- idx + 1
  }
  if (!is.null(color)) {
    sets <- c(sets, paste0("color = $", idx))
    params[[idx]] <- color; idx <- idx + 1
  }

  if (length(sets) == 0) return(list(success = FALSE, error = "Dəyişiklik yoxdur"))

  sets <- c(sets, "updated_at = NOW()")
  query <- paste0("UPDATE calendar_events SET ", paste(sets, collapse = ", "),
                  " WHERE id = $", idx)
  params[[idx]] <- event_id

  result <- db_execute(db_pool, query, params = params)
  list(success = result > 0)
}

#' Hadisəni sil (soft delete)
delete_event <- function(db_pool, event_id) {
  result <- db_execute(db_pool,
    "UPDATE calendar_events SET is_active = FALSE, updated_at = NOW() WHERE id = $1",
    params = list(event_id)
  )
  list(success = result > 0)
}

#' Gələcək hadisələri al
get_upcoming_events <- function(db_pool, days = 30, school_id = NULL) {
  query <- "SELECT ce.*, s.name as subject_name
            FROM calendar_events ce
            LEFT JOIN subjects s ON ce.subject_id = s.id
            WHERE ce.is_active = TRUE
              AND ce.start_date >= CURRENT_DATE
              AND ce.start_date <= CURRENT_DATE + $1 * interval '1 day'"
  params <- list(days)

  if (!is_empty(school_id)) {
    query <- paste0(query, " AND ce.school_id = $2")
    params[[2]] <- school_id
  }

  query <- paste0(query, " ORDER BY ce.start_date, ce.start_time LIMIT 50")
  db_query(db_pool, query, params = params)
}

#' Hadisə növü etiketini al
get_event_type_label <- function(type) {
  switch(type,
    "exam" = "İmtahan",
    "holiday" = "Tətil",
    "meeting" = "İclas",
    "deadline" = "Son Tarix",
    "training" = "Təlim",
    "other" = "Digər",
    type
  )
}

#' Hadisə növü rəngini al
get_event_type_color <- function(type) {
  switch(type,
    "exam" = "#e74c3c",
    "holiday" = "#27ae60",
    "meeting" = "#3498db",
    "deadline" = "#f39c12",
    "training" = "#9b59b6",
    "other" = "#95a5a6",
    "#3498db"
  )
}
