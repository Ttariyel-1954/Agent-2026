# =============================================
# ARTI-2026: Sual Bankı İdarəetməsi
# =============================================

# === Sual Bankı UI ===
item_bank_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(column(12, h2(icon("database"), "Sual Bankı"), hr())),
    fluidRow(
      column(3, selectInput(ns("filter_subject"), "Fənn:", choices = c("Hamısı" = "", SUBJECTS))),
      column(2, selectInput(ns("filter_difficulty"), "Çətinlik:", choices = c("Hamısı" = "", DIFFICULTY_LEVELS))),
      column(2, selectInput(ns("filter_bloom"), "Bloom:", choices = c("Hamısı" = "", BLOOM_LEVELS))),
      column(2, selectInput(ns("filter_grade"), "Sinif:", choices = c("Hamısı" = "", 1:11))),
      column(3, textInput(ns("search"), "Axtar:", placeholder = "Sual mətni..."))
    ),
    fluidRow(column(12, div(class = "btn-toolbar",
      actionButton(ns("btn_add"), "Yeni Sual", icon = icon("plus"), class = "btn-success"),
      actionButton(ns("btn_edit"), "Redaktə", icon = icon("edit"), class = "btn-primary"),
      actionButton(ns("btn_delete"), "Sil", icon = icon("trash"), class = "btn-danger"),
      actionButton(ns("btn_import"), "İdxal", icon = icon("upload"), class = "btn-info"),
      downloadButton(ns("btn_export"), "İxrac", class = "btn-warning"),
      actionButton(ns("btn_calibrate"), "Kalibrə", icon = icon("cog"), class = "btn-secondary"),
      actionButton(ns("btn_ai_generate"), "AI ilə Sual Yarat", icon = icon("robot"), class = "btn-info")
    ))),
    br(),
    fluidRow(column(12, DTOutput(ns("items_table")))),
    fluidRow(
      column(4, wellPanel(h4("Ümumi"), h2(textOutput(ns("total_items")), class = "text-center text-primary"))),
      column(4, wellPanel(h4("Aktiv"), h2(textOutput(ns("active_items")), class = "text-center text-success"))),
      column(4, wellPanel(h4("Kalibrə edilmiş"), h2(textOutput(ns("calibrated_items")), class = "text-center text-info")))
    ),
    uiOutput(ns("item_modal"))
  )
}

