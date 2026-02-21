# =============================================
# ARTI-2026: Tədqiqat AI Asistent — API Funksiyaları
# =============================================

# --- İstinad formatları ---
CITATION_FORMATS <- c(
  apa = "APA (7-ci nəşr)",
  harvard = "Harvard",
  vancouver = "Vancouver",
  chicago = "Chicago"
)

RESEARCH_FIELDS <- c(
  "Təhsil" = "education",
  "Pedaqogika" = "pedagogy",
  "Psixologiya" = "psychology",
  "Kurikulum" = "curriculum",
  "Qiymətləndirmə" = "assessment",
  "Təhsil Texnologiyası" = "edtech",
  "Xüsusi Təhsil" = "special_education",
  "Təhsil İdarəetməsi" = "education_management",
  "Digər" = "other"
)

# === 1. Ədəbiyyat Axtarışı ===
search_literature_ai <- function(db_pool, research_question, research_field,
                                  citation_format = "apa", project_context = "",
                                  user_id = NULL) {
  # Prompt yarat
  template <- load_prompt_template("research_literature")
  prompt <- sprintf(template,
    research_question,
    research_field,
    citation_format,
    if (nchar(project_context) > 0) project_context else "Əlavə kontekst yoxdur"
  )

  system_prompt <- paste(
    "Sən təhsil sahəsində təcrübəli akademik tədqiqatçısan.",
    "Yalnız JSON formatında cavab ver.",
    "Mənbələr realist və akademik standartlara uyğun olmalıdır."
  )

  # AI çağır
  result <- tryCatch({
    call_claude_api(
      prompt = prompt,
      system_prompt = system_prompt,
      max_tokens = 8192,
      temperature = 0.4
    )
  }, error = function(e) {
    log_error("Ədəbiyyat axtarışı AI xətası: {e$message}")
    return(list(success = FALSE, error = e$message))
  })

  if (isFALSE(result$success)) {
    return(result)
  }

  # JSON parse
  parsed <- parse_research_response(result$content)
  if (is.null(parsed)) {
    return(list(success = FALSE, error = "AI cavabı parse edilə bilmədi"))
  }

  # Token istifadəsini hesabla
  tokens_used <- result$usage$input_tokens + result$usage$output_tokens

  list(
    success = TRUE,
    literature_review = parsed$literature_review,
    sources = parsed$sources,
    suggested_search_terms = parsed$suggested_search_terms,
    recommended_databases = parsed$recommended_databases,
    tokens_used = tokens_used
  )
}

# === 2. Metodologiya Tövsiyəsi ===
recommend_methodology_ai <- function(db_pool, research_question, research_field,
                                      research_type = "tetbiqi",
                                      literature_context = "",
                                      user_id = NULL) {
  template <- load_prompt_template("research_methodology")
  prompt <- sprintf(template,
    research_question,
    research_field,
    research_type,
    if (nchar(literature_context) > 0) literature_context else "Ədəbiyyat icmalı hələ aparılmayıb"
  )

  system_prompt <- paste(
    "Sən tədqiqat metodologiyası üzrə ekspertsen.",
    "Yalnız JSON formatında cavab ver.",
    "Azərbaycan təhsil kontekstinə uyğun tövsiyələr ver."
  )

  result <- tryCatch({
    call_claude_api(
      prompt = prompt,
      system_prompt = system_prompt,
      max_tokens = 6144,
      temperature = 0.4
    )
  }, error = function(e) {
    log_error("Metodologiya tövsiyəsi AI xətası: {e$message}")
    return(list(success = FALSE, error = e$message))
  })

  if (isFALSE(result$success)) return(result)

  parsed <- parse_research_response(result$content)
  if (is.null(parsed)) {
    return(list(success = FALSE, error = "AI cavabı parse edilə bilmədi"))
  }

  tokens_used <- result$usage$input_tokens + result$usage$output_tokens

  list(
    success = TRUE,
    research_design = parsed$research_design,
    methodology = parsed$methodology,
    sampling = parsed$sampling,
    data_collection = parsed$data_collection,
    ethical_considerations = parsed$ethical_considerations,
    limitations = parsed$limitations,
    alternative_methods = parsed$alternative_methods,
    tokens_used = tokens_used
  )
}

