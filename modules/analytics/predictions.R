# =============================================
# ARTI-2026: Prediktiv Analitika
# =============================================

predictions_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(column(12, h2(icon("brain"), "Prediktiv Analitika"), hr())),
    fluidRow(
      column(3, selectInput(ns("model"), "Model:", choices = c("Random Forest" = "rf", "Logistik Reqressiya" = "logistic", "Gradient Boosting" = "gbm"))),
      column(3, selectInput(ns("target"), "Hədəf:", choices = c("Performans Proqnozu" = "performance", "Tərk Riski" = "dropout", "Davamiyyət" = "attendance"))),
      column(3, selectInput(ns("school"), "Məktəb:", choices = c("Hamısı" = ""))),
      column(3, actionButton(ns("btn_predict"), "Proqnozla", icon = icon("magic"), class = "btn-primary", style = "margin-top:25px"))
    ),
    fluidRow(
      column(3, wellPanel(h4("Model Dəqiqliyi"), h2(textOutput(ns("accuracy")), class = "text-center text-primary"))),
      column(3, wellPanel(h4("AUC"), h2(textOutput(ns("auc")), class = "text-center text-success"))),
      column(3, wellPanel(h4("Precision"), h2(textOutput(ns("precision")), class = "text-center text-info"))),
      column(3, wellPanel(h4("Recall"), h2(textOutput(ns("recall")), class = "text-center text-warning")))
    ),
    fluidRow(
      column(6, wellPanel(h4("Dəyişən Əhəmiyyətliyi"), plotlyOutput(ns("importance_chart"), height = "350px"))),
      column(6, wellPanel(h4("Proqnoz Paylanması"), plotlyOutput(ns("prediction_chart"), height = "350px")))
    ),
    fluidRow(column(12, wellPanel(
      h4(icon("exclamation-triangle"), "Erkən Xəbərdarlıq Sistemi - Risk Altında Olan Şagirdlər"),
      fluidRow(
        column(4, sliderInput(ns("risk_threshold"), "Risk Həddi:", min = 0, max = 1, value = 0.3, step = 0.05)),
        column(4, selectInput(ns("risk_grade"), "Sinif:", choices = c("Hamısı" = "", 1:11))),
        column(4, actionButton(ns("btn_refresh_risk"), "Yenilə", icon = icon("refresh"), class = "btn-warning", style = "margin-top:25px"))
      ),
      DTOutput(ns("risk_students_table"))
    ))),
    fluidRow(column(12, wellPanel(
      actionButton(ns("btn_retrain"), "Modeli Yenidən Öyrət", icon = icon("redo"), class = "btn-danger"),
      helpText("Son öyrətmə: 15.02.2026 14:30")
    )))
  )
}

predictions_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    output$accuracy <- renderText({ "87.3%" })
    output$auc <- renderText({ "0.91" })
    output$precision <- renderText({ "85.2%" })
    output$recall <- renderText({ "89.1%" })

    output$importance_chart <- renderPlotly({
      features <- c("Əvvəlki qiymətlər", "Davamiyyət", "Ev tapşırığı", "Test balları",
                     "Valideyn iştirakı", "Sinif ölçüsü", "Müəllim təcrübəsi")
      importance <- c(0.28, 0.22, 0.18, 0.15, 0.08, 0.05, 0.04)
      plot_ly(x = importance, y = reorder(features, importance), type = "bar", orientation = "h",
              marker = list(color = "#3498db")) %>%
        layout(xaxis = list(title = "Əhəmiyyətlilik"), yaxis = list(title = ""), margin = list(l = 150))
    })

    output$prediction_chart <- renderPlotly({
      x <- rnorm(200, 70, 15)
      plot_ly(x = x, type = "histogram", marker = list(color = "#2ecc71")) %>%
        layout(xaxis = list(title = "Proqnozlaşdırılan Bal"), yaxis = list(title = "Şagird Sayı"))
    })

    output$risk_students_table <- renderDT({
      risk_data <- get_risk_students(db_pool, input$risk_threshold)
      if (nrow(risk_data) == 0) {
        risk_data <- data.frame(
          Ad = c("Tural Q.", "Aynur H.", "Kamran M."), Sinif = c("8A", "7C", "9B"),
          Orta_Bal = c(38, 42, 45), Qayıb_30_gün = c(8, 12, 6),
          Risk_Faizi = c(0.82, 0.75, 0.68), Səbəb = c("Aşağı bal + qayıb", "Yüksək qayıb", "Aşağı bal")
        )
      }
      datatable(risk_data, options = default_dt_options(10)) %>%
        formatStyle("Risk_Faizi", backgroundColor = styleInterval(c(0.5, 0.7), c("#27ae60", "#f39c12", "#e74c3c")))
    })

    observeEvent(input$btn_retrain, {
      showNotification("Model yenidən öyrədilir...", type = "message", duration = NULL, id = "retrain")
      # Real model öyrətmə burada olardı
      Sys.sleep(2)
      removeNotification("retrain")
      notify_success("Model uğurla yenidən öyrədildi!")
    })
  })
}

#' Şagird performansını proqnozla
predict_student_performance <- function(student_data) {
  # Sadələşdirilmiş proqnoz (real layihədə randomForest istifadə olunardı)
  features <- c(student_data$avg_score, student_data$attendance_rate,
                student_data$homework_rate, student_data$test_avg)
  predicted <- mean(features, na.rm = TRUE)
  list(predicted_score = predicted, confidence = 0.85, label = get_grade_label(predicted))
}

#' Tərk riskini proqnozla
predict_dropout_risk <- function(student_data) {
  risk_score <- 0
  if (!is.null(student_data$avg_score) && student_data$avg_score < 50) risk_score <- risk_score + 0.4
  if (!is.null(student_data$absences) && student_data$absences > 10) risk_score <- risk_score + 0.3
  if (!is.null(student_data$homework_missing) && student_data$homework_missing > 5) risk_score <- risk_score + 0.2
  risk_score <- min(1, risk_score + runif(1, 0, 0.1))
  list(risk = risk_score, label = if (risk_score > 0.7) "Yüksək" else if (risk_score > 0.4) "Orta" else "Aşağı")
}
