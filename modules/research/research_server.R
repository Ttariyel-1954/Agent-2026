# =============================================
# Tədqiqat Modulu - Server
# =============================================

# --- Tədqiqat Layihələri Server ---
research_projects_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    projects <- reactive({
      input$btn_r_refresh
      query <- "SELECT rp.*, u.username AS lead_researcher
                FROM research_projects rp
                LEFT JOIN users u ON rp.lead_researcher_id = u.id
                WHERE 1=1"
      params <- list()
      param_idx <- 1

      if (!is_empty(input$filter_r_status)) {
        query <- paste0(query, " AND rp.status = $", param_idx)
        params[[param_idx]] <- input$filter_r_status
        param_idx <- param_idx + 1
      }

      query <- paste0(query, " ORDER BY rp.created_at DESC")

      if (length(params) > 0) db_query(db_pool, query, params = params)
      else db_query(db_pool, query)
    })

    output$research_table <- renderDT({
      data <- projects()
      if (nrow(data) == 0) return(datatable(data.frame("Məlumat yoxdur" = character(0))))

      display <- data %>%
        select(title, research_type, lead_researcher, start_date, end_date, progress, status) %>%
        rename(
          "Layihə" = title, "Növ" = research_type, "Rəhbər" = lead_researcher,
          "Başlama" = start_date, "Bitmə" = end_date, "İrəliləyiş (%)" = progress,
          "Status" = status
        )

      datatable(display, selection = "single", options = default_dt_options())
    })

    # Metrikalar
    metrics <- reactive({
      calculate_research_metrics(db_pool)
    })

    output$total_projects_box <- renderValueBox({
      m <- metrics()
      valueBox(m$total_projects, "Ümumi Layihə", icon = icon("flask"), color = "aqua")
    })

    output$active_projects_box <- renderValueBox({
      m <- metrics()
      valueBox(m$active_projects, "Aktiv Layihə", icon = icon("spinner"), color = "green")
    })

    output$total_publications_box <- renderValueBox({
      m <- metrics()
      valueBox(m$total_publications, "Nəşrlər", icon = icon("file-alt"), color = "yellow")
    })

    output$total_citations_box <- renderValueBox({
      m <- metrics()
      valueBox(m$total_citations, "İstinadlar", icon = icon("quote-right"), color = "purple")
    })

    # Yeni tədqiqat
    observeEvent(input$btn_add_research, {
      showModal(modalDialog(
        title = "Yeni Tədqiqat Layihəsi", size = "l",
        textInput(ns("r_title"), "Layihə adı:"),
        selectInput(ns("r_type"), "Tədqiqat növü:",
          choices = c("Fundamental" = "fundamental", "Tətbiqi" = "tetbiqi",
                      "Siyasət Analizi" = "siyaset_analizi")),
        textAreaInput(ns("r_desc"), "Təsvir:", rows = 3),
        textAreaInput(ns("r_objectives"), "Məqsədlər:", rows = 2),
        textAreaInput(ns("r_methodology"), "Metodologiya:", rows = 2),
        textInput(ns("r_department"), "Şöbə:"),
        fluidRow(
          column(6, dateInput(ns("r_start"), "Başlama tarixi:", language = "az")),
          column(6, dateInput(ns("r_end"), "Bitmə tarixi:", language = "az"))
        ),
        numericInput(ns("r_budget"), "Büdcə (AZN):", value = 0, min = 0),
        textInput(ns("r_funding"), "Maliyyə mənbəyi:"),
        footer = tagList(
          modalButton("Ləğv et"),
          actionButton(ns("btn_save_research"), "Saxla", class = "btn-primary")
        )
      ))
    })

    observeEvent(input$btn_save_research, {
      data <- list(
        title = input$r_title,
        research_type = input$r_type,
        start_date = input$r_start,
        end_date = input$r_end,
        budget = input$r_budget,
        progress = 0
      )

      errors <- validate_research_data(data)
      if (length(errors) > 0) {
        notify_error(paste(errors, collapse = "\n"))
        return()
      }

      tryCatch({
        db_execute(db_pool,
          "INSERT INTO research_projects
           (title, research_type, description, objectives, methodology,
            lead_researcher_id, department, start_date, end_date, budget, funding_source, status)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, 'planned')",
          params = list(
            input$r_title, input$r_type, input$r_desc, input$r_objectives,
            input$r_methodology, user_data()$sub, input$r_department,
            input$r_start, input$r_end, input$r_budget, input$r_funding
          ))
        removeModal()
        notify_success("Tədqiqat layihəsi yaradıldı")
      }, error = function(e) {
        log_error("Tədqiqat yaratma xətası: {e$message}")
        notify_error("Xəta baş verdi")
      })
    })
  })
}

