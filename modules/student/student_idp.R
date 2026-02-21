# =============================================
# ARTI-2026: Fərdi İnkişaf Planı (FİP) Modulu
# AI əsaslı tam fərdi inkişaf planı sistemi
# =============================================

# =============================================
# HELPERS (~200 sətir)
# =============================================

#' Şagird akademik məlumatlarını topla
#' @param db_pool DB bağlantı pool-u
#' @param student_id Şagird UUID
#' @param academic_year Tədris ili (məs: "2025-2026")
#' @return list: info, grades, theta, attendance
collect_student_academic_data <- function(db_pool, student_id, academic_year) {
  # Şagird əsas info
  student <- db_get_one(db_pool,
    "SELECT s.id, s.first_name, s.last_name, s.first_name || ' ' || s.last_name as full_name,
            c.grade as class_grade, c.section as class_section
     FROM students s
     LEFT JOIN classes c ON s.class_id = c.id
     WHERE s.id = $1",
    params = list(student_id))

  # Fənn üzrə orta bal, min, max, grade_count
  grades <- tryCatch(
    db_query(db_pool,
      "SELECT sub.id as subject_id, sub.name as subject_name,
              AVG(g.score) as avg_score, MIN(g.score) as min_score,
              MAX(g.score) as max_score, COUNT(g.id) as grade_count,
              ARRAY_AGG(g.score ORDER BY g.created_at) as scores,
              ARRAY_AGG(EXTRACT(EPOCH FROM g.created_at) ORDER BY g.created_at) as timestamps
       FROM grades g
       JOIN subjects sub ON g.subject_id = sub.id
       WHERE g.student_id = $1 AND g.academic_year = $2
       GROUP BY sub.id, sub.name
       ORDER BY sub.name",
      params = list(student_id, academic_year)),
    error = function(e) data.frame()
  )

  # Trend hesabla — hər fənn üçün lm(score ~ day_num) slope
  if (nrow(grades) > 0) {
    grades$trend_direction <- "stable"
    grades$trend_slope <- 0
    for (i in seq_len(nrow(grades))) {
      scores_str <- grades$scores[i]
      if (is.character(scores_str)) {
        scores <- as.numeric(unlist(strsplit(gsub("[{}]", "", scores_str), ",")))
      } else if (is.list(scores_str)) {
        scores <- as.numeric(unlist(scores_str))
      } else {
        scores <- as.numeric(scores_str)
      }
      if (length(scores) >= 3) {
        day_num <- seq_along(scores)
        fit <- tryCatch(lm(scores ~ day_num), error = function(e) NULL)
        if (!is.null(fit)) {
          slope <- coef(fit)[2]
          grades$trend_slope[i] <- round(slope, 4)
          if (slope > 0.5) grades$trend_direction[i] <- "up"
          else if (slope < -0.5) grades$trend_direction[i] <- "down"
          else grades$trend_direction[i] <- "stable"
        }
      }
    }
  }

  # IRT theta — son tamamlanmış test sessiyası
  theta_data <- tryCatch(
    db_query(db_pool,
      "SELECT ts.theta_estimate, ts.se_estimate, sub.name as subject_name, sub.id as subject_id
       FROM test_sessions ts
       JOIN tests t ON ts.test_id = t.id
       JOIN subjects sub ON t.subject_id = sub.id
       WHERE ts.student_id = $1 AND ts.status = 'completed'
             AND ts.theta_estimate IS NOT NULL
       ORDER BY ts.end_time DESC",
      params = list(student_id)),
    error = function(e) data.frame()
  )

  # Davamiyyət faizi
  attendance <- tryCatch(
    db_get_one(db_pool,
      "SELECT COUNT(*) as total,
              SUM(CASE WHEN status = 'present' THEN 1 ELSE 0 END) as present_count
       FROM attendance
       WHERE student_id = $1
             AND date >= (CASE WHEN SUBSTRING($2, 1, 4)::int < SUBSTRING($2, 6, 4)::int
                               THEN (SUBSTRING($2, 1, 4) || '-09-01')::date
                               ELSE (SUBSTRING($2, 1, 4) || '-09-01')::date END)",
      params = list(student_id, academic_year)),
    error = function(e) list(total = 0, present_count = 0)
  )

  att_rate <- if (!is.null(attendance) && attendance$total > 0) {
    round(attendance$present_count / attendance$total * 100, 1)
  } else 0

  list(
    student = student,
    grades = grades,
    theta = theta_data,
    attendance_rate = att_rate,
    attendance = attendance
  )
}

#' Bacarıq profilini hesabla və cache-ə yaz
#' @return data.frame: subject_name, avg_score, theta, trend, level
compute_ability_profile <- function(db_pool, student_id, academic_year) {
  data <- collect_student_academic_data(db_pool, student_id, academic_year)
  grades <- data$grades
  theta_data <- data$theta

  if (nrow(grades) == 0) return(data.frame())

  profiles <- data.frame(
    subject_id = grades$subject_id,
    subject_name = grades$subject_name,
    avg_score = round(as.numeric(grades$avg_score), 2),
    min_score = round(as.numeric(grades$min_score), 2),
    max_score = round(as.numeric(grades$max_score), 2),
    grade_count = as.integer(grades$grade_count),
    trend_direction = grades$trend_direction,
    trend_slope = grades$trend_slope,
    theta_estimate = NA_real_,
    theta_se = NA_real_,
    ability_level = "",
    stringsAsFactors = FALSE
  )

  # Theta birləşdir
  if (nrow(theta_data) > 0) {
    for (i in seq_len(nrow(profiles))) {
      theta_match <- theta_data[theta_data$subject_id == profiles$subject_id[i], ]
      if (nrow(theta_match) > 0) {
        profiles$theta_estimate[i] <- theta_match$theta_estimate[1]
        profiles$theta_se[i] <- theta_match$se_estimate[1]
      }
    }
  }

  # Ability level
  profiles$ability_level <- sapply(profiles$avg_score, function(s) {
    if (is.na(s)) return("qeyri-kafi")
    if (s >= 86) return("əla")
    if (s >= 71) return("yaxşı")
    if (s >= 51) return("kafi")
    return("qeyri-kafi")
  })

  # UPSERT idp_ability_profiles
  for (i in seq_len(nrow(profiles))) {
    tryCatch(
      db_execute(db_pool,
        "INSERT INTO idp_ability_profiles
         (student_id, subject_id, subject_name, academic_year, avg_score, min_score, max_score,
          grade_count, theta_estimate, theta_se, trend_direction, trend_slope, ability_level,
          attendance_rate, updated_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, NOW())
         ON CONFLICT (student_id, subject_id, academic_year) DO UPDATE SET
           avg_score = EXCLUDED.avg_score, min_score = EXCLUDED.min_score,
           max_score = EXCLUDED.max_score, grade_count = EXCLUDED.grade_count,
           theta_estimate = EXCLUDED.theta_estimate, theta_se = EXCLUDED.theta_se,
           trend_direction = EXCLUDED.trend_direction, trend_slope = EXCLUDED.trend_slope,
           ability_level = EXCLUDED.ability_level, attendance_rate = EXCLUDED.attendance_rate,
           updated_at = NOW()",
        params = list(
          student_id, profiles$subject_id[i], profiles$subject_name[i], academic_year,
          as.numeric(profiles$avg_score[i])[1],
          as.numeric(profiles$min_score[i])[1],
          as.numeric(profiles$max_score[i])[1],
          as.integer(profiles$grade_count[i])[1],
          if (is.na(profiles$theta_estimate[i])) NA_real_ else as.numeric(profiles$theta_estimate[i])[1],
          if (is.na(profiles$theta_se[i])) NA_real_ else as.numeric(profiles$theta_se[i])[1],
          as.character(profiles$trend_direction[i])[1],
          as.numeric(profiles$trend_slope[i])[1],
          as.character(profiles$ability_level[i])[1],
          as.numeric(data$attendance_rate)[1]
        )),
      error = function(e) logger::log_error("Ability profile UPSERT xətası: {e$message}")
    )
  }

  profiles
}

