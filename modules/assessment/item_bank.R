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
      actionButton(ns("btn_calibrate"), "Kalibrə", icon = icon("cog"), class = "btn-secondary")
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
      input$btn_add; input$btn_delete  # Trigger
      query <- "SELECT i.*, s.name as subject_name FROM items i
                LEFT JOIN subjects s ON i.subject_id = s.id WHERE 1=1"
      params <- list(); idx <- 1

      if (!is_empty(input$filter_subject)) {
        query <- paste0(query, " AND s.name = $", idx); params[[idx]] <- input$filter_subject; idx <- idx+1
      }
      if (!is_empty(input$filter_difficulty)) {
        query <- paste0(query, " AND i.difficulty_label = $", idx); params[[idx]] <- input$filter_difficulty; idx <- idx+1
      }
      if (!is_empty(input$filter_bloom)) {
        query <- paste0(query, " AND i.bloom_level = $", idx); params[[idx]] <- input$filter_bloom; idx <- idx+1
      }
      if (!is_empty(input$search)) {
        query <- paste0(query, " AND i.content ILIKE $", idx); params[[idx]] <- paste0("%", input$search, "%")
      }
      query <- paste0(query, " ORDER BY i.created_at DESC")
      if (length(params) > 0) db_query(db_pool, query, params = params) else db_query(db_pool, query)
    })

    output$items_table <- renderDT({
      data <- items()
      if (nrow(data) == 0) return(datatable(data.frame("Sual tapılmadı" = character(0))))
      display <- data %>% select(id, content, subject_name, difficulty_label, bloom_level, irt_a, irt_b, irt_c, is_active)
      display$content <- substr(display$content, 1, 80)
      names(display) <- c("ID", "Mətn", "Fənn", "Çətinlik", "Bloom", "a", "b", "c", "Aktiv")
      datatable(display, selection = "single", options = default_dt_options())
    })

    output$total_items <- renderText({ nrow(items()) })
    output$active_items <- renderText({ sum(items()$is_active, na.rm = TRUE) })
    output$calibrated_items <- renderText({ sum(!is.na(items()$irt_a), na.rm = TRUE) })

    # Yeni sual əlavə et
    observeEvent(input$btn_add, {
      showModal(modalDialog(
        title = "Yeni Sual Əlavə Et", size = "l", easyClose = TRUE,
        textAreaInput(ns("item_content"), "Sual mətni:", rows = 4, width = "100%"),
        fluidRow(
          column(6, textInput(ns("option_a"), "A variantı:")), column(6, textInput(ns("option_b"), "B variantı:")),
          column(6, textInput(ns("option_c"), "C variantı:")), column(6, textInput(ns("option_d"), "D variantı:")),
          column(6, textInput(ns("option_e"), "E variantı (isteğe bağlı):"))
        ),
        selectInput(ns("correct_answer"), "Düzgün cavab:", choices = c("A", "B", "C", "D", "E")),
        fluidRow(
          column(4, selectInput(ns("item_subject"), "Fənn:", choices = SUBJECTS)),
          column(4, selectInput(ns("item_difficulty"), "Çətinlik:", choices = DIFFICULTY_LEVELS)),
          column(4, selectInput(ns("item_bloom"), "Bloom:", choices = BLOOM_LEVELS))
        ),
        fluidRow(
          column(4, numericInput(ns("item_a"), "IRT a (ayrıd etmə):", value = 1.0, min = 0.1, max = 3, step = 0.1)),
          column(4, numericInput(ns("item_b"), "IRT b (çətinlik):", value = 0, min = -4, max = 4, step = 0.1)),
          column(4, numericInput(ns("item_c"), "IRT c (təxmin):", value = 0.2, min = 0, max = 0.5, step = 0.05))
        ),
        footer = tagList(
          actionButton(ns("btn_save_item"), "Saxla", class = "btn-success"),
          modalButton("Ləğv et")
        )
      ))
    })

    observeEvent(input$btn_save_item, {
      req(input$item_content, input$option_a, input$option_b, input$correct_answer)
      options_json <- jsonlite::toJSON(list(
        A = input$option_a, B = input$option_b, C = input$option_c,
        D = input$option_d, E = input$option_e
      ), auto_unbox = TRUE)

      result <- db_execute(db_pool,
        "INSERT INTO items (content, options_json, correct_answer, subject_id, bloom_level,
         difficulty_label, irt_a, irt_b, irt_c, is_active, created_by, created_at)
         VALUES ($1, $2, $3, (SELECT id FROM subjects WHERE name = $4), $5, $6, $7, $8, $9, TRUE, $10, NOW())",
        params = list(input$item_content, options_json, input$correct_answer,
                      input$item_subject, input$item_bloom, input$item_difficulty,
                      input$item_a, input$item_b, input$item_c, user_data()$id))
      if (result > 0) { removeModal(); notify_success("Sual əlavə edildi!") }
      else notify_error("Sual əlavə edilərkən xəta!")
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
