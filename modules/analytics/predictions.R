# =============================================
# ARTI-2026: Prediktiv Analitika (Tam Funksional)
# randomForest ML + AI tövsiyə + avtomatik bildiriş
# =============================================

predictions_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(column(12, h2(icon("brain"), "Prediktiv Analitika"), hr())),
    # Filtr paneli
    fluidRow(
      column(3, selectInput(ns("model"), "Model:",
        choices = c("Random Forest" = "rf", "Logistik Reqressiya" = "logistic"))),
      column(3, selectInput(ns("target"), "Hədəf:",
        choices = c("Tərk Riski" = "dropout", "Performans Proqnozu" = "performance"))),
      column(3, selectInput(ns("school"), "Məktəb:", choices = c("Hamısı" = ""))),
      column(3, actionButton(ns("btn_predict"), "Proqnozla", icon = icon("magic"),
        class = "btn-primary", style = "margin-top:25px"))
    ),
    # Model metrikləri
    fluidRow(
      column(3, wellPanel(class = "text-center", h4("Model Dəqiqliyi"),
        h2(textOutput(ns("accuracy")), class = "text-primary"), textOutput(ns("accuracy_label")))),
      column(3, wellPanel(class = "text-center", h4("AUC"),
        h2(textOutput(ns("auc")), class = "text-success"))),
      column(3, wellPanel(class = "text-center", h4("Precision"),
        h2(textOutput(ns("precision")), class = "text-info"))),
      column(3, wellPanel(class = "text-center", h4("Recall"),
        h2(textOutput(ns("recall")), class = "text-warning")))
    ),
    # Qrafiklər
    fluidRow(
      column(6, wellPanel(h4("Dəyişən Əhəmiyyətliyi"), plotlyOutput(ns("importance_chart"), height = "350px"))),
      column(6, wellPanel(h4("Risk Paylanması"), plotlyOutput(ns("risk_distribution"), height = "350px")))
    ),
    # Risk dashboard
    fluidRow(column(12, wellPanel(
      h3(icon("exclamation-triangle"), "Erkən Xəbərdarlıq Sistemi"),
      fluidRow(
        column(2, wellPanel(style = "background:#e74c3c;color:#fff;text-align:center;",
          h4("Yüksək Risk"), h2(textOutput(ns("high_risk_count"))))),
        column(2, wellPanel(style = "background:#f39c12;color:#fff;text-align:center;",
          h4("Orta Risk"), h2(textOutput(ns("medium_risk_count"))))),
        column(2, wellPanel(style = "background:#27ae60;color:#fff;text-align:center;",
          h4("Aşağı Risk"), h2(textOutput(ns("low_risk_count"))))),
        column(3, sliderInput(ns("risk_threshold"), "Risk həddi:", min = 30, max = 80, value = 60, post = "%")),
        column(3,
          actionButton(ns("btn_notify_teachers"), "Müəllimlərə Bildiriş", icon = icon("bell"),
            class = "btn-danger", style = "margin-top:10px;"),
          br(), br(),
          actionButton(ns("btn_ai_recommend"), "AI Tövsiyələr", icon = icon("robot"),
            class = "btn-info")
        )
      )
    ))),
    # Risk cədvəli
    fluidRow(column(12, wellPanel(
      h4("Risk Altında Olan Şagirdlər"),
      fluidRow(
        column(3, selectInput(ns("risk_grade"), "Sinif:", choices = c("Hamısı" = "", 1:11))),
        column(3, selectInput(ns("risk_category"), "Risk:",
          choices = c("Hamısı" = "", "Yüksək" = "yüksək", "Orta" = "orta", "Aşağı" = "aşağı")))
      ),
      DTOutput(ns("risk_table"))
    ))),
    # AI Tövsiyələr
    fluidRow(column(12, uiOutput(ns("ai_recommendations_panel")))),
    # Model idarəetmə
    fluidRow(column(12, wellPanel(
      fluidRow(
        column(4, actionButton(ns("btn_retrain"), "Modeli Yenidən Öyrət", icon = icon("redo"), class = "btn-danger")),
        column(4, textOutput(ns("last_train_info"))),
        column(4, textOutput(ns("model_version")))
      )
    )))
  )
}