#' AI prompt quruculuğu
build_idp_ai_prompt <- function(data, profiles) {
  student <- data$student
  att_rate <- data$attendance_rate

  # Fənn nəticələri
  subject_lines <- sapply(seq_len(nrow(profiles)), function(i) {
    p <- profiles[i, ]
    theta_str <- if (!is.na(p$theta_estimate)) sprintf(", IRT theta: %.2f (SE: %.2f)", p$theta_estimate, p$theta_se) else ""
    trend_icon <- switch(p$trend_direction, up = "yuxari", down = "asagi", "sabit")
    sprintf("- %s: orta bal %.1f, min %.1f, max %.1f, %d qiymət, trend: %s%s",
            p$subject_name, p$avg_score, p$min_score, p$max_score, p$grade_count, trend_icon, theta_str)
  })

  # Güclü/zəif fənlər
  strong <- profiles[profiles$avg_score >= 71, "subject_name"]
  weak <- profiles[profiles$avg_score < 51, "subject_name"]
  medium <- profiles[profiles$avg_score >= 51 & profiles$avg_score < 71, "subject_name"]

  system_prompt <- paste0(
    "Sən Azərbaycan təhsil sistemi üzrə mütəxəssis pedaqoqsan. ",
    "Azərbaycan qiymət şkalası: 86-100=Əla, 71-85=Yaxşı, 51-70=Kafi, 0-50=Qeyri-kafi. ",
    "IRT theta: 0 orta səviyyə, +2 çox yüksək, -2 çox aşağı. ",
    "Cavabını YALNIZ JSON formatında ver, heç bir əlavə mətn olmasın. ",
    "Azərbaycan dilində yaz. Həftəlik tapşırıqlar 4 həftəlik olsun."
  )

  user_prompt <- paste0(
    "Bu şagird üçün fərdi inkişaf planı hazırla:\n\n",
    "Ad: ", student$full_name, "\n",
    "Sinif: ", student$class_grade, "-", student$class_section, "\n",
    "Davamiyyət: ", att_rate, "%\n\n",
    "Fənn nəticələri:\n", paste(subject_lines, collapse = "\n"), "\n\n",
    if (length(strong) > 0) paste0("Güclü fənlər: ", paste(strong, collapse = ", "), "\n") else "",
    if (length(weak) > 0) paste0("Zəif fənlər: ", paste(weak, collapse = ", "), "\n") else "",
    if (length(medium) > 0) paste0("Kafi fənlər: ", paste(medium, collapse = ", "), "\n") else "",
    "\nAşağıdakı JSON strukturunda cavab ver:\n",
    '{\n',
    '  "overall_assessment": "Umumi qiymetlendirme metni",\n',
    '  "overall_level": "ela/yaxsi/kafi/qeyri-kafi",\n',
    '  "subject_analyses": [{\n',
    '    "subject": "Fenn adi",\n',
    '    "level": "kafi",\n',
    '    "score": 62.5,\n',
    '    "strengths": ["Guclu teref 1"],\n',
    '    "weaknesses": ["Zeif teref 1"],\n',
    '    "resources": ["Resurs 1"],\n',
    '    "weekly_tasks": [{"week":1, "task":"Tapshiriq", "type":"practice", "minutes":30}]\n',
    '  }],\n',
    '  "teacher_recommendations": [\n',
    '    {"subject":"Fenn", "recommendation":"Tovsiye metni", "priority":"high"}\n',
    '  ],\n',
    '  "parent_summary": "Valideyn ucun xulase",\n',
    '  "weekly_schedule": [{"week":1, "focus_subject":"Fenn", "tasks_summary":"Xulase"}],\n',
    '  "motivational_note": "Heveslendirici mesaj"\n',
    '}'
  )

  list(system_prompt = system_prompt, user_prompt = user_prompt)
}

#' AI cavabını parse et
parse_idp_ai_response <- function(response) {
  # Əvvəlcə extract_json_from_response() cəhd et
  result <- extract_json_from_response(response)
  if (!is.null(result)) return(result)

  # Fallback: birbaşa fromJSON
  tryCatch(
    jsonlite::fromJSON(response, simplifyVector = TRUE),
    error = function(e) {
      logger::log_error("FİP AI cavab parse xətası: {e$message}")
      NULL
    }
  )
}

#' Valideyn hesabat datası topla
generate_parent_report_data <- function(db_pool, student_id, academic_year, month) {
  student <- db_get_one(db_pool,
    "SELECT s.first_name || ' ' || s.last_name as full_name, c.grade, c.section
     FROM students s LEFT JOIN classes c ON s.class_id = c.id WHERE s.id = $1",
    params = list(student_id))

  # Qiymətlər
  grades <- tryCatch(
    db_query(db_pool,
      "SELECT sub.name as subject, AVG(g.score) as avg_score
       FROM grades g JOIN subjects sub ON g.subject_id = sub.id
       WHERE g.student_id = $1 AND g.academic_year = $2
             AND EXTRACT(MONTH FROM g.created_at) = $3
       GROUP BY sub.name ORDER BY sub.name",
      params = list(student_id, academic_year, month)),
    error = function(e) data.frame()
  )

  # Davamiyyət
  att <- tryCatch(
    db_get_one(db_pool,
      "SELECT COUNT(*) as total,
              SUM(CASE WHEN status = 'present' THEN 1 ELSE 0 END) as present
       FROM attendance
       WHERE student_id = $1 AND EXTRACT(MONTH FROM date) = $2",
      params = list(student_id, month)),
    error = function(e) list(total = 0, present = 0)
  )

  # Aktiv plan xülasəsi
  plan <- tryCatch(
    db_get_one(db_pool,
      "SELECT overall_assessment, parent_summary FROM idp_ai_plans
       WHERE student_id = $1 AND academic_year = $2 AND status = 'active'
       ORDER BY created_at DESC LIMIT 1",
      params = list(student_id, academic_year)),
    error = function(e) NULL
  )

  # Tapşırıq tamamlanma
  tasks <- tryCatch(
    db_get_one(db_pool,
      "SELECT COUNT(*) as total,
              SUM(CASE WHEN is_completed THEN 1 ELSE 0 END) as completed
       FROM idp_weekly_tasks wt
       JOIN idp_ai_plans ap ON wt.plan_id = ap.id
       WHERE wt.student_id = $1 AND ap.academic_year = $2 AND ap.status = 'active'",
      params = list(student_id, academic_year)),
    error = function(e) list(total = 0, completed = 0)
  )

  list(
    student = student,
    grades = grades,
    attendance = att,
    plan_summary = plan,
    task_completion = tasks,
    month = month,
    academic_year = academic_year
  )
}


# =============================================
# UI (~150 sətir)
# =============================================

