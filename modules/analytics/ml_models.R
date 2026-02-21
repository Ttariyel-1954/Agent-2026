# =============================================
# ARTI-2026: ML Model İdarəetmə və Doğrulama
# Gün 16: Model yaradılması + Gün 19: Doğrulama
# =============================================

# =============================================
# UI
# =============================================
ml_models_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(column(12, h2(icon("brain"), "ML Model İdarəetmə"),
      tags$p(class = "text-muted", "Model öyrətmə, doğrulama, müqayisə və performans izləmə"), hr())),

    # Statistika valueBoxes
    fluidRow(
      valueBoxOutput(ns("stat_models_count"), width = 3),
      valueBoxOutput(ns("stat_best_accuracy"), width = 3),
      valueBoxOutput(ns("stat_best_auc"), width = 3),
      valueBoxOutput(ns("stat_last_trained"), width = 3)
    ),

    fluidRow(
      # Sol panel - Model öyrətmə
      column(4,
        box(title = tagList(icon("cog"), " Model Parametrləri"), status = "primary", solidHeader = TRUE, width = 12,
          selectInput(ns("ml_model_type"), "Model növü:", choices = c(
            "Random Forest" = "rf", "Logistik Reqressiya" = "glm",
            "Ensemble (Ağırlıqlı)" = "ensemble")),
          selectInput(ns("ml_target"), "Hədəf dəyişən:", choices = c(
            "Tərk Riski" = "dropout", "Performans" = "performance", "Davamiyyət Riski" = "attendance")),
          sliderInput(ns("ml_train_split"), "Öyrətmə/Test nisbəti:", min = 0.5, max = 0.9, value = 0.7, step = 0.05),

          tags$hr(),
          tags$h5("Random Forest Parametrləri"),
          conditionalPanel(
            condition = sprintf("input['%s'] == 'rf' || input['%s'] == 'ensemble'", ns("ml_model_type"), ns("ml_model_type")),
            fluidRow(
              column(6, numericInput(ns("ml_ntree"), "Ağac sayı:", value = 200, min = 50, max = 1000, step = 50)),
              column(6, numericInput(ns("ml_mtry"), "mtry:", value = 3, min = 1, max = 8))
            )
          ),

          tags$hr(),
          tags$h5("Cross-Validation"),
          fluidRow(
            column(6, numericInput(ns("ml_cv_folds"), "K-fold:", value = 5, min = 3, max = 10)),
            column(6, checkboxInput(ns("ml_cv_enable"), "CV aktiv", value = TRUE))
          ),

          selectInput(ns("ml_school_filter"), "Məktəb:", choices = c("Bütün məktəblər" = "")),

          tags$div(style = "margin-top:10px;",
            actionButton(ns("btn_ml_train"), "Modeli Öyrət", icon = icon("play"), class = "btn-success btn-lg btn-block"),
            tags$br(),
            fluidRow(
              column(6, actionButton(ns("btn_ml_save"), "Modeli Saxla", icon = icon("save"), class = "btn-primary btn-block")),
              column(6, actionButton(ns("btn_ml_load"), "Model Yüklə", icon = icon("upload"), class = "btn-info btn-block"))
            )
          )
        ),

        # Saxlanmış modellər
        box(title = tagList(icon("archive"), " Saxlanmış Modellər"), status = "info", solidHeader = TRUE, width = 12, collapsible = TRUE, collapsed = TRUE,
          DTOutput(ns("ml_saved_models_table")),
          actionButton(ns("btn_ml_delete_model"), "Seçilmişi Sil", icon = icon("trash"), class = "btn-danger btn-sm", style = "margin-top:6px;")
        )
      ),

      # Sağ panel - Nəticələr
      column(8,
        # Model metrikləri
        box(title = tagList(icon("chart-bar"), " Model Metrikləri"), status = "success", solidHeader = TRUE, width = 12,
          uiOutput(ns("ml_metrics_panel")),
          tags$hr(),
          fluidRow(
            column(6, plotlyOutput(ns("ml_roc_curve"), height = "320px")),
            column(6, plotlyOutput(ns("ml_confusion_matrix"), height = "320px"))
          )
        ),

        # Feature importance + CV results
        box(title = tagList(icon("sort-amount-down"), " Dəyişən Əhəmiyyətliyi"), status = "warning", solidHeader = TRUE, width = 12,
          fluidRow(
            column(6, plotlyOutput(ns("ml_importance_chart"), height = "300px")),
            column(6, plotlyOutput(ns("ml_cv_results_chart"), height = "300px"))
          )
        ),

        # Model müqayisəsi
        box(title = tagList(icon("balance-scale"), " Model Müqayisəsi"), status = "info", solidHeader = TRUE, width = 12, collapsible = TRUE,
          actionButton(ns("btn_ml_compare"), "Bütün Modelləri Müqayisə Et", icon = icon("exchange-alt"), class = "btn-warning"),
          tags$br(), tags$br(),
          DTOutput(ns("ml_comparison_table")),
          plotlyOutput(ns("ml_comparison_chart"), height = "300px")
        ),

        # Model tarixçəsi
        box(title = tagList(icon("history"), " Öyrətmə Tarixçəsi"), status = "primary", solidHeader = TRUE, width = 12, collapsible = TRUE, collapsed = TRUE,
          DTOutput(ns("ml_history_table"))
        )
      )
    )
  )
}