predictions_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Reaktiv dəyərlər
    model_object <- reactiveVal(NULL)
    model_metrics <- reactiveVal(list(accuracy = 0, auc = 0, precision = 0, recall = 0))
    risk_predictions <- reactiveVal(data.frame())
    feature_importance <- reactiveVal(data.frame())
    ai_recs <- reactiveVal(NULL)
    last_trained <- reactiveVal(NULL)

    # Məktəb siyahısı yüklə
    observe({
      schools <- tryCatch(
        db_query(db_pool, "SELECT id, name FROM schools WHERE status = 'active' ORDER BY name"),
        error = function(e) data.frame())
      if (nrow(schools) > 0) {
        updateSelectInput(session, "school",
          choices = c("Hamısı" = "", setNames(schools$id, schools$name)))
      }
    })

    # ==========================================
    # DATA: Şagird xüsusiyyətlərini (features) çıxar
    # ==========================================
    extract_student_features <- function(school_filter = NULL) {
      # Orta bal
      scores_query <- "
        SELECT g.student_id,
               AVG(g.score) as avg_score,
               STDDEV(g.score) as score_sd,
               COUNT(g.id) as grade_count
        FROM grades g
        WHERE g.grade_date >= CURRENT_DATE - INTERVAL '6 months'
        GROUP BY g.student_id"
      scores <- tryCatch(db_query(db_pool, scores_query), error = function(e) data.frame())

      # Bal trendi (son 3 ay vs əvvəlki 3 ay)
      trend_query <- "
        SELECT student_id,
               AVG(CASE WHEN grade_date >= CURRENT_DATE - INTERVAL '3 months' THEN score END) as recent_avg,
               AVG(CASE WHEN grade_date < CURRENT_DATE - INTERVAL '3 months'
                        AND grade_date >= CURRENT_DATE - INTERVAL '6 months' THEN score END) as prev_avg
        FROM grades
        WHERE grade_date >= CURRENT_DATE - INTERVAL '6 months'
        GROUP BY student_id"
      trends <- tryCatch(db_query(db_pool, trend_query), error = function(e) data.frame())

      # Davamiyyət
      att_query <- "
        SELECT a.student_id,
               COUNT(CASE WHEN a.status = 'iştirak' THEN 1 END)::float /
                 NULLIF(COUNT(a.id), 0) * 100 as attendance_pct,
               COUNT(CASE WHEN a.status = 'qayıb' THEN 1 END) as absent_count
        FROM attendance a
        WHERE a.attendance_date >= CURRENT_DATE - INTERVAL '3 months'
        GROUP BY a.student_id"
      attendance <- tryCatch(db_query(db_pool, att_query), error = function(e) data.frame())

      # Ev tapşırığı tamamlama (gündəlik qiymətlər mövcudluğu proxy kimi)
      hw_query <- "
        SELECT student_id,
               COUNT(CASE WHEN grade_type = 'gündəlik' AND score > 0 THEN 1 END)::float /
                 NULLIF(COUNT(CASE WHEN grade_type = 'gündəlik' THEN 1 END), 0) * 100 as hw_completion
        FROM grades
        WHERE grade_date >= CURRENT_DATE - INTERVAL '3 months'
        GROUP BY student_id"
      homework <- tryCatch(db_query(db_pool, hw_query), error = function(e) data.frame())

      # Şagird əsas məlumatları
      student_query <- "
        SELECT s.id as student_id, s.first_name, s.last_name,
               c.grade, c.section, sc.name as school_name,
               s.school_id,
               EXTRACT(YEAR FROM age(s.birth_date)) as age
        FROM students s
        LEFT JOIN classes c ON s.class_id = c.id
        LEFT JOIN schools sc ON s.school_id = sc.id
        WHERE s.status = 'active'"
      students <- tryCatch(db_query(db_pool, student_query), error = function(e) data.frame())

      if (nrow(students) == 0) return(data.frame())

      # Məktəb filteri
      if (!is.null(school_filter) && nchar(school_filter) > 0) {
        students <- students[students$school_id == school_filter, ]
      }
      if (nrow(students) == 0) return(data.frame())

      # Feature-ləri birləşdir
      df <- students
      if (nrow(scores) > 0) df <- merge(df, scores, by = "student_id", all.x = TRUE)
      if (nrow(trends) > 0) df <- merge(df, trends, by = "student_id", all.x = TRUE)
      if (nrow(attendance) > 0) df <- merge(df, attendance, by = "student_id", all.x = TRUE)
      if (nrow(homework) > 0) df <- merge(df, homework, by = "student_id", all.x = TRUE)

      # NA-ları default-larla doldur
      df$avg_score <- ifelse(is.na(df$avg_score), 50, df$avg_score)
      df$score_sd <- ifelse(is.na(df$score_sd), 15, df$score_sd)
      df$grade_count <- ifelse(is.na(df$grade_count), 0, df$grade_count)
      df$recent_avg <- ifelse(is.na(df$recent_avg), df$avg_score, df$recent_avg)
      df$prev_avg <- ifelse(is.na(df$prev_avg), df$avg_score, df$prev_avg)
      df$score_trend <- df$recent_avg - df$prev_avg
      df$attendance_pct <- ifelse(is.na(df$attendance_pct), 85, df$attendance_pct)
      df$absent_count <- ifelse(is.na(df$absent_count), 0, df$absent_count)
      df$hw_completion <- ifelse(is.na(df$hw_completion), 70, df$hw_completion)
      df$age <- ifelse(is.na(df$age), 14, df$age)
      df$grade <- ifelse(is.na(df$grade), 8, df$grade)

      df
    }

    # ==========================================
    # MODEL: Öyrətmə + Proqnozlama
    # ==========================================
    train_and_predict <- function(features_df, model_type = "rf") {
      if (nrow(features_df) == 0) {
        return(list(predictions = data.frame(), metrics = list(accuracy=0,auc=0,precision=0,recall=0), importance = data.frame()))
      }

      # Risk label yaratma (hədəf dəyişən)
      features_df$is_risk <- as.factor(ifelse(
        features_df$avg_score < 51 |
        features_df$attendance_pct < 75 |
        (features_df$score_trend < -10 & features_df$avg_score < 65), 1, 0))

      # Model xüsusiyyətləri
      feature_cols <- c("avg_score", "score_sd", "score_trend", "attendance_pct",
                        "absent_count", "hw_completion", "grade", "age")
      model_df <- features_df[, c(feature_cols, "is_risk")]
      model_df <- model_df[complete.cases(model_df), ]

      if (nrow(model_df) < 10) {
        # Kifayət qədər data yoxdursa, sadə heuristik istifadə et
        features_df$risk_score <- calculate_heuristic_risk(features_df)
        features_df$risk_category <- cut(features_df$risk_score,
          breaks = c(-1, 40, 65, 101), labels = c("aşağı", "orta", "yüksək"))
        return(list(
          predictions = features_df,
          metrics = list(accuracy = 0, auc = 0, precision = 0, recall = 0),
          importance = data.frame(
            feature = c("Orta bal", "Davamiyyət", "Bal trendi", "Ev tapşırığı", "Qayıb gün", "Yaş"),
            importance = c(0.30, 0.25, 0.18, 0.12, 0.10, 0.05))
        ))
      }

      # Train/Test bölmə
      set.seed(42)
      train_idx <- sample(seq_len(nrow(model_df)), size = floor(0.7 * nrow(model_df)))
      train_data <- model_df[train_idx, ]
      test_data <- model_df[-train_idx, ]

      # Model öyrət
      trained_model <- NULL
      if (model_type == "rf") {
        trained_model <- tryCatch(
          randomForest::randomForest(is_risk ~ ., data = train_data, ntree = 200, importance = TRUE),
          error = function(e) NULL)
      } else {
        trained_model <- tryCatch(
          glm(is_risk ~ ., data = train_data, family = binomial),
          error = function(e) NULL)
      }

      if (is.null(trained_model)) {
        features_df$risk_score <- calculate_heuristic_risk(features_df)
        features_df$risk_category <- cut(features_df$risk_score,
          breaks = c(-1, 40, 65, 101), labels = c("aşağı", "orta", "yüksək"))
        return(list(predictions = features_df,
          metrics = list(accuracy=0, auc=0, precision=0, recall=0),
          importance = data.frame(feature = feature_cols, importance = rep(1/length(feature_cols), length(feature_cols)))))
      }

      # Metrikləri hesabla
      metrics <- calculate_model_metrics(trained_model, test_data, model_type)

      # Dəyişən əhəmiyyətliyi
      imp_df <- extract_importance(trained_model, feature_cols, model_type)

      # Bütün dataya proqnoz ver
      pred_features <- features_df[, feature_cols]
      pred_features <- pred_features[complete.cases(pred_features), ]

      if (model_type == "rf") {
        risk_probs <- tryCatch(
          predict(trained_model, pred_features, type = "prob")[, "1"],
          error = function(e) rep(0.5, nrow(pred_features)))
      } else {
        risk_probs <- tryCatch(
          predict(trained_model, pred_features, type = "response"),
          error = function(e) rep(0.5, nrow(pred_features)))
      }

      features_df$risk_score <- round(as.numeric(risk_probs) * 100, 1)
      features_df$risk_category <- cut(features_df$risk_score,
        breaks = c(-1, 40, 65, 101), labels = c("aşağı", "orta", "yüksək"))

      model_object(trained_model)
      last_trained(Sys.time())

      list(predictions = features_df, metrics = metrics, importance = imp_df)
    }

    # ==========================================
    # PROQNOZLAma Düyməsi
    # ==========================================
    observeEvent(input$btn_predict, {
      withProgress(message = "Data hazırlanır...", value = 0.2, {
        features <- extract_student_features(input$school)

        setProgress(value = 0.5, message = "Model öyrədilir...")
        results <- train_and_predict(features, input$model)

        setProgress(value = 0.9, message = "Nəticələr hazırlanır...")
        risk_predictions(results$predictions)
        model_metrics(results$metrics)
        feature_importance(results$importance)
        setProgress(value = 1)
      })
    })

    # ==========================================
    # METRİKLƏR
    # ==========================================
    output$accuracy <- renderText({
      m <- model_metrics()
      if (m$accuracy > 0) paste0(round(m$accuracy * 100, 1), "%") else "—"
    })
    output$accuracy_label <- renderText({
      m <- model_metrics()
      if (m$accuracy == 0) "Model hələ öyrədilməyib" else ""
    })
    output$auc <- renderText({
      m <- model_metrics()
      if (m$auc > 0) round(m$auc, 3) else "—"
    })
    output$precision <- renderText({
      m <- model_metrics()
      if (m$precision > 0) paste0(round(m$precision * 100, 1), "%") else "—"
    })
    output$recall <- renderText({
      m <- model_metrics()
      if (m$recall > 0) paste0(round(m$recall * 100, 1), "%") else "—"
    })

    # ==========================================
    # QRAFİKLƏR
    # ==========================================
    output$importance_chart <- renderPlotly({
      imp <- feature_importance()
      if (nrow(imp) == 0) return(plotly_empty("Modeli öyrədin"))

      label_map <- c(avg_score = "Orta bal", score_sd = "Bal dəyişkənliyi", score_trend = "Bal trendi",
        attendance_pct = "Davamiyyət %", absent_count = "Qayıb gün", hw_completion = "Ev tapşırığı %",
        grade = "Sinif", age = "Yaş")
      imp$label <- ifelse(imp$feature %in% names(label_map), label_map[imp$feature], imp$feature)

      plot_ly(imp, x = ~importance, y = ~reorder(label, importance), type = "bar", orientation = "h",
              marker = list(color = "#3498db")) %>%
        layout(xaxis = list(title = "Əhəmiyyətlilik"), yaxis = list(title = ""), margin = list(l = 150))
    })

    output$risk_distribution <- renderPlotly({
      preds <- risk_predictions()
      if (nrow(preds) == 0) return(plotly_empty("Proqnoz hələ aparılmayıb"))

      plot_ly(preds, x = ~risk_score, type = "histogram",
              marker = list(color = ifelse(preds$risk_score > 65, "#e74c3c",
                ifelse(preds$risk_score > 40, "#f39c12", "#27ae60")))) %>%
        layout(xaxis = list(title = "Risk Balı (0-100)"), yaxis = list(title = "Şagird Sayı"),
               shapes = list(
                 list(type = "line", x0 = 65, x1 = 65, y0 = 0, y1 = 1, yref = "paper",
                   line = list(color = "#e74c3c", dash = "dash", width = 2)),
                 list(type = "line", x0 = 40, x1 = 40, y0 = 0, y1 = 1, yref = "paper",
                   line = list(color = "#f39c12", dash = "dash", width = 2))
               ))
    })

    # ==========================================
    # RİSK SAYĞACLARI
    # ==========================================
    output$high_risk_count <- renderText({
      preds <- risk_predictions()
      if (nrow(preds) == 0) return("0")
      sum(preds$risk_score > input$risk_threshold, na.rm = TRUE)
    })
    output$medium_risk_count <- renderText({
      preds <- risk_predictions()
      if (nrow(preds) == 0) return("0")
      sum(preds$risk_score > 40 & preds$risk_score <= input$risk_threshold, na.rm = TRUE)
    })
    output$low_risk_count <- renderText({
      preds <- risk_predictions()
      if (nrow(preds) == 0) return("0")
      sum(preds$risk_score <= 40, na.rm = TRUE)
    })

    # ==========================================
    # RİSK CƏDVƏLİ
    # ==========================================
    output$risk_table <- renderDT({
      preds <- risk_predictions()
      if (nrow(preds) == 0) return(datatable(data.frame("Proqnoz aparılmayıb" = character(0))))

      display <- preds %>%
        select(first_name, last_name, school_name, grade, section,
               avg_score, attendance_pct, score_trend, hw_completion, risk_score, risk_category)
      names(display) <- c("Ad", "Soyad", "Məktəb", "Sinif", "Bölmə",
                           "Orta Bal", "Davamiyyət%", "Trend", "Ev Tapş%", "Risk Balı", "Risk")

      # Filterlər
      if (!is_empty(input$risk_grade)) {
        display <- display[display$Sinif == as.integer(input$risk_grade), ]
      }
      if (!is_empty(input$risk_category)) {
        display <- display[display$Risk == input$risk_category, ]
      }

      display <- display[order(-display$`Risk Balı`), ]

      datatable(display, options = default_dt_options(15), selection = "multiple") %>%
        formatRound(c("Orta Bal", "Davamiyyət%", "Trend", "Ev Tapş%", "Risk Balı"), 1) %>%
        formatStyle("Risk Balı",
          backgroundColor = styleInterval(c(40, 65), c("#d5f5e3", "#fdebd0", "#fadbd8")),
          fontWeight = "bold") %>%
        formatStyle("Risk",
          color = styleEqual(c("yüksək", "orta", "aşağı"), c("#e74c3c", "#f39c12", "#27ae60")),
          fontWeight = "bold")
    })

    # ==========================================
    # MÜƏLLİMLƏRƏ BİLDİRİŞ
    # ==========================================
    observeEvent(input$btn_notify_teachers, {
      preds <- risk_predictions()
      req(nrow(preds) > 0)

      high_risk <- preds[preds$risk_score > input$risk_threshold, ]
      if (nrow(high_risk) == 0) {
        notify_warning("Seçilmiş həddə uyğun yüksək riskli şagird yoxdur.")
        return()
      }

      withProgress(message = "Bildirişlər göndərilir...", value = 0, {
        sent <- 0
        # Hər şagird üçün sinif müəllimini tap və bildiriş göndər
        for (i in seq_len(nrow(high_risk))) {
          s <- high_risk[i, ]
          # Şagirdin müəllimlərini tap
          teachers <- tryCatch(
            db_query(db_pool,
              "SELECT DISTINCT t.user_id FROM teachers t
               JOIN grades g ON g.teacher_id = t.id
               WHERE g.student_id = $1 AND g.grade_date >= CURRENT_DATE - INTERVAL '3 months'",
              params = list(s$student_id)),
            error = function(e) data.frame()
          )
          if (nrow(teachers) > 0) {
            for (j in seq_len(nrow(teachers))) {
              tryCatch(
                db_execute(db_pool,
                  "INSERT INTO notifications (user_id, title, message, type, created_at)
                   VALUES ($1, $2, $3, 'warning', NOW())",
                  params = list(
                    teachers$user_id[j],
                    paste0("Yüksək Risk: ", s$first_name, " ", s$last_name),
                    paste0(s$first_name, " ", s$last_name, " (", s$grade, s$section, ") ",
                           "risk balı: ", round(s$risk_score, 1), "%. ",
                           "Orta bal: ", round(s$avg_score, 1), ", ",
                           "Davamiyyət: ", round(s$attendance_pct, 1), "%.")
                  )),
                error = function(e) NULL)
            }
            sent <- sent + 1
          }
          setProgress(value = i / nrow(high_risk))
        }
      })
      notify_success(paste0(nrow(high_risk), " şagird üçün müəllimlərə bildiriş göndərildi!"))
    })

    # ==========================================
    # AI TÖVSİYƏLƏR
    # ==========================================
    observeEvent(input$btn_ai_recommend, {
      preds <- risk_predictions()
      req(nrow(preds) > 0)

      # Seçilmiş sətirləri və ya yüksək riskliləri götür
      selected <- input$risk_table_rows_selected
      if (!is.null(selected) && length(selected) > 0) {
        sorted_preds <- preds[order(-preds$risk_score), ]
        target_students <- sorted_preds[selected, ]
      } else {
        target_students <- preds[preds$risk_score > input$risk_threshold, ]
        if (nrow(target_students) > 10) target_students <- head(target_students[order(-target_students$risk_score), ], 10)
      }

      if (nrow(target_students) == 0) {
        notify_warning("Tövsiyə üçün şagird seçin və ya risk həddini aşağı salın.")
        return()
      }

      student_summaries <- paste(sapply(seq_len(nrow(target_students)), function(i) {
        s <- target_students[i, ]
        paste0("- ", s$first_name, " ", s$last_name, " (", s$grade, s$section, "): ",
               "orta bal=", round(s$avg_score, 1), ", davamiyyət=", round(s$attendance_pct, 1),
               "%, trend=", round(s$score_trend, 1), ", ev tapşırığı=", round(s$hw_completion, 1),
               "%, risk=", round(s$risk_score, 1), "%")
      }), collapse = "\n")

      prompt <- paste0(
        "Aşağıdakı risk altında olan şagirdlər üçün fərdi tövsiyələr hazırla.\n\n",
        "Şagirdlər:\n", student_summaries, "\n\n",
        "Hər şagird üçün:\n",
        "1. Risk səbəbinin analizi (bal, davamiyyət, trend)\n",
        "2. Konkret müdaxilə strategiyası\n",
        "3. Hansı fənn(lər)də əlavə dəstək lazımdır\n",
        "4. Müəllim/valideyn üçün tövsiyə\n\n",
        "Cavabı JSON formatında qaytar:\n",
        "[{\"student_name\": \"...\", \"risk_factors\": [\"...\"], ",
        "\"interventions\": [\"...\"], \"subject_support\": [\"...\"], ",
        "\"teacher_action\": \"...\", \"parent_action\": \"...\", \"priority\": \"yüksək|orta\"}]"
      )

      system_prompt <- paste0(
        "Sən Azərbaycan təhsil sistemi üçün şagird riski analiz edən təcrübəli pedaqoq-psixoloqsan. ",
        "Data əsaslı, konkret və tətbiqi tövsiyələr verirsən. Azərbaycan dilində cavab ver. ",
        "Cavabı YALNIZ JSON formatında qaytar."
      )

      withProgress(message = "AI tövsiyələr hazırlanır...", value = 0.5, {
        result <- tryCatch(
          call_claude_api(prompt, system_prompt, max_tokens = 4096, temperature = 0.5),
          error = function(e) list(success = FALSE, message = e$message))

        if (result$success) {
          recs <- tryCatch(extract_json_from_response(result$message), error = function(e) NULL)
          ai_recs(recs)
        } else {
          notify_error(paste("AI xətası:", result$message))
        }
        setProgress(value = 1)
      })
    })

    # AI Tövsiyə paneli
    output$ai_recommendations_panel <- renderUI({
      recs <- ai_recs()
      if (is.null(recs)) return(NULL)

      if (!is.data.frame(recs)) {
        recs <- tryCatch(
          as.data.frame(do.call(rbind, lapply(recs, function(r) {
            data.frame(
              student_name = r$student_name %||% "?",
              risk_factors = paste(unlist(r$risk_factors), collapse = "; "),
              interventions = paste(unlist(r$interventions), collapse = "; "),
              subject_support = paste(unlist(r$subject_support), collapse = ", "),
              teacher_action = r$teacher_action %||% "",
              parent_action = r$parent_action %||% "",
              priority = r$priority %||% "orta",
              stringsAsFactors = FALSE)
          })), stringsAsFactors = FALSE),
          error = function(e) data.frame())
      }

      if (nrow(recs) == 0) return(NULL)

      wellPanel(
        h3(icon("robot"), "AI Fərdi Tövsiyələr"),
        lapply(seq_len(nrow(recs)), function(i) {
          r <- recs[i, ]
          priority_color <- if (r$priority == "yüksək") "#e74c3c" else "#f39c12"
          tags$div(
            style = paste0("border: 1px solid #ddd; border-left: 5px solid ", priority_color,
                           "; border-radius: 8px; padding: 14px; margin-bottom: 12px;"),
            tags$h4(style = "margin-top: 0;", icon("user-graduate"), " ", r$student_name,
              tags$span(style = paste0("float:right;color:", priority_color, ";font-size:0.8em;"),
                toupper(r$priority), " prioritet")),
            tags$div(style = "display: grid; grid-template-columns: 1fr 1fr; gap: 10px; font-size: 0.9em;",
              tags$div(
                tags$strong(style = "color: #e74c3c;", icon("exclamation-triangle"), " Risk faktorları:"),
                tags$p(r$risk_factors)
              ),
              tags$div(
                tags$strong(style = "color: #3498db;", icon("tools"), " Müdaxilə:"),
                tags$p(r$interventions)
              ),
              tags$div(
                tags$strong(style = "color: #27ae60;", icon("book"), " Fənn dəstəyi:"),
                tags$p(r$subject_support)
              ),
              tags$div(
                tags$strong(style = "color: #8e44ad;", icon("chalkboard-teacher"), " Müəllim üçün:"),
                tags$p(r$teacher_action)
              )
            ),
            if (nchar(r$parent_action) > 0) tags$div(style = "margin-top: 6px; font-size: 0.85em; color: #666;",
              tags$strong(icon("home"), " Valideyn üçün: "), r$parent_action)
          )
        })
      )
    })

    # ==========================================
    # MODELİ YENİDƏN ÖYRƏT
    # ==========================================
    observeEvent(input$btn_retrain, {
      withProgress(message = "Model yenidən öyrədilir...", value = 0.3, {
        features <- extract_student_features(NULL)  # bütün məktəblər
        setProgress(value = 0.6, message = "Random Forest öyrədilir...")
        results <- train_and_predict(features, "rf")
        risk_predictions(results$predictions)
        model_metrics(results$metrics)
        feature_importance(results$importance)
        setProgress(value = 1)
      })
      notify_success("Model uğurla yenidən öyrədildi!")
    })

    output$last_train_info <- renderText({
      lt <- last_trained()
      if (is.null(lt)) "Son öyrətmə: hələ öyrədilməyib"
      else paste0("Son öyrətmə: ", format(lt, "%d.%m.%Y %H:%M"))
    })

    output$model_version <- renderText({
      mo <- model_object()
      if (is.null(mo)) "Model: —"
      else if (inherits(mo, "randomForest")) paste0("Model: Random Forest (", mo$ntree, " ağac)")
      else "Model: Logistik Reqressiya"
    })
  })
}

