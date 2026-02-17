# =============================================
# ARTI-2026: Kurikulum Standartları
# =============================================

standards_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(column(12, h2(icon("book"), "Kurikulum Standartları"), hr())),
    fluidRow(
      column(3, selectInput(ns("filter_subject"), "Fənn:", choices = c("Hamısı" = "", SUBJECTS))),
      column(3, selectInput(ns("filter_grade"), "Sinif:", choices = c("Hamısı" = "", setNames(1:11, paste0(1:11, "-ci sinif"))))),
      column(3, selectInput(ns("filter_level"), "Təhsil pilləsi:", choices = c("Hamısı" = "", "İbtidai" = "primary", "Ümumi orta" = "lower_secondary", "Tam orta" = "upper_secondary"))),
      column(3, selectInput(ns("filter_bloom"), "Bloom:", choices = c("Hamısı" = "", BLOOM_LEVELS)))
    ),
    fluidRow(column(12, div(class = "btn-toolbar",
      actionButton(ns("btn_add"), "Yeni Standart", icon = icon("plus"), class = "btn-success"),
      actionButton(ns("btn_edit"), "Redaktə", icon = icon("edit"), class = "btn-primary"),
      downloadButton(ns("btn_export_excel"), "Excel", class = "btn-info"),
      downloadButton(ns("btn_export_csv"), "CSV", class = "btn-warning")
    ))),
    br(),
    fluidRow(
      column(8, wellPanel(h4("Standartlar Cədvəli"), DTOutput(ns("standards_table")))),
      column(4,
        wellPanel(h4("Bloom Paylanması"), plotlyOutput(ns("bloom_chart"), height = "250px")),
        wellPanel(h4("Sinif Paylanması"), plotlyOutput(ns("grade_chart"), height = "250px"))
      )
    )
  )
}

standards_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    standards_data <- reactive({
      query <- "SELECT cs.*, s.name as subject_name FROM curriculum_standards cs
                LEFT JOIN subjects s ON cs.subject_id = s.id WHERE 1=1"
      params <- list(); idx <- 1
      if (!is_empty(input$filter_subject)) {
        query <- paste0(query, " AND s.name = $", idx); params[[idx]] <- input$filter_subject; idx <- idx+1
      }
      if (!is_empty(input$filter_grade)) {
        query <- paste0(query, " AND cs.grade = $", idx); params[[idx]] <- as.integer(input$filter_grade); idx <- idx+1
      }
      if (!is_empty(input$filter_bloom)) {
        query <- paste0(query, " AND cs.bloom_level = $", idx); params[[idx]] <- input$filter_bloom
      }
      query <- paste0(query, " ORDER BY cs.code")
      if (length(params) > 0) db_query(db_pool, query, params = params) else db_query(db_pool, query)
    })

    output$standards_table <- renderDT({
      data <- standards_data()
      if (nrow(data) == 0) return(datatable(data.frame()))
      display <- data %>% select(code, subject_name, grade, description, bloom_level)
      names(display) <- c("Kod", "Fənn", "Sinif", "Təsvir", "Bloom")
      datatable(display, selection = "single", options = default_dt_options())
    })

    output$bloom_chart <- renderPlotly({
      data <- standards_data()
      if (nrow(data) == 0) return(plotly_empty())
      counts <- data %>% count(bloom_level)
      plot_ly(data = counts, x = ~bloom_level, y = ~n, type = "bar",
              marker = list(color = "#3498db")) %>%
        layout(xaxis = list(title = "", tickangle = -45), yaxis = list(title = "Say"))
    })

    output$grade_chart <- renderPlotly({
      data <- standards_data()
      if (nrow(data) == 0) return(plotly_empty())
      counts <- data %>% count(grade)
      plot_ly(data = counts, x = ~paste0(grade, "-ci sinif"), y = ~n, type = "bar",
              marker = list(color = "#27ae60")) %>%
        layout(xaxis = list(title = ""), yaxis = list(title = "Say"))
    })

    observeEvent(input$btn_add, {
      showModal(modalDialog(
        title = "Yeni Standart", size = "l",
        textInput(ns("std_code"), "Standart kodu:", placeholder = "AZ.RIY.5.1.1"),
        selectInput(ns("std_subject"), "Fənn:", choices = SUBJECTS),
        selectInput(ns("std_grade"), "Sinif:", choices = 1:11),
        textAreaInput(ns("std_desc"), "Təsvir:", rows = 3, width = "100%"),
        selectInput(ns("std_bloom"), "Bloom:", choices = BLOOM_LEVELS),
        footer = tagList(actionButton(ns("btn_save_std"), "Saxla", class = "btn-success"), modalButton("Ləğv"))
      ))
    })

    observeEvent(input$btn_save_std, {
      req(input$std_code, input$std_desc)
      result <- db_execute(db_pool,
        "INSERT INTO curriculum_standards (subject_id, grade, code, description, bloom_level)
         VALUES ((SELECT id FROM subjects WHERE name = $1), $2, $3, $4, $5)",
        params = list(input$std_subject, as.integer(input$std_grade), input$std_code, input$std_desc, input$std_bloom))
      if (result > 0) { removeModal(); notify_success("Standart əlavə edildi!") }
    })

    output$btn_export_excel <- downloadHandler(
      filename = function() paste0("standartlar_", Sys.Date(), ".xlsx"),
      content = function(file) export_to_excel(standards_data(), file, "Standartlar")
    )
    output$btn_export_csv <- downloadHandler(
      filename = function() paste0("standartlar_", Sys.Date(), ".csv"),
      content = function(file) write.csv(standards_data(), file, row.names = FALSE)
    )
  })
}
