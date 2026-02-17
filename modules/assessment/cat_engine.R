# =============================================
# ARTI-2026: CAT (Computerized Adaptive Testing) Mühərriki
# Kompüterləşdirilmiş Adaptiv Test alqoritmi
# =============================================

# === CAT Sessiya İdarəetməsi ===

#' CAT sessiyasını başlat
#' @param item_pool Sual hovuzu (data.frame)
#' @param config CAT konfiqurasiyası
#' @return list - CAT sessiya obyekti
initialize_cat <- function(item_pool, config = CAT_DEFAULTS) {
  list(
    theta = config$initial_theta,
    se = Inf,
    items_administered = integer(0),
    responses = integer(0),
    theta_history = config$initial_theta,
    se_history = Inf,
    item_pool = item_pool,
    available_items = seq_len(nrow(item_pool)),
    config = config,
    status = "active",
    start_time = Sys.time()
  )
}

#' Növbəti sualı seç (Maximum Fisher Information)
#' @param session CAT sessiyası
#' @return integer - Seçilmiş sualın indeksi
select_next_item <- function(session) {
  available <- session$available_items
  if (length(available) == 0) return(NULL)

  pool <- session$item_pool
  theta <- session$theta

  # Hər əlçatan sual üçün Fisher informasiyasını hesabla
  info_values <- sapply(available, function(idx) {
    calculate_information(theta, pool$irt_a[idx], pool$irt_b[idx], pool$irt_c[idx] %||% 0)
  })

  # Exposure control tətbiq et (Sympson-Hetter)
  if (isTRUE(session$config$exposure_control)) {
    exposure_rates <- pool$exposure_count[available] / max(1, sum(pool$exposure_count))
    max_rate <- session$config$max_exposure_rate
    eligible <- exposure_rates < max_rate | info_values == max(info_values)
    if (any(eligible)) {
      available <- available[eligible]
      info_values <- info_values[eligible]
    }
  }

  # Ən yüksək informasiyalı sualı seç
  best_idx <- available[which.max(info_values)]
  best_idx
}

#' Cavabdan sonra theta-nı yenilə
#' @param session CAT sessiyası
#' @param item_idx Sualın indeksi
#' @param response Cavab (0 = yanlış, 1 = düzgün)
#' @return list - Yenilənmiş sessiya
update_theta <- function(session, item_idx, response) {
  session$items_administered <- c(session$items_administered, item_idx)
  session$responses <- c(session$responses, response)

  # Əlçatan suallardan sil
  session$available_items <- setdiff(session$available_items, item_idx)

  # Sual parametrlərini al
  admin_items <- session$item_pool[session$items_administered, ]

  # MLE ilə theta qiymətləndir (minimum 2 cavab lazımdır)
  if (length(session$responses) >= 2 && !(all(session$responses == 1) || all(session$responses == 0))) {
    result <- estimate_theta_mle(session$responses, admin_items)
    session$theta <- result$theta
    session$se <- result$se
  } else {
    # Bayesian yenilənmə (ilk suallar üçün)
    if (response == 1) {
      session$theta <- session$theta + 0.5 / max(1, length(session$responses))
    } else {
      session$theta <- session$theta - 0.5 / max(1, length(session$responses))
    }
    session$se <- 1 / sqrt(max(1, length(session$responses)))
  }

  session$theta <- max(-4, min(4, session$theta))
  session$theta_history <- c(session$theta_history, session$theta)
  session$se_history <- c(session$se_history, session$se)

  session
}

#' Dayandırma qaydasını yoxla
#' @param session CAT sessiyası
#' @return logical - TRUE = test dayandırılmalıdır
check_stopping_rule <- function(session) {
  n_items <- length(session$items_administered)
  config <- session$config

  # Minimum sual sayına çatılmayıb
  if (n_items < config$min_items) return(FALSE)
  # Maksimum sual sayına çatılıb
  if (n_items >= config$max_items) return(TRUE)
  # SE həddinə çatılıb
  if (!is.na(session$se) && session$se <= config$se_threshold) return(TRUE)
  # Əlçatan sual yoxdur
  if (length(session$available_items) == 0) return(TRUE)

  FALSE
}

#' Standart xəta hesabla
calculate_se <- function(theta, items, responses) {
  info <- sum(sapply(seq_len(nrow(items)), function(i) {
    calculate_information(theta, items$irt_a[i], items$irt_b[i], items$irt_c[i] %||% 0)
  }))
  if (info > 0) 1 / sqrt(info) else NA
}

#' Sympson-Hetter exposure control
exposure_control <- function(item_pool, exposure_counts, max_rate = 0.25) {
  total <- max(1, sum(exposure_counts))
  rates <- exposure_counts / total
  control_params <- ifelse(rates > max_rate, max_rate / rates, 1)
  control_params
}

#' CAT hesabatı generasiya et
generate_cat_report <- function(session) {
  list(
    theta = session$theta,
    se = session$se,
    total_items = length(session$items_administered),
    correct_items = sum(session$responses),
    percent_correct = mean(session$responses) * 100,
    theta_history = session$theta_history,
    se_history = session$se_history,
    duration = difftime(Sys.time(), session$start_time, units = "mins"),
    status = if (check_stopping_rule(session)) "completed" else "active",
    ability_label = get_grade_label(pnorm(session$theta) * 100)
  )
}