student_idp_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(column(12, h2(icon("clipboard-list"), "Fərdi İnkişaf Planı (FİP)"), hr())),

    # Yuxarı sətir: şagird, tədris ili, düymələr
    fluidRow(
      column(4, selectizeInput(ns("idp_student"), "Şagird seçin:", choices = NULL,
                               options = list(placeholder = "Axtar..."))),
      column(2, selectInput(ns("idp_year"), "Tədris ili:",
                            choices = c("2025-2026", "2024-2025"))),
      column(6, div(style = "margin-top: 25px;",
        actionButton(ns("btn_generate_plan"), "AI Plan Yarat",
                     icon = icon("robot"), class = "btn-success"),
        actionButton(ns("btn_refresh_profile"), "Profili Yenilə",
                     icon = icon("refresh"), class = "btn-info")
      ))
    ),

    # KPI sətiri
    fluidRow(
      column(3, wellPanel(class = "text-center",
        h4("Ümumi Səviyyə"), uiOutput(ns("kpi_level")))),
      column(3, wellPanel(class = "text-center",
        h4("Orta Bal"), h2(textOutput(ns("kpi_avg_score"))))),
      column(3, wellPanel(class = "text-center",
        h4("Davamiyyət"), h2(textOutput(ns("kpi_attendance"))))),
      column(3, wellPanel(class = "text-center",
        h4("Tapşırıq Tamamlanma"), uiOutput(ns("kpi_task_progress"))))
    ),

    # 6 Tab
    tabsetPanel(id = ns("idp_tabs"),
      # Tab 1: Bacarıq Profili
      tabPanel("Bacarıq Profili", value = "profile", icon = icon("chart-area"),
        br(),
        fluidRow(
          column(6, wellPanel(h3(icon("bullseye"), "Radar Qrafik"),
            plotlyOutput(ns("radar_chart"), height = "400px"))),
          column(6, wellPanel(h3(icon("table"), "Bacarıq Cədvəli"),
            DTOutput(ns("ability_table"))))
        ),
        fluidRow(column(12, wellPanel(h3(icon("chart-line"), "Tərəqqi Trendi"),
          plotlyOutput(ns("trend_chart"), height = "300px"))))
      ),

      # Tab 2: AI İnkişaf Planı
      tabPanel("AI İnkişaf Planı", value = "ai_plan", icon = icon("robot"),
        br(),
        uiOutput(ns("ai_plan_content"))
      ),

      # Tab 3: Həftəlik Tapşırıqlar
      tabPanel("Həftəlik Tapşırıqlar", value = "tasks", icon = icon("tasks"),
        br(),
        fluidRow(
          column(3, selectInput(ns("task_week_filter"), "Həftə:",
                                choices = c("Hamısı" = "", 1:4))),
          column(3, selectInput(ns("task_subject_filter"), "Fənn:",
                                choices = c("Hamısı" = ""))),
          column(3, selectInput(ns("task_status_filter"), "Status:",
                                choices = c("Hamısı" = "", "Tamamlanmış" = "completed",
                                            "Gözləyən" = "pending"))),
          column(3, br(), actionButton(ns("btn_refresh_tasks"), "Yenilə", icon = icon("refresh"),
                                       class = "btn-default"))
        ),
        fluidRow(
          column(8, wellPanel(DTOutput(ns("tasks_table")))),
          column(4, wellPanel(h4(icon("chart-pie"), "Tapşırıq Statistikası"),
            plotlyOutput(ns("tasks_chart"), height = "300px")))
        )
      ),

      # Tab 4: Müəllim Tövsiyələri
      tabPanel("Müəllim Tövsiyələri", value = "recommendations", icon = icon("chalkboard-teacher"),
        br(),
        fluidRow(column(12, wellPanel(
          h3(icon("lightbulb"), "Tövsiyələr"),
          DTOutput(ns("recs_table")),
          hr(),
          h4("Yeni Tövsiyə Əlavə Et"),
          fluidRow(
            column(4, selectInput(ns("rec_subject"), "Fənn:", choices = c("Ümumi" = "", SUBJECTS))),
            column(3, selectInput(ns("rec_type"), "Növ:",
                                  choices = c("Ümumi" = "general", "Akademik" = "academic",
                                              "Davranış" = "behavioral", "Resurs" = "resource",
                                              "Valideyn görüşü" = "parent_meeting"))),
            column(3, selectInput(ns("rec_priority"), "Prioritet:",
                                  choices = c("Orta" = "medium", "Yüksək" = "high", "Aşağı" = "low")))
          ),
          fluidRow(
            column(9, textAreaInput(ns("rec_text"), "Tövsiyə mətni:", rows = 2,
                                    placeholder = "Tövsiyənizi yazın...")),
            column(3, br(), actionButton(ns("btn_add_rec"), "Əlavə Et",
                                         icon = icon("plus"), class = "btn-success"))
          )
        )))
      ),

      # Tab 5: Valideyn Hesabatı
      tabPanel("Valideyn Hesabatı", value = "parent_report", icon = icon("file-alt"),
        br(),
        fluidRow(
          column(3, selectInput(ns("report_month"), "Ay:",
                                choices = setNames(1:12, c("Yanvar","Fevral","Mart","Aprel","May","İyun",
                                                           "İyul","Avqust","Sentyabr","Oktyabr","Noyabr","Dekabr")),
                                selected = as.integer(format(Sys.Date(), "%m")))),
          column(3, br(), actionButton(ns("btn_generate_report"), "Hesabat Yarat",
                                       icon = icon("file-medical"), class = "btn-primary")),
          column(3, br(), downloadButton(ns("btn_download_report"), "Yüklə (HTML)",
                                         class = "btn-info"))
        ),
        fluidRow(column(12, wellPanel(
          h3(icon("file-alt"), "Hesabat Önbaxışı"),
          uiOutput(ns("parent_report_preview"))
        )))
      ),

      # Tab 6: Tarixçə
      tabPanel("Tarixçə", value = "history", icon = icon("history"),
        br(),
        fluidRow(
          column(6, wellPanel(
            h3(icon("clipboard-list"), "Mövcud FİP-lər"),
            DTOutput(ns("idp_list"))
          )),
          column(6, wellPanel(
            h3(icon("sticky-note"), "Plan Qeydləri"),
            fluidRow(
              column(8, textAreaInput(ns("new_note"), "Yeni qeyd:", placeholder = "Tərəqqi qeydi...", rows = 2)),
              column(4, br(), actionButton(ns("btn_add_note"), "Əlavə Et",
                                           icon = icon("plus"), class = "btn-success"))
            ),
            DTOutput(ns("notes_table"))
          ))
        )
      )
    )
  )
}


# =============================================
# SERVER (~450 sətir)
# =============================================