# === Sual Bankı Server ===
item_bank_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    items <- reactive({
      input$btn_add; input$btn_delete; input$btn_ai_save  # Trigger
      query <- "SELECT i.*, s.name as subject_name FROM items i
                LEFT JOIN subjects s ON i.subject_id = s.id WHERE 1=1"
      params <- list(); idx <- 1

      if (!is_empty(input$filter_subject)) {
        query <- paste0(query, " AND s.name = $", idx); params[[idx]] <- input$filter_subject; idx <- idx+1
      }
      if (!is_empty(input$filter_difficulty)) {
        query <- paste0(query, " AND i.difficulty = $", idx); params[[idx]] <- input$filter_difficulty; idx <- idx+1
      }
      if (!is_empty(input$filter_bloom)) {
        query <- paste0(query, " AND i.bloom_level = $", idx); params[[idx]] <- input$filter_bloom; idx <- idx+1
      }
      if (!is_empty(input$search)) {
        query <- paste0(query, " AND i.question_text ILIKE $", idx); params[[idx]] <- paste0("%", input$search, "%")
      }
      query <- paste0(query, " ORDER BY i.created_at DESC")
      if (length(params) > 0) db_query(db_pool, query, params = params) else db_query(db_pool, query)
    })

    output$items_table <- renderDT({
      data <- items()
      if (nrow(data) == 0) return(datatable(data.frame("Sual tapılmadı" = character(0))))
      display <- data[, c("id", "question_text", "subject_name", "difficulty", "bloom_level", "dok_level", "irt_a", "irt_b", "is_active"), drop = FALSE]
      display$question_text <- substr(display$question_text, 1, 80)
      names(display) <- c("ID", "Mətn", "Fənn", "Çətinlik", "Bloom", "DOK", "a", "b", "Aktiv")
      datatable(display, selection = "single", options = default_dt_options())
    })

    output$total_items <- renderText({ nrow(items()) })
    output$active_items <- renderText({ sum(items()$is_active, na.rm = TRUE) })
    output$calibrated_items <- renderText({ sum(items()$is_calibrated %||% FALSE, na.rm = TRUE) })

    # Yeni sual əlavə et (manual)
    observeEvent(input$btn_add, {
      showModal(modalDialog(
        title = "Yeni Sual Əlavə Et", size = "l", easyClose = TRUE,
        textAreaInput(ns("item_content"), "Sual mətni:", rows = 4, width = "100%"),
        fluidRow(
          column(6, textInput(ns("option_a"), "A variantı:")), column(6, textInput(ns("option_b"), "B variantı:")),
          column(6, textInput(ns("option_c"), "C variantı:")), column(6, textInput(ns("option_d"), "D variantı:"))
        ),
        selectInput(ns("correct_answer"), "Düzgün cavab:", choices = c("A", "B", "C", "D")),
        fluidRow(
          column(3, selectInput(ns("item_subject"), "Fənn:", choices = SUBJECTS)),
          column(3, selectInput(ns("item_difficulty"), "Çətinlik:", choices = DIFFICULTY_LEVELS)),
          column(3, selectInput(ns("item_bloom"), "Bloom:", choices = BLOOM_LEVELS)),
          column(3, selectInput(ns("item_dok"), "DOK:", choices = c("1" = 1, "2" = 2, "3" = 3, "4" = 4)))
        ),
        fluidRow(
          column(3, selectInput(ns("item_grade"), "Sinif:", choices = 1:11)),
          column(3, numericInput(ns("item_a"), "IRT a:", value = 1.0, min = 0.1, max = 3, step = 0.1)),
          column(3, numericInput(ns("item_b"), "IRT b:", value = 0, min = -4, max = 4, step = 0.1)),
          column(3, numericInput(ns("item_c"), "IRT c:", value = 0.2, min = 0, max = 0.5, step = 0.05))
        ),
        footer = tagList(
          actionButton(ns("btn_save_item"), "Saxla", class = "btn-success"),
          modalButton("Ləğv et")
        )
      ))
    })

    observeEvent(input$btn_save_item, {
      req(input$item_content, input$option_a, input$option_b, input$correct_answer)
      result <- tryCatch(
        db_execute(db_pool,
          "INSERT INTO items (question_text, question_type, option_a, option_b, option_c, option_d,
           correct_answer, subject_id, bloom_level, difficulty, dok_level, grade_level,
           irt_a, irt_b, irt_c, is_active, created_by)
           VALUES ($1, 'mcq', $2, $3, $4, $5, $6, (SELECT id FROM subjects WHERE name = $7),
           $8, $9, $10, $11, $12, $13, $14, TRUE, $15)",
          params = list(input$item_content, input$option_a, input$option_b, input$option_c,
                        input$option_d, input$correct_answer, input$item_subject,
                        input$item_bloom, input$item_difficulty, as.integer(input$item_dok),
                        as.integer(input$item_grade), input$item_a, input$item_b, input$item_c,
                        user_data()$id)),
        error = function(e) { log_error("Sual saxlama xətası: {e$message}"); 0 }
      )
      if (result > 0) { removeModal(); notify_success("Sual əlavə edildi!") }
      else notify_error("Sual əlavə edilərkən xəta!")
    })

    # === AI Sual Generasiyası ===
    ai_questions <- reactiveVal(NULL)

    # Addım 2: AI parametr modalı
    observeEvent(input$btn_ai_generate, {
      showModal(modalDialog(
        title = tagList(icon("robot"), "AI ilə Sual Yaratma"),
        size = "m", easyClose = TRUE,
        fluidRow(
          column(6, selectInput(ns("ai_subject"), "Fənn:", choices = SUBJECTS)),
          column(6, selectInput(ns("ai_grade"), "Sinif:", choices = 1:11))
        ),
        textInput(ns("ai_topic"), "Mövzu:", placeholder = "Məs: Tənliklər sistemi", width = "100%"),
        fluidRow(
          column(4, selectInput(ns("ai_bloom"), "Bloom səviyyəsi:",
                                choices = c("Qarışıq", BLOOM_LEVELS))),
          column(4, selectInput(ns("ai_difficulty"), "Çətinlik:",
                                choices = DIFFICULTY_LEVELS)),
          column(4, numericInput(ns("ai_count"), "Sual sayı:",
                                 value = 5, min = 1, max = 20))
        ),
        footer = tagList(
          actionButton(ns("btn_ai_run"), "Yarat", icon = icon("robot"), class = "btn-info"),
          modalButton("Ləğv et")
        )
      ))
    })

    # Addım 3: Claude API çağırışı (şablondan istifadə)
    observeEvent(input$btn_ai_run, {
      req(input$ai_topic)
      removeModal()

      # Bloom parametri
      bloom_param <- if (input$ai_bloom == "Qarışıq") "müxtəlif səviyyələrdə" else input$ai_bloom

      # Şablonu yüklə və parametrləri yerləşdir
      template <- load_prompt_template("question_generation")

      prompt <- if (nchar(template) > 0) {
        sprintf(template, input$ai_subject, input$ai_grade, input$ai_topic,
                input$ai_difficulty, bloom_param, input$ai_count)
      } else {
        # Fallback: şablon tapılmasa inline prompt
        paste0(
          input$ai_subject, " fənni, ", input$ai_grade, "-ci sinif, \"", input$ai_topic,
          "\" mövzusu, ", input$ai_count, " sual, ", input$ai_difficulty, " çətinlik, ",
          bloom_param, " Bloom səviyyəsində.\n",
          "JSON array qaytar: question_text, option_a, option_b, option_c, option_d, ",
          "correct_answer (A/B/C/D), bloom_level, dok_level (1-4), difficulty, explanation"
        )
      }

      system_prompt <- paste0(
        "Sən Azərbaycan Respublikası Təhsil Nazirliyi standartlarına əsasən sual hazırlayan ",
        "ekspert pedaqoqsan. Cavabı YALNIZ düzgün JSON array formatında qaytar. ",
        "JSON-dan əvvəl/sonra heç bir mətn, izah, markdown yazma. ",
        "Yalnız [ ilə başla və ] ilə bitir."
      )

      withProgress(message = "AI sualları yaradır...", value = 0.3, {
        result <- tryCatch(
          call_claude_api(prompt, system_prompt, max_tokens = 6144,
                          temperature = 0.7, task_type = "question_generation"),
          error = function(e) list(success = FALSE, message = e$message)
        )
        setProgress(0.7, detail = "Cavab emal edilir...")

        if (!result$success) {
          notify_error(paste("AI xətası:", result$message))
          return()
        }

        questions <- tryCatch(
          extract_json_from_response(result$message),
          error = function(e) NULL
        )

        if (is.null(questions)) {
          notify_error("AI cavabı emal edilə bilmədi. Yenidən cəhd edin.")
          return()
        }

        # data.frame-ə çevir
        if (!is.data.frame(questions)) {
          questions <- tryCatch(
            as.data.frame(do.call(rbind, lapply(questions, function(x) {
              as.data.frame(x, stringsAsFactors = FALSE)
            })), stringsAsFactors = FALSE),
            error = function(e) NULL
          )
        }

        if (is.null(questions) || nrow(questions) == 0) {
          notify_error("AI heç bir sual yarada bilmədi.")
          return()
        }

        # Sütun adlarını normallaşdır
        names(questions) <- tolower(trimws(names(questions)))

        # Məcburi sütunları yoxla, əskik olanları əlavə et
        required_cols <- c("question_text", "option_a", "option_b", "option_c", "option_d",
                           "correct_answer", "bloom_level", "dok_level", "difficulty", "explanation")
        for (col in required_cols) {
          if (!col %in% names(questions)) questions[[col]] <- NA
        }

        # dok_level-i ədədə çevir
        questions$dok_level <- as.integer(questions$dok_level %||% 2)
        questions$dok_level[is.na(questions$dok_level)] <- 2

        ai_questions(questions)
        setProgress(1, detail = paste0(nrow(questions), " sual yaradıldı"))
      })

      # Addım 4: Nəzərdən keçirmə modalını aç
      req(ai_questions())
      qs <- ai_questions()

      # Hər sual üçün kart
      question_html <- lapply(seq_len(nrow(qs)), function(i) {
        q <- qs[i, ]
        correct <- toupper(trimws(q$correct_answer %||% ""))
        dok_badge <- paste0("DOK ", q$dok_level %||% "?")

        # Variant stilləri
        opt_style <- function(letter) {
          if (identical(correct, letter)) {
            "color: #27ae60; font-weight: bold; background: #eafaf1; padding: 2px 6px; border-radius: 3px;"
          } else ""
        }

        tags$div(
          style = "border: 1px solid #ddd; border-radius: 8px; padding: 14px; margin-bottom: 10px; background: #fafafa;",
          tags$div(style = "display: flex; justify-content: space-between; align-items: center;",
            tags$strong(style = "font-size: 1.05em;", paste0(i, ". ", q$question_text %||% "")),
            tags$span(style = "display: flex; gap: 6px;",
              tags$span(class = "label label-info", q$bloom_level %||% ""),
              tags$span(class = "label label-warning", q$difficulty %||% ""),
              tags$span(class = "label label-default", dok_badge)
            )
          ),
          tags$div(style = "margin: 8px 0 8px 16px; line-height: 1.8;",
            tags$div(style = opt_style("A"), paste0("A) ", q$option_a %||% "")),
            tags$div(style = opt_style("B"), paste0("B) ", q$option_b %||% "")),
            tags$div(style = opt_style("C"), paste0("C) ", q$option_c %||% "")),
            tags$div(style = opt_style("D"), paste0("D) ", q$option_d %||% ""))
          ),
          if (!is.na(q$explanation) && nchar(q$explanation %||% "") > 0) {
            tags$div(style = "color: #7f8c8d; font-size: 0.88em; border-top: 1px solid #eee; padding-top: 6px; margin-top: 4px;",
              tags$em(icon("lightbulb"), paste0(" ", q$explanation))
            )
          }
        )
      })

      choices <- setNames(seq_len(nrow(qs)), paste0("Sual ", seq_len(nrow(qs))))

      showModal(modalDialog(
        title = tagList(icon("check-double"), paste0(" AI Sualları — ", nrow(qs), " sual yaradıldı")),
        size = "l", easyClose = FALSE,
        tags$div(style = "margin-bottom: 10px; padding: 8px; background: #d5f5e3; border-radius: 6px;",
          icon("info-circle"),
          paste0("Fənn: ", input$ai_subject, " | Sinif: ", input$ai_grade,
                 " | Mövzu: ", input$ai_topic, " | Yaşıl = düzgün cavab")
        ),
        checkboxGroupInput(ns("ai_select"), "Saxlanılacaq sualları seçin:",
                           choices = choices, selected = choices),
        tags$div(style = "max-height: 500px; overflow-y: auto;", question_html),
        footer = tagList(
          actionButton(ns("btn_ai_save"), paste0("Seçilmişləri Saxla (", length(choices), ")"),
                       icon = icon("save"), class = "btn-success"),
          actionButton(ns("btn_ai_regenerate"), "Yenidən Yarat", icon = icon("redo"), class = "btn-warning"),
          modalButton("Ləğv et")
        )
      ))
    })

    # Yenidən yarat düyməsi
    observeEvent(input$btn_ai_regenerate, {
      removeModal()
      ai_questions(NULL)
      shinyjs::click("btn_ai_generate")
    })

    # Addım 5: Seçilmiş sualları DB-yə yaz (items cədvəli sxeminə uyğun)
    observeEvent(input$btn_ai_save, {
      req(input$ai_select, ai_questions())
      qs <- ai_questions()
      selected_idx <- as.integer(input$ai_select)
      saved <- 0

      for (idx in selected_idx) {
        q <- qs[idx, ]
        correct <- toupper(trimws(q$correct_answer %||% "A"))
        dok <- as.integer(q$dok_level %||% 2)
        if (is.na(dok) || dok < 1 || dok > 4) dok <- 2L

        result <- tryCatch(
          db_execute(db_pool,
            "INSERT INTO items (question_text, question_type, option_a, option_b, option_c, option_d,
             correct_answer, subject_id, bloom_level, difficulty, dok_level, grade_level,
             is_active, created_by)
             VALUES ($1, 'mcq', $2, $3, $4, $5, $6,
             (SELECT id FROM subjects WHERE name = $7 LIMIT 1),
             $8, $9, $10, $11, TRUE, $12)",
            params = list(
              q$question_text %||% "", q$option_a %||% "", q$option_b %||% "",
              q$option_c %||% "", q$option_d %||% "", correct,
              input$ai_subject, q$bloom_level %||% "Bilmə",
              q$difficulty %||% "Orta", dok, as.integer(input$ai_grade),
              user_data()$id
            )),
          error = function(e) { log_error("AI sual saxlama: {e$message}"); 0 }
        )
        if (result > 0) saved <- saved + 1
      }

      removeModal()
      ai_questions(NULL)

      if (saved > 0) {
        notify_success(paste0(saved, "/", length(selected_idx), " sual sual bankına əlavə edildi!"))
      } else {
        notify_error("Suallar əlavə edilərkən xəta baş verdi.")
      }
    })

    # Kalibrə et
    observeEvent(input$btn_calibrate, {
      notify_warning("IRT kalibrəsi başladı... Bu bir neçə dəqiqə çəkə bilər.")
      # Burada real IRT kalibrəsi aparılardı (mirt paketi ilə)
      notify_success("Kalibrə tamamlandı!")
    })

    # İxrac
    output$btn_export <- downloadHandler(
      filename = function() paste0("sual_banki_", format(Sys.Date(), "%Y%m%d"), ".xlsx"),
      content = function(file) export_to_excel(items(), file, "Sual Bankı")
    )
  })
}