# =============================================
# SERVER
# =============================================
ml_models_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Reactive values
    trained_model <- reactiveVal(NULL)
    model_metrics <- reactiveVal(NULL)
    cv_results <- reactiveVal(NULL)
    feature_imp <- reactiveVal(NULL)
    roc_data <- reactiveVal(NULL)
    confusion_data <- reactiveVal(NULL)
    comparison_results <- reactiveVal(data.frame())
    train_history <- reactiveVal(data.frame())

    # Load schools for filter
    observe({
      schools <- tryCatch(
        db_query(db_pool, "SELECT id, name FROM schools WHERE status = 'active' ORDER BY name"),
        error = function(e) data.frame()
      )
      if (nrow(schools) > 0) {
        updateSelectInput(session, "ml_school_filter",
          choices = c("Bütün məktəblər" = "", setNames(schools$id, schools$name)))
      }
    })

    # ---- Statistics ----
    output$stat_models_count <- renderValueBox({
      model_dir <- file.path("data", "models")
      count <- if (dir.exists(model_dir)) length(list.files(model_dir, pattern = "\\.rds$")) else 0
      valueBox(count, "Saxlanmış Model", icon = icon("database"), color = "blue")
    })

    output$stat_best_accuracy <- renderValueBox({
      m <- model_metrics()
      val <- if (!is.null(m)) paste0(round(m$accuracy * 100, 1), "%") else "\u2014"
      valueBox(val, "Cari Dəqiqlik", icon = icon("check-circle"), color = "green")
    })

    output$stat_best_auc <- renderValueBox({
      m <- model_metrics()
      val <- if (!is.null(m)) round(m$auc, 3) else "\u2014"
      valueBox(val, "Cari AUC", icon = icon("chart-area"), color = "yellow")
    })

    output$stat_last_trained <- renderValueBox({
      m <- trained_model()
      val <- if (!is.null(m)) format(m$trained_at, "%d.%m %H:%M") else "\u2014"
      valueBox(val, "Son Öyrətmə", icon = icon("clock"), color = "purple")
    })

    # ---- FEATURE ENGINEERING ----
    prepare_features <- function(school_filter = NULL) {
      df <- extract_student_features(school_filter)
      if (nrow(df) == 0) return(data.frame())

      # Additional engineered features
      df$score_volatility <- df$score_sd / pmax(df$avg_score, 1)
      df$absence_rate <- df$absent_count / 90 * 100
      df$hw_gap <- pmax(0, 80 - df$hw_completion)
      df$is_declining <- as.integer(df$score_trend < -5)
      df$engagement_score <- (df$attendance_pct * 0.4 + df$hw_completion * 0.3 + pmin(100, df$avg_score) * 0.3)

      df
    }

    # ---- CREATE TARGET VARIABLE ----
    create_target <- function(df, target_type) {
      if (target_type == "dropout") {
        as.factor(ifelse(
          df$avg_score < 51 | df$attendance_pct < 75 | (df$score_trend < -10 & df$avg_score < 65),
          1, 0))
      } else if (target_type == "performance") {
        as.factor(ifelse(
          df$avg_score < 60 | (df$score_trend < -8 & df$hw_completion < 60),
          1, 0))
      } else {
        as.factor(ifelse(
          df$attendance_pct < 80 | df$absent_count > 15,
          1, 0))
      }
    }

    # ---- MODEL TRAIN ----
    observeEvent(input$btn_ml_train, {
      withProgress(message = "Data haz\u0131rlan\u0131r...", value = 0.1, {

        # 1. Feature extraction
        features <- prepare_features(input$ml_school_filter)
        if (nrow(features) < 20) {
          notify_warning("Kifay\u0259t q\u0259d\u0259r data yoxdur (minimum 20 \u015Fagird).")
          return()
        }

        # 2. Create target
        features$target <- create_target(features, input$ml_target)

        feature_cols <- c("avg_score", "score_sd", "score_trend", "attendance_pct",
                         "absent_count", "hw_completion", "grade", "age",
                         "score_volatility", "absence_rate", "hw_gap", "engagement_score")

        model_df <- features[, c(feature_cols, "target")]
        model_df <- model_df[complete.cases(model_df), ]

        if (nrow(model_df) < 20) {
          notify_warning("Complete cases 20-d\u0259n azd\u0131r.")
          return()
        }

        setProgress(0.3, detail = "Model \u00F6yr\u0259dilir...")

        # 3. Train/test split
        set.seed(42)
        train_idx <- sample(seq_len(nrow(model_df)), size = floor(input$ml_train_split * nrow(model_df)))
        train_data <- model_df[train_idx, ]
        test_data <- model_df[-train_idx, ]

        # 4. Train model
        model_type <- input$ml_model_type
        model_obj <- NULL

        if (model_type == "rf") {
          model_obj <- tryCatch(
            randomForest::randomForest(target ~ ., data = train_data,
              ntree = input$ml_ntree,
              mtry = min(input$ml_mtry, length(feature_cols)),
              importance = TRUE),
            error = function(e) { notify_error(paste("RF x\u0259tas\u0131:", e$message)); NULL }
          )
        } else if (model_type == "glm") {
          model_obj <- tryCatch(
            glm(target ~ ., data = train_data, family = binomial),
            error = function(e) { notify_error(paste("GLM x\u0259tas\u0131:", e$message)); NULL }
          )
        } else {
          # Ensemble: RF + GLM
          rf_model <- tryCatch(
            randomForest::randomForest(target ~ ., data = train_data, ntree = input$ml_ntree, importance = TRUE),
            error = function(e) NULL
          )
          glm_model <- tryCatch(
            glm(target ~ ., data = train_data, family = binomial),
            error = function(e) NULL
          )
          if (!is.null(rf_model) && !is.null(glm_model)) {
            model_obj <- list(rf = rf_model, glm = glm_model, type = "ensemble",
                             weights = c(rf = 0.7, glm = 0.3))
          }
        }

        if (is.null(model_obj)) {
          notify_error("Model \u00F6yr\u0259dil\u0259 bilm\u0259di.")
          return()
        }

        setProgress(0.6, detail = "Metrikl\u0259r hesablan\u0131r...")

        # 5. Predict on test
        pred_results <- predict_model(model_obj, test_data, model_type, feature_cols)

        # 6. Calculate metrics
        metrics <- calculate_full_metrics(pred_results$pred_class, pred_results$pred_prob, test_data$target)
        model_metrics(metrics)

        # 7. ROC data
        roc_d <- calculate_roc_data(pred_results$pred_prob, test_data$target)
        roc_data(roc_d)

        # 8. Confusion matrix
        cm <- table(Predicted = pred_results$pred_class, Actual = test_data$target)
        confusion_data(cm)

        # 9. Feature importance
        imp <- extract_feature_importance(model_obj, model_type, feature_cols)
        feature_imp(imp)

        setProgress(0.8, detail = "Cross-validation...")

        # 10. Cross-validation
        if (isTRUE(input$ml_cv_enable)) {
          cv_res <- run_cross_validation(model_df, model_type, input$ml_cv_folds,
                                         feature_cols, input$ml_ntree)
          cv_results(cv_res)
        }

        # Store model
        trained_model(list(
          model = model_obj, type = model_type, target = input$ml_target,
          features = feature_cols, n_samples = nrow(model_df),
          n_train = nrow(train_data), n_test = nrow(test_data),
          metrics = metrics, trained_at = Sys.time()
        ))

        # Update history
        hist <- train_history()
        new_row <- data.frame(
          Tarix = format(Sys.time(), "%d.%m.%Y %H:%M"),
          Model = model_type,
          "H\u0259d\u0259f" = input$ml_target,
          "N\u00FCmun\u0259" = nrow(model_df),
          "D\u0259qiqlik" = paste0(round(metrics$accuracy * 100, 1), "%"),
          AUC = round(metrics$auc, 3),
          F1 = round(metrics$f1, 3),
          stringsAsFactors = FALSE,
          check.names = FALSE
        )
        train_history(rbind(new_row, hist))

        setProgress(1)
      })
      notify_success("Model u\u011Furla \u00F6yr\u0259dildi!")
    })

    # ---- PREDICT HELPER ----
    predict_model <- function(model_obj, test_data, model_type, feature_cols) {
      if (model_type == "rf") {
        pred_class <- predict(model_obj, test_data)
        pred_prob <- predict(model_obj, test_data, type = "prob")[, "1"]
      } else if (model_type == "glm") {
        pred_prob <- predict(model_obj, test_data, type = "response")
        pred_class <- factor(ifelse(pred_prob > 0.5, 1, 0), levels = c("0", "1"))
      } else {
        # Ensemble
        rf_prob <- predict(model_obj$rf, test_data, type = "prob")[, "1"]
        glm_prob <- predict(model_obj$glm, test_data, type = "response")
        pred_prob <- model_obj$weights["rf"] * rf_prob + model_obj$weights["glm"] * glm_prob
        pred_class <- factor(ifelse(pred_prob > 0.5, 1, 0), levels = c("0", "1"))
      }
      list(pred_class = pred_class, pred_prob = pred_prob)
    }

    # ---- METRICS PANEL ----
    output$ml_metrics_panel <- renderUI({
      m <- model_metrics()
      if (is.null(m)) {
        return(tags$p(class = "text-muted", "Modeli \u00F6yr\u0259din \u2014 n\u0259tic\u0259l\u0259r burada g\u00F6st\u0259ril\u0259c\u0259k"))
      }

      make_metric <- function(label, value, color) {
        tags$div(style = "text-align:center; padding:10px;",
          tags$h2(style = paste0("color:", color, "; margin:0;"), value),
          tags$small(label))
      }

      fluidRow(
        column(2, make_metric("D\u0259qiqlik", paste0(round(m$accuracy * 100, 1), "%"), "#27ae60")),
        column(2, make_metric("AUC", round(m$auc, 3), "#3498db")),
        column(2, make_metric("Precision", paste0(round(m$precision * 100, 1), "%"), "#9b59b6")),
        column(2, make_metric("Recall", paste0(round(m$recall * 100, 1), "%"), "#f39c12")),
        column(2, make_metric("F1", round(m$f1, 3), "#e74c3c")),
        column(2, make_metric("Specificity", paste0(round(m$specificity * 100, 1), "%"), "#1abc9c"))
      )
    })

    # ---- ROC CURVE ----
    output$ml_roc_curve <- renderPlotly({
      rd <- roc_data()
      if (is.null(rd)) return(plotly_empty("ROC \u0259yrisi \u2014 model \u00F6yr\u0259din"))

      plot_ly() %>%
        add_trace(x = rd$fpr, y = rd$tpr, type = "scatter", mode = "lines",
          line = list(color = "#3498db", width = 3), name = "Model") %>%
        add_trace(x = c(0, 1), y = c(0, 1), type = "scatter", mode = "lines",
          line = list(color = "#bdc3c7", dash = "dash"), name = "Random") %>%
        layout(
          title = paste0("ROC \u018Fyrisi (AUC: ", round(rd$auc, 3), ")"),
          xaxis = list(title = "False Positive Rate"),
          yaxis = list(title = "True Positive Rate")
        )
    })

    # ---- CONFUSION MATRIX ----
    output$ml_confusion_matrix <- renderPlotly({
      cm <- confusion_data()
      if (is.null(cm)) return(plotly_empty("Confusion Matrix \u2014 model \u00F6yr\u0259din"))

      labels <- c("Neqativ (0)", "Pozitiv (1)")
      z_matrix <- matrix(0, nrow = 2, ncol = 2)
      for (i in rownames(cm)) {
        for (j in colnames(cm)) {
          ri <- as.integer(i) + 1
          ci <- as.integer(j) + 1
          if (ri >= 1 && ri <= 2 && ci >= 1 && ci <= 2) {
            z_matrix[ri, ci] <- cm[i, j]
          }
        }
      }

      plot_ly(
        z = z_matrix, x = labels, y = labels, type = "heatmap",
        colorscale = list(c(0, "#ecf0f1"), c(1, "#3498db")),
        text = z_matrix, texttemplate = "%{text}", showscale = FALSE
      ) %>%
        layout(
          title = "Confusion Matrix",
          xaxis = list(title = "H\u0259qiqi"),
          yaxis = list(title = "Proqnoz")
        )
    })

    # ---- IMPORTANCE CHART ----
    output$ml_importance_chart <- renderPlotly({
      imp <- feature_imp()
      if (is.null(imp) || nrow(imp) == 0) return(plotly_empty("D\u0259yi\u015F\u0259n \u0259h\u0259miyy\u0259tliyi"))

      label_map <- c(
        avg_score = "Orta bal",
        score_sd = "Bal d\u0259yi\u015Fk\u0259nliyi",
        score_trend = "Bal trendi",
        attendance_pct = "Davamiyy\u0259t%",
        absent_count = "Qay\u0131b g\u00FCn",
        hw_completion = "Ev tap\u015F\u0131r\u0131\u011F\u0131%",
        grade = "Sinif",
        age = "Ya\u015F",
        score_volatility = "Bal d\u0259yi\u015Fk\u0259nlik \u0259msal\u0131",
        absence_rate = "Qay\u0131b faizi",
        hw_gap = "Ev tap\u015F. bo\u015Flu\u011Fu",
        engagement_score = "C\u0259lb olunma bal\u0131"
      )
      imp$label <- ifelse(imp$feature %in% names(label_map), label_map[imp$feature], imp$feature)

      plot_ly(imp, x = ~importance, y = ~reorder(label, importance), type = "bar", orientation = "h",
        marker = list(color = "#e67e22")) %>%
        layout(
          title = "D\u0259yi\u015F\u0259n \u018Fh\u0259miyy\u0259tliyi",
          xaxis = list(title = ""),
          yaxis = list(title = ""),
          margin = list(l = 160)
        )
    })

    # ---- CV RESULTS CHART ----
    output$ml_cv_results_chart <- renderPlotly({
      cv <- cv_results()
      if (is.null(cv) || nrow(cv) == 0) return(plotly_empty("Cross-Validation n\u0259tic\u0259l\u0259ri"))

      plot_ly(cv, x = ~fold, y = ~accuracy, type = "bar", name = "D\u0259qiqlik",
        marker = list(color = "#27ae60")) %>%
        add_trace(y = ~auc, name = "AUC", marker = list(color = "#3498db")) %>%
        layout(
          title = paste0("K-Fold CV (Orta D\u0259qiqlik: ", round(mean(cv$accuracy) * 100, 1), "%)"),
          barmode = "group",
          xaxis = list(title = "Fold"),
          yaxis = list(title = "Bal", range = c(0, 1))
        )
    })

    # ---- MODEL COMPARISON ----
    observeEvent(input$btn_ml_compare, {
      withProgress(message = "Modell\u0259r m\u00FCqayis\u0259 edilir...", value = 0.1, {
        features <- prepare_features(input$ml_school_filter)
        if (nrow(features) < 20) {
          notify_warning("Kifay\u0259t q\u0259d\u0259r data yoxdur.")
          return()
        }

        features$target <- create_target(features, input$ml_target)
        feature_cols <- c("avg_score", "score_sd", "score_trend", "attendance_pct",
                         "absent_count", "hw_completion", "grade", "age",
                         "score_volatility", "absence_rate", "hw_gap", "engagement_score")
        model_df <- features[, c(feature_cols, "target")]
        model_df <- model_df[complete.cases(model_df), ]

        if (nrow(model_df) < 20) {
          notify_warning("Kifay\u0259t q\u0259d\u0259r tam data yoxdur.")
          return()
        }

        set.seed(42)
        train_idx <- sample(seq_len(nrow(model_df)), size = floor(0.7 * nrow(model_df)))
        train_data <- model_df[train_idx, ]
        test_data <- model_df[-train_idx, ]

        results <- data.frame()

        # RF
        setProgress(0.3, detail = "Random Forest...")
        rf <- tryCatch(
          randomForest::randomForest(target ~ ., data = train_data, ntree = 200, importance = TRUE),
          error = function(e) NULL
        )
        if (!is.null(rf)) {
          pr <- predict_model(rf, test_data, "rf", feature_cols)
          m <- calculate_full_metrics(pr$pred_class, pr$pred_prob, test_data$target)
          results <- rbind(results, data.frame(
            Model = "Random Forest",
            "D\u0259qiqlik" = round(m$accuracy * 100, 1),
            AUC = round(m$auc, 3),
            Precision = round(m$precision * 100, 1),
            Recall = round(m$recall * 100, 1),
            F1 = round(m$f1, 3),
            stringsAsFactors = FALSE, check.names = FALSE
          ))
        }

        # GLM
        setProgress(0.6, detail = "Logistik Reqressiya...")
        glm_m <- tryCatch(
          glm(target ~ ., data = train_data, family = binomial),
          error = function(e) NULL
        )
        if (!is.null(glm_m)) {
          pr <- predict_model(glm_m, test_data, "glm", feature_cols)
          m <- calculate_full_metrics(pr$pred_class, pr$pred_prob, test_data$target)
          results <- rbind(results, data.frame(
            Model = "Logistik Reqressiya",
            "D\u0259qiqlik" = round(m$accuracy * 100, 1),
            AUC = round(m$auc, 3),
            Precision = round(m$precision * 100, 1),
            Recall = round(m$recall * 100, 1),
            F1 = round(m$f1, 3),
            stringsAsFactors = FALSE, check.names = FALSE
          ))
        }

        # Ensemble
        setProgress(0.8, detail = "Ensemble...")
        if (!is.null(rf) && !is.null(glm_m)) {
          ens <- list(rf = rf, glm = glm_m, type = "ensemble", weights = c(rf = 0.7, glm = 0.3))
          pr <- predict_model(ens, test_data, "ensemble", feature_cols)
          m <- calculate_full_metrics(pr$pred_class, pr$pred_prob, test_data$target)
          results <- rbind(results, data.frame(
            Model = "Ensemble",
            "D\u0259qiqlik" = round(m$accuracy * 100, 1),
            AUC = round(m$auc, 3),
            Precision = round(m$precision * 100, 1),
            Recall = round(m$recall * 100, 1),
            F1 = round(m$f1, 3),
            stringsAsFactors = FALSE, check.names = FALSE
          ))
        }

        comparison_results(results)
        setProgress(1)
      })
      notify_success("Model m\u00FCqayis\u0259si tamamland\u0131!")
    })

    output$ml_comparison_table <- renderDT({
      res <- comparison_results()
      if (nrow(res) == 0) {
        return(datatable(data.frame("M\u00FCqayis\u0259 apar\u0131lmay\u0131b" = character(0))))
      }
      datatable(res, options = list(dom = "t", pageLength = 10), rownames = FALSE) %>%
        formatStyle("AUC", fontWeight = "bold",
          color = styleInterval(c(0.7, 0.85), c("#e74c3c", "#f39c12", "#27ae60")))
    })

    output$ml_comparison_chart <- renderPlotly({
      res <- comparison_results()
      if (nrow(res) == 0) return(NULL)

      deqiqlik_col <- grep("qiqlik", names(res), value = TRUE)[1]

      plot_ly(res, x = ~Model, y = ~AUC, type = "bar", name = "AUC",
        marker = list(color = "#3498db")) %>%
        add_trace(y = as.formula(paste0("~`", deqiqlik_col, "`/100")),
          name = "D\u0259qiqlik", marker = list(color = "#27ae60")) %>%
        add_trace(y = ~F1, name = "F1", marker = list(color = "#e67e22")) %>%
        layout(
          title = "Model M\u00FCqayis\u0259si",
          barmode = "group",
          yaxis = list(title = "Bal", range = c(0, 1))
        )
    })

    # ---- SAVE MODEL ----
    observeEvent(input$btn_ml_save, {
      m <- trained_model()
      if (is.null(m)) {
        notify_warning("\u018Fvv\u0259lc\u0259 model \u00F6yr\u0259din.")
        return()
      }

      model_dir <- file.path("data", "models")
      dir.create(model_dir, showWarnings = FALSE, recursive = TRUE)

      filename <- paste0("model_", m$type, "_", m$target, "_",
                         format(Sys.time(), "%Y%m%d_%H%M%S"), ".rds")
      filepath <- file.path(model_dir, filename)

      tryCatch({
        saveRDS(m, filepath)
        notify_success(paste0("Model saxland\u0131: ", filename))
      }, error = function(e) {
        notify_error(paste("Saxlama x\u0259tas\u0131:", e$message))
      })
    })

    # ---- LOAD MODEL ----
    observeEvent(input$btn_ml_load, {
      model_dir <- file.path("data", "models")
      if (!dir.exists(model_dir)) {
        notify_warning("Saxlanm\u0131\u015F model yoxdur.")
        return()
      }

      files <- list.files(model_dir, pattern = "\\.rds$", full.names = TRUE)
      if (length(files) == 0) {
        notify_warning("Model fayl\u0131 tap\u0131lmad\u0131.")
        return()
      }

      # Load most recent
      latest <- files[which.max(file.mtime(files))]
      tryCatch({
        m <- readRDS(latest)
        trained_model(m)
        if (!is.null(m$metrics)) model_metrics(m$metrics)
        notify_success(paste0("Model y\u00FCkl\u0259ndi: ", basename(latest)))
      }, error = function(e) {
        notify_error(paste("Y\u00FCkl\u0259m\u0259 x\u0259tas\u0131:", e$message))
      })
    })

    # ---- SAVED MODELS TABLE ----
    output$ml_saved_models_table <- renderDT({
      # Invalidate when save/delete happens
      input$btn_ml_save
      input$btn_ml_delete_model

      model_dir <- file.path("data", "models")
      if (!dir.exists(model_dir)) {
        return(datatable(data.frame("Model yoxdur" = character(0))))
      }

      files <- list.files(model_dir, pattern = "\\.rds$")
      if (length(files) == 0) {
        return(datatable(data.frame("Model yoxdur" = character(0))))
      }

      info <- file.info(file.path(model_dir, files))
      df <- data.frame(
        Fayl = files,
        "\u00D6l\u00E7\u00FC" = paste0(round(info$size / 1024, 1), " KB"),
        Tarix = format(info$mtime, "%d.%m.%Y %H:%M"),
        stringsAsFactors = FALSE,
        check.names = FALSE
      )
      datatable(df, selection = "single", options = list(dom = "t", pageLength = 10), rownames = FALSE)
    })

    # DELETE model
    observeEvent(input$btn_ml_delete_model, {
      sel <- input$ml_saved_models_table_rows_selected
      if (is.null(sel)) {
        notify_warning("Model se\u00E7in.")
        return()
      }
      model_dir <- file.path("data", "models")
      files <- list.files(model_dir, pattern = "\\.rds$")
      if (sel <= length(files)) {
        tryCatch({
          file.remove(file.path(model_dir, files[sel]))
          notify_success("Model silindi.")
        }, error = function(e) {
          notify_error(e$message)
        })
      }
    })

    # ---- HISTORY TABLE ----
    output$ml_history_table <- renderDT({
      hist <- train_history()
      if (nrow(hist) == 0) {
        return(datatable(data.frame("Tarix\u00E7\u0259 bo\u015Fdur" = character(0))))
      }
      datatable(hist, options = list(dom = "tp", pageLength = 10), rownames = FALSE)
    })
  })
}