student_idp_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Reaktiv dəyərlər
    ability_profiles <- reactiveVal(data.frame())
    current_ai_plan <- reactiveVal(NULL)
    academic_data <- reactiveVal(NULL)

    # --- Şagird siyahısını yüklə ---
    observe({
      students <- db_query(db_pool,
        "SELECT id, first_name || ' ' || last_name as name FROM students WHERE status = 'active' ORDER BY name")
      if (nrow(students) > 0) {
        updateSelectizeInput(session, "idp_student", choices = setNames(students$id, students$name))
      }
    })

    # --- Şagird / il dəyişdikdə profili yenilə ---
    observeEvent(list(input$idp_student, input$idp_year), {
      req(input$idp_student, input$idp_year)
      student_id <- input$idp_student
      year <- input$idp_year

      # Bacarıq profili hesabla
      profiles <- tryCatch(
        compute_ability_profile(db_pool, student_id, year),
        error = function(e) {
          logger::log_error("Profil hesablama xətası: {e$message}")
          data.frame()
        }
      )
      ability_profiles(profiles)

      # Akademik data cache
      acad_data <- tryCatch(
        collect_student_academic_data(db_pool, student_id, year),
        error = function(e) NULL
      )
      academic_data(acad_data)

      # Mövcud aktiv AI plan yüklə
      plan <- tryCatch(
        db_get_one(db_pool,
          "SELECT * FROM idp_ai_plans
           WHERE student_id = $1 AND academic_year = $2 AND status = 'active'
           ORDER BY created_at DESC LIMIT 1",
          params = list(student_id, year)),
        error = function(e) NULL
      )
      if (!is.null(plan) && !is.null(plan$plan_json)) {
        plan$plan_parsed <- tryCatch(
          jsonlite::fromJSON(plan$plan_json, simplifyVector = TRUE),
          error = function(e) NULL
        )
      }
      current_ai_plan(plan)

      # Tapşırıq fənn filterini güncəllə
      if (nrow(profiles) > 0) {
        choices <- c("Hamısı" = "", setNames(profiles$subject_name, profiles$subject_name))
        updateSelectInput(session, "task_subject_filter", choices = choices)
      }
    })

    # --- Profili Yenilə düyməsi ---
    observeEvent(input$btn_refresh_profile, {
      req(input$idp_student, input$idp_year)
      profiles <- tryCatch(
        compute_ability_profile(db_pool, input$idp_student, input$idp_year),
        error = function(e) data.frame()
      )
      ability_profiles(profiles)
      notify_success("Bacarıq profili yeniləndi!")
    })

    # =============================================
    # KPI SƏTRI
    # =============================================

    output$kpi_level <- renderUI({
      profiles <- ability_profiles()
      if (nrow(profiles) == 0) return(h2("—"))
      avg <- mean(profiles$avg_score, na.rm = TRUE)
      label <- get_grade_label(avg)
      color <- get_grade_color(avg)
      tags$h2(tags$span(class = "badge", style = paste0("background-color:", color, ";color:white;padding:8px 16px;font-size:1.2em;"), label))
    })

    output$kpi_avg_score <- renderText({
      profiles <- ability_profiles()
      if (nrow(profiles) == 0) return("—")
      format_number_az(mean(profiles$avg_score, na.rm = TRUE), 1)
    })

    output$kpi_attendance <- renderText({
      data <- academic_data()
      if (is.null(data)) return("—")
      paste0(data$attendance_rate, "%")
    })

    output$kpi_task_progress <- renderUI({
      plan <- current_ai_plan()
      if (is.null(plan)) return(tags$div(h2("—"), tags$p("Plan yoxdur")))

      tasks <- tryCatch(
        db_get_one(db_pool,
          "SELECT COUNT(*) as total, SUM(CASE WHEN is_completed THEN 1 ELSE 0 END) as done
           FROM idp_weekly_tasks WHERE plan_id = $1",
          params = list(plan$id)),
        error = function(e) list(total = 0, done = 0)
      )
      total <- tasks$total %||% 0
      done <- tasks$done %||% 0
      pct <- if (total > 0) round(done / total * 100) else 0

      tags$div(
        tags$div(class = "progress", style = "height: 25px;",
          tags$div(class = paste0("progress-bar bg-", if (pct >= 75) "success" else if (pct >= 50) "info" else "warning"),
                   style = paste0("width:", pct, "%;"), paste0(pct, "%"))),
        tags$p(paste0(done, "/", total, " tapşırıq"))
      )
    })

    # =============================================
    # TAB 1: BACARIQ PROFİLİ
    # =============================================

    # Radar chart
    output$radar_chart <- renderPlotly({
      profiles <- ability_profiles()
      if (nrow(profiles) == 0) return(plotly_empty() %>% layout(title = "Məlumat yoxdur"))

      plot_ly(type = "scatterpolar", fill = "toself",
              r = c(profiles$avg_score, profiles$avg_score[1]),
              theta = c(profiles$subject_name, profiles$subject_name[1]),
              name = "Orta Bal",
              fillcolor = "rgba(52, 152, 219, 0.3)",
              line = list(color = "#3498db")) %>%
        layout(
          polar = list(
            radialaxis = list(visible = TRUE, range = c(0, 100)),
            angularaxis = list(direction = "clockwise")
          ),
          showlegend = FALSE,
          margin = list(t = 30, b = 30)
        )
    })

    # Ability cədvəli
    output$ability_table <- renderDT({
      profiles <- ability_profiles()
      if (nrow(profiles) == 0) return(datatable(data.frame("Məlumat yoxdur" = character(0))))

      display <- data.frame(
        Fenn = profiles$subject_name,
        Bal = round(profiles$avg_score, 1),
        Seviyye = sapply(profiles$avg_score, function(s) grade_badge(round(s, 1))),
        Theta = ifelse(is.na(profiles$theta_estimate), "—",
                        sprintf("%.2f", profiles$theta_estimate)),
        Trend = sapply(profiles$trend_direction, function(t) {
          switch(t,
            up = '<i class="fa fa-arrow-up" style="color:#27ae60;"></i> Yuxarı',
            down = '<i class="fa fa-arrow-down" style="color:#e74c3c;"></i> Aşağı',
            '<i class="fa fa-minus" style="color:#f39c12;"></i> Sabit')
        }),
        Qiymet_Sayi = profiles$grade_count,
        stringsAsFactors = FALSE
      )
      names(display) <- c("Fənn", "Orta Bal", "Səviyyə", "IRT Theta", "Trend", "Qiymət Sayı")
      datatable(display, escape = FALSE, options = list(pageLength = 15, dom = "t", scrollX = TRUE),
                rownames = FALSE)
    })

    # Trend xətti
    output$trend_chart <- renderPlotly({
      profiles <- ability_profiles()
      if (nrow(profiles) == 0) return(plotly_empty())

      p <- plot_ly()
      colors <- c("#3498db", "#e74c3c", "#27ae60", "#f39c12", "#9b59b6",
                   "#1abc9c", "#e67e22", "#2ecc71", "#34495e", "#d35400")
      for (i in seq_len(min(nrow(profiles), 10))) {
        scores_str <- tryCatch({
          data <- academic_data()
          if (!is.null(data) && nrow(data$grades) >= i) data$grades$scores[i] else NULL
        }, error = function(e) NULL)

        if (!is.null(scores_str)) {
          if (is.character(scores_str)) {
            scores <- as.numeric(unlist(strsplit(gsub("[{}]", "", scores_str), ",")))
          } else {
            scores <- as.numeric(unlist(scores_str))
          }
          if (length(scores) > 0) {
            p <- p %>% add_trace(x = seq_along(scores), y = scores,
                                  type = "scatter", mode = "lines+markers",
                                  name = profiles$subject_name[i],
                                  line = list(color = colors[i]))
          }
        }
      }
      p %>% layout(
        xaxis = list(title = "Qiymət Sırası"),
        yaxis = list(title = "Bal", range = c(0, 100)),
        showlegend = TRUE
      )
    })

    # =============================================
    # TAB 2: AI İNKİŞAF PLANI
    # =============================================

    # AI Plan Yarat düyməsi
    observeEvent(input$btn_generate_plan, {
      req(input$idp_student, input$idp_year)
      student_id <- input$idp_student
      year <- input$idp_year

      profiles <- ability_profiles()
      if (nrow(profiles) == 0) {
        notify_warning("Əvvəlcə profil yaradılmalıdır. Qiymət məlumatı tapılmadı.")
        return()
      }

      withProgress(message = "AI plan yaradılır...", value = 0, {
        setProgress(0.1, detail = "Məlumat toplanır...")
        data <- academic_data()
        if (is.null(data)) {
          data <- collect_student_academic_data(db_pool, student_id, year)
        }

        setProgress(0.3, detail = "AI prompt hazırlanır...")
        prompts <- build_idp_ai_prompt(data, profiles)

        setProgress(0.4, detail = "Claude API çağırılır...")
        result <- tryCatch(
          call_claude_api(
            prompt = prompts$user_prompt,
            system_prompt = prompts$system_prompt,
            max_tokens = 6144,
            temperature = 0.5
          ),
          error = function(e) list(success = FALSE, message = e$message)
        )

        if (!result$success) {
          notify_error(paste0("AI xətası: ", result$message))
          return()
        }

        setProgress(0.7, detail = "Cavab parse edilir...")
        parsed <- parse_idp_ai_response(result$message)
        if (is.null(parsed)) {
          notify_error("AI cavabı parse edilə bilmədi.")
          return()
        }

        tokens_used <- (result$usage$input_tokens %||% 0) + (result$usage$output_tokens %||% 0)

        setProgress(0.8, detail = "Verilənlər bazasına yazılır...")

        # Köhnə planları superseded et
        tryCatch(
          db_execute(db_pool,
            "UPDATE idp_ai_plans SET status = 'superseded', updated_at = NOW()
             WHERE student_id = $1 AND academic_year = $2 AND status = 'active'",
            params = list(student_id, year)),
          error = function(e) NULL
        )

        # Generasiya nömrəsini tap
        gen_num <- tryCatch({
          cnt <- db_get_one(db_pool,
            "SELECT COUNT(*) as cnt FROM idp_ai_plans WHERE student_id = $1 AND academic_year = $2",
            params = list(student_id, year))
          (cnt$cnt %||% 0) + 1
        }, error = function(e) 1)

        # Yeni plan INSERT
        plan_id <- generate_uuid()
        overall_level <- parsed$overall_level %||% "kafi"
        # overall_level düzəlt (Azərbaycan diacritics)
        overall_level <- switch(tolower(gsub("[^a-zəüöğışç]", "", overall_level)),
          "la" = "əla", "ela" = "əla",
          "yax" = "yaxşı", "yaxi" = "yaxşı", "yaxsi" = "yaxşı",
          "kafi" = "kafi",
          "qeyrikafi" = "qeyri-kafi", "qeyri-kafi" = "qeyri-kafi",
          "kafi"  # default
        )

        tryCatch(
          db_execute(db_pool,
            "INSERT INTO idp_ai_plans (id, student_id, academic_year, plan_json, overall_assessment,
             overall_level, parent_summary, generation_number, tokens_used, status, created_by)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, 'active', $10)",
            params = list(
              plan_id, student_id, year,
              jsonlite::toJSON(parsed, auto_unbox = TRUE, pretty = TRUE),
              parsed$overall_assessment %||% "",
              overall_level,
              parsed$parent_summary %||% "",
              gen_num, tokens_used,
              user_data()$id
            )),
          error = function(e) {
            logger::log_error("Plan INSERT xətası: {e$message}")
            notify_error("Plan yadda saxlanarkən xəta baş verdi.")
          }
        )

        # Weekly tasks INSERT
        if (!is.null(parsed$subject_analyses)) {
          subjects <- if (is.data.frame(parsed$subject_analyses)) {
            lapply(seq_len(nrow(parsed$subject_analyses)), function(i) as.list(parsed$subject_analyses[i, ]))
          } else {
            parsed$subject_analyses
          }

          for (sa in subjects) {
            # Subject ID tap
            subj <- tryCatch(
              db_get_one(db_pool,
                "SELECT id FROM subjects WHERE name = $1 LIMIT 1",
                params = list(sa$subject %||% "")),
              error = function(e) NULL
            )
            subj_id <- if (!is.null(subj)) subj$id else NULL

            tasks <- sa$weekly_tasks
            if (!is.null(tasks)) {
              if (is.data.frame(tasks)) {
                tasks <- lapply(seq_len(nrow(tasks)), function(j) as.list(tasks[j, ]))
              }
              for (task in tasks) {
                tryCatch(
                  db_execute(db_pool,
                    "INSERT INTO idp_weekly_tasks (plan_id, student_id, subject_id, subject_name,
                     week_number, task_title, task_type, estimated_minutes)
                     VALUES ($1, $2, $3, $4, $5, $6, $7, $8)",
                    params = list(
                      plan_id, student_id, subj_id, sa$subject %||% "",
                      task$week %||% 1,
                      task$task %||% "Tapşırıq",
                      task$type %||% "practice",
                      task$minutes %||% 30
                    )),
                  error = function(e) logger::log_error("Task INSERT xətası: {e$message}")
                )
              }
            }
          }
        }

        # Teacher recommendations INSERT
        if (!is.null(parsed$teacher_recommendations)) {
          recs <- if (is.data.frame(parsed$teacher_recommendations)) {
            lapply(seq_len(nrow(parsed$teacher_recommendations)), function(i) as.list(parsed$teacher_recommendations[i, ]))
          } else {
            parsed$teacher_recommendations
          }

          for (rec in recs) {
            subj <- tryCatch(
              db_get_one(db_pool, "SELECT id FROM subjects WHERE name = $1 LIMIT 1",
                params = list(rec$subject %||% "")),
              error = function(e) NULL
            )
            tryCatch(
              db_execute(db_pool,
                "INSERT INTO idp_teacher_recommendations
                 (student_id, subject_id, subject_name, academic_year,
                  recommendation_text, priority, is_ai_generated, plan_id)
                 VALUES ($1, $2, $3, $4, $5, $6, TRUE, $7)",
                params = list(
                  student_id,
                  if (!is.null(subj)) subj$id else NULL,
                  rec$subject %||% "",
                  year,
                  rec$recommendation %||% "",
                  rec$priority %||% "medium",
                  plan_id
                )),
              error = function(e) logger::log_error("Rec INSERT xətası: {e$message}")
            )
          }
        }

        setProgress(1, detail = "Tamamlandı!")

        # Planı yenidən yüklə
        new_plan <- tryCatch(
          db_get_one(db_pool,
            "SELECT * FROM idp_ai_plans WHERE id = $1",
            params = list(plan_id)),
          error = function(e) NULL
        )
        if (!is.null(new_plan)) {
          new_plan$plan_parsed <- parsed
          current_ai_plan(new_plan)
        }
        notify_success("AI İnkişaf Planı uğurla yaradıldı!")
      })
    })

    # AI Plan göstər
    output$ai_plan_content <- renderUI({
      plan <- current_ai_plan()
      if (is.null(plan)) {
        return(tags$div(class = "text-center", style = "padding: 60px;",
          icon("robot", style = "font-size: 4em; color: #bdc3c7;"), tags$br(), tags$br(),
          tags$h3("Hələ AI plan yaradılmayıb"),
          tags$p("Yuxarıdakı 'AI Plan Yarat' düyməsinə basın")
        ))
      }

      parsed <- plan$plan_parsed
      if (is.null(parsed)) {
        parsed <- tryCatch(jsonlite::fromJSON(plan$plan_json, simplifyVector = TRUE), error = function(e) NULL)
      }
      if (is.null(parsed)) return(tags$p("Plan parse edilə bilmədi."))

      # Ümumi qiymətləndirmə + motivasiya
      overall_ui <- tags$div(
        wellPanel(style = "background: #eaf6ff;",
          tags$h3(icon("star"), "Ümumi Qiymətləndirmə"),
          tags$p(style = "font-size: 1.1em;", parsed$overall_assessment %||% "—"),
          if (!is.null(parsed$motivational_note))
            tags$div(style = "margin-top: 12px; padding: 10px; background: #fff3cd; border-radius: 8px;",
              icon("lightbulb", style = "color: #f39c12;"), " ",
              tags$em(parsed$motivational_note))
        )
      )

      # Fənn kartları
      subject_cards <- NULL
      if (!is.null(parsed$subject_analyses)) {
        subjects <- if (is.data.frame(parsed$subject_analyses)) {
          lapply(seq_len(nrow(parsed$subject_analyses)), function(i) as.list(parsed$subject_analyses[i, ]))
        } else {
          parsed$subject_analyses
        }

        subject_cards <- lapply(subjects, function(sa) {
          level_color <- switch(sa$level %||% "kafi",
            "ela" = "#27ae60", "əla" = "#27ae60",
            "yaxsi" = "#2980b9", "yaxşı" = "#2980b9",
            "kafi" = "#f39c12",
            "#e74c3c")

          tags$div(class = "col-md-6", style = "margin-bottom: 15px;",
            wellPanel(style = paste0("border-left: 4px solid ", level_color, ";"),
              tags$h4(sa$subject %||% "Fənn",
                tags$span(class = "badge", style = paste0("background:", level_color, ";color:white;margin-left:8px;"),
                          paste0(round(sa$score %||% 0, 1), " — ", sa$level %||% ""))),
              if (!is.null(sa$strengths) && length(sa$strengths) > 0)
                tags$div(
                  tags$strong(style = "color:#27ae60;", icon("check-circle"), " Güclü tərəflər:"),
                  tags$ul(lapply(sa$strengths, function(s) tags$li(s)))
                ),
              if (!is.null(sa$weaknesses) && length(sa$weaknesses) > 0)
                tags$div(
                  tags$strong(style = "color:#e74c3c;", icon("exclamation-circle"), " Zəif tərəflər:"),
                  tags$ul(lapply(sa$weaknesses, function(w) tags$li(w)))
                ),
              if (!is.null(sa$resources) && length(sa$resources) > 0)
                tags$div(
                  tags$strong(style = "color:#3498db;", icon("book"), " Resurslar:"),
                  tags$ul(lapply(sa$resources, function(r) tags$li(r)))
                )
            )
          )
        })
      }

      tagList(
        overall_ui,
        tags$div(class = "row", subject_cards),
        if (!is.null(parsed$parent_summary))
          wellPanel(style = "background: #f0fff0;",
            tags$h4(icon("users"), "Valideyn üçün Xülasə"),
            tags$p(parsed$parent_summary))
      )
    })

    # =============================================
    # TAB 3: HƏFTƏLİK TAPŞIRIQLAR
    # =============================================

    tasks_data <- reactive({
      plan <- current_ai_plan()
      if (is.null(plan)) return(data.frame())
      input$btn_refresh_tasks  # trigger

      query <- "SELECT wt.id, wt.subject_name, wt.week_number, wt.task_title,
                       wt.task_type, wt.estimated_minutes, wt.is_completed, wt.completed_at,
                       wt.teacher_feedback
                FROM idp_weekly_tasks wt
                WHERE wt.plan_id = $1"
      params <- list(plan$id)
      i <- 2

      if (!is_empty(input$task_week_filter)) {
        query <- paste0(query, " AND wt.week_number = $", i)
        params[[i]] <- as.integer(input$task_week_filter)
        i <- i + 1
      }
      if (!is_empty(input$task_subject_filter)) {
        query <- paste0(query, " AND wt.subject_name = $", i)
        params[[i]] <- input$task_subject_filter
        i <- i + 1
      }
      if (!is_empty(input$task_status_filter)) {
        if (input$task_status_filter == "completed") {
          query <- paste0(query, " AND wt.is_completed = TRUE")
        } else {
          query <- paste0(query, " AND wt.is_completed = FALSE")
        }
      }

      query <- paste0(query, " ORDER BY wt.week_number, wt.subject_name")
      tryCatch(db_query(db_pool, query, params = params), error = function(e) data.frame())
    })

    output$tasks_table <- renderDT({
      data <- tasks_data()
      if (nrow(data) == 0) return(datatable(data.frame("Tapşırıq tapılmadı" = character(0))))

      display <- data.frame(
        Hefte = data$week_number,
        Fenn = data$subject_name,
        Tapshiriq = data$task_title,
        Nov = data$task_type,
        Deqiqe = data$estimated_minutes,
        Status = ifelse(data$is_completed,
          '<span class="badge" style="background:#27ae60;color:white;">Tamamlanmış</span>',
          '<span class="badge" style="background:#f39c12;color:white;">Gözləyən</span>'),
        stringsAsFactors = FALSE
      )
      names(display) <- c("Həftə", "Fənn", "Tapşırıq", "Növ", "Dəq.", "Status")
      datatable(display, escape = FALSE, selection = "single",
                options = list(pageLength = 15, dom = "frtip", scrollX = TRUE),
                rownames = FALSE)
    })

    # Row click — tapşırığı tamamla/geri al
    observeEvent(input$tasks_table_rows_selected, {
      sel <- input$tasks_table_rows_selected
      data <- tasks_data()
      if (is.null(sel) || length(sel) == 0 || nrow(data) == 0) return()

      task_id <- data$id[sel]
      new_status <- !data$is_completed[sel]

      tryCatch(
        db_execute(db_pool,
          "UPDATE idp_weekly_tasks SET is_completed = $1,
           completed_at = CASE WHEN $1 THEN NOW() ELSE NULL END
           WHERE id = $2",
          params = list(new_status, task_id)),
        error = function(e) notify_error("Status yenilənə bilmədi.")
      )

      notify_success(if (new_status) "Tapşırıq tamamlandı!" else "Tapşırıq geri alındı.")
      # Reactive trigger — tasks_data btn_refresh_tasks ilə yenilənəcək
      # Manual trigger
      shinyjs::click("btn_refresh_tasks")
    })

    # Tapşırıq statistikası chart
    output$tasks_chart <- renderPlotly({
      plan <- current_ai_plan()
      if (is.null(plan)) return(plotly_empty())

      stats <- tryCatch(
        db_query(db_pool,
          "SELECT
             SUM(CASE WHEN is_completed THEN 1 ELSE 0 END) as completed,
             SUM(CASE WHEN NOT is_completed THEN 1 ELSE 0 END) as pending
           FROM idp_weekly_tasks WHERE plan_id = $1",
          params = list(plan$id)),
        error = function(e) data.frame(completed = 0, pending = 0)
      )

      completed <- stats$completed[1] %||% 0
      pending <- stats$pending[1] %||% 0

      plot_ly(labels = ~c("Tamamlanmış", "Gözləyən"),
              values = ~c(completed, pending), type = "pie",
              marker = list(colors = c("#27ae60", "#f39c12")),
              textinfo = "label+percent") %>%
        layout(showlegend = TRUE)
    })

    # =============================================
    # TAB 4: MÜƏLLİM TÖVSİYƏLƏRİ
    # =============================================

    output$recs_table <- renderDT({
      req(input$idp_student, input$idp_year)
      data <- tryCatch(
        db_query(db_pool,
          "SELECT r.id, r.subject_name, r.recommendation_text, r.recommendation_type,
                  r.priority, r.is_ai_generated, r.status, r.created_at
           FROM idp_teacher_recommendations r
           WHERE r.student_id = $1 AND r.academic_year = $2
           ORDER BY r.created_at DESC",
          params = list(input$idp_student, input$idp_year)),
        error = function(e) data.frame()
      )
      if (nrow(data) == 0) return(datatable(data.frame("Tövsiyə tapılmadı" = character(0))))

      display <- data.frame(
        Fenn = data$subject_name,
        Tovsiye = data$recommendation_text,
        Nov = data$recommendation_type,
        Prioritet = sapply(data$priority, function(p) {
          switch(p,
            high = '<span class="badge" style="background:#e74c3c;color:white;">Yüksək</span>',
            medium = '<span class="badge" style="background:#f39c12;color:white;">Orta</span>',
            '<span class="badge" style="background:#3498db;color:white;">Aşağı</span>')
        }),
        Menbey = ifelse(data$is_ai_generated, "AI", "Müəllim"),
        Tarix = format(as.Date(data$created_at), "%d.%m.%Y"),
        stringsAsFactors = FALSE
      )
      names(display) <- c("Fənn", "Tövsiyə", "Növ", "Prioritet", "Mənbə", "Tarix")
      datatable(display, escape = FALSE, options = list(pageLength = 10, scrollX = TRUE), rownames = FALSE)
    })

    # Yeni tövsiyə əlavə et
    observeEvent(input$btn_add_rec, {
      req(input$idp_student, input$idp_year, input$rec_text)
      rec_text <- trimws(input$rec_text)
      if (nchar(rec_text) == 0) {
        notify_warning("Tövsiyə mətni boş ola bilməz.")
        return()
      }

      subj <- NULL
      subj_name <- ""
      if (!is_empty(input$rec_subject)) {
        subj <- tryCatch(
          db_get_one(db_pool, "SELECT id FROM subjects WHERE name = $1 LIMIT 1",
            params = list(input$rec_subject)),
          error = function(e) NULL
        )
        subj_name <- input$rec_subject
      }

      tryCatch({
        db_execute(db_pool,
          "INSERT INTO idp_teacher_recommendations
           (student_id, teacher_id, subject_id, subject_name, academic_year,
            recommendation_text, recommendation_type, priority, is_ai_generated)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, FALSE)",
          params = list(
            input$idp_student,
            user_data()$id,
            if (!is.null(subj)) subj$id else NULL,
            subj_name,
            input$idp_year,
            rec_text,
            input$rec_type,
            input$rec_priority
          ))
        updateTextAreaInput(session, "rec_text", value = "")
        notify_success("Tövsiyə əlavə edildi!")
      }, error = function(e) {
        notify_error("Tövsiyə əlavə edilərkən xəta baş verdi.")
      })
    })

    # =============================================
    # TAB 5: VALİDEYN HESABATI
    # =============================================

    report_data <- reactiveVal(NULL)

    observeEvent(input$btn_generate_report, {
      req(input$idp_student, input$idp_year, input$report_month)
      month <- as.integer(input$report_month)

      rdata <- tryCatch(
        generate_parent_report_data(db_pool, input$idp_student, input$idp_year, month),
        error = function(e) {
          notify_error("Hesabat yaradılarkən xəta baş verdi.")
          NULL
        }
      )
      if (is.null(rdata)) return()
      report_data(rdata)

      # UPSERT parent report
      summary_text <- ""
      if (!is.null(rdata$plan_summary) && !is.null(rdata$plan_summary$parent_summary)) {
        summary_text <- rdata$plan_summary$parent_summary
      }
      tryCatch(
        db_execute(db_pool,
          "INSERT INTO idp_parent_reports (student_id, academic_year, report_month, report_json, summary_text)
           VALUES ($1, $2, $3, $4, $5)
           ON CONFLICT (student_id, academic_year, report_month) DO UPDATE SET
             report_json = EXCLUDED.report_json, summary_text = EXCLUDED.summary_text",
          params = list(
            input$idp_student, input$idp_year, month,
            jsonlite::toJSON(rdata, auto_unbox = TRUE),
            summary_text
          )),
        error = function(e) NULL
      )
      notify_success("Valideyn hesabatı yaradıldı!")
    })

    output$parent_report_preview <- renderUI({
      rdata <- report_data()
      if (is.null(rdata)) {
        return(tags$p(style = "color: #999; text-align: center; padding: 30px;",
                      "Hesabat yaratmaq üçün ay seçin və 'Hesabat Yarat' düyməsinə basın."))
      }

      month_names <- c("Yanvar","Fevral","Mart","Aprel","May","İyun",
                        "İyul","Avqust","Sentyabr","Oktyabr","Noyabr","Dekabr")
      month_name <- month_names[rdata$month]
      student_name <- if (!is.null(rdata$student)) rdata$student$full_name else "Şagird"

      att_pct <- if (!is.null(rdata$attendance) && rdata$attendance$total > 0) {
        round(rdata$attendance$present / rdata$attendance$total * 100, 1)
      } else "N/A"

      task_info <- if (!is.null(rdata$task_completion)) {
        paste0(rdata$task_completion$completed %||% 0, "/", rdata$task_completion$total %||% 0)
      } else "—"

      # Qiymətlər cədvəli
      grades_html <- if (!is.null(rdata$grades) && nrow(rdata$grades) > 0) {
        rows <- paste(sapply(seq_len(nrow(rdata$grades)), function(i) {
          g <- rdata$grades[i, ]
          score <- round(g$avg_score, 1)
          sprintf("<tr><td>%s</td><td>%s</td><td>%s</td></tr>",
                  g$subject, score, get_grade_label(score))
        }), collapse = "")
        paste0("<table class='table table-sm table-bordered'><thead><tr><th>Fənn</th><th>Orta Bal</th><th>Səviyyə</th></tr></thead><tbody>",
               rows, "</tbody></table>")
      } else "<p>Bu ay üçün qiymət məlumatı yoxdur.</p>"

      summary_html <- if (!is.null(rdata$plan_summary) && !is.null(rdata$plan_summary$parent_summary)) {
        tags$div(style = "background: #f0fff0; padding: 12px; border-radius: 8px;",
          tags$h4("AI Tövsiyəsi:"),
          tags$p(rdata$plan_summary$parent_summary))
      } else NULL

      tags$div(style = "border: 1px solid #ddd; padding: 20px; border-radius: 8px; background: white;",
        tags$h2(style = "text-align: center; color: #2c3e50;", "Valideyn Hesabatı"),
        tags$h4(style = "text-align: center;", paste0(student_name, " — ", month_name, " ", rdata$academic_year)),
        tags$hr(),
        tags$div(class = "row",
          tags$div(class = "col-md-4 text-center",
            tags$h5("Davamiyyət"), tags$h3(paste0(att_pct, "%"))),
          tags$div(class = "col-md-4 text-center",
            tags$h5("Tapşırıq Tamamlanma"), tags$h3(task_info)),
          tags$div(class = "col-md-4 text-center",
            tags$h5("Fənn Sayı"),
            tags$h3(if (!is.null(rdata$grades)) nrow(rdata$grades) else 0))
        ),
        tags$hr(),
        tags$h4("Fənn Nəticələri"),
        HTML(grades_html),
        summary_html
      )
    })

    # Download report
    output$btn_download_report <- downloadHandler(
      filename = function() {
        paste0("hesabat_", input$idp_student, "_", input$report_month, ".html")
      },
      content = function(file) {
        rdata <- report_data()
        if (is.null(rdata)) {
          writeLines("<h1>Hesabat yoxdur</h1>", file)
          return()
        }

        month_names <- c("Yanvar","Fevral","Mart","Aprel","May","İyun",
                          "İyul","Avqust","Sentyabr","Oktyabr","Noyabr","Dekabr")
        month_name <- month_names[rdata$month]
        student_name <- if (!is.null(rdata$student)) rdata$student$full_name else "Şagird"

        att_pct <- if (!is.null(rdata$attendance) && rdata$attendance$total > 0) {
          round(rdata$attendance$present / rdata$attendance$total * 100, 1)
        } else "N/A"

        grades_rows <- ""
        if (!is.null(rdata$grades) && nrow(rdata$grades) > 0) {
          grades_rows <- paste(sapply(seq_len(nrow(rdata$grades)), function(i) {
            g <- rdata$grades[i, ]
            score <- round(g$avg_score, 1)
            sprintf("<tr><td>%s</td><td>%s</td><td>%s</td></tr>",
                    htmltools::htmlEscape(g$subject), score, get_grade_label(score))
          }), collapse = "")
        }

        summary_text <- ""
        if (!is.null(rdata$plan_summary) && !is.null(rdata$plan_summary$parent_summary)) {
          summary_text <- paste0("<h3>Tövsiyələr</h3><p>",
                                 htmltools::htmlEscape(rdata$plan_summary$parent_summary), "</p>")
        }

        html <- paste0(
          "<!DOCTYPE html><html><head><meta charset='utf-8'>",
          "<title>Valideyn Hesabatı</title>",
          "<style>body{font-family:Arial,sans-serif;max-width:800px;margin:0 auto;padding:20px}",
          "table{width:100%;border-collapse:collapse}th,td{border:1px solid #ddd;padding:8px;text-align:left}",
          "th{background:#2c3e50;color:white}.header{text-align:center;margin-bottom:20px}</style></head>",
          "<body><div class='header'><h1>Valideyn Hesabatı</h1>",
          "<h2>", htmltools::htmlEscape(student_name), " — ", month_name, " ", rdata$academic_year, "</h2></div>",
          "<p><strong>Davamiyyət:</strong> ", att_pct, "%</p>",
          "<h3>Fənn Nəticələri</h3>",
          "<table><thead><tr><th>Fənn</th><th>Orta Bal</th><th>Səviyyə</th></tr></thead>",
          "<tbody>", grades_rows, "</tbody></table>",
          summary_text,
          "</body></html>"
        )
        writeLines(html, file)
      }
    )

    # =============================================
    # TAB 6: TARİXÇƏ
    # =============================================

    output$idp_list <- renderDT({
      req(input$idp_student)
      data <- tryCatch(
        db_query(db_pool,
          "SELECT ip.id, ip.title, ip.status, ip.progress, ip.start_date, ip.end_date
           FROM individual_plans ip
           WHERE ip.student_id = $1
           ORDER BY ip.start_date DESC",
          params = list(input$idp_student)),
        error = function(e) data.frame()
      )

      # AI planları da göstər
      ai_plans <- tryCatch(
        db_query(db_pool,
          "SELECT id, CONCAT('AI Plan #', generation_number) as title, status,
                  CASE overall_level WHEN 'əla' THEN 100 WHEN 'yaxşı' THEN 75
                       WHEN 'kafi' THEN 55 ELSE 25 END as progress,
                  created_at::date as start_date, NULL::date as end_date
           FROM idp_ai_plans
           WHERE student_id = $1 AND academic_year = $2
           ORDER BY created_at DESC",
          params = list(input$idp_student, input$idp_year)),
        error = function(e) data.frame()
      )

      combined <- if (nrow(data) > 0 && nrow(ai_plans) > 0) {
        rbind(data, ai_plans)
      } else if (nrow(ai_plans) > 0) {
        ai_plans
      } else if (nrow(data) > 0) {
        data
      } else {
        data.frame(title = "FİP tapılmadı", status = "-", progress = 0,
                   start_date = "-", end_date = "-")
      }

      datatable(combined[, c("title", "status", "progress", "start_date")],
                colnames = c("Plan", "Status", "Tərəqqi (%)", "Tarix"),
                options = list(pageLength = 10, dom = "t"), rownames = FALSE)
    })

    # Plan qeydləri
    output$notes_table <- renderDT({
      req(input$idp_student)
      data <- tryCatch(
        db_query(db_pool,
          "SELECT pn.note, pn.created_at,
                  u.first_name || ' ' || u.last_name as author
           FROM plan_notes pn
           JOIN individual_plans ip ON pn.plan_id = ip.id
           LEFT JOIN users u ON pn.created_by = u.id
           WHERE ip.student_id = $1
           ORDER BY pn.created_at DESC",
          params = list(input$idp_student)),
        error = function(e) data.frame()
      )
      if (nrow(data) == 0) {
        return(datatable(data.frame("Qeyd tapılmadı" = character(0)), options = list(dom = "t")))
      }
      data$created_at <- format(as.Date(data$created_at), "%d.%m.%Y")
      names(data) <- c("Qeyd", "Tarix", "Müəllif")
      datatable(data, options = list(pageLength = 10, dom = "t"), rownames = FALSE)
    })

    # Yeni qeyd əlavə et
    observeEvent(input$btn_add_note, {
      req(input$idp_student, input$new_note)
      note_text <- trimws(input$new_note)
      if (nchar(note_text) == 0) return()

      # Son aktiv planı tap
      plan <- tryCatch(
        db_get_one(db_pool,
          "SELECT id FROM individual_plans WHERE student_id = $1 AND status = 'active'
           ORDER BY start_date DESC LIMIT 1",
          params = list(input$idp_student)),
        error = function(e) NULL
      )

      if (is.null(plan)) {
        notify_warning("Aktiv plan tapılmadı. Əvvəlcə plan yaradılmalıdır.")
        return()
      }

      tryCatch({
        db_execute(db_pool,
          "INSERT INTO plan_notes (plan_id, note, created_by) VALUES ($1, $2, $3)",
          params = list(plan$id, note_text, user_data()$id))
        updateTextAreaInput(session, "new_note", value = "")
        notify_success("Qeyd əlavə edildi!")
      }, error = function(e) {
        notify_error("Qeyd əlavə edilərkən xəta baş verdi.")
      })
    })

    # =============================================
    # AVTOMATİK YENİLƏMƏ OBSERVERİ
    # =============================================

    observe({
      # Hər 60 saniyədə yoxla
      invalidateLater(60000, session)
      plan <- current_ai_plan()
      if (is.null(plan)) return()

      # Son plandan 7+ gün keçib?
      plan_date <- as.Date(plan$created_at)
      days_since <- as.numeric(Sys.Date() - plan_date)
      if (days_since < 7) return()

      # Son plandan sonra yeni qiymətlər var?
      new_grades <- tryCatch(
        db_get_one(db_pool,
          "SELECT COUNT(*) as cnt FROM grades
           WHERE student_id = $1 AND created_at > $2",
          params = list(input$idp_student, plan$created_at)),
        error = function(e) list(cnt = 0)
      )

      if ((new_grades$cnt %||% 0) > 0) {
        showNotification(
          tagList(
            icon("exclamation-triangle"),
            " Son plandan sonra yeni qiymətlər əlavə olunub. ",
            "Planı yeniləmək tövsiyə olunur."
          ),
          type = "warning", duration = 15
        )
      }
    })
  })
}