# === 3. Statistik Analiz Planı ===
generate_analysis_plan_ai <- function(db_pool, research_question, research_field,
                                       methodology_summary = "",
                                       variables_desc = "",
                                       sample_size = "",
                                       user_id = NULL) {
  template <- load_prompt_template("research_analysis_plan")
  prompt <- sprintf(template,
    research_question,
    research_field,
    if (nchar(methodology_summary) > 0) methodology_summary else "Metodologiya hələ müəyyən edilməyib",
    if (nchar(variables_desc) > 0) variables_desc else "Dəyişənlər hələ müəyyən edilməyib",
    if (nchar(sample_size) > 0) sample_size else "Seçmə həcmi hələ müəyyən edilməyib"
  )

  system_prompt <- paste(
    "Sən statistik analiz üzrə ekspertsen.",
    "Yalnız JSON formatında cavab ver.",
    "R proqramlaşdırma dilində kod nümunələri ver."
  )

  result <- tryCatch({
    call_claude_api(
      prompt = prompt,
      system_prompt = system_prompt,
      max_tokens = 8192,
      temperature = 0.3
    )
  }, error = function(e) {
    log_error("Analiz planı AI xətası: {e$message}")
    return(list(success = FALSE, error = e$message))
  })

  if (isFALSE(result$success)) return(result)

  parsed <- parse_research_response(result$content)
  if (is.null(parsed)) {
    return(list(success = FALSE, error = "AI cavabı parse edilə bilmədi"))
  }

  tokens_used <- result$usage$input_tokens + result$usage$output_tokens

  list(
    success = TRUE,
    hypotheses = parsed$hypotheses,
    variables = parsed$variables,
    statistical_tests = parsed$statistical_tests,
    power_analysis = parsed$power_analysis,
    data_screening = parsed$data_screening,
    analysis_steps = parsed$analysis_steps,
    software_recommendations = parsed$software_recommendations,
    tokens_used = tokens_used
  )
}

# === 4. Nəticə Bölməsi Qaralama ===
draft_results_section_ai <- function(db_pool, research_question,
                                      methodology_summary = "",
                                      analysis_plan_summary = "",
                                      data_context = "",
                                      citation_format = "apa",
                                      user_id = NULL) {
  template <- load_prompt_template("research_results_draft")
  prompt <- sprintf(template,
    research_question,
    if (nchar(methodology_summary) > 0) methodology_summary else "Metodologiya hələ müəyyən edilməyib",
    if (nchar(analysis_plan_summary) > 0) analysis_plan_summary else "Analiz planı hələ hazırlanmayıb",
    if (nchar(data_context) > 0) data_context else "Əlavə kontekst yoxdur",
    citation_format
  )

  system_prompt <- paste(
    "Sən akademik yazı üzrə ekspertsen.",
    "Yalnız JSON formatında cavab ver.",
    "Akademik Azərbaycan dilində yaz.",
    sprintf("%s istinad formatına uyğun yaz.", toupper(citation_format))
  )

  result <- tryCatch({
    call_claude_api(
      prompt = prompt,
      system_prompt = system_prompt,
      max_tokens = 8192,
      temperature = 0.5
    )
  }, error = function(e) {
    log_error("Nəticə qaralama AI xətası: {e$message}")
    return(list(success = FALSE, error = e$message))
  })

  if (isFALSE(result$success)) return(result)

  parsed <- parse_research_response(result$content)
  if (is.null(parsed)) {
    return(list(success = FALSE, error = "AI cavabı parse edilə bilmədi"))
  }

  tokens_used <- result$usage$input_tokens + result$usage$output_tokens

  list(
    success = TRUE,
    results_section = parsed$results_section,
    discussion_points = parsed$discussion_points,
    limitations_from_results = parsed$limitations_from_results,
    future_research_suggestions = parsed$future_research_suggestions,
    tokens_used = tokens_used
  )
}