# =============================================
# KÖMƏKÇI FUNKSİYALAR
# =============================================

#' Tam metrikləri hesabla
#'
#' @param pred_class Factor of predicted classes (0/1)
#' @param pred_prob Numeric vector of predicted probabilities for class 1
#' @param actual Factor of actual classes (0/1)
#' @return Named list with accuracy, precision, recall, specificity, f1, auc
calculate_full_metrics <- function(pred_class, pred_prob, actual) {
  tryCatch({
    cm <- table(Predicted = pred_class, Actual = actual)

    tp <- if ("1" %in% rownames(cm) && "1" %in% colnames(cm)) cm["1", "1"] else 0
    fp <- if ("1" %in% rownames(cm) && "0" %in% colnames(cm)) cm["1", "0"] else 0
    fn <- if ("0" %in% rownames(cm) && "1" %in% colnames(cm)) cm["0", "1"] else 0
    tn <- if ("0" %in% rownames(cm) && "0" %in% colnames(cm)) cm["0", "0"] else 0

    total <- tp + tn + fp + fn
    accuracy <- (tp + tn) / max(1, total)
    precision <- tp / max(1, tp + fp)
    recall <- tp / max(1, tp + fn)
    specificity <- tn / max(1, tn + fp)
    f1 <- 2 * precision * recall / max(0.001, precision + recall)

    auc_val <- tryCatch({
      roc_obj <- pROC::roc(
        as.numeric(as.character(actual)),
        as.numeric(pred_prob),
        quiet = TRUE
      )
      as.numeric(pROC::auc(roc_obj))
    }, error = function(e) 0)

    list(
      accuracy = accuracy,
      precision = precision,
      recall = recall,
      specificity = specificity,
      f1 = f1,
      auc = auc_val
    )
  }, error = function(e) {
    list(accuracy = 0, precision = 0, recall = 0, specificity = 0, f1 = 0, auc = 0)
  })
}

