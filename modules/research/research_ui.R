# =============================================
# Tədqiqat Modulu - UI
# =============================================

# --- Tədqiqatlar ---
research_projects_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(
      column(12, h2(icon("flask"), "Tədqiqat Layihələri"), hr())
    ),
    fluidRow(
      column(3,
        selectInput(ns("filter_r_type"), "Tədqiqat Növü:",
          choices = c("Hamısı" = "", RESEARCH_STATUS))
      ),
      column(3,
        selectInput(ns("filter_r_status"), "Status:",
          choices = c("Hamısı" = "", "Planlaşdırılmış" = "planned",
                      "Aktiv" = "active", "Tamamlanmış" = "completed",
                      "Dayandırılmış" = "suspended"))
      ),
      column(3,
        actionButton(ns("btn_r_refresh"), "Yenilə", icon = icon("refresh"),
                     class = "btn-default", style = "margin-top: 25px;")
      ),
      column(3,
        actionButton(ns("btn_add_research"), "Yeni Tədqiqat", icon = icon("plus"),
                     class = "btn-primary", style = "margin-top: 25px;")
      )
    ),
    fluidRow(
      column(12, DTOutput(ns("research_table")))
    ),
    fluidRow(
      column(12,
        box(
          title = "Tədqiqat Metrikaları", status = "primary", solidHeader = TRUE,
          width = 12, collapsible = TRUE, collapsed = TRUE,
          fluidRow(
            valueBoxOutput(ns("total_projects_box"), width = 3),
            valueBoxOutput(ns("active_projects_box"), width = 3),
            valueBoxOutput(ns("total_publications_box"), width = 3),
            valueBoxOutput(ns("total_citations_box"), width = 3)
          )
        )
      )
    ),
    uiOutput(ns("research_modal"))
  )
}

# --- Siyasət Analizi ---
research_policy_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(
      column(12, h2(icon("balance-scale"), "Siyasət Analizi"), hr())
    ),
    fluidRow(
      column(4,
        selectInput(ns("filter_policy_status"), "Status:",
          choices = c("Hamısı" = "", "Aktiv" = "active", "Tamamlanmış" = "completed"))
      ),
      column(4,
        actionButton(ns("btn_policy_refresh"), "Yenilə", icon = icon("refresh"),
                     class = "btn-default", style = "margin-top: 25px;")
      ),
      column(4,
        actionButton(ns("btn_add_policy"), "Yeni Analiz", icon = icon("plus"),
                     class = "btn-success", style = "margin-top: 25px;")
      )
    ),
    fluidRow(
      column(12, DTOutput(ns("policy_table")))
    ),
    fluidRow(
      column(12,
        box(
          title = "Nəşrlər", status = "info", solidHeader = TRUE, width = 12,
          DTOutput(ns("publications_table")),
          tags$hr(),
          actionButton(ns("btn_add_publication"), "Yeni Nəşr", icon = icon("plus"),
                       class = "btn-info")
        )
      )
    ),
    uiOutput(ns("policy_modal"))
  )
}

# --- Doktorantura Proqramları ---
research_doctoral_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(
      column(12, h2(icon("user-graduate"), "Doktorantura Proqramları"), hr())
    ),
    fluidRow(
      column(4,
        selectInput(ns("filter_doc_program"), "Proqram:",
          choices = c("Hamısı" = ""))
      ),
      column(4,
        selectInput(ns("filter_doc_status"), "Status:",
          choices = c("Hamısı" = "", "Aktiv" = "active",
                      "Tamamlanmış" = "completed", "Dayandırılmış" = "suspended"))
      ),
      column(4,
        actionButton(ns("btn_add_doctoral"), "Yeni Doktorant", icon = icon("plus"),
                     class = "btn-primary", style = "margin-top: 25px;")
      )
    ),
    fluidRow(
      column(12,
        box(
          title = "Proqramlar", status = "primary", solidHeader = TRUE, width = 12,
          DTOutput(ns("doctoral_programs_table")),
          tags$hr(),
          actionButton(ns("btn_add_program"), "Yeni Proqram", icon = icon("plus"),
                       class = "btn-info")
        )
      )
    ),
    fluidRow(
      column(12,
        box(
          title = "Doktorantlar", status = "success", solidHeader = TRUE, width = 12,
          DTOutput(ns("doctoral_students_table"))
        )
      )
    ),
    uiOutput(ns("doctoral_modal"))
  )
}
