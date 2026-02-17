# =============================================
# ARTI-2026: Beynəlxalq Müqayisə
# =============================================

comparison_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(column(12, h2(icon("globe"), "Beynəlxalq Müqayisə"), hr())),
    fluidRow(
      column(6, checkboxGroupInput(ns("countries"), "Ölkələr:", choices = COMPARISON_COUNTRIES[-1],
                                    selected = c("Finlandiya", "Sinqapur", "Estoniya"), inline = TRUE)),
      column(3, selectInput(ns("assessment_type"), "Qiymətləndirmə:", choices = c("PISA" = "pisa", "TIMSS" = "timss"))),
      column(3, actionButton(ns("btn_compare"), "Müqayisə Et", icon = icon("balance-scale"), class = "btn-primary", style = "margin-top:25px"))
    ),
    fluidRow(
      column(6, wellPanel(h4("Radar Diaqram"), plotlyOutput(ns("radar_chart"), height = "400px"))),
      column(6, wellPanel(h4("Bal Müqayisəsi"), plotlyOutput(ns("score_chart"), height = "400px")))
    ),
    fluidRow(
      column(6, wellPanel(h4("PISA Balları"), DTOutput(ns("pisa_table")))),
      column(6, wellPanel(h4("Güclü/Zəif Tərəflər"), uiOutput(ns("strengths_weaknesses"))))
    ),
    fluidRow(column(12, wellPanel(
      h4("Ətraflı Müqayisə Hesabatı"),
      downloadButton(ns("btn_report"), "Hesabatı Yüklə", class = "btn-info")
    )))
  )
}

comparison_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    comparison_data <- reactive({
      req(input$countries)
      compare_curricula(c("Azərbaycan", input$countries))
    })

    output$radar_chart <- renderPlotly({
      data <- comparison_data()
      dimensions <- c("STEM Fokus", "Rəqəmsal Savadlılıq", "Tənqidi Düşüncə",
                       "Yaradıcılıq", "Sosial Bacarıqlar", "Praktik Tətbiq")
      p <- plot_ly(type = "scatterpolar", fill = "toself")
      colors <- c("#e74c3c", "#3498db", "#2ecc71", "#f39c12", "#9b59b6", "#1abc9c")
      for (i in seq_along(data$countries)) {
        p <- add_trace(p, r = data$scores[[i]], theta = dimensions,
                       name = data$countries[i], line = list(color = colors[i]))
      }
      p %>% layout(polar = list(radialaxis = list(range = c(0, 100))), title = "Kurikulum Müqayisəsi")
    })

    output$score_chart <- renderPlotly({
      countries <- c("Azərbaycan", input$countries)
      scores <- c(420, sample(480:550, length(input$countries)))
      plot_ly(x = countries, y = scores, type = "bar",
              marker = list(color = ifelse(countries == "Azərbaycan", "#e74c3c", "#3498db"))) %>%
        layout(xaxis = list(title = ""), yaxis = list(title = "PISA Balı"), title = "PISA Bal Müqayisəsi")
    })

    output$pisa_table <- renderDT({
      datatable(data.frame(
        Ölkə = c("Azərbaycan", "Finlandiya", "Sinqapur", "Estoniya"),
        Riyaziyyat = c(420, 507, 569, 523), Oxu = c(389, 520, 549, 523),
        Elm = c(398, 522, 551, 530), Orta = c(402, 516, 556, 525)
      ), options = list(pageLength = 10, dom = "t"))
    })

    output$strengths_weaknesses <- renderUI({
      tags$div(
        tags$h5(icon("check", style="color:green"), "Güclü tərəflər:"),
        tags$ul(tags$li("Riyaziyyat kurrikulumunun strukturu"), tags$li("Əzbərçilik bacarığı")),
        tags$h5(icon("times", style="color:red"), "Zəif tərəflər:"),
        tags$ul(tags$li("Tənqidi düşüncə vurğusu az"), tags$li("Rəqəmsal savadlılıq aşağı"), tags$li("Praktik tətbiq imkanları məhdud"))
      )
    })

    output$btn_report <- downloadHandler(
      filename = function() paste0("beynelxalq_muqayise_", Sys.Date(), ".pdf"),
      content = function(file) { file.copy("docs/sample_comparison.pdf", file) }
    )
  })
}

#' Kurikulumları müqayisə et
compare_curricula <- function(countries) {
  dimensions <- c("STEM Fokus", "Rəqəmsal Savadlılıq", "Tənqidi Düşüncə",
                   "Yaradıcılıq", "Sosial Bacarıqlar", "Praktik Tətbiq")
  scores <- lapply(countries, function(c) {
    base <- switch(c,
      "Azərbaycan" = c(60, 45, 40, 35, 50, 40),
      "Finlandiya" = c(75, 80, 90, 85, 88, 82),
      "Sinqapur" = c(95, 85, 80, 70, 65, 75),
      "Cənubi Koreya" = c(90, 80, 75, 65, 60, 70),
      "Estoniya" = c(80, 82, 85, 75, 78, 80),
      "Yaponiya" = c(88, 78, 72, 68, 62, 75),
      "Türkiyə" = c(65, 55, 50, 45, 55, 50),
      sample(40:80, 6))
  })
  list(countries = countries, dimensions = dimensions, scores = scores)
}
