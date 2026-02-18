# =============================================
# İnstitut Strukturu: İstifadəçi İnterfeysi
# =============================================

# === 1. Struktur Tab ===
inst_structure_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(
      valueBoxOutput(ns("units_count_box"), width = 3),
      valueBoxOutput(ns("personnel_count_box"), width = 3),
      valueBoxOutput(ns("projects_count_box"), width = 3),
      valueBoxOutput(ns("areas_count_box"), width = 3)
    ),
    fluidRow(
      box(
        title = "Təşkilati Struktur",
        status = "primary",
        solidHeader = TRUE,
        width = 12,
        collapsible = TRUE,
        fluidRow(
          column(8, uiOutput(ns("org_chart"))),
          column(4,
            selectInput(ns("filter_unit_type"), "Vahid Növü:",
              choices = c("Hamısı" = "", UNIT_TYPES),
              selected = ""
            ),
            actionButton(ns("add_unit_btn"), "Yeni Vahid",
              icon = icon("plus"), class = "btn-primary btn-block")
          )
        )
      )
    ),
    fluidRow(
      box(
        title = "Təşkilati Vahidlər Cədvəli",
        status = "info",
        solidHeader = TRUE,
        width = 12,
        collapsible = TRUE,
        DTOutput(ns("units_table"))
      )
    )
  )
}

# === 2. Resurslar Tab ===
inst_resources_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(
      box(
        title = "Resurs Filtrləri",
        status = "primary",
        solidHeader = TRUE,
        width = 12,
        fluidRow(
          column(3,
            selectInput(ns("res_unit_filter"), "Vahid:",
              choices = c("Hamısı" = ""), selected = "")
          ),
          column(3,
            selectInput(ns("res_type_filter"), "Resurs Növü:",
              choices = c("Hamısı" = "", INST_RESOURCE_TYPES), selected = "")
          ),
          column(3,
            selectInput(ns("res_condition_filter"), "Vəziyyət:",
              choices = c("Hamısı" = "", RESOURCE_CONDITION), selected = "")
          ),
          column(3,
            actionButton(ns("add_resource_btn"), "Yeni Resurs",
              icon = icon("plus"), class = "btn-primary",
              style = "margin-top: 25px; width: 100%;")
          )
        )
      )
    ),
    fluidRow(
      box(
        title = "Resurslar Cədvəli",
        status = "info",
        solidHeader = TRUE,
        width = 8,
        DTOutput(ns("resources_table"))
      ),
      box(
        title = "Büdcə Paylanması",
        status = "success",
        solidHeader = TRUE,
        width = 4,
        plotlyOutput(ns("budget_pie_chart"), height = "300px"),
        tags$hr(),
        uiOutput(ns("budget_summary"))
      )
    )
  )
}

# === 3. Kontingent Tab ===
inst_contingent_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(
      box(
        title = "Personal Filtrləri",
        status = "primary",
        solidHeader = TRUE,
        width = 12,
        fluidRow(
          column(3,
            selectInput(ns("pers_unit_filter"), "Vahid:",
              choices = c("Hamısı" = ""), selected = "")
          ),
          column(3,
            selectInput(ns("pers_type_filter"), "Personal Növü:",
              choices = c("Hamısı" = "", PERSONNEL_TYPES), selected = "")
          ),
          column(3,
            selectInput(ns("pers_employment_filter"), "Məşğulluq:",
              choices = c("Hamısı" = "", EMPLOYMENT_TYPES), selected = "")
          ),
          column(3,
            actionButton(ns("add_personnel_btn"), "Yeni Personal",
              icon = icon("plus"), class = "btn-primary",
              style = "margin-top: 25px; width: 100%;")
          )
        )
      )
    ),
    fluidRow(
      box(
        title = "Personal Siyahısı",
        status = "info",
        solidHeader = TRUE,
        width = 8,
        DTOutput(ns("personnel_table"))
      ),
      column(4,
        box(
          title = "Vahid üzrə Paylanma",
          status = "warning",
          solidHeader = TRUE,
          width = 12,
          plotlyOutput(ns("personnel_by_unit_chart"), height = "250px")
        ),
        box(
          title = "Növ üzrə Paylanma",
          status = "success",
          solidHeader = TRUE,
          width = 12,
          plotlyOutput(ns("personnel_by_type_chart"), height = "250px")
        )
      )
    )
  )
}