# --- Siyasət Analizi Server ---
research_policy_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    policy_projects <- reactive({
      input$btn_policy_refresh
      query <- "SELECT rp.*, u.username AS lead_researcher
                FROM research_projects rp
                LEFT JOIN users u ON rp.lead_researcher_id = u.id
                WHERE rp.research_type = 'siyaset_analizi'"
      params <- list()
      param_idx <- 1

      if (!is_empty(input$filter_policy_status)) {
        query <- paste0(query, " AND rp.status = $", param_idx)
        params[[param_idx]] <- input$filter_policy_status
        param_idx <- param_idx + 1
      }

      query <- paste0(query, " ORDER BY rp.created_at DESC")

      if (length(params) > 0) db_query(db_pool, query, params = params)
      else db_query(db_pool, query)
    })

    output$policy_table <- renderDT({
      data <- policy_projects()
      if (nrow(data) == 0) return(datatable(data.frame("Məlumat yoxdur" = character(0))))

      display <- data %>%
        select(title, lead_researcher, start_date, progress, status) %>%
        rename(
          "Analiz" = title, "Rəhbər" = lead_researcher,
          "Başlama" = start_date, "İrəliləyiş (%)" = progress, "Status" = status
        )

      datatable(display, selection = "single", options = default_dt_options())
    })

    # Nəşrlər
    publications <- reactive({
      db_query(db_pool,
        "SELECT rp.* FROM research_publications rp
         JOIN research_projects rj ON rp.project_id = rj.id
         WHERE rj.research_type = 'siyaset_analizi'
         ORDER BY rp.publish_date DESC")
    })

    output$publications_table <- renderDT({
      data <- publications()
      if (nrow(data) == 0) return(datatable(data.frame("Məlumat yoxdur" = character(0))))

      display <- data %>%
        select(title, authors, journal, publish_date, citation_count) %>%
        rename(
          "Nəşr" = title, "Müəlliflər" = authors, "Jurnal" = journal,
          "Tarix" = publish_date, "İstinad" = citation_count
        )

      datatable(display, selection = "single", options = default_dt_options())
    })

    # Yeni nəşr
    observeEvent(input$btn_add_publication, {
      projects <- db_query(db_pool,
        "SELECT id, title FROM research_projects ORDER BY title")
      project_choices <- c("Seçin" = "")
      if (nrow(projects) > 0) {
        project_choices <- c(project_choices, setNames(projects$id, projects$title))
      }

      showModal(modalDialog(
        title = "Yeni Nəşr", size = "l",
        selectInput(ns("pub_project"), "Layihə:", choices = project_choices),
        textInput(ns("pub_title"), "Nəşr adı:"),
        textInput(ns("pub_authors"), "Müəlliflər:"),
        textInput(ns("pub_journal"), "Jurnal:"),
        fluidRow(
          column(4, textInput(ns("pub_volume"), "Cild:")),
          column(4, textInput(ns("pub_issue"), "Buraxılış:")),
          column(4, textInput(ns("pub_pages"), "Səhifələr:"))
        ),
        dateInput(ns("pub_date"), "Nəşr tarixi:", language = "az"),
        textInput(ns("pub_doi"), "DOI:"),
        textAreaInput(ns("pub_abstract"), "Xülasə:", rows = 3),
        textInput(ns("pub_keywords"), "Açar sözlər:"),
        selectInput(ns("pub_type"), "Nəşr növü:",
          choices = c("Məqalə" = "article", "Konfrans" = "conference",
                      "Kitab fəsli" = "book_chapter", "Hesabat" = "report")),
        footer = tagList(
          modalButton("Ləğv et"),
          actionButton(ns("btn_save_publication"), "Saxla", class = "btn-info")
        )
      ))
    })

    observeEvent(input$btn_save_publication, {
      data <- list(title = input$pub_title, authors = input$pub_authors, doi = input$pub_doi)

      errors <- validate_publication_data(data)
      if (length(errors) > 0) {
        notify_error(paste(errors, collapse = "\n"))
        return()
      }

      tryCatch({
        db_execute(db_pool,
          "INSERT INTO research_publications
           (project_id, title, authors, journal, volume, issue, pages,
            publish_date, doi, abstract, keywords, publication_type)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)",
          params = list(
            if (is_empty(input$pub_project)) NULL else input$pub_project,
            input$pub_title, input$pub_authors, input$pub_journal,
            input$pub_volume, input$pub_issue, input$pub_pages,
            input$pub_date, input$pub_doi, input$pub_abstract,
            input$pub_keywords, input$pub_type
          ))
        removeModal()
        notify_success("Nəşr əlavə edildi")
      }, error = function(e) {
        log_error("Nəşr əlavə xətası: {e$message}")
        notify_error("Xəta baş verdi")
      })
    })
  })
}

