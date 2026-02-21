# =============================================
# ARTI-2026: Strategiya Modulu — UI Komponentləri
# =============================================

# === 1. SWOT Analiz UI ===
strategy_swot_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(column(12, h2(icon("chess-king"), "Strateji SWOT Analiz"), hr())),

    # Parametrlər
    fluidRow(
      column(3, selectInput(ns("school_filter"), "Məktəb:", choices = c("Bütün məktəblər" = ""))),
      column(2, selectInput(ns("academic_year"), "Tədris ili:",
        choices = c("2025-2026", "2024-2025"), selected = "2025-2026")),
      column(2, selectInput(ns("report_type"), "Hesabat növü:", choices = c(
        "SWOT Analiz" = "swot",
        "Resurs Bölgüsü" = "resource_allocation",
        "Müəllim Optimallaşdırma" = "teacher_optimization"
      ))),
      column(3, div(style = "margin-top:25px",
        actionButton(ns("btn_generate"), "AI Analiz Yarat", icon = icon("magic"), class = "btn-success btn-lg"),
        downloadButton(ns("btn_export"), "Excel", class = "btn-info")
      ))
    ),

    # Ümumi statistika
    fluidRow(
      column(3, valueBoxOutput(ns("vb_schools"), width = 12)),
      column(3, valueBoxOutput(ns("vb_students"), width = 12)),
      column(3, valueBoxOutput(ns("vb_teachers"), width = 12)),
      column(3, valueBoxOutput(ns("vb_avg_score"), width = 12))
    ),

    # Məktəb müqayisə cədvəli
    fluidRow(column(12, wellPanel(
      h4(icon("table"), "Məktəb Müqayisə Cədvəli"),
      DTOutput(ns("schools_table"))
    ))),

    # SWOT nəticəsi
    uiOutput(ns("swot_result_ui")),

    # Resurs tövsiyələri
    uiOutput(ns("resource_recommendations_ui")),

    # Müəllim optimallaşdırma
    uiOutput(ns("teacher_optimization_ui")),

    # Büdcə prioritetləri
    uiOutput(ns("budget_priorities_ui")),

    # Keçmiş hesabatlar
    fluidRow(column(12, wellPanel(
      h4(icon("history"), "Keçmiş Hesabatlar"),
      DTOutput(ns("reports_history"))
    )))
  )
}

# === 2. Resurs Bölgüsü UI ===
strategy_resources_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(column(12, h2(icon("balance-scale"), "Resurs Bölgüsü Analizi"), hr())),

    # Müəllim-şagird nisbəti
    fluidRow(
      column(6, wellPanel(
        h4(icon("users"), "Müəllim-Şagird Nisbəti (Məktəb üzrə)"),
        plotlyOutput(ns("ratio_chart"), height = "400px")
      )),
      column(6, wellPanel(
        h4(icon("chart-bar"), "Müəllim Kateqoriya Paylanması"),
        plotlyOutput(ns("category_chart"), height = "400px")
      ))
    ),

    # Fənn əhatəsi
    fluidRow(column(12, wellPanel(
      h4(icon("book"), "Fənn Əhatə Matrisi"),
      helpText("Hər məktəbdə hər fənn üzrə müəllim sayı / sinif sayı nisbəti"),
      DTOutput(ns("coverage_table"))
    ))),

    # TALIS müqayisəsi
    fluidRow(column(12, wellPanel(
      h4(icon("chart-line"), "TALIS Göstəriciləri (Məktəb üzrə)"),
      plotlyOutput(ns("talis_heatmap"), height = "400px")
    ))),

    # Performans trendi
    fluidRow(column(12, wellPanel(
      h4(icon("chart-area"), "Performans Trendi (Son 6 Ay)"),
      plotlyOutput(ns("trend_chart"), height = "350px")
    )))
  )
}

