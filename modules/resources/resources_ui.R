# =============================================
# Tədris Resursları Modulu - UI
# =============================================

# --- Tədris Proqramları ---
resources_programs_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(
      column(12, h2(icon("graduation-cap"), "Tədris Proqramları"), hr())
    ),
    fluidRow(
      column(3,
        selectInput(ns("filter_prog_subject"), "Fənn:",
          choices = c("Hamısı" = "", SUBJECTS))
      ),
      column(3,
        selectInput(ns("filter_prog_grade"), "Sinif:",
          choices = c("Hamısı" = "", setNames(1:11, paste0(1:11, "-ci sinif"))))
      ),
      column(3,
        actionButton(ns("btn_prog_refresh"), "Yenilə", icon = icon("refresh"),
                     class = "btn-default", style = "margin-top: 25px;")
      ),
      column(3,
        actionButton(ns("btn_add_program"), "Yeni Proqram", icon = icon("plus"),
                     class = "btn-primary", style = "margin-top: 25px;")
      )
    ),
    fluidRow(
      column(12, DTOutput(ns("programs_table")))
    ),
    uiOutput(ns("program_modal"))
  )
}

# --- Rəqəmsal Kontent ---
resources_digital_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(
      column(12, h2(icon("laptop"), "Rəqəmsal Kontent"), hr())
    ),
    fluidRow(
      column(3,
        textInput(ns("search_digital"), "Axtar:", placeholder = "Kontent adı və ya açar söz...")
      ),
      column(3,
        selectInput(ns("filter_dig_subject"), "Fənn:",
          choices = c("Hamısı" = "", SUBJECTS))
      ),
      column(3,
        selectInput(ns("filter_dig_type"), "Format:",
          choices = c("Hamısı" = "", "Video" = "video", "Audio" = "audio",
                      "Sənəd" = "document", "Təqdimat" = "presentation",
                      "İnteraktiv" = "interactive"))
      ),
      column(3,
        actionButton(ns("btn_upload_content"), "Yüklə", icon = icon("upload"),
                     class = "btn-success", style = "margin-top: 25px;")
      )
    ),
    fluidRow(
      column(12, DTOutput(ns("digital_table")))
    ),
    fluidRow(
      column(12,
        box(
          title = "Kontent Statistikası", status = "info", solidHeader = TRUE,
          width = 12, collapsible = TRUE, collapsed = TRUE,
          fluidRow(
            valueBoxOutput(ns("total_content_box"), width = 3),
            valueBoxOutput(ns("total_downloads_box"), width = 3),
            valueBoxOutput(ns("total_views_box"), width = 3),
            valueBoxOutput(ns("avg_rating_box"), width = 3)
          )
        )
      )
    ),
    uiOutput(ns("digital_modal"))
  )
}

# --- Dərsliklər və Metodik Vəsaitlər ---
resources_textbooks_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(
      column(12, h2(icon("book-open"), "Dərsliklər və Metodik Vəsaitlər"), hr())
    ),
    fluidRow(
      column(3,
        selectInput(ns("filter_tb_subject"), "Fənn:",
          choices = c("Hamısı" = "", SUBJECTS))
      ),
      column(3,
        selectInput(ns("filter_tb_grade"), "Sinif:",
          choices = c("Hamısı" = "", setNames(1:11, paste0(1:11, "-ci sinif"))))
      ),
      column(3,
        selectInput(ns("filter_tb_status"), "Status:",
          choices = c("Hamısı" = "", "Aktiv" = "active", "Təsdiqlənmiş" = "approved"))
      ),
      column(3,
        actionButton(ns("btn_add_textbook"), "Yeni Dərslik", icon = icon("plus"),
                     class = "btn-primary", style = "margin-top: 25px;")
      )
    ),
    fluidRow(
      column(12, DTOutput(ns("textbooks_table")))
    ),
    fluidRow(
      column(6,
        downloadButton(ns("btn_export_catalog"), "Kataloqu İxrac Et", class = "btn-warning")
      )
    ),
    uiOutput(ns("textbook_modal"))
  )
}
