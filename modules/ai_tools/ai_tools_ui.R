# =============================================
# ARTI-2026: AI Alətləri — İstifadəçi İnterfeysi
# Gün 6: Sual Generatoru UI + Gün 9: Dərs Planı UI
# =============================================

# =============================================
# BÖLÜM 1: SUAL GENERATORU UI (Gün 6)
# =============================================
question_generator_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(
      column(12,
        h2(icon("robot"), "AI Sual Generatoru"),
        tags$p(class = "text-muted", "Süni intellekt vasitəsilə müxtəlif fənlər üzrə test sualları yaradın"),
        hr()
      )
    ),

    # Statistika paneli
    fluidRow(
      valueBoxOutput(ns("stat_total_generated"), width = 3),
      valueBoxOutput(ns("stat_success_rate"), width = 3),
      valueBoxOutput(ns("stat_total_tokens"), width = 3),
      valueBoxOutput(ns("stat_avg_time"), width = 3)
    ),

    fluidRow(
      # Sol panel — Parametrlər
      column(4,
        box(
          title = tagList(icon("cog"), " Generasiya Parametrləri"),
          status = "primary", solidHeader = TRUE, width = 12, collapsible = TRUE,

          fluidRow(
            column(6, selectInput(ns("qg_subject"), "Fənn:", choices = SUBJECTS)),
            column(6, selectInput(ns("qg_grade"), "Sinif:", choices = setNames(1:11, paste0(1:11, "-ci sinif"))))
          ),

          textInput(ns("qg_topic"), "Mövzu:", placeholder = "Məs: Tənliklər sistemi", width = "100%"),

          fluidRow(
            column(6, textInput(ns("qg_subtopic"), "Alt mövzu:", placeholder = "İsteğe bağlı")),
            column(6, textInput(ns("qg_standard"), "Standart kodu:", placeholder = "Məs: 3.2.1"))
          ),

          tags$hr(),

          fluidRow(
            column(6, selectInput(ns("qg_type"), "Sual tipi:", choices = QUESTION_TYPES)),
            column(6, numericInput(ns("qg_count"), "Sual sayı:", value = 5, min = 1, max = 30))
          ),

          fluidRow(
            column(6, selectInput(ns("qg_difficulty"), "Çətinlik:",
                                  choices = c("Qarışıq" = "mixed", DIFFICULTY_LEVELS))),
            column(6, selectInput(ns("qg_bloom"), "Bloom səviyyəsi:",
                                  choices = c("Qarışıq" = "mixed", setNames(BLOOM_LEVELS, BLOOM_LEVELS))))
          ),

          fluidRow(
            column(6, selectInput(ns("qg_dok"), "DOK səviyyəsi:",
                                  choices = c("Qarışıq" = "mixed", DOK_LEVELS))),
            column(6, selectInput(ns("qg_language"), "Dil:",
                                  choices = c("Azərbaycan" = "az", "İngilis" = "en", "Rus" = "ru")))
          ),

          tags$hr(),

          tags$h5("Əlavə Seçimlər"),
          checkboxInput(ns("qg_include_explanation"), "İzah əlavə et", value = TRUE),
          checkboxInput(ns("qg_include_bloom_tag"), "Bloom etiketləməsi", value = TRUE),
          checkboxInput(ns("qg_include_standard_code"), "Standart kodu əlaqələndir", value = FALSE),
          checkboxInput(ns("qg_include_time_estimate"), "Vaxt təxmini əlavə et", value = FALSE),

          textAreaInput(ns("qg_context"), "Əlavə kontekst:", rows = 3, width = "100%",
                        placeholder = "AI-yə əlavə təlimatlar (isteğe bağlı)"),

          tags$hr(),

          fluidRow(
            column(6, selectInput(ns("qg_provider"), "AI Provayder:",
                                  choices = c("Avtomatik (Router)" = "auto",
                                              "Claude" = "claude", "GPT" = "gpt"))),
            column(6, sliderInput(ns("qg_temperature"), "Kreativlik:",
                                  min = 0.1, max = 1.0, value = 0.8, step = 0.1))
          ),

          tags$div(
            style = "margin-top: 10px;",
            actionButton(ns("btn_qg_generate"), "Sualları Yarat",
                         icon = icon("magic"), class = "btn-success btn-lg btn-block"),
            tags$br(),
            actionButton(ns("btn_qg_clear"), "Təmizlə",
                         icon = icon("eraser"), class = "btn-default btn-sm", style = "margin-top:8px;")
          )
        )
      ),

      # Sağ panel — Nəticələr
      column(8,
        box(
          title = tagList(icon("list-check"), " Yaradılmış Suallar"),
          status = "success", solidHeader = TRUE, width = 12,

          uiOutput(ns("qg_status_message")),
          uiOutput(ns("qg_results_ui")),

          conditionalPanel(
            condition = paste0("output['", ns("qg_has_results"), "'] == true"),
            tags$hr(),
            fluidRow(
              column(3, actionButton(ns("btn_qg_save_bank"), "Sual Bankına Saxla",
                                     icon = icon("database"), class = "btn-primary btn-block")),
              column(3, downloadButton(ns("btn_qg_export_txt"), "TXT Yüklə", class = "btn-info btn-block")),
              column(3, downloadButton(ns("btn_qg_export_word"), "Word Yüklə", class = "btn-warning btn-block")),
              column(3, actionButton(ns("btn_qg_regenerate"), "Yenidən Yarat",
                                     icon = icon("sync"), class = "btn-default btn-block"))
            )
          )
        ),

        box(
          title = tagList(icon("history"), " Son Generasiyalar"),
          status = "info", solidHeader = TRUE, width = 12, collapsible = TRUE, collapsed = TRUE,
          DTOutput(ns("qg_history_table"))
        )
      )
    )
  )
}

