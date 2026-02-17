# =============================================
# ARTI-2026: Hesabat Generasiyası
# =============================================

reports_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(column(12, h2(icon("file-pdf"), "Hesabatlar"), hr())),
    fluidRow(
      column(3, selectInput(ns("report_type"), "Hesabat növü:", choices = c(
        "Şagird Hesabatı" = "student", "Sinif Hesabatı" = "class",
        "Məktəb Hesabatı" = "school", "Müəllim Hesabatı" = "teacher",
        "Qiymətləndirmə Hesabatı" = "assessment"
      ))),
      column(3, selectInput(ns("format"), "Format:", choices = EXPORT_FORMATS)),
      column(3, selectInput(ns("period"), "Dövr:", choices = c("I yarımil" = "sem1", "II yarımil" = "sem2", "İllik" = "year"))),
      column(3, actionButton(ns("btn_preview"), "Önbaxış", icon = icon("eye"), class = "btn-info", style = "margin-top:25px"))
    ),
    fluidRow(
      column(4, conditionalPanel(
        condition = sprintf("input['%s'] == 'student'", ns("report_type")),
        selectizeInput(ns("student_select"), "Şagird:", choices = NULL)
      )),
      column(4, conditionalPanel(
        condition = sprintf("input['%s'] == 'class'", ns("report_type")),
        selectInput(ns("class_select"), "Sinif:", choices = c("Seçin..." = ""))
      )),
      column(4, conditionalPanel(
        condition = sprintf("input['%s'] == 'teacher'", ns("report_type")),
        selectInput(ns("teacher_select"), "Müəllim:", choices = NULL)
      ))
    ),
    fluidRow(column(12, wellPanel(
      h4("Hesabat Önbaxışı"), uiOutput(ns("report_preview")),
      tags$hr(),
      downloadButton(ns("btn_download"), "Hesabatı Yüklə", class = "btn-success btn-lg"),
      actionButton(ns("btn_email"), "E-poçtla Göndər", icon = icon("envelope"), class = "btn-primary")
    ))),
    fluidRow(column(12, wellPanel(
      h4("Planlanmış Hesabatlar"),
      actionButton(ns("btn_schedule"), "Yeni Plan", icon = icon("clock"), class = "btn-warning"),
      DTOutput(ns("scheduled_reports"))
    )))
  )
}

reports_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    observe({
      students <- db_query(db_pool, "SELECT id, first_name || ' ' || last_name as name FROM students WHERE status = 'active'")
      if (nrow(students) > 0) updateSelectizeInput(session, "student_select", choices = setNames(students$id, students$name))
      teachers <- db_query(db_pool, "SELECT id, first_name || ' ' || last_name as name FROM teachers")
      if (nrow(teachers) > 0) updateSelectInput(session, "teacher_select", choices = setNames(teachers$id, teachers$name))
    })

    output$report_preview <- renderUI({
      tags$div(class = "report-preview", style = "padding:20px; border:1px solid #ddd; min-height:300px;",
        tags$h3("ARTI-2026 Hesabat Sistemi"),
        tags$p(paste("Hesabat növü:", input$report_type)),
        tags$p(paste("Dövr:", input$period)),
        tags$p(paste("Yaradılma tarixi:", format(Sys.time(), "%d.%m.%Y %H:%M"))),
        tags$hr(), tags$p("Önbaxış üçün 'Önbaxış' düyməsinə basın.")
      )
    })

    output$btn_download <- downloadHandler(
      filename = function() paste0("hesabat_", input$report_type, "_", format(Sys.Date(), "%Y%m%d"), ".", input$format),
      content = function(file) {
        if (input$format == "xlsx") {
          data <- generate_report_data(db_pool, input$report_type, input$period)
          export_to_excel(data, file, "Hesabat")
        } else if (input$format == "csv") {
          data <- generate_report_data(db_pool, input$report_type, input$period)
          write.csv(data, file, row.names = FALSE)
        } else {
          writeLines("Hesabat generasiya edildi", file)
        }
      }
    )

    output$scheduled_reports <- renderDT({
      datatable(data.frame(
        Hesabat = c("Aylıq Məktəb", "Yarımill Şagird"), Format = c("PDF", "Excel"),
        Tezlik = c("Aylıq", "Yarımill"), Növbəti = c("01.03.2026", "30.01.2026")
      ), options = list(pageLength = 5, dom = "t"))
    })
  })
}

#' Hesabat datasinı generasiya et
generate_report_data <- function(db_pool, report_type, period) {
  switch(report_type,
    "student" = db_query(db_pool,
      "SELECT s.first_name, s.last_name, sub.name as subject,
              AVG(g.score) as avg_score FROM grades g
       JOIN students s ON g.student_id = s.id JOIN subjects sub ON g.subject_id = sub.id
       GROUP BY s.first_name, s.last_name, sub.name ORDER BY s.last_name"),
    "class" = db_query(db_pool,
      "SELECT c.grade, c.section, COUNT(s.id) as student_count,
              AVG(g.score) as avg_score FROM classes c
       LEFT JOIN students s ON s.class_id = c.id
       LEFT JOIN grades g ON g.student_id = s.id
       GROUP BY c.grade, c.section ORDER BY c.grade, c.section"),
    data.frame(mesaj = "Hesabat data yoxdur")
  )
}
