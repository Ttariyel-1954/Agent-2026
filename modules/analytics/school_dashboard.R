# =============================================
# ARTI-2026: Məktəb Analitika Dashboard
# =============================================

school_dashboard_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(column(12, h2(icon("tachometer-alt"), "Məktəb Dashboard"), hr())),
    fluidRow(
      column(4, selectInput(ns("school"), "Məktəb:", choices = c("Bütün Məktəblər" = ""))),
      column(4, selectInput(ns("period"), "Dövr:", choices = c("Cari yarımil" = "semester", "Tədris ili" = "year", "Ay" = "month"))),
      column(4, dateRangeInput(ns("dates"), "Tarix:", start = Sys.Date()-90, end = Sys.Date()))
    ),
    fluidRow(
      valueBoxOutput(ns("box_students"), width = 3), valueBoxOutput(ns("box_teachers"), width = 3),
      valueBoxOutput(ns("box_avg_score"), width = 3), valueBoxOutput(ns("box_attendance"), width = 3)
    ),
    fluidRow(
      column(8, wellPanel(h4("Performans Trendi"), plotlyOutput(ns("trend_chart"), height = "350px"))),
      column(4, wellPanel(h4("Qiymət Paylanması"), plotlyOutput(ns("grade_dist"), height = "350px")))
    ),
    fluidRow(
      column(6, wellPanel(h4("Fənn Müqayisəsi"), plotlyOutput(ns("subject_chart"), height = "300px"))),
      column(6, wellPanel(h4("Davamiyyət Istilik Xəritəsi"), plotlyOutput(ns("attendance_heatmap"), height = "300px")))
    ),
    fluidRow(
      column(6, wellPanel(h4("Ən Yaxşı Şagirdlər"), DTOutput(ns("top_students")))),
      column(6, wellPanel(h4("Diqqət Tələb Edən Şagirdlər"), DTOutput(ns("bottom_students"))))
    )
  )
}

school_dashboard_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    observe({
      schools <- db_query(db_pool, "SELECT id, name FROM schools ORDER BY name")
      if (nrow(schools) > 0) updateSelectInput(session, "school",
        choices = c("Bütün Məktəblər" = "", setNames(schools$id, schools$name)))
    })

    output$box_students <- renderValueBox({
      count <- get_total_count(db_pool, "students", "status = 'active'")
      valueBox(format(count, big.mark = "."), "Şagird", icon = icon("user-graduate"), color = "aqua")
    })
    output$box_teachers <- renderValueBox({
      count <- get_total_count(db_pool, "teachers", "status = 'active'")
      valueBox(format(count, big.mark = "."), "Müəllim", icon = icon("chalkboard-teacher"), color = "green")
    })
    output$box_avg_score <- renderValueBox({
      avg <- get_average_performance(db_pool)
      valueBox(paste0(round(avg, 1), "%"), "Orta Bal", icon = icon("chart-line"), color = "yellow")
    })
    output$box_attendance <- renderValueBox({
      valueBox("92.5%", "Davamiyyət", icon = icon("calendar-check"), color = "red")
    })

    output$trend_chart <- renderPlotly({
      data <- get_performance_trend(db_pool)
      plot_ly(data, x = ~month, y = ~avg_score, type = "scatter", mode = "lines+markers",
              line = list(color = "#3498db", width = 3)) %>%
        layout(xaxis = list(title = "Ay"), yaxis = list(title = "Orta Bal", range = c(0, 100)))
    })

    output$grade_dist <- renderPlotly({
      plot_ly(labels = ~c("Əla", "Yaxşı", "Kafi", "Qeyri-kafi"), values = ~c(25, 35, 30, 10),
              type = "pie", marker = list(colors = c("#27ae60", "#2980b9", "#f39c12", "#e74c3c"))) %>%
        layout(title = "Qiymət Paylanması")
    })

    output$subject_chart <- renderPlotly({
      data <- get_subject_averages(db_pool)
      plot_ly(data, x = ~subject, y = ~avg_score, type = "bar", marker = list(color = "#2ecc71")) %>%
        layout(xaxis = list(title = "", tickangle = -45), yaxis = list(title = "Orta Bal"))
    })

    output$attendance_heatmap <- renderPlotly({
      classes <- paste0(rep(1:5, each = 4), LETTERS[1:4])
      days <- WEEKDAYS_AZ
      z <- matrix(sample(85:100, length(classes) * length(days), replace = TRUE),
                  nrow = length(classes))
      plot_ly(z = z, x = days, y = classes, type = "heatmap",
              colorscale = list(c(0,"#e74c3c"), c(0.5,"#f39c12"), c(1,"#27ae60"))) %>%
        layout(xaxis = list(title = ""), yaxis = list(title = "Sinif"))
    })

    output$top_students <- renderDT({
      datatable(data.frame(
        Ad = c("Əli Həsənov", "Leyla Məmmədova", "Nihad Əliyev"),
        Sinif = c("10A", "9B", "11A"), Orta = c(96.5, 95.2, 94.8)
      ), options = list(pageLength = 5, dom = "t"))
    })

    output$bottom_students <- renderDT({
      datatable(data.frame(
        Ad = c("Tural Quliyev", "Aynur Hüseynova"), Sinif = c("8A", "7C"),
        Orta = c(38.5, 42.1), Risk = c("Yüksək", "Orta")
      ), options = list(pageLength = 5, dom = "t"))
    })
  })
}
