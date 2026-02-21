# =============================================
# ARTI-2026: Akademik Təqvim UI
# Aylıq grid görünüşü və hadisə idarəetməsi
# =============================================

calendar_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(
      column(12, h2(icon("calendar-alt"), "Akademik Təqvim"), hr())
    ),

    # Navigasiya və filtrlər
    fluidRow(
      column(4,
        div(class = "btn-toolbar", style = "margin-bottom: 10px;",
          actionButton(ns("btn_prev_month"), "", icon = icon("chevron-left"),
                       class = "btn-default"),
          tags$span(style = "font-size: 18px; font-weight: bold; margin: 0 15px; vertical-align: middle;",
            textOutput(ns("current_month_label"), inline = TRUE)
          ),
          actionButton(ns("btn_next_month"), "", icon = icon("chevron-right"),
                       class = "btn-default"),
          actionButton(ns("btn_today"), "Bu gün", class = "btn-info",
                       style = "margin-left: 10px;")
        )
      ),
      column(3,
        selectInput(ns("filter_type"), "Hadisə Növü:",
          choices = c("Hamısı" = "", "İmtahan" = "exam", "Tətil" = "holiday",
                      "İclas" = "meeting", "Son Tarix" = "deadline",
                      "Təlim" = "training", "Digər" = "other")
        )
      ),
      column(5,
        div(style = "margin-top: 25px;",
          actionButton(ns("btn_add_event"), "Yeni Hadisə",
                       icon = icon("plus"), class = "btn-success"),
          downloadButton(ns("btn_export"), "İxrac", class = "btn-warning")
        )
      )
    ),

    # Əsas məzmun
    fluidRow(
      # Təqvim grid
      column(9,
        box(
          title = NULL,
          width = 12,
          status = "primary",
          div(style = "overflow-x: auto;",
            uiOutput(ns("calendar_grid"))
          )
        )
      ),

      # Sağ panel — Gələcək hadisələr
      column(3,
        box(
          title = "Gələcək Hadisələr",
          status = "info",
          solidHeader = TRUE,
          width = 12,
          uiOutput(ns("upcoming_events_list"))
        ),

        # Hadisə növü açıqlaması
        box(
          title = "Rəng Açıqlaması",
          width = 12,
          tags$div(
            lapply(list(
              c("exam", "İmtahan", "#e74c3c"),
              c("holiday", "Tətil", "#27ae60"),
              c("meeting", "İclas", "#3498db"),
              c("deadline", "Son Tarix", "#f39c12"),
              c("training", "Təlim", "#9b59b6"),
              c("other", "Digər", "#95a5a6")
            ), function(item) {
              tags$div(style = "margin-bottom: 5px;",
                tags$span(style = paste0("display:inline-block;width:12px;height:12px;",
                                         "background:", item[3], ";border-radius:2px;",
                                         "margin-right:8px;vertical-align:middle;")),
                tags$span(item[2])
              )
            })
          )
        )
      )
    ),

    # Hadisə siyahısı cədvəli
    fluidRow(
      box(
        title = "Aylıq Hadisə Siyahısı",
        status = "primary",
        solidHeader = TRUE,
        width = 12,
        collapsible = TRUE,
        collapsed = TRUE,
        DTOutput(ns("events_table"))
      )
    )
  )
}
