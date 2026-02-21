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

# === 4. AI Tədqiqat Asistenti UI ===
research_ai_assistant_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(column(12, h2(icon("robot"), "AI Tədqiqat Asistenti"), hr())),

    # Əsas parametrlər
    fluidRow(
      column(4,
        wellPanel(
          h4(icon("question-circle"), "Tədqiqat Sualı"),
          textAreaInput(ns("research_question"), NULL, rows = 4, width = "100%",
                        placeholder = "Tədqiqat sualınızı daxil edin..."),
          fluidRow(
            column(6, selectInput(ns("research_field"), "Sahə:",
              choices = c("Təhsil" = "education", "Pedaqogika" = "pedagogy",
                          "Psixologiya" = "psychology", "Kurikulum" = "curriculum",
                          "Qiymətləndirmə" = "assessment", "Təhsil Texnologiyası" = "edtech",
                          "Xüsusi Təhsil" = "special_education",
                          "Təhsil İdarəetməsi" = "education_management",
                          "Digər" = "other"))),
            column(6, selectInput(ns("citation_format"), "İstinad Formatı:",
              choices = c("APA (7-ci nəşr)" = "apa", "Harvard" = "harvard",
                          "Vancouver" = "vancouver", "Chicago" = "chicago")))
          ),
          selectInput(ns("linked_project"), "Əlaqəli Layihə:", choices = c("Yoxdur" = "")),
          selectInput(ns("research_type_ai"), "Tədqiqat Növü:",
            choices = c("Tətbiqi" = "tetbiqi", "Fundamental" = "fundamental",
                        "Siyasət Analizi" = "siyaset_analizi"))
        )
      ),

      # Addımlı proses düymələri
      column(8,
        wellPanel(
          h4(icon("list-ol"), "Tədqiqat Addımları"),
          fluidRow(
            column(3,
              actionButton(ns("btn_literature"), "1. Ədəbiyyat Axtarışı",
                icon = icon("search"), class = "btn-primary btn-block",
                style = "margin-bottom: 10px;"),
              tags$small(class = "text-muted", "AI müvafiq mənbələri tapır")
            ),
            column(3,
              actionButton(ns("btn_methodology"), "2. Metodologiya",
                icon = icon("sitemap"), class = "btn-success btn-block",
                style = "margin-bottom: 10px;"),
              tags$small(class = "text-muted", "Tədqiqat dizaynı tövsiyəsi")
            ),
            column(3,
              actionButton(ns("btn_analysis_plan"), "3. Analiz Planı",
                icon = icon("calculator"), class = "btn-warning btn-block",
                style = "margin-bottom: 10px;"),
              tags$small(class = "text-muted", "Statistik testlər və hipotezlər")
            ),
            column(3,
              actionButton(ns("btn_results_draft"), "4. Nəticə Qaralama",
                icon = icon("file-alt"), class = "btn-info btn-block",
                style = "margin-bottom: 10px;"),
              tags$small(class = "text-muted", "Akademik nəticə bölməsi")
            )
          ),
          tags$hr(),
          fluidRow(
            column(6,
              actionButton(ns("btn_full_pipeline"), "Tam Proses (1-4 Hamısı)",
                icon = icon("rocket"), class = "btn-danger btn-lg",
                style = "width: 100%;")
            ),
            column(3,
              actionButton(ns("btn_save_session"), "Sessiyanı Saxla",
                icon = icon("save"), class = "btn-default btn-block",
                style = "margin-top: 5px;")
            ),
            column(3,
              actionButton(ns("btn_clear_results"), "Təmizlə",
                icon = icon("eraser"), class = "btn-default btn-block",
                style = "margin-top: 5px;")
            )
          )
        ),

        # Token statistikası
        fluidRow(
          column(4, valueBoxOutput(ns("vb_tokens_used"), width = 12)),
          column(4, valueBoxOutput(ns("vb_sources_found"), width = 12)),
          column(4, valueBoxOutput(ns("vb_session_count"), width = 12))
        )
      )
    ),

    # Nəticə tabları
    fluidRow(column(12,
      tabsetPanel(id = ns("results_tabs"), type = "tabs",
        # Tab 1: Ədəbiyyat İcmalı
        tabPanel("Ədəbiyyat İcmalı", icon = icon("book"),
          br(),
          uiOutput(ns("literature_summary_ui")),
          br(),
          wellPanel(
            h4(icon("list"), "Tapılan Mənbələr"),
            DTOutput(ns("literature_table")),
            br(),
            div(class = "btn-toolbar",
              actionButton(ns("btn_export_citations_apa"), "APA İxrac", icon = icon("download"), class = "btn-default"),
              actionButton(ns("btn_export_citations_harvard"), "Harvard İxrac", icon = icon("download"), class = "btn-default"),
              actionButton(ns("btn_save_literature_db"), "Mənbələri DB-yə Saxla", icon = icon("database"), class = "btn-info")
            )
          ),
          wellPanel(
            h4(icon("lightbulb"), "Təklif Edilən Axtarış Terminləri"),
            uiOutput(ns("search_terms_ui"))
          )
        ),

        # Tab 2: Metodologiya
        tabPanel("Metodologiya", icon = icon("sitemap"),
          br(),
          fluidRow(
            column(6, wellPanel(
              h4(icon("compass"), "Tədqiqat Dizaynı"),
              uiOutput(ns("design_ui"))
            )),
            column(6, wellPanel(
              h4(icon("flask"), "Əsas Metodologiya"),
              uiOutput(ns("method_ui"))
            ))
          ),
          fluidRow(
            column(6, wellPanel(
              h4(icon("users"), "Seçmə Strategiyası"),
              uiOutput(ns("sampling_ui"))
            )),
            column(6, wellPanel(
              h4(icon("tools"), "Məlumat Toplama Alətləri"),
              uiOutput(ns("data_collection_ui"))
            ))
          ),
          fluidRow(
            column(6, wellPanel(
              h4(icon("shield-alt"), "Etik Məsələlər"),
              uiOutput(ns("ethics_ui"))
            )),
            column(6, wellPanel(
              h4(icon("exchange-alt"), "Alternativ Metodlar"),
              uiOutput(ns("alternatives_ui"))
            ))
          )
        ),

        # Tab 3: Analiz Planı
        tabPanel("Analiz Planı", icon = icon("calculator"),
          br(),
          fluidRow(
            column(12,
              textAreaInput(ns("variables_input"), "Dəyişənlər (əlavə kontekst):",
                rows = 2, width = "100%",
                placeholder = "Asılı dəyişən: şagird nailiyyəti; Asılı olmayan: tədris metodu..."),
              textInput(ns("sample_size_input"), "Seçmə həcmi:",
                placeholder = "məs: 200 şagird, 10 məktəb")
            )
          ),
          fluidRow(
            column(6, wellPanel(
              h4(icon("bullseye"), "Hipotezlər"),
              uiOutput(ns("hypotheses_ui"))
            )),
            column(6, wellPanel(
              h4(icon("chart-bar"), "Dəyişənlər"),
              uiOutput(ns("variables_ui"))
            ))
          ),
          fluidRow(
            column(12, wellPanel(
              h4(icon("vial"), "Statistik Testlər"),
              DTOutput(ns("stat_tests_table"))
            ))
          ),
          fluidRow(
            column(6, wellPanel(
              h4(icon("bolt"), "Güc Analizi"),
              uiOutput(ns("power_analysis_ui"))
            )),
            column(6, wellPanel(
              h4(icon("broom"), "Məlumat Yoxlaması"),
              uiOutput(ns("data_screening_ui"))
            ))
          ),
          fluidRow(
            column(12, wellPanel(
              h4(icon("code"), "R Kod Nümunələri"),
              verbatimTextOutput(ns("r_code_output"))
            ))
          )
        ),

        # Tab 4: Nəticə Qaralama
        tabPanel("Nəticə Qaralama", icon = icon("file-alt"),
          br(),
          fluidRow(
            column(12,
              textAreaInput(ns("data_context_input"), "Əlavə Məlumat Konteksti:",
                rows = 2, width = "100%",
                placeholder = "Hipotetik və ya real məlumatlar haqqında əlavə kontekst..."))
          ),
          fluidRow(
            column(8, wellPanel(
              div(style = "display:flex; align-items:center; justify-content:space-between;",
                h4(icon("file-alt"), "Nəticə Bölməsi"),
                downloadButton(ns("btn_download_results"), "Word/TXT Yüklə", class = "btn-default btn-sm")
              ),
              uiOutput(ns("results_text_ui"))
            )),
            column(4,
              wellPanel(
                h4(icon("table"), "Təklif Edilən Cədvəllər"),
                uiOutput(ns("tables_ui"))
              ),
              wellPanel(
                h4(icon("chart-area"), "Təklif Edilən Qrafiklər"),
                uiOutput(ns("figures_ui"))
              )
            )
          ),
          fluidRow(
            column(6, wellPanel(
              h4(icon("comments"), "Müzakirə Nöqtələri"),
              uiOutput(ns("discussion_points_ui"))
            )),
            column(6, wellPanel(
              h4(icon("forward"), "Gələcək Tədqiqat Təklifləri"),
              uiOutput(ns("future_suggestions_ui"))
            ))
          )
        ),

        # Tab 5: Tarixçə
        tabPanel("Tarixçə", icon = icon("history"),
          br(),
          fluidRow(
            column(3, selectInput(ns("hist_field"), "Sahə:",
              choices = c("Hamısı" = "", "Təhsil" = "education", "Pedaqogika" = "pedagogy",
                          "Psixologiya" = "psychology", "Kurikulum" = "curriculum",
                          "Qiymətləndirmə" = "assessment"))),
            column(3, selectInput(ns("hist_type"), "Növ:",
              choices = c("Hamısı" = "", "Ədəbiyyat" = "literature_review",
                          "Metodologiya" = "methodology", "Analiz Planı" = "analysis_plan",
                          "Nəticə Qaralama" = "results_draft", "Tam Proses" = "full_pipeline"))),
            column(3, actionButton(ns("btn_hist_refresh"), "Yenilə",
              icon = icon("sync"), class = "btn-info", style = "margin-top:25px;")),
            column(3, downloadButton(ns("btn_hist_export"), "Excel İxrac",
              class = "btn-success", style = "margin-top:25px;"))
          ),
          DTOutput(ns("history_table")),
          br(),
          uiOutput(ns("selected_session_detail"))
        )
      )
    ))
  )
}