# --- Doktorantura Server ---
research_doctoral_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Proqram siyahısını yenilə
    observe({
      programs <- db_query(db_pool,
        "SELECT id, program_name FROM doctoral_programs WHERE status = 'active' ORDER BY program_name")
      choices <- c("Hamısı" = "")
      if (nrow(programs) > 0) {
        choices <- c(choices, setNames(programs$id, programs$program_name))
      }
      updateSelectInput(session, "filter_doc_program", choices = choices)
    })

    # Proqramlar cədvəli
    doctoral_programs <- reactive({
      db_query(db_pool,
        "SELECT dp.*, u.username AS coordinator,
                COUNT(ds.id) AS student_count
         FROM doctoral_programs dp
         LEFT JOIN users u ON dp.coordinator_id = u.id
         LEFT JOIN doctoral_students ds ON ds.program_id = dp.id AND ds.status = 'active'
         GROUP BY dp.id, u.username
         ORDER BY dp.program_name")
    })

    output$doctoral_programs_table <- renderDT({
      data <- doctoral_programs()
      if (nrow(data) == 0) return(datatable(data.frame("Məlumat yoxdur" = character(0))))

      display <- data %>%
        select(program_name, department, duration_years, student_count, max_students, status) %>%
        rename(
          "Proqram" = program_name, "Şöbə" = department,
          "Müddət (il)" = duration_years, "Doktorant" = student_count,
          "Maks." = max_students, "Status" = status
        )

      datatable(display, selection = "single", options = default_dt_options())
    })

    # Doktorantlar cədvəli
    doctoral_students <- reactive({
      query <- "SELECT ds.*, dp.program_name, u.username AS student_name,
                       su.username AS supervisor_name
                FROM doctoral_students ds
                JOIN doctoral_programs dp ON ds.program_id = dp.id
                JOIN users u ON ds.user_id = u.id
                LEFT JOIN users su ON ds.supervisor_id = su.id
                WHERE 1=1"
      params <- list()
      param_idx <- 1

      if (!is_empty(input$filter_doc_program)) {
        query <- paste0(query, " AND ds.program_id = $", param_idx)
        params[[param_idx]] <- input$filter_doc_program
        param_idx <- param_idx + 1
      }

      if (!is_empty(input$filter_doc_status)) {
        query <- paste0(query, " AND ds.status = $", param_idx)
        params[[param_idx]] <- input$filter_doc_status
        param_idx <- param_idx + 1
      }

      query <- paste0(query, " ORDER BY ds.admission_date DESC")

      if (length(params) > 0) db_query(db_pool, query, params = params)
      else db_query(db_pool, query)
    })

    output$doctoral_students_table <- renderDT({
      data <- doctoral_students()
      if (nrow(data) == 0) return(datatable(data.frame("Məlumat yoxdur" = character(0))))

      display <- data %>%
        select(student_name, program_name, supervisor_name, dissertation_title,
               admission_date, progress, status) %>%
        rename(
          "Doktorant" = student_name, "Proqram" = program_name,
          "Elmi Rəhbər" = supervisor_name, "Dissertasiya" = dissertation_title,
          "Qəbul" = admission_date, "İrəliləyiş (%)" = progress, "Status" = status
        )

      datatable(display, selection = "single", options = default_dt_options())
    })

    # Yeni proqram
    observeEvent(input$btn_add_program, {
      showModal(modalDialog(
        title = "Yeni Doktorantura Proqramı",
        textInput(ns("dp_name"), "Proqram adı:"),
        textInput(ns("dp_department"), "Şöbə:"),
        textInput(ns("dp_code"), "İxtisas kodu:"),
        textAreaInput(ns("dp_desc"), "Təsvir:", rows = 3),
        numericInput(ns("dp_duration"), "Müddət (il):", value = 4, min = 2, max = 7),
        numericInput(ns("dp_max"), "Maks. doktorant:", value = 10, min = 1),
        textAreaInput(ns("dp_requirements"), "Qəbul tələbləri:", rows = 3),
        footer = tagList(
          modalButton("Ləğv et"),
          actionButton(ns("btn_save_program"), "Saxla", class = "btn-primary")
        )
      ))
    })

    observeEvent(input$btn_save_program, {
      if (is_empty(input$dp_name)) {
        notify_error("Proqram adı daxil edilməlidir")
        return()
      }

      tryCatch({
        db_execute(db_pool,
          "INSERT INTO doctoral_programs
           (program_name, department, specialization_code, description,
            duration_years, max_students, coordinator_id, admission_requirements)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8)",
          params = list(
            input$dp_name, input$dp_department, input$dp_code, input$dp_desc,
            input$dp_duration, input$dp_max, user_data()$sub, input$dp_requirements
          ))
        removeModal()
        notify_success("Doktorantura proqramı yaradıldı")
      }, error = function(e) {
        log_error("Proqram yaratma xətası: {e$message}")
        notify_error("Xəta baş verdi")
      })
    })

    # Yeni doktorant
    observeEvent(input$btn_add_doctoral, {
      programs <- db_query(db_pool,
        "SELECT id, program_name FROM doctoral_programs WHERE status = 'active'")
      prog_choices <- setNames(programs$id, programs$program_name)

      showModal(modalDialog(
        title = "Yeni Doktorant",
        selectInput(ns("ds_program"), "Proqram:", choices = prog_choices),
        textInput(ns("ds_dissertation"), "Dissertasiya mövzusu:"),
        textInput(ns("ds_area"), "Tədqiqat sahəsi:"),
        dateInput(ns("ds_admission"), "Qəbul tarixi:", language = "az"),
        dateInput(ns("ds_expected"), "Gözlənilən bitmə:", language = "az"),
        footer = tagList(
          modalButton("Ləğv et"),
          actionButton(ns("btn_save_doctoral"), "Saxla", class = "btn-primary")
        )
      ))
    })

    observeEvent(input$btn_save_doctoral, {
      data <- list(
        program_id = input$ds_program,
        user_id = user_data()$sub,
        dissertation_title = input$ds_dissertation
      )

      errors <- validate_doctoral_data(data)
      if (length(errors) > 0) {
        notify_error(paste(errors, collapse = "\n"))
        return()
      }

      tryCatch({
        db_execute(db_pool,
          "INSERT INTO doctoral_students
           (program_id, user_id, dissertation_title, research_area,
            admission_date, expected_completion, status)
           VALUES ($1, $2, $3, $4, $5, $6, 'active')",
          params = list(
            input$ds_program, user_data()$sub, input$ds_dissertation,
            input$ds_area, input$ds_admission, input$ds_expected
          ))
        removeModal()
        notify_success("Doktorant əlavə edildi")
      }, error = function(e) {
        log_error("Doktorant əlavə xətası: {e$message}")
        notify_error("Xəta baş verdi")
      })
    })
  })
}