# === 5. AI Cavabı Parse ===
parse_research_response <- function(response_text) {
  tryCatch({
    parsed <- extract_json_from_response(response_text)
    if (!is.null(parsed)) return(parsed)

    # Fallback: birbaşa JSON parse
    jsonlite::fromJSON(response_text, simplifyVector = FALSE)
  }, error = function(e) {
    log_error("Tədqiqat AI cavab parse xətası: {e$message}")
    NULL
  })
}

# === 6. Sessiya Saxla ===
save_research_session <- function(db_pool, user_id, research_question, research_field,
                                   session_type, citation_format = "apa",
                                   project_id = NULL,
                                   literature_results = NULL,
                                   methodology_results = NULL,
                                   analysis_plan_results = NULL,
                                   results_draft_results = NULL,
                                   total_tokens = 0, ai_model = "claude") {
  tryCatch({
    session_id <- db_get_one(db_pool,
      "INSERT INTO research_ai_sessions
       (project_id, user_id, research_question, research_field, session_type,
        citation_format, literature_results, methodology_results,
        analysis_plan_results, results_draft_results,
        total_tokens_used, ai_model, created_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $2)
       RETURNING id",
      params = list(
        if (!is.null(project_id) && project_id != "") project_id else NA,
        user_id,
        research_question,
        research_field,
        session_type,
        citation_format,
        if (!is.null(literature_results)) jsonlite::toJSON(literature_results, auto_unbox = TRUE) else NA,
        if (!is.null(methodology_results)) jsonlite::toJSON(methodology_results, auto_unbox = TRUE) else NA,
        if (!is.null(analysis_plan_results)) jsonlite::toJSON(analysis_plan_results, auto_unbox = TRUE) else NA,
        if (!is.null(results_draft_results)) jsonlite::toJSON(results_draft_results, auto_unbox = TRUE) else NA,
        total_tokens,
        ai_model
      ))
    session_id$id
  }, error = function(e) {
    log_error("Tədqiqat sessiyası saxlama xətası: {e$message}")
    NULL
  })
}

# === 7. Ədəbiyyatı DB-yə saxla ===
save_literature_to_db <- function(db_pool, session_id, sources, project_id = NULL) {
  saved <- 0
  for (src in sources) {
    tryCatch({
      db_execute(db_pool,
        "INSERT INTO research_literature
         (session_id, project_id, title, authors, year, journal, volume, issue, pages,
          doi, abstract, relevance_score, key_findings, methodology_used, sample_info,
          citation_apa, citation_harvard, source_type)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, 'ai_suggested')",
        params = list(
          session_id,
          if (!is.null(project_id) && project_id != "") project_id else NA,
          src$title %||% "",
          src$authors %||% "",
          as.integer(src$year %||% NA),
          src$journal %||% "",
          src$volume %||% "",
          src$issue %||% "",
          src$pages %||% "",
          src$doi %||% "",
          src$abstract %||% "",
          as.numeric(src$relevance_score %||% 0),
          src$key_findings %||% "",
          src$methodology_used %||% "",
          src$sample_info %||% "",
          src$citation_apa %||% "",
          src$citation_harvard %||% ""
        ))
      saved <- saved + 1
    }, error = function(e) {
      log_error("Ədəbiyyat saxlama xətası: {e$message}")
    })
  }
  saved
}

# === 8. Sessiya Yenilə (addenda) ===
update_session_results <- function(db_pool, session_id, field, results, tokens = 0) {
  valid_fields <- c("literature_results", "methodology_results",
                     "analysis_plan_results", "results_draft_results")
  if (!field %in% valid_fields) {
    log_error("Yanlış sessiya sahəsi: {field}")
    return(FALSE)
  }

  tryCatch({
    query <- sprintf(
      "UPDATE research_ai_sessions
       SET %s = $1, total_tokens_used = total_tokens_used + $2, updated_at = NOW()
       WHERE id = $3", field
    )
    db_execute(db_pool, query,
      params = list(jsonlite::toJSON(results, auto_unbox = TRUE), tokens, session_id))
    TRUE
  }, error = function(e) {
    log_error("Sessiya yeniləmə xətası: {e$message}")
    FALSE
  })
}