# =============================================
# KÖMƏKÇI FUNKSİYALAR
# =============================================

#' Heuristik risk hesablama (ML olmadan fallback)
calculate_heuristic_risk <- function(df) {
  risk <- rep(0, nrow(df))
  # Orta bal — ən böyük ağırlıq
  risk <- risk + pmax(0, (60 - df$avg_score)) * 1.2
  # Davamiyyət
  risk <- risk + pmax(0, (85 - df$attendance_pct)) * 0.8
  # Bal trendi (mənfi trend risk artırır)
  risk <- risk + pmax(0, -df$score_trend) * 1.0
  # Ev tapşırığı
  risk <- risk + pmax(0, (70 - df$hw_completion)) * 0.5
  # Qayıb günlər
  risk <- risk + df$absent_count * 1.5
  # 0-100 arasına normallaşdır
  risk <- pmin(100, pmax(0, risk))
  round(risk, 1)
}

#' Model metrikləri hesabla
calculate_model_metrics <- function(model, test_data, model_type) {
  tryCatch({
    if (model_type == "rf") {
      pred <- predict(model, test_data)
      pred_prob <- predict(model, test_data, type = "prob")[, "1"]
    } else {
      pred_prob <- predict(model, test_data, type = "response")
      pred <- factor(ifelse(pred_prob > 0.5, 1, 0), levels = c("0", "1"))
    }

    actual <- test_data$is_risk
    cm <- table(Predicted = pred, Actual = actual)

    tp <- if ("1" %in% rownames(cm) && "1" %in% colnames(cm)) cm["1", "1"] else 0
    fp <- if ("1" %in% rownames(cm) && "0" %in% colnames(cm)) cm["1", "0"] else 0
    fn <- if ("0" %in% rownames(cm) && "1" %in% colnames(cm)) cm["0", "1"] else 0
    tn <- if ("0" %in% rownames(cm) && "0" %in% colnames(cm)) cm["0", "0"] else 0

    accuracy <- (tp + tn) / max(1, tp + tn + fp + fn)
    precision <- tp / max(1, tp + fp)
    recall <- tp / max(1, tp + fn)

    auc_val <- tryCatch({
      roc_obj <- pROC::roc(as.numeric(as.character(actual)), pred_prob, quiet = TRUE)
      as.numeric(pROC::auc(roc_obj))
    }, error = function(e) 0)

    list(accuracy = accuracy, auc = auc_val, precision = precision, recall = recall)
  }, error = function(e) {
    list(accuracy = 0, auc = 0, precision = 0, recall = 0)
  })
}