# === Shiny Modul ===

cat_test_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(column(12, h2(icon("laptop-code"), "Adaptiv Test (CAT)"), hr())),
    fluidRow(
      column(4, selectInput(ns("subject"), "Fənn:", choices = c("Seçin..." = "", SUBJECTS))),
      column(4, selectInput(ns("difficulty"), "Başlanğıc çətinlik:", choices = c("Orta" = "medium", "Asan" = "easy", "Çətin" = "hard"))),
      column(4, actionButton(ns("btn_start"), "Testi Başla", icon = icon("play"), class = "btn-success btn-lg", style = "margin-top:25px"))
    ),
    fluidRow(
      column(8, wellPanel(
        uiOutput(ns("question_display")),
        radioButtons(ns("answer"), "Cavabınız:", choices = c("A", "B", "C", "D", "E"), inline = TRUE),
        actionButton(ns("btn_answer"), "Cavabla", icon = icon("check"), class = "btn-primary"),
        actionButton(ns("btn_skip"), "Keç", icon = icon("forward"), class = "btn-warning")
      )),
      column(4,
        wellPanel(h4("Test Vəziyyəti"),
          tags$p(tags$strong("Sual:"), textOutput(ns("item_count"), inline = TRUE)),
          tags$p(tags$strong("Düzgün:"), textOutput(ns("correct_count"), inline = TRUE)),
          tags$p(tags$strong("Theta (θ):"), textOutput(ns("current_theta"), inline = TRUE)),
          tags$p(tags$strong("SE:"), textOutput(ns("current_se"), inline = TRUE)),
          tags$hr(),
          tags$p(tags$strong("Tərəqqi:")),
          tags$div(class = "progress", uiOutput(ns("progress_bar")))
        ),
        wellPanel(h4("Theta Trendi"), plotlyOutput(ns("theta_trend"), height = "200px"))
      )
    ),
    fluidRow(column(12, uiOutput(ns("final_report"))))
  )
}

cat_test_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    cat_session <- reactiveVal(NULL)
    current_item <- reactiveVal(NULL)

    # Testi başla
    observeEvent(input$btn_start, {
      req(input$subject)
      items <- db_query(db_pool,
        "SELECT i.* FROM items i JOIN subjects s ON i.subject_id = s.id
         WHERE s.name = $1 AND i.is_active = TRUE",
        params = list(input$subject))
      if (nrow(items) < 10) { notify_error("Kifayət qədər sual yoxdur (minimum 10)"); return() }
      sess <- initialize_cat(items)
      cat_session(sess)
      next_idx <- select_next_item(sess)
      current_item(next_idx)
    })

    # Cavab ver
    observeEvent(input$btn_answer, {
      req(cat_session(), current_item())
      sess <- cat_session()
      idx <- current_item()
      correct <- sess$item_pool$correct_answer[idx]
      response <- as.integer(input$answer == correct)
      sess <- update_theta(sess, idx, response)

      if (check_stopping_rule(sess)) {
        sess$status <- "completed"
        cat_session(sess)
        current_item(NULL)
      } else {
        cat_session(sess)
        next_idx <- select_next_item(sess)
        current_item(next_idx)
      }
    })

    output$question_display <- renderUI({
      idx <- current_item()
      sess <- cat_session()
      if (is.null(idx) || is.null(sess)) return(tags$p("Testi başlatmaq üçün fənn seçin."))
      if (sess$status == "completed") return(tags$h3(class = "text-success", "Test tamamlandı!"))
      item <- sess$item_pool[idx, ]
      tags$div(
        tags$h4(paste0("Sual #", length(sess$items_administered) + 1)),
        tags$p(class = "lead", item$content),
        tags$span(class = "badge badge-info", item$difficulty_label),
        tags$span(class = "badge badge-secondary", item$bloom_level)
      )
    })

    output$item_count <- renderText({ length(cat_session()$items_administered %||% integer(0)) })
    output$correct_count <- renderText({ sum(cat_session()$responses %||% integer(0)) })
    output$current_theta <- renderText({ round(cat_session()$theta %||% 0, 3) })
    output$current_se <- renderText({ round(cat_session()$se %||% Inf, 3) })

    output$progress_bar <- renderUI({
      sess <- cat_session()
      if (is.null(sess)) return(NULL)
      pct <- min(100, length(sess$items_administered) / sess$config$max_items * 100)
      tags$div(class = "progress-bar bg-info", style = paste0("width:", pct, "%"), paste0(round(pct), "%"))
    })

    output$theta_trend <- renderPlotly({
      sess <- cat_session()
      if (is.null(sess)) return(plotly_empty())
      plot_ly(x = seq_along(sess$theta_history), y = sess$theta_history,
              type = "scatter", mode = "lines+markers") %>%
        layout(xaxis = list(title = "Sual"), yaxis = list(title = "θ", range = c(-4, 4)))
    })
  })
}