# === 4. AI Tədqiqat Asistenti Server ===
research_ai_assistant_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Reaktiv dəyərlər
    literature_result <- reactiveVal(NULL)
    methodology_result <- reactiveVal(NULL)
    analysis_plan_result <- reactiveVal(NULL)
    results_draft_result <- reactiveVal(NULL)
    total_tokens <- reactiveVal(0)
    current_session_id <- reactiveVal(NULL)

    # Layihə siyahısını yenilə
    observe({
      choices <- get_research_project_choices(db_pool, user_data()$sub)
      updateSelectInput(session, "linked_project", choices = choices)
    })

    # --- 1. Ədəbiyyat Axtarışı ---
    observeEvent(input$btn_literature, {
      req(input$research_question)
      if (nchar(trimws(input$research_question)) < 10) {
        notify_error("Tədqiqat sualı ən azı 10 simvol olmalıdır")
        return()
      }

      project_context <- get_project_context(db_pool, input$linked_project)

      withProgress(message = "AI ədəbiyyat axtarır...", value = 0.3, {
        result <- search_literature_ai(
          db_pool = db_pool,
          research_question = input$research_question,
          research_field = input$research_field,
          citation_format = input$citation_format,
          project_context = project_context,
          user_id = user_data()$sub
        )
        setProgress(1)
      })

      if (isTRUE(result$success)) {
        literature_result(result)
        total_tokens(total_tokens() + (result$tokens_used %||% 0))
        notify_success(sprintf("Ədəbiyyat icmalı hazırdır! %d mənbə tapıldı.",
          length(result$sources %||% list())))
      } else {
        notify_error(paste("Xəta:", result$error %||% "Naməlum xəta"))
      }
    })

    # --- 2. Metodologiya Tövsiyəsi ---
    observeEvent(input$btn_methodology, {
      req(input$research_question)
      if (nchar(trimws(input$research_question)) < 10) {
        notify_error("Tədqiqat sualı ən azı 10 simvol olmalıdır")
        return()
      }

      lit_context <- ""
      if (!is.null(literature_result())) {
        lit_context <- format_literature_summary(literature_result()$sources)
      }

      withProgress(message = "AI metodologiya hazırlayır...", value = 0.3, {
        result <- recommend_methodology_ai(
          db_pool = db_pool,
          research_question = input$research_question,
          research_field = input$research_field,
          research_type = input$research_type_ai,
          literature_context = lit_context,
          user_id = user_data()$sub
        )
        setProgress(1)
      })

      if (isTRUE(result$success)) {
        methodology_result(result)
        total_tokens(total_tokens() + (result$tokens_used %||% 0))
        notify_success("Metodologiya tövsiyəsi hazırdır!")
      } else {
        notify_error(paste("Xəta:", result$error %||% "Naməlum xəta"))
      }
    })

    # --- 3. Statistik Analiz Planı ---
    observeEvent(input$btn_analysis_plan, {
      req(input$research_question)
      if (nchar(trimws(input$research_question)) < 10) {
        notify_error("Tədqiqat sualı ən azı 10 simvol olmalıdır")
        return()
      }

      meth_summary <- format_methodology_summary(methodology_result())

      withProgress(message = "AI analiz planı hazırlayır...", value = 0.3, {
        result <- generate_analysis_plan_ai(
          db_pool = db_pool,
          research_question = input$research_question,
          research_field = input$research_field,
          methodology_summary = meth_summary,
          variables_desc = format_variables_description(input$variables_input),
          sample_size = input$sample_size_input %||% "",
          user_id = user_data()$sub
        )
        setProgress(1)
      })

      if (isTRUE(result$success)) {
        analysis_plan_result(result)
        total_tokens(total_tokens() + (result$tokens_used %||% 0))
        notify_success("Statistik analiz planı hazırdır!")
      } else {
        notify_error(paste("Xəta:", result$error %||% "Naməlum xəta"))
      }
    })

    # --- 4. Nəticə Qaralama ---
    observeEvent(input$btn_results_draft, {
      req(input$research_question)
      if (nchar(trimws(input$research_question)) < 10) {
        notify_error("Tədqiqat sualı ən azı 10 simvol olmalıdır")
        return()
      }

      meth_summary <- format_methodology_summary(methodology_result())
      analysis_summary <- format_analysis_plan_summary(analysis_plan_result())

      withProgress(message = "AI nəticə bölməsi yazır...", value = 0.3, {
        result <- draft_results_section_ai(
          db_pool = db_pool,
          research_question = input$research_question,
          methodology_summary = meth_summary,
          analysis_plan_summary = analysis_summary,
          data_context = input$data_context_input %||% "",
          citation_format = input$citation_format,
          user_id = user_data()$sub
        )
        setProgress(1)
      })

      if (isTRUE(result$success)) {
        results_draft_result(result)
        total_tokens(total_tokens() + (result$tokens_used %||% 0))
        notify_success("Nəticə bölməsi qaralama hazırdır!")
      } else {
        notify_error(paste("Xəta:", result$error %||% "Naməlum xəta"))
      }
    })

    # --- 5. Tam Proses (1-4 ardıcıl) ---
    observeEvent(input$btn_full_pipeline, {
      req(input$research_question)
      if (nchar(trimws(input$research_question)) < 10) {
        notify_error("Tədqiqat sualı ən azı 10 simvol olmalıdır")
        return()
      }

      project_context <- get_project_context(db_pool, input$linked_project)

      withProgress(message = "Tam tədqiqat prosesi başladı...", value = 0, {
        # Addım 1: Ədəbiyyat
        setProgress(0.1, detail = "Ədəbiyyat axtarılır...")
        lit_res <- search_literature_ai(db_pool, input$research_question,
          input$research_field, input$citation_format, project_context, user_data()$sub)
        if (isTRUE(lit_res$success)) {
          literature_result(lit_res)
          total_tokens(total_tokens() + (lit_res$tokens_used %||% 0))
        }
        Sys.sleep(0.5)

        # Addım 2: Metodologiya
        setProgress(0.3, detail = "Metodologiya hazırlanır...")
        lit_context <- if (isTRUE(lit_res$success)) format_literature_summary(lit_res$sources) else ""
        meth_res <- recommend_methodology_ai(db_pool, input$research_question,
          input$research_field, input$research_type_ai, lit_context, user_data()$sub)
        if (isTRUE(meth_res$success)) {
          methodology_result(meth_res)
          total_tokens(total_tokens() + (meth_res$tokens_used %||% 0))
        }
        Sys.sleep(0.5)

        # Addım 3: Analiz Planı
        setProgress(0.6, detail = "Analiz planı hazırlanır...")
        meth_summary <- if (isTRUE(meth_res$success)) format_methodology_summary(meth_res) else ""
        analysis_res <- generate_analysis_plan_ai(db_pool, input$research_question,
          input$research_field, meth_summary,
          format_variables_description(input$variables_input),
          input$sample_size_input %||% "", user_data()$sub)
        if (isTRUE(analysis_res$success)) {
          analysis_plan_result(analysis_res)
          total_tokens(total_tokens() + (analysis_res$tokens_used %||% 0))
        }
        Sys.sleep(0.5)

        # Addım 4: Nəticə Qaralama
        setProgress(0.85, detail = "Nəticə bölməsi yazılır...")
        analysis_summary <- if (isTRUE(analysis_res$success)) format_analysis_plan_summary(analysis_res) else ""
        draft_res <- draft_results_section_ai(db_pool, input$research_question,
          meth_summary, analysis_summary,
          input$data_context_input %||% "", input$citation_format, user_data()$sub)
        if (isTRUE(draft_res$success)) {
          results_draft_result(draft_res)
          total_tokens(total_tokens() + (draft_res$tokens_used %||% 0))
        }

        setProgress(1, detail = "Tamamlandı!")
      })

      notify_success("Tam tədqiqat prosesi tamamlandı!")
    })

    # --- 6. Sessiyanı Saxla ---
    observeEvent(input$btn_save_session, {
      req(input$research_question)

      session_id <- save_research_session(
        db_pool = db_pool,
        user_id = user_data()$sub,
        research_question = input$research_question,
        research_field = input$research_field,
        session_type = "full_pipeline",
        citation_format = input$citation_format,
        project_id = input$linked_project,
        literature_results = literature_result(),
        methodology_results = methodology_result(),
        analysis_plan_results = analysis_plan_result(),
        results_draft_results = results_draft_result(),
        total_tokens = total_tokens(),
        ai_model = "claude"
      )

      if (!is.null(session_id)) {
        current_session_id(session_id)

        # Ədəbiyyatı da saxla
        if (!is.null(literature_result()) && !is.null(literature_result()$sources)) {
          saved <- save_literature_to_db(db_pool, session_id,
            literature_result()$sources, input$linked_project)
          notify_success(sprintf("Sessiya saxlandı! %d mənbə bazaya əlavə edildi.", saved))
        } else {
          notify_success("Sessiya saxlandı!")
        }
      } else {
        notify_error("Sessiya saxlama xətası baş verdi")
      }
    })

    # --- 7. Təmizlə ---
    observeEvent(input$btn_clear_results, {
      literature_result(NULL)
      methodology_result(NULL)
      analysis_plan_result(NULL)
      results_draft_result(NULL)
      total_tokens(0)
      current_session_id(NULL)
      notify_success("Nəticələr təmizləndi")
    })

    # === RENDER: Statistika ValueBox-lar ===
    output$vb_tokens_used <- renderValueBox({
      valueBox(
        format_token_usage(total_tokens()),
        "Token İstifadəsi",
        icon = icon("microchip"),
        color = "aqua"
      )
    })

    output$vb_sources_found <- renderValueBox({
      cnt <- length(literature_result()$sources %||% list())
      valueBox(cnt, "Tapılan Mənbə", icon = icon("book"), color = "green")
    })

    output$vb_session_count <- renderValueBox({
      stats <- get_research_ai_stats(db_pool, user_data()$sub)
      valueBox(stats$total_sessions, "Ümumi Sessiya", icon = icon("history"), color = "purple")
    })

    # === RENDER: Ədəbiyyat İcmalı ===
    output$literature_summary_ui <- renderUI({
      lit <- literature_result()
      if (is.null(lit) || is.null(lit$literature_review)) {
        return(tags$p(class = "text-muted", "Ədəbiyyat axtarışı hələ aparılmayıb."))
      }
      review <- lit$literature_review
      tagList(
        wellPanel(style = "border-left: 4px solid #3498db;",
          h4("Ümumi Xülasə"),
          tags$p(review$summary %||% ""),
          if (!is.null(review$key_themes)) tagList(
            tags$strong("Əsas Mövzular: "),
            tags$span(paste(review$key_themes, collapse = ", "))
          ),
          if (!is.null(review$gaps) && length(review$gaps) > 0) tagList(
            tags$hr(),
            tags$strong("Ədəbiyyatdakı Boşluqlar:"),
            tags$ul(lapply(review$gaps, tags$li))
          ),
          if (!is.null(review$contradictions) && length(review$contradictions) > 0) tagList(
            tags$strong("Ziddiyyətlər:"),
            tags$ul(lapply(review$contradictions, tags$li))
          )
        )
      )
    })

    # Ədəbiyyat cədvəli
    output$literature_table <- renderDT({
      lit <- literature_result()
      if (is.null(lit) || is.null(lit$sources) || length(lit$sources) == 0) {
        return(datatable(data.frame("Mənbə tapılmadı" = character(0))))
      }

      df <- do.call(rbind, lapply(lit$sources, function(s) {
        data.frame(
          Müəllif = s$authors %||% "",
          İl = as.integer(s$year %||% NA),
          Başlıq = s$title %||% "",
          Jurnal = s$journal %||% "",
          Müvafiqlik = as.numeric(s$relevance_score %||% 0),
          stringsAsFactors = FALSE
        )
      }))

      datatable(df, selection = "single", options = default_dt_options(),
        rownames = FALSE) %>%
        formatStyle("Müvafiqlik", backgroundColor = styleInterval(
          c(0.5, 0.7, 0.9), c("#f8d7da", "#fff3cd", "#d4edda", "#c3e6cb")))
    })

    # Axtarış terminləri
    output$search_terms_ui <- renderUI({
      lit <- literature_result()
      if (is.null(lit) || is.null(lit$suggested_search_terms)) {
        return(tags$p(class = "text-muted", "Hələ termin yoxdur"))
      }
      tags$div(
        lapply(lit$suggested_search_terms, function(term) {
          tags$span(class = "label label-info", style = "margin: 3px; font-size: 13px;", term)
        })
      )
    })

    # İstinad ixracı
    observeEvent(input$btn_export_citations_apa, {
      lit <- literature_result()
      req(lit, lit$sources)
      citations <- sapply(lit$sources, function(s) format_citation(s, "apa"))
      showModal(modalDialog(
        title = "APA İstinadlar", size = "l",
        tags$pre(style = "white-space:pre-wrap;", paste(citations, collapse = "\n\n")),
        footer = modalButton("Bağla")
      ))
    })

    observeEvent(input$btn_export_citations_harvard, {
      lit <- literature_result()
      req(lit, lit$sources)
      citations <- sapply(lit$sources, function(s) format_citation(s, "harvard"))
      showModal(modalDialog(
        title = "Harvard İstinadlar", size = "l",
        tags$pre(style = "white-space:pre-wrap;", paste(citations, collapse = "\n\n")),
        footer = modalButton("Bağla")
      ))
    })

    # Mənbələri DB-yə saxla
    observeEvent(input$btn_save_literature_db, {
      lit <- literature_result()
      req(lit, lit$sources)
      sid <- current_session_id()
      if (is.null(sid)) {
        notify_warning("Əvvəlcə sessiyanı saxlayın")
        return()
      }
      saved <- save_literature_to_db(db_pool, sid, lit$sources, input$linked_project)
      notify_success(sprintf("%d mənbə verilənlər bazasına saxlandı", saved))
    })

    # === RENDER: Metodologiya ===
    output$design_ui <- renderUI({
      meth <- methodology_result()
      if (is.null(meth) || is.null(meth$research_design)) {
        return(tags$p(class = "text-muted", "Metodologiya hələ hazırlanmayıb."))
      }
      d <- meth$research_design
      tagList(
        tags$p(tags$strong("Növ: "), d$type %||% ""),
        tags$p(tags$strong("Yanaşma: "), d$approach %||% ""),
        tags$p(tags$strong("Əsaslandırma: "), d$justification %||% "")
      )
    })

    output$method_ui <- renderUI({
      meth <- methodology_result()
      if (is.null(meth) || is.null(meth$methodology)) {
        return(tags$p(class = "text-muted", "Metodologiya hələ hazırlanmayıb."))
      }
      m <- meth$methodology
      tagList(
        tags$p(tags$strong("Metod: "), m$primary_method %||% ""),
        tags$p(m$description %||% ""),
        if (!is.null(m$strengths)) tagList(
          tags$strong("Güclü tərəflər:"),
          tags$ul(lapply(m$strengths, tags$li))
        ),
        if (!is.null(m$limitations)) tagList(
          tags$strong("Məhdudiyyətlər:"),
          tags$ul(lapply(m$limitations, tags$li))
        )
      )
    })

    output$sampling_ui <- renderUI({
      meth <- methodology_result()
      if (is.null(meth) || is.null(meth$sampling)) {
        return(tags$p(class = "text-muted", "Seçmə məlumatı yoxdur."))
      }
      s <- meth$sampling
      tagList(
        tags$p(tags$strong("Strategiya: "), s$strategy %||% ""),
        tags$p(tags$strong("Hədəf: "), s$target_population %||% ""),
        tags$p(tags$strong("Tövsiyə olunan həcm: "), s$recommended_size %||% ""),
        tags$p(tags$strong("Əsaslandırma: "), s$justification %||% ""),
        if (!is.null(s$inclusion_criteria)) tagList(
          tags$strong("Daxiletmə meyarları:"),
          tags$ul(lapply(s$inclusion_criteria, tags$li))
        )
      )
    })

    output$data_collection_ui <- renderUI({
      meth <- methodology_result()
      if (is.null(meth) || is.null(meth$data_collection)) {
        return(tags$p(class = "text-muted", "Məlumat toplama planı yoxdur."))
      }
      dc <- meth$data_collection
      tagList(
        if (!is.null(dc$instruments)) tagList(
          lapply(dc$instruments, function(inst) {
            tags$div(style = "margin-bottom:10px; padding:8px; background:#f8f9fa; border-radius:4px;",
              tags$strong(inst$name %||% ""),
              tags$span(class = "label label-default", inst$type %||% ""),
              tags$p(inst$description %||% ""),
              tags$small(class = "text-muted", inst$validity_reliability %||% "")
            )
          })
        ),
        tags$p(tags$strong("Prosedur: "), dc$procedure %||% ""),
        tags$p(tags$strong("Vaxt: "), dc$timeline %||% "")
      )
    })

    output$ethics_ui <- renderUI({
      meth <- methodology_result()
      if (is.null(meth) || is.null(meth$ethical_considerations)) {
        return(tags$p(class = "text-muted", "Etik məlumat yoxdur."))
      }
      tags$ul(lapply(meth$ethical_considerations, function(e) {
        tags$li(style = "margin-bottom:5px;", icon("exclamation-circle"), e)
      }))
    })

    output$alternatives_ui <- renderUI({
      meth <- methodology_result()
      if (is.null(meth) || is.null(meth$alternative_methods)) {
        return(tags$p(class = "text-muted", "Alternativ yoxdur."))
      }
      tagList(
        lapply(meth$alternative_methods, function(alt) {
          tags$div(style = "margin-bottom:10px; padding:8px; background:#f8f9fa; border-radius:4px;",
            tags$strong(alt$method %||% ""),
            tags$p(tags$span(class = "text-success", icon("plus"), alt$pros %||% "")),
            tags$p(tags$span(class = "text-danger", icon("minus"), alt$cons %||% ""))
          )
        })
      )
    })

    # === RENDER: Analiz Planı ===
    output$hypotheses_ui <- renderUI({
      ap <- analysis_plan_result()
      if (is.null(ap) || is.null(ap$hypotheses)) {
        return(tags$p(class = "text-muted", "Hipotez hələ formalaşdırılmayıb."))
      }
      tagList(
        lapply(ap$hypotheses, function(h) {
          tags$div(style = "margin-bottom:12px; padding:10px; background:#f8f9fa; border-radius:4px;",
            tags$strong(h$id %||% "H"),
            tags$span(class = "label label-default", h$type %||% ""),
            tags$p(tags$em("H0: "), h$null_hypothesis %||% ""),
            tags$p(tags$em("H1: "), h$alternative_hypothesis %||% "")
          )
        })
      )
    })

    output$variables_ui <- renderUI({
      ap <- analysis_plan_result()
      if (is.null(ap) || is.null(ap$variables)) {
        return(tags$p(class = "text-muted", "Dəyişən analizi yoxdur."))
      }
      v <- ap$variables
      tagList(
        if (!is.null(v$dependent)) tagList(
          tags$strong("Asılı Dəyişənlər:"),
          tags$ul(lapply(v$dependent, function(d) {
            tags$li(sprintf("%s (%s, %s)", d$name %||% "", d$type %||% "", d$scale %||% ""))
          }))
        ),
        if (!is.null(v$independent)) tagList(
          tags$strong("Asılı Olmayan Dəyişənlər:"),
          tags$ul(lapply(v$independent, function(d) {
            tags$li(sprintf("%s (%s, %s)", d$name %||% "", d$type %||% "", d$scale %||% ""))
          }))
        ),
        if (!is.null(v$control)) tagList(
          tags$strong("Nəzarət Dəyişənləri:"),
          tags$ul(lapply(v$control, function(d) tags$li(d$name %||% "")))
        )
      )
    })

    output$stat_tests_table <- renderDT({
      ap <- analysis_plan_result()
      if (is.null(ap) || is.null(ap$statistical_tests) || length(ap$statistical_tests) == 0) {
        return(datatable(data.frame("Statistik test yoxdur" = character(0))))
      }

      df <- do.call(rbind, lapply(ap$statistical_tests, function(t) {
        data.frame(
          Hipotez = t$hypothesis_id %||% "",
          Test = t$test_name %||% "",
          Əsaslandırma = t$justification %||% "",
          Alternativ = t$alternative_test %||% "",
          "Effekt Ölçüsü" = t$effect_size_measure %||% "",
          alpha = t$significance_level %||% 0.05,
          stringsAsFactors = FALSE, check.names = FALSE
        )
      }))

      datatable(df, selection = "none", options = default_dt_options(), rownames = FALSE)
    })

    output$power_analysis_ui <- renderUI({
      ap <- analysis_plan_result()
      if (is.null(ap) || is.null(ap$power_analysis)) {
        return(tags$p(class = "text-muted", "Güc analizi yoxdur."))
      }
      pa <- ap$power_analysis
      tagList(
        tags$p(tags$strong("Min. seçmə həcmi: "), pa$minimum_sample_size %||% ""),
        tags$p(tags$strong("Güc: "), pa$power %||% ""),
        tags$p(tags$strong("Alpha: "), pa$alpha %||% ""),
        tags$p(tags$strong("Gözlənilən effekt: "), pa$expected_effect_size %||% ""),
        if (!is.null(pa$r_code)) tagList(
          tags$strong("R kodu:"),
          tags$pre(style = "background:#f0f0f0; padding:8px;", pa$r_code)
        )
      )
    })

    output$data_screening_ui <- renderUI({
      ap <- analysis_plan_result()
      if (is.null(ap) || is.null(ap$data_screening)) {
        return(tags$p(class = "text-muted", "Məlumat yoxlama planı yoxdur."))
      }
      ds <- ap$data_screening
      tagList(
        tags$p(tags$strong("Normalluq testləri: "),
          paste(ds$normality_tests %||% c(), collapse = ", ")),
        tags$p(tags$strong("Outlier aşkarlama: "), ds$outlier_detection %||% ""),
        tags$p(tags$strong("Əksik məlumat: "), ds$missing_data_strategy %||% ""),
        tags$p(tags$strong("Multikollinearlıq: "), ds$multicollinearity_check %||% "")
      )
    })

    # R kod nümunələri
    output$r_code_output <- renderText({
      ap <- analysis_plan_result()
      if (is.null(ap) || is.null(ap$statistical_tests)) return("# R kod nümunələri burada görünəcək...")

      codes <- c("# === Statistik Analiz R Kodları ===\n")
      for (t in ap$statistical_tests) {
        if (!is.null(t$r_code)) {
          codes <- c(codes, sprintf("# --- %s ---", t$test_name %||% "Test"), t$r_code, "\n")
        }
      }
      if (!is.null(ap$power_analysis$r_code)) {
        codes <- c(codes, "# --- Güc Analizi ---", ap$power_analysis$r_code)
      }
      paste(codes, collapse = "\n")
    })

    # === RENDER: Nəticə Qaralama ===
    output$results_text_ui <- renderUI({
      draft <- results_draft_result()
      if (is.null(draft) || is.null(draft$results_section)) {
        return(tags$p(class = "text-muted", "Nəticə bölməsi hələ yazılmayıb."))
      }
      rs <- draft$results_section
      tagList(
        tags$div(style = "border-left:4px solid #2ecc71; padding:15px; background:#f8f9fa;",
          tags$h4(rs$title %||% "Nəticələr"),
          if (!is.null(rs$descriptive_stats)) tagList(
            tags$h5("Təsviri Statistika"),
            tags$p(rs$descriptive_stats)
          ),
          if (!is.null(rs$full_text)) tagList(
            tags$hr(),
            tags$div(style = "white-space:pre-wrap;", rs$full_text)
          )
        )
      )
    })

    output$tables_ui <- renderUI({
      draft <- results_draft_result()
      if (is.null(draft) || is.null(draft$results_section) || is.null(draft$results_section$tables)) {
        return(tags$p(class = "text-muted", "Cədvəl təklifi yoxdur."))
      }
      tagList(
        lapply(draft$results_section$tables, function(tbl) {
          tags$div(style = "margin-bottom:10px; padding:8px; background:#f8f9fa; border-radius:4px;",
            tags$strong(sprintf("Cədvəl %s", tbl$number %||% "")),
            tags$p(tbl$title %||% ""),
            tags$small(class = "text-muted", tbl$description %||% ""),
            if (!is.null(tbl$suggested_columns)) tags$p(
              tags$em("Sütunlar: "), paste(tbl$suggested_columns, collapse = " | ")
            )
          )
        })
      )
    })

    output$figures_ui <- renderUI({
      draft <- results_draft_result()
      if (is.null(draft) || is.null(draft$results_section) || is.null(draft$results_section$figures)) {
        return(tags$p(class = "text-muted", "Qrafik təklifi yoxdur."))
      }
      tagList(
        lapply(draft$results_section$figures, function(fig) {
          tags$div(style = "margin-bottom:10px; padding:8px; background:#f8f9fa; border-radius:4px;",
            tags$strong(sprintf("Şəkil %s", fig$number %||% "")),
            tags$span(class = "label label-default", fig$type %||% ""),
            tags$p(fig$title %||% ""),
            tags$small(class = "text-muted", fig$description %||% ""),
            if (!is.null(fig$r_code)) tags$pre(style = "font-size:11px; margin-top:5px;", fig$r_code)
          )
        })
      )
    })

    output$discussion_points_ui <- renderUI({
      draft <- results_draft_result()
      if (is.null(draft) || is.null(draft$discussion_points)) {
        return(tags$p(class = "text-muted", "Müzakirə nöqtələri yoxdur."))
      }
      tags$ol(lapply(draft$discussion_points, function(p) tags$li(style = "margin-bottom:8px;", p)))
    })

    output$future_suggestions_ui <- renderUI({
      draft <- results_draft_result()
      if (is.null(draft) || is.null(draft$future_research_suggestions)) {
        return(tags$p(class = "text-muted", "Təklif yoxdur."))
      }
      tags$ul(lapply(draft$future_research_suggestions, function(s) {
        tags$li(style = "margin-bottom:5px;", icon("arrow-right"), s)
      }))
    })

    # Nəticə yükləmə
    output$btn_download_results <- downloadHandler(
      filename = function() {
        paste0("tedqiqat_neticeler_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".txt")
      },
      content = function(file) {
        draft <- results_draft_result()
        if (!is.null(draft) && !is.null(draft$results_section)) {
          text <- paste(
            "TƏDQIQAT NƏTİCƏLƏRİ",
            paste(rep("=", 50), collapse = ""),
            sprintf("Tədqiqat sualı: %s", input$research_question),
            sprintf("Tarix: %s", Sys.Date()),
            sprintf("İstinad formatı: %s", toupper(input$citation_format)),
            "",
            draft$results_section$full_text %||% "",
            "",
            "MÜZAKİRƏ NÖQTƏLƏRİ:",
            paste(draft$discussion_points %||% c(), collapse = "\n"),
            "",
            "GƏLƏCƏK TƏDQİQAT TƏKLİFLƏRİ:",
            paste(draft$future_research_suggestions %||% c(), collapse = "\n"),
            sep = "\n"
          )
          writeLines(text, file)
        }
      }
    )

    # === RENDER: Tarixçə ===
    history_data <- reactive({
      input$btn_hist_refresh
      get_research_sessions(
        db_pool,
        user_id = user_data()$sub,
        session_type = if (!is_empty(input$hist_type)) input$hist_type else NULL,
        limit = 100
      )
    })

    output$history_table <- renderDT({
      data <- history_data()
      if (is.null(data) || nrow(data) == 0) {
        return(datatable(data.frame("Tarixçə yoxdur" = character(0))))
      }

      display <- data %>%
        mutate(
          session_type = sapply(session_type, function(t) SESSION_TYPE_LABELS[t] %||% t),
          status = sapply(status, session_status_badge),
          created_at = format(created_at, "%d.%m.%Y %H:%M")
        ) %>%
        select(research_question, research_field, session_type, citation_format,
               total_tokens_used, status, created_at) %>%
        rename(
          "Tədqiqat Sualı" = research_question,
          "Sahə" = research_field,
          "Növ" = session_type,
          "Format" = citation_format,
          "Token" = total_tokens_used,
          "Status" = status,
          "Tarix" = created_at
        )

      datatable(display, selection = "single", escape = FALSE,
        options = default_dt_options(), rownames = FALSE)
    })

    # Seçilmiş sessiya detalı
    output$selected_session_detail <- renderUI({
      sel <- input$history_table_rows_selected
      if (is.null(sel) || length(sel) == 0) return(NULL)

      data <- history_data()
      if (is.null(data) || nrow(data) < sel) return(NULL)

      session_id <- data$id[sel]
      detail <- get_session_detail(db_pool, session_id)
      if (is.null(detail)) return(NULL)

      wellPanel(style = "border-left:4px solid #9b59b6;",
        h4(icon("info-circle"), "Sessiya Detalı"),
        tags$p(tags$strong("Sual: "), detail$research_question),
        tags$p(tags$strong("Sahə: "), detail$research_field),
        tags$p(tags$strong("Token: "), format_token_usage(detail$total_tokens_used)),
        tags$p(tags$strong("Yaradılma: "), format(detail$created_at, "%d.%m.%Y %H:%M")),
        actionButton(ns("btn_load_session"), "Bu Sessiyanı Yüklə",
          icon = icon("upload"), class = "btn-info")
      )
    })

    # Excel ixrac
    output$btn_hist_export <- downloadHandler(
      filename = function() {
        paste0("tedqiqat_tarixce_", format(Sys.time(), "%Y%m%d"), ".xlsx")
      },
      content = function(file) {
        data <- history_data()
        if (!is.null(data) && nrow(data) > 0) {
          export_to_excel(data, file)
        }
      }
    )
  })
}