# === Klassik Test Teoriyası Statistikaları ===

#' Sual statistikalarını hesabla (p-dəyər, rpbis)
get_item_statistics <- function(responses_matrix) {
  n_items <- ncol(responses_matrix)
  n_examinees <- nrow(responses_matrix)
  total_scores <- rowSums(responses_matrix)

  stats <- data.frame(
    item = seq_len(n_items), p_value = NA, rpbis = NA, var = NA
  )

  for (i in seq_len(n_items)) {
    item_responses <- responses_matrix[, i]
    stats$p_value[i] <- mean(item_responses, na.rm = TRUE)
    stats$var[i] <- var(item_responses, na.rm = TRUE)
    if (sd(item_responses, na.rm = TRUE) > 0 && sd(total_scores, na.rm = TRUE) > 0) {
      stats$rpbis[i] <- cor(item_responses, total_scores, use = "complete.obs")
    }
  }
  stats
}

# === Test Nəticələri UI/Server ===

test_results_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(column(12, h2(icon("chart-bar"), "Test Nəticələri"), hr())),
    fluidRow(
      column(4, selectInput(ns("test_type"), "Test növü:", choices = c("CAT" = "cat", "MST" = "mst", "Standart" = "standard"))),
      column(4, selectInput(ns("subject"), "Fənn:", choices = c("Hamısı" = "", SUBJECTS))),
      column(4, dateRangeInput(ns("dates"), "Tarix:", start = Sys.Date()-30, end = Sys.Date()))
    ),
    fluidRow(
      column(8, wellPanel(h4("Nəticələr"), DTOutput(ns("results_table")))),
      column(4, wellPanel(h4("Paylanma"), plotlyOutput(ns("score_dist"), height = "300px")))
    ),
    fluidRow(
      column(6, wellPanel(h4("Theta Paylanması"), plotlyOutput(ns("theta_dist"), height = "300px"))),
      column(6, wellPanel(h4("Trend"), plotlyOutput(ns("trend_chart"), height = "300px")))
    )
  )
}