#' Dəyişən əhəmiyyətliliyini çıxar
extract_importance <- function(model, feature_cols, model_type) {
  tryCatch({
    if (model_type == "rf") {
      imp <- randomForest::importance(model)
      df <- data.frame(
        feature = rownames(imp),
        importance = imp[, "MeanDecreaseGini"],
        stringsAsFactors = FALSE)
    } else {
      coefs <- abs(coef(model)[-1])  # intercept-i çıxar
      df <- data.frame(
        feature = names(coefs),
        importance = as.numeric(coefs),
        stringsAsFactors = FALSE)
    }
    df$importance <- df$importance / max(df$importance, na.rm = TRUE)
    df[order(-df$importance), ]
  }, error = function(e) {
    data.frame(feature = feature_cols, importance = rep(0, length(feature_cols)))
  })
}

#' Plotly boş qrafik
plotly_empty <- function(msg = "") {
  plot_ly() %>%
    layout(
      xaxis = list(visible = FALSE), yaxis = list(visible = FALSE),
      annotations = list(list(text = msg, showarrow = FALSE,
        font = list(size = 14, color = "#999"))))
}

#' Avtomatik aylıq yenidən öyrətmə (cron job-dan çağırılır)
scheduled_retrain <- function(db_pool) {
  tryCatch({
    logger::log_info("Aylıq model yenidən öyrətmə başladı")

    # Bütün şagirdlər üçün feature-lər
    scores <- db_query(db_pool,
      "SELECT g.student_id, AVG(g.score) as avg_score, STDDEV(g.score) as score_sd,
              COUNT(g.id) as grade_count
       FROM grades g WHERE g.grade_date >= CURRENT_DATE - INTERVAL '6 months'
       GROUP BY g.student_id")

    trends <- db_query(db_pool,
      "SELECT student_id,
              AVG(CASE WHEN grade_date >= CURRENT_DATE - INTERVAL '3 months' THEN score END) as recent_avg,
              AVG(CASE WHEN grade_date < CURRENT_DATE - INTERVAL '3 months'
                       AND grade_date >= CURRENT_DATE - INTERVAL '6 months' THEN score END) as prev_avg
       FROM grades WHERE grade_date >= CURRENT_DATE - INTERVAL '6 months'
       GROUP BY student_id")

    attendance <- db_query(db_pool,
      "SELECT student_id,
              COUNT(CASE WHEN status = 'iştirak' THEN 1 END)::float /
                NULLIF(COUNT(id), 0) * 100 as attendance_pct,
              COUNT(CASE WHEN status = 'qayıb' THEN 1 END) as absent_count
       FROM attendance WHERE attendance_date >= CURRENT_DATE - INTERVAL '3 months'
       GROUP BY student_id")

    homework <- db_query(db_pool,
      "SELECT student_id,
              COUNT(CASE WHEN grade_type = 'gündəlik' AND score > 0 THEN 1 END)::float /
                NULLIF(COUNT(CASE WHEN grade_type = 'gündəlik' THEN 1 END), 0) * 100 as hw_completion
       FROM grades WHERE grade_date >= CURRENT_DATE - INTERVAL '3 months'
       GROUP BY student_id")

    students <- db_query(db_pool,
      "SELECT s.id as student_id, c.grade, EXTRACT(YEAR FROM age(s.birth_date)) as age
       FROM students s LEFT JOIN classes c ON s.class_id = c.id WHERE s.status = 'active'")

    if (nrow(students) == 0) { logger::log_warn("Öyrətmə üçün data tapılmadı"); return(invisible(NULL)) }

    df <- students
    if (nrow(scores) > 0) df <- merge(df, scores, by = "student_id", all.x = TRUE)
    if (nrow(trends) > 0) df <- merge(df, trends, by = "student_id", all.x = TRUE)
    if (nrow(attendance) > 0) df <- merge(df, attendance, by = "student_id", all.x = TRUE)
    if (nrow(homework) > 0) df <- merge(df, homework, by = "student_id", all.x = TRUE)

    df$avg_score <- ifelse(is.na(df$avg_score), 50, df$avg_score)
    df$score_sd <- ifelse(is.na(df$score_sd), 15, df$score_sd)
    df$grade_count <- ifelse(is.na(df$grade_count), 0, df$grade_count)
    df$recent_avg <- ifelse(is.na(df$recent_avg), df$avg_score, df$recent_avg)
    df$prev_avg <- ifelse(is.na(df$prev_avg), df$avg_score, df$prev_avg)
    df$score_trend <- df$recent_avg - df$prev_avg
    df$attendance_pct <- ifelse(is.na(df$attendance_pct), 85, df$attendance_pct)
    df$absent_count <- ifelse(is.na(df$absent_count), 0, df$absent_count)
    df$hw_completion <- ifelse(is.na(df$hw_completion), 70, df$hw_completion)
    df$age <- ifelse(is.na(df$age), 14, df$age)
    df$grade <- ifelse(is.na(df$grade), 8, df$grade)

    df$is_risk <- as.factor(ifelse(df$avg_score < 51 | df$attendance_pct < 75 |
      (df$score_trend < -10 & df$avg_score < 65), 1, 0))

    feature_cols <- c("avg_score", "score_sd", "score_trend", "attendance_pct",
                      "absent_count", "hw_completion", "grade", "age")
    model_df <- df[, c(feature_cols, "is_risk")]
    model_df <- model_df[complete.cases(model_df), ]

    if (nrow(model_df) < 20) { logger::log_warn("Kifayət qədər data yoxdur"); return(invisible(NULL)) }

    model <- randomForest::randomForest(is_risk ~ ., data = model_df, ntree = 300, importance = TRUE)

    # Modeli saxla
    model_path <- file.path("data", "models", "risk_model.rds")
    dir.create(dirname(model_path), showWarnings = FALSE, recursive = TRUE)
    saveRDS(list(model = model, trained_at = Sys.time(), n_samples = nrow(model_df)), model_path)

    logger::log_info("Model uğurla saxlandı: {model_path}, n={nrow(model_df)}")
    invisible(model)
  }, error = function(e) {
    logger::log_error("Aylıq öyrətmə xətası: {e$message}")
    invisible(NULL)
  })
}