#' ROC datası hesabla
#'
#' @param pred_prob Numeric vector of predicted probabilities
#' @param actual Factor of actual classes (0/1)
#' @return Named list with fpr, tpr, auc
calculate_roc_data <- function(pred_prob, actual) {
  tryCatch({
    roc_obj <- pROC::roc(
      as.numeric(as.character(actual)),
      as.numeric(pred_prob),
      quiet = TRUE
    )
    list(
      fpr = 1 - roc_obj$specificities,
      tpr = roc_obj$sensitivities,
      auc = as.numeric(pROC::auc(roc_obj))
    )
  }, error = function(e) {
    list(fpr = c(0, 1), tpr = c(0, 1), auc = 0.5)
  })
}

#' Feature importance çıxar
#'
#' @param model_obj Trained model object (RF, GLM, or ensemble list)
#' @param model_type Character: "rf", "glm", or "ensemble"
#' @param feature_cols Character vector of feature names
#' @return data.frame with columns: feature, importance (normalized 0-1)
extract_feature_importance <- function(model_obj, model_type, feature_cols) {
  tryCatch({
    if (model_type == "rf") {
      imp <- randomForest::importance(model_obj)
      df <- data.frame(
        feature = rownames(imp),
        importance = imp[, "MeanDecreaseGini"],
        stringsAsFactors = FALSE
      )
    } else if (model_type == "glm") {
      coefs <- abs(coef(model_obj)[-1])  # exclude intercept
      df <- data.frame(
        feature = names(coefs),
        importance = as.numeric(coefs),
        stringsAsFactors = FALSE
      )
    } else {
      # Ensemble: use RF importance component
      imp <- randomForest::importance(model_obj$rf)
      df <- data.frame(
        feature = rownames(imp),
        importance = imp[, "MeanDecreaseGini"],
        stringsAsFactors = FALSE
      )
    }

    # Normalize to 0-1
    max_imp <- max(df$importance, na.rm = TRUE)
    if (max_imp > 0) {
      df$importance <- df$importance / max_imp
    }

    df[order(-df$importance), ]
  }, error = function(e) {
    data.frame(
      feature = feature_cols,
      importance = rep(0, length(feature_cols)),
      stringsAsFactors = FALSE
    )
  })
}