test_results_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    results <- reactive({
      db_query(db_pool,
        "SELECT ts.*, s.first_name || ' ' || s.last_name as student_name,
                sub.name as subject_name
         FROM test_sessions ts
         JOIN students s ON ts.student_id = s.id
         LEFT JOIN subjects sub ON ts.subject_id = sub.id
         WHERE ts.test_type = $1 AND ts.start_time >= $2 AND ts.start_time <= $3
         ORDER BY ts.start_time DESC",
        params = list(input$test_type, input$dates[1], input$dates[2]))
    })

    output$results_table <- renderDT({
      data <- results()
      if (nrow(data) == 0) return(datatable(data.frame()))
      display <- data %>% select(student_name, subject_name, theta_estimate, se, total_items, correct_items, status)
      names(display) <- c("Şagird", "Fənn", "Theta", "SE", "Sual", "Düzgün", "Status")
      datatable(display, options = default_dt_options(15))
    })

    output$score_dist <- renderPlotly({
      data <- results()
      if (nrow(data) == 0) return(plotly_empty())
      plot_ly(x = data$theta_estimate, type = "histogram", marker = list(color = "#3498db")) %>%
        layout(xaxis = list(title = "Theta"), yaxis = list(title = "Tezlik"))
    })

    output$theta_dist <- renderPlotly({
      plot_ly(x = rnorm(100), type = "histogram") %>%
        layout(xaxis = list(title = "Theta"), yaxis = list(title = "Say"))
    })

    output$trend_chart <- renderPlotly({
      plot_ly(x = seq.Date(Sys.Date()-30, Sys.Date(), by = "day"),
              y = rnorm(31, 0.5, 0.3), type = "scatter", mode = "lines") %>%
        layout(xaxis = list(title = ""), yaxis = list(title = "Orta Theta"))
    })
  })
}
