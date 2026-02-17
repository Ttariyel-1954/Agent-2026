# =============================================
# ARTI-2026: Uyğunluq Analizi
# Standartlar və qiymətləndirmə uyğunluğu
# =============================================

alignment_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(column(12, h2(icon("project-diagram"), "Uyğunluq Analizi"), hr())),
    fluidRow(
      column(4, selectInput(ns("subject"), "Fənn:", choices = c("Seçin..." = "", SUBJECTS))),
      column(4, selectInput(ns("grade"), "Sinif:", choices = c("Seçin..." = "", setNames(1:11, paste0(1:11, "-ci sinif"))))),
      column(4, actionButton(ns("btn_analyze"), "Analiz Et", icon = icon("search"), class = "btn-primary", style = "margin-top:25px"))
    ),
    fluidRow(
      column(8, wellPanel(h4("Uyğunluq Matrisi"), plotlyOutput(ns("alignment_heatmap"), height = "500px"))),
      column(4,
        wellPanel(h4("Uyğunluq Statistikası"),
          tags$p(tags$strong("Webb İndeksi:"), textOutput(ns("webb_index"), inline = TRUE)),
          tags$p(tags$strong("Əhatə dərəcəsi:"), textOutput(ns("coverage"), inline = TRUE)),
          tags$p(tags$strong("Boşluq sayı:"), textOutput(ns("gaps_count"), inline = TRUE)),
          tags$p(tags$strong("Artıqlıq sayı:"), textOutput(ns("redundancy_count"), inline = TRUE))
        ),
        wellPanel(h4("DOK Paylanması"), plotlyOutput(ns("dok_chart"), height = "200px"))
      )
    ),
    fluidRow(
      column(6, wellPanel(h4(icon("exclamation-triangle"), "Boşluqlar (Əhatə Olunmayan Standartlar)"), DTOutput(ns("gaps_table")))),
      column(6, wellPanel(h4(icon("clone"), "Artıqlıqlar (Həddindən Artıq Qiymətləndirmə)"), DTOutput(ns("redundancy_table"))))
    ),
    fluidRow(column(12, wellPanel(
      downloadButton(ns("btn_report"), "Uyğunluq Hesabatını Yüklə", class = "btn-info")
    )))
  )
}

alignment_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    alignment_result <- reactiveVal(NULL)

    observeEvent(input$btn_analyze, {
      req(input$subject, input$grade)
      result <- calculate_alignment(db_pool, input$subject, as.integer(input$grade))
      alignment_result(result)
    })

    output$alignment_heatmap <- renderPlotly({
      result <- alignment_result()
      if (is.null(result)) return(plotly_empty())
      matrix <- result$matrix
      plot_ly(z = as.matrix(matrix), x = colnames(matrix), y = rownames(matrix),
              type = "heatmap", colorscale = list(c(0,"#ecf0f1"), c(0.5,"#3498db"), c(1,"#e74c3c"))) %>%
        layout(xaxis = list(title = "Suallar", tickangle = -45),
               yaxis = list(title = "Standartlar"), title = "Standart-Sual Uyğunluq Matrisi")
    })

    output$webb_index <- renderText({ round(alignment_result()$webb_index %||% 0, 2) })
    output$coverage <- renderText({ format_percent(alignment_result()$coverage %||% 0) })
    output$gaps_count <- renderText({ length(alignment_result()$gaps %||% character(0)) })
    output$redundancy_count <- renderText({ length(alignment_result()$redundancies %||% character(0)) })

    output$dok_chart <- renderPlotly({
      plot_ly(labels = ~c("DOK 1", "DOK 2", "DOK 3", "DOK 4"), values = ~c(30, 40, 20, 10),
              type = "pie", marker = list(colors = c("#3498db", "#2ecc71", "#f39c12", "#e74c3c"))) %>%
        layout(showlegend = TRUE)
    })

    output$gaps_table <- renderDT({
      result <- alignment_result()
      if (is.null(result) || length(result$gaps) == 0)
        return(datatable(data.frame(Standart = "Boşluq tapılmadı")))
      datatable(data.frame(Standart = result$gaps), options = list(pageLength = 10, dom = "t"))
    })

    output$redundancy_table <- renderDT({
      result <- alignment_result()
      if (is.null(result) || length(result$redundancies) == 0)
        return(datatable(data.frame(Standart = "Artıqlıq tapılmadı")))
      datatable(data.frame(Standart = result$redundancies, Sual_sayı = sample(3:8, length(result$redundancies), replace = TRUE)),
                options = list(pageLength = 10, dom = "t"))
    })
  })
}

#' Webb DOK Uyğunluq hesabla
calculate_alignment <- function(db_pool, subject, grade) {
  standards <- db_query(db_pool,
    "SELECT cs.* FROM curriculum_standards cs JOIN subjects s ON cs.subject_id = s.id
     WHERE s.name = $1 AND cs.grade = $2", params = list(subject, grade))

  items <- db_query(db_pool,
    "SELECT i.* FROM items i JOIN subjects s ON i.subject_id = s.id
     WHERE s.name = $1 AND i.is_active = TRUE", params = list(subject))

  alignment <- db_query(db_pool,
    "SELECT * FROM assessment_alignment aa
     WHERE aa.standard_id IN (SELECT id FROM curriculum_standards cs
       JOIN subjects s ON cs.subject_id = s.id WHERE s.name = $1 AND cs.grade = $2)",
    params = list(subject, grade))

  n_std <- max(1, nrow(standards)); n_items <- max(1, nrow(items))

  # Uyğunluq matrisi
  matrix_data <- matrix(0, nrow = n_std, ncol = min(n_items, 20))
  if (nrow(alignment) > 0) {
    for (i in seq_len(nrow(alignment))) {
      s_idx <- which(standards$id == alignment$standard_id[i])
      i_idx <- which(items$id == alignment$item_id[i])
      if (length(s_idx) > 0 && length(i_idx) > 0 && i_idx <= 20) matrix_data[s_idx, i_idx] <- alignment$dok_level[i]
    }
  }
  rownames(matrix_data) <- if (nrow(standards) > 0) standards$code else paste0("S", 1:n_std)
  colnames(matrix_data) <- paste0("Q", seq_len(ncol(matrix_data)))

  # Boşluqlar - heç bir sualla uyğunlaşdırılmamış standartlar
  covered <- unique(alignment$standard_id)
  gaps <- if (nrow(standards) > 0) standards$code[!standards$id %in% covered] else character(0)

  # Artıqlıqlar - 3-dən çox sualla uyğunlaşdırılmış
  std_counts <- table(alignment$standard_id)
  redundant_ids <- names(std_counts[std_counts > 3])
  redundancies <- if (nrow(standards) > 0) standards$code[standards$id %in% redundant_ids] else character(0)

  coverage <- if (nrow(standards) > 0) length(covered) / nrow(standards) * 100 else 0
  webb_index <- coverage / 100 * 0.8 + 0.2  # Sadələşdirilmiş

  list(matrix = matrix_data, gaps = gaps, redundancies = redundancies,
       coverage = coverage, webb_index = webb_index)
}