#' K-fold Cross-Validation
#'
#' @param data data.frame with feature columns and 'target' column
#' @param model_type Character: "rf", "glm", or "ensemble"
#' @param k_folds Integer number of folds
#' @param feature_cols Character vector of feature names
#' @param ntree Integer number of trees for RF
#' @return data.frame with columns: fold, accuracy, auc, precision, recall
run_cross_validation <- function(data, model_type, k_folds, feature_cols, ntree = 200) {
  n <- nrow(data)
  folds <- sample(rep(1:k_folds, length.out = n))

  results <- data.frame()

  for (i in 1:k_folds) {
    train_fold <- data[folds != i, ]
    test_fold <- data[folds == i, ]

    # Skip folds with insufficient data or single-class targets
    if (nrow(train_fold) < 10 || nrow(test_fold) < 5) next
    if (length(unique(train_fold$target)) < 2) next

    model <- tryCatch({
      if (model_type == "rf") {
        randomForest::randomForest(target ~ ., data = train_fold, ntree = ntree)
      } else if (model_type == "glm") {
        glm(target ~ ., data = train_fold, family = binomial)
      } else {
        rf <- randomForest::randomForest(target ~ ., data = train_fold, ntree = ntree)
        gl <- glm(target ~ ., data = train_fold, family = binomial)
        list(rf = rf, glm = gl, type = "ensemble", weights = c(rf = 0.7, glm = 0.3))
      }
    }, error = function(e) NULL)

    if (is.null(model)) next

    # Predict on fold
    if (model_type == "rf") {
      pred_prob <- predict(model, test_fold, type = "prob")[, "1"]
      pred_class <- predict(model, test_fold)
    } else if (model_type == "glm") {
      pred_prob <- predict(model, test_fold, type = "response")
      pred_class <- factor(ifelse(pred_prob > 0.5, 1, 0), levels = c("0", "1"))
    } else {
      rf_p <- predict(model$rf, test_fold, type = "prob")[, "1"]
      gl_p <- predict(model$glm, test_fold, type = "response")
      pred_prob <- 0.7 * rf_p + 0.3 * gl_p
      pred_class <- factor(ifelse(pred_prob > 0.5, 1, 0), levels = c("0", "1"))
    }

    m <- calculate_full_metrics(pred_class, pred_prob, test_fold$target)

    results <- rbind(results, data.frame(
      fold = paste0("Fold-", i),
      accuracy = m$accuracy,
      auc = m$auc,
      precision = m$precision,
      recall = m$recall,
      stringsAsFactors = FALSE
    ))
  }

  results
}