# === 4. Monitorinq Tab ===
inst_monitoring_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(
      tabBox(
        title = "Monitorinq və Nəzarət",
        width = 12,
        id = ns("monitoring_tabs"),

        # Fəaliyyət sahələri
        tabPanel(
          title = tagList(icon("tasks"), " Fəaliyyət Sahələri"),
          value = "areas_tab",
          fluidRow(
            column(4,
              selectInput(ns("area_unit_filter"), "Vahid:",
                choices = c("Hamısı" = ""), selected = "")
            ),
            column(4,
              selectInput(ns("area_category_filter"), "Kateqoriya:",
                choices = c("Hamısı" = "", ACTIVITY_CATEGORIES), selected = "")
            ),
            column(4,
              actionButton(ns("add_area_btn"), "Yeni Sahə",
                icon = icon("plus"), class = "btn-primary",
                style = "margin-top: 25px; width: 100%;")
            )
          ),
          DTOutput(ns("areas_table"))
        ),

        # KPI
        tabPanel(
          title = tagList(icon("chart-bar"), " KPI Göstəriciləri"),
          value = "kpi_tab",
          fluidRow(
            column(4,
              selectInput(ns("kpi_activity_filter"), "Fəaliyyət Sahəsi:",
                choices = c("Hamısı" = ""), selected = "")
            ),
            column(4,
              actionButton(ns("add_kpi_btn"), "Yeni KPI",
                icon = icon("plus"), class = "btn-primary",
                style = "margin-top: 25px;")
            ),
            column(4,
              actionButton(ns("add_progress_btn"), "İrəliləyiş Qeyd Et",
                icon = icon("chart-line"), class = "btn-success",
                style = "margin-top: 25px;")
            )
          ),
          DTOutput(ns("kpis_table")),
          tags$hr(),
          plotlyOutput(ns("kpi_completion_chart"), height = "300px")
        ),

        # Layihələr
        tabPanel(
          title = tagList(icon("project-diagram"), " Layihələr"),
          value = "projects_tab",
          fluidRow(
            column(3,
              selectInput(ns("proj_unit_filter"), "Vahid:",
                choices = c("Hamısı" = ""), selected = "")
            ),
            column(3,
              selectInput(ns("proj_status_filter"), "Status:",
                choices = c("Hamısı" = "", INST_PROJECT_STATUS), selected = "")
            ),
            column(3,
              selectInput(ns("proj_priority_filter"), "Prioritet:",
                choices = c("Hamısı" = "", PROJECT_PRIORITY), selected = "")
            ),
            column(3,
              actionButton(ns("add_project_btn"), "Yeni Layihə",
                icon = icon("plus"), class = "btn-primary",
                style = "margin-top: 25px; width: 100%;")
            )
          ),
          DTOutput(ns("projects_table"))
        ),

        # İrəliləyiş
        tabPanel(
          title = tagList(icon("clipboard-list"), " İrəliləyiş"),
          value = "progress_tab",
          fluidRow(
            column(6,
              selectInput(ns("prog_kpi_filter"), "KPI:",
                choices = c("Hamısı" = ""), selected = "")
            ),
            column(6,
              dateRangeInput(ns("prog_date_range"), "Tarix Aralığı:",
                start = Sys.Date() - 90, end = Sys.Date(),
                language = "az", separator = " - ")
            )
          ),
          DTOutput(ns("progress_table")),
          tags$hr(),
          plotlyOutput(ns("progress_trend_chart"), height = "300px")
        )
      )
    )
  )
}