# =============================================
# BÖLÜM 2: DƏRS PLANI GENERATORU UI (Gün 9)
# =============================================
lesson_plan_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(
      column(12,
        h2(icon("chalkboard"), "AI Dərs Planı Generatoru"),
        tags$p(class = "text-muted", "Süni intellekt vasitəsilə hərtərəfli dərs planları yaradın"),
        hr()
      )
    ),

    fluidRow(
      valueBoxOutput(ns("lp_stat_total"), width = 3),
      valueBoxOutput(ns("lp_stat_subjects"), width = 3),
      valueBoxOutput(ns("lp_stat_tokens"), width = 3),
      valueBoxOutput(ns("lp_stat_cost"), width = 3)
    ),

    fluidRow(
      # Sol panel — Parametrlər
      column(4,
        box(
          title = tagList(icon("cog"), " Dərs Parametrləri"),
          status = "primary", solidHeader = TRUE, width = 12, collapsible = TRUE,

          fluidRow(
            column(6, selectInput(ns("lp_subject"), "Fənn:", choices = SUBJECTS)),
            column(6, selectInput(ns("lp_grade"), "Sinif:", choices = setNames(1:11, paste0(1:11, "-ci sinif"))))
          ),

          textInput(ns("lp_topic"), "Mövzu:", placeholder = "Dərs mövzusu", width = "100%"),
          textAreaInput(ns("lp_objectives"), "Dərsin məqsədi:", rows = 2, width = "100%",
                        placeholder = "Əsas öyrənmə məqsədlərini yazın"),

          tags$hr(),

          fluidRow(
            column(6, selectInput(ns("lp_duration"), "Müddət:", choices = LESSON_DURATIONS)),
            column(6, selectInput(ns("lp_method"), "Tədris metodu:", choices = TEACHING_METHODS))
          ),

          fluidRow(
            column(6, numericInput(ns("lp_student_count"), "Şagird sayı:", value = 25, min = 5, max = 45)),
            column(6, selectInput(ns("lp_level"), "Sinif səviyyəsi:",
                                  choices = c("Yüksək" = "high", "Orta" = "medium", "Aşağı" = "low", "Qarışıq" = "mixed")))
          ),

          tags$hr(),

          tags$h5("Daxil ediləcək bölmələr"),
          checkboxInput(ns("lp_inc_outcomes"), "Öyrənmə nəticələri", value = TRUE),
          checkboxInput(ns("lp_inc_stages"), "Dərs mərhələləri", value = TRUE),
          checkboxInput(ns("lp_inc_differentiation"), "Fərqləndirmə strategiyaları", value = TRUE),
          checkboxInput(ns("lp_inc_assessment"), "Qiymətləndirmə tapşırıqları", value = TRUE),
          checkboxInput(ns("lp_inc_homework"), "Ev tapşırığı", value = TRUE),
          checkboxInput(ns("lp_inc_materials"), "Lazım olan materiallar", value = TRUE),
          checkboxInput(ns("lp_inc_ict"), "İKT inteqrasiyası", value = FALSE),

          textAreaInput(ns("lp_context"), "Əlavə kontekst:", rows = 3, width = "100%",
                        placeholder = "Xüsusi tələblər, şagird ehtiyacları..."),

          tags$hr(),

          fluidRow(
            column(6, selectInput(ns("lp_provider"), "AI Provayder:",
                                  choices = c("Avtomatik" = "auto", "Claude" = "claude", "GPT" = "gpt"))),
            column(6, sliderInput(ns("lp_temperature"), "Kreativlik:",
                                  min = 0.1, max = 1.0, value = 0.6, step = 0.1))
          ),

          tags$div(
            style = "margin-top: 10px;",
            actionButton(ns("btn_lp_generate"), "Dərs Planı Yarat",
                         icon = icon("magic"), class = "btn-success btn-lg btn-block"),
            tags$br(),
            actionButton(ns("btn_lp_clear"), "Təmizlə",
                         icon = icon("eraser"), class = "btn-default btn-sm", style = "margin-top:8px;")
          )
        )
      ),

      # Sağ panel — Nəticə
      column(8,
        box(
          title = tagList(icon("file-alt"), " Dərs Planı"),
          status = "success", solidHeader = TRUE, width = 12,

          uiOutput(ns("lp_status_message")),
          uiOutput(ns("lp_results_ui")),

          conditionalPanel(
            condition = paste0("output['", ns("lp_has_results"), "'] == true"),
            tags$hr(),
            fluidRow(
              column(3, downloadButton(ns("btn_lp_export_txt"), "TXT Yüklə", class = "btn-info btn-block")),
              column(3, downloadButton(ns("btn_lp_export_word"), "Word Yüklə", class = "btn-warning btn-block")),
              column(3, actionButton(ns("btn_lp_save_db"), "DB-yə Saxla",
                                     icon = icon("database"), class = "btn-primary btn-block")),
              column(3, actionButton(ns("btn_lp_regenerate"), "Yenidən Yarat",
                                     icon = icon("sync"), class = "btn-default btn-block"))
            )
          )
        ),

        box(
          title = tagList(icon("history"), " Son Dərs Planları"),
          status = "info", solidHeader = TRUE, width = 12, collapsible = TRUE, collapsed = TRUE,
          DTOutput(ns("lp_history_table"))
        )
      )
    )
  )
}