# === 3. What-If Scenari UI ===
strategy_whatif_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(column(12, h2(icon("random"), "\"Əgər... Olsa\" Scenari Analizi"), hr())),

    # Scenari parametrləri
    fluidRow(
      column(4, wellPanel(
        h4(icon("cogs"), "Scenari Parametrləri"),

        selectInput(ns("scenario_type"), "Scenari növü:", choices = c(
          "Müəllim İşə Qəbulu" = "teacher_hire",
          "Büdcə Dəyişikliyi" = "budget_change",
          "Sinif Yenidənqurma" = "class_restructure",
          "Resurs Yenidən Bölgüsü" = "resource_realloc",
          "Siyasət Dəyişikliyi" = "policy_change",
          "Xüsusi Scenari" = "custom"
        )),

        selectInput(ns("scenario_school"), "Hədəf məktəb:", choices = c("Bütün məktəblər" = "")),

        # Dinamik parametrlər
        conditionalPanel(
          condition = sprintf("input['%s'] == 'teacher_hire'", ns("scenario_type")),
          numericInput(ns("param_teacher_count"), "Yeni müəllim sayı:", value = 5, min = 1, max = 50),
          selectInput(ns("param_teacher_subject"), "Fənn:", choices = c("Bütün fənlər" = "", SUBJECTS))
        ),

        conditionalPanel(
          condition = sprintf("input['%s'] == 'budget_change'", ns("scenario_type")),
          numericInput(ns("param_budget_pct"), "Büdcə dəyişikliyi (%):", value = 10, min = -50, max = 100),
          selectInput(ns("param_budget_area"), "Sahə:", choices = c(
            "Ümumi" = "general", "İKT" = "ict", "Təlim" = "training",
            "İnfrastruktur" = "infrastructure", "Əmək haqqı" = "salary"))
        ),

        conditionalPanel(
          condition = sprintf("input['%s'] == 'class_restructure'", ns("scenario_type")),
          numericInput(ns("param_max_class_size"), "Maks sinif ölçüsü:", value = 25, min = 15, max = 40),
          numericInput(ns("param_min_class_size"), "Min sinif ölçüsü:", value = 15, min = 5, max = 30)
        ),

        textAreaInput(ns("scenario_desc"), "Scenari təsviri:", rows = 4,
                      placeholder = "Scenarini ətraflı təsvir edin..."),

        actionButton(ns("btn_run_scenario"), "Scenarini İşlət", icon = icon("play"), class = "btn-primary btn-block"),
        hr(),
        tags$small(class = "text-muted", "AI scenarini modelləşdirib nəticələri proqnozlaşdırır")
      )),

      # Nəticə paneli
      column(8,
        # Əsas göstəricilər
        uiOutput(ns("scenario_summary_ui")),

        # Təsirlər (qısa/orta/uzun müddət)
        uiOutput(ns("scenario_impacts_ui")),

        # Büdcə təsiri
        uiOutput(ns("scenario_budget_ui")),

        # Risklər
        uiOutput(ns("scenario_risks_ui")),

        # Alternativlər
        uiOutput(ns("scenario_alternatives_ui"))
      )
    ),

    # Scenari tarixçəsi
    fluidRow(column(12, wellPanel(
      h4(icon("history"), "Scenari Tarixçəsi"),
      DTOutput(ns("scenario_history"))
    )))
  )
}

# === 4. Beynəlxalq Benchmark UI ===
strategy_benchmark_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(column(12, h2(icon("globe"), "Beynəlxalq Benchmark Müqayisəsi"), hr())),

    # Ölkə seçimi
    fluidRow(
      column(6, checkboxGroupInput(ns("selected_countries"), "Ölkələr:",
        choices = COMPARISON_COUNTRIES, selected = COMPARISON_COUNTRIES, inline = TRUE)),
      column(3, selectInput(ns("benchmark_type"), "Göstərici növü:", choices = c(
        "PISA Balları" = "pisa",
        "TALIS Göstəriciləri" = "talis"
      ))),
      column(3, div(style = "margin-top:25px",
        actionButton(ns("btn_refresh"), "Yenilə", icon = icon("sync"), class = "btn-info")))
    ),

    # PISA müqayisəsi
    conditionalPanel(
      condition = sprintf("input['%s'] == 'pisa'", ns("benchmark_type")),
      fluidRow(
        column(6, wellPanel(
          h4(icon("chart-bar"), "PISA Balları Müqayisəsi"),
          plotlyOutput(ns("pisa_bar_chart"), height = "400px")
        )),
        column(6, wellPanel(
          h4(icon("chart-line"), "PISA Radar Qrafiki"),
          plotlyOutput(ns("pisa_radar_chart"), height = "400px")
        ))
      ),
      fluidRow(column(12, wellPanel(
        h4(icon("table"), "PISA Detallı Cədvəl"),
        DTOutput(ns("pisa_table"))
      )))
    ),

    # TALIS müqayisəsi
    conditionalPanel(
      condition = sprintf("input['%s'] == 'talis'", ns("benchmark_type")),
      fluidRow(
        column(6, wellPanel(
          h4(icon("chart-bar"), "TALIS Göstəriciləri Müqayisəsi"),
          plotlyOutput(ns("talis_bar_chart"), height = "400px")
        )),
        column(6, wellPanel(
          h4(icon("chart-line"), "TALIS Radar Qrafiki"),
          plotlyOutput(ns("talis_radar_chart"), height = "400px")
        ))
      ),
      fluidRow(column(12, wellPanel(
        h4(icon("table"), "TALIS Detallı Cədvəl"),
        DTOutput(ns("talis_table"))
      )))
    ),

    # Boşluq analizi
    fluidRow(column(12, wellPanel(
      h4(icon("exclamation-triangle"), "OECD Boşluq Analizi"),
      helpText("Azərbaycanın OECD ortalamasına nisbətən vəziyyəti"),
      plotlyOutput(ns("gap_chart"), height = "350px")
    ))),

    # Benchmark datası idarəetmə
    fluidRow(column(12, wellPanel(
      h4(icon("database"), "Benchmark Datası"),
      fluidRow(
        column(2, textInput(ns("bm_country"), "Ölkə:")),
        column(2, textInput(ns("bm_indicator"), "Göstərici:")),
        column(2, selectInput(ns("bm_category"), "Kateqoriya:", choices = c(
          "PISA" = "pisa", "TALIS" = "talis", "Təhsil Sistemi" = "education_system",
          "Resurs" = "resource", "Nəticə" = "outcome"))),
        column(1, numericInput(ns("bm_value"), "Dəyər:", value = 0)),
        column(1, numericInput(ns("bm_year"), "İl:", value = 2022, min = 2000, max = 2030)),
        column(2, textInput(ns("bm_source"), "Mənbə:")),
        column(2, div(style = "margin-top:25px",
          actionButton(ns("btn_add_benchmark"), "Əlavə Et", icon = icon("plus"), class = "btn-success btn-sm")))
      ),
      DTOutput(ns("benchmark_db_table"))
    )))
  )
}