# === 9. Sessiya Tarixçəsi ===
get_research_sessions <- function(db_pool, user_id = NULL, project_id = NULL,
                                   session_type = NULL, limit = 50) {
  where <- "1=1"
  params <- list()
  p <- 0

  if (!is.null(user_id) && user_id != "") {
    p <- p + 1
    where <- paste(where, sprintf("AND ras.user_id = $%d", p))
    params[[p]] <- user_id
  }
  if (!is.null(project_id) && project_id != "") {
    p <- p + 1
    where <- paste(where, sprintf("AND ras.project_id = $%d", p))
    params[[p]] <- project_id
  }
  if (!is.null(session_type) && session_type != "") {
    p <- p + 1
    where <- paste(where, sprintf("AND ras.session_type = $%d", p))
    params[[p]] <- session_type
  }

  p <- p + 1
  query <- sprintf("
    SELECT ras.id, ras.research_question, ras.research_field, ras.session_type,
           ras.citation_format, ras.status, ras.total_tokens_used,
           ras.created_at, u.username AS created_by_name,
           rp.title AS project_title
    FROM research_ai_sessions ras
    LEFT JOIN users u ON ras.created_by = u.id
    LEFT JOIN research_projects rp ON ras.project_id = rp.id
    WHERE %s
    ORDER BY ras.created_at DESC
    LIMIT $%d
  ", where, p)
  params[[p]] <- limit

  db_query(db_pool, query, params = params)
}

# === 10. Sessiya Detalı ===
get_session_detail <- function(db_pool, session_id) {
  db_get_one(db_pool,
    "SELECT * FROM research_ai_sessions WHERE id = $1",
    params = list(session_id))
}

# === 11. Sessiya Ədəbiyyatı ===
get_session_literature <- function(db_pool, session_id) {
  db_query(db_pool,
    "SELECT * FROM research_literature
     WHERE session_id = $1
     ORDER BY relevance_score DESC",
    params = list(session_id))
}

# === 12. İstinad Formatla ===
format_citation <- function(source, format = "apa") {
  if (format == "apa") {
    source$citation_apa %||% sprintf(
      "%s (%s). %s. %s, %s(%s), %s.",
      source$authors %||% "N/A",
      source$year %||% "n.d.",
      source$title %||% "",
      source$journal %||% "",
      source$volume %||% "",
      source$issue %||% "",
      source$pages %||% ""
    )
  } else if (format == "harvard") {
    source$citation_harvard %||% sprintf(
      "%s %s, '%s', %s, vol. %s, no. %s, pp. %s.",
      source$authors %||% "N/A",
      source$year %||% "n.d.",
      source$title %||% "",
      source$journal %||% "",
      source$volume %||% "",
      source$issue %||% "",
      source$pages %||% ""
    )
  } else {
    sprintf("%s (%s). %s.", source$authors %||% "N/A", source$year %||% "n.d.", source$title %||% "")
  }
}

# === 13. Sessiya Statistikası ===
get_research_ai_stats <- function(db_pool, user_id = NULL) {
  where <- if (!is.null(user_id) && user_id != "") "WHERE user_id = $1" else "WHERE 1=1"
  params <- if (!is.null(user_id) && user_id != "") list(user_id) else list()

  total <- db_get_one(db_pool, sprintf("SELECT COUNT(*) as cnt FROM research_ai_sessions %s", where), params = params)
  tokens <- db_get_one(db_pool, sprintf("SELECT COALESCE(SUM(total_tokens_used), 0) as total FROM research_ai_sessions %s", where), params = params)
  literature <- db_get_one(db_pool, sprintf(
    "SELECT COUNT(*) as cnt FROM research_literature rl
     JOIN research_ai_sessions ras ON rl.session_id = ras.id %s",
    gsub("WHERE", "AND", where)), params = params)

  list(
    total_sessions = total$cnt,
    total_tokens = tokens$total,
    total_literature = literature$cnt
  )
}
