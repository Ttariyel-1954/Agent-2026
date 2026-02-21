# =============================================
# ARTI-2026: IRT (Item Response Theory) Mühərriki
# Sualların Cavab Nəzəriyyəsi hesablamaları
# =============================================

# === IRT Ehtimal Funksiyaları ===

#' 1PL (Rasch) model ehtimalı: P(θ) = 1 / (1 + exp(-(θ - b)))
irt_1pl_probability <- function(theta, b) {
  1 / (1 + exp(-(theta - b)))
}

#' 2PL model ehtimalı: P(θ) = 1 / (1 + exp(-a(θ - b)))
irt_2pl_probability <- function(theta, a, b) {
  1 / (1 + exp(-a * (theta - b)))
}

#' 3PL model ehtimalı: P(θ) = c + (1 - c) / (1 + exp(-a(θ - b)))
irt_3pl_probability <- function(theta, a, b, c) {
  c + (1 - c) / (1 + exp(-a * (theta - b)))
}

#' Fisher İnformasiya Funksiyası (2PL)
calculate_information <- function(theta, a, b, c = 0) {
  p <- irt_3pl_probability(theta, a, b, c)
  q <- 1 - p
  numerator <- a^2 * (p - c)^2 * q
  denominator <- ((1 - c)^2) * p
  if (denominator == 0) return(0)
  numerator / denominator
}

#' Test İnformasiya Funksiyası (bütün suallar üçün)
test_information <- function(theta, items) {
  sum(sapply(seq_len(nrow(items)), function(i) {
    calculate_information(theta, items$irt_a[i], items$irt_b[i], items$irt_c[i] %||% 0)
  }))
}

# === Bacarıq Qiymətləndirmə (Theta Estimation) ===

#' MLE (Maximum Likelihood Estimation) ilə theta qiymətləndir
#' @param responses Cavablar vektoru (0/1)
#' @param items data.frame sual parametrləri ilə (irt_a, irt_b, irt_c)
#' @param theta_range Theta diapazonu
#' @param max_iter Maksimum iterasiya
#' @return list(theta, se, converged)
estimate_theta_mle <- function(responses, items, theta_range = c(-4, 4),
                                max_iter = IRT_DEFAULTS$max_iterations,
                                convergence = IRT_DEFAULTS$convergence) {
  theta <- 0  # Başlanğıc theta

  for (iter in seq_len(max_iter)) {
    # Birinci törəmə (gradient)
    dl <- 0
    # İkinci törəmə (Hessian)
    d2l <- 0

    for (i in seq_along(responses)) {
      a <- items$irt_a[i]; b <- items$irt_b[i]; c_param <- items$irt_c[i] %||% 0
      p <- irt_3pl_probability(theta, a, b, c_param)
      q <- 1 - p
      u <- responses[i]

      # p* = (p - c) / (1 - c) - 3PL üçün düzəliş
      p_star <- (p - c_param) / (1 - c_param)
      if (p_star <= 0) p_star <- 1e-10

      w <- p_star * q
      dl <- dl + a * (u - p) * p_star / p
      d2l <- d2l - a^2 * w * ((u - p) / p * (p_star / p - 1) + p_star / p)
    }

    if (d2l == 0) break
    delta <- -dl / d2l
    theta <- theta + delta

    # Theta-nı məhdudla
    theta <- max(theta_range[1], min(theta_range[2], theta))

    if (abs(delta) < convergence) {
      se <- 1 / sqrt(abs(d2l))
      return(list(theta = theta, se = se, converged = TRUE, iterations = iter))
    }
  }

  se <- if (d2l != 0) 1 / sqrt(abs(d2l)) else NA
  list(theta = theta, se = se, converged = FALSE, iterations = max_iter)
}

#' EAP (Expected A Posteriori) ilə theta qiymətləndir
#' @param responses Cavablar vektoru (0/1)
#' @param items data.frame sual parametrləri ilə
#' @param n_points Quadrature nöqtə sayı
#' @return list(theta, se)
estimate_theta_eap <- function(responses, items, n_points = IRT_DEFAULTS$theta_points,
                                theta_range = IRT_DEFAULTS$theta_range) {
  # Quadrature nöqtələri
  theta_points <- seq(theta_range[1], theta_range[2], length.out = n_points)
  # Prior: standart normal paylanma
  prior <- dnorm(theta_points, mean = 0, sd = 1)

  # Hər nöqtə üçün likelihood hesabla
  likelihood <- sapply(theta_points, function(theta) {
    log_lik <- 0
    for (i in seq_along(responses)) {
      a <- items$irt_a[i]; b <- items$irt_b[i]; c_param <- items$irt_c[i] %||% 0
      p <- irt_3pl_probability(theta, a, b, c_param)
      p <- max(1e-10, min(1 - 1e-10, p))
      log_lik <- log_lik + responses[i] * log(p) + (1 - responses[i]) * log(1 - p)
    }
    exp(log_lik)
  })

  # Posterior
  posterior <- likelihood * prior
  posterior <- posterior / sum(posterior)

  # EAP theta
  theta_eap <- sum(theta_points * posterior)

  # Standart xəta
  se <- sqrt(sum((theta_points - theta_eap)^2 * posterior))

  list(theta = theta_eap, se = se)
}

# === Sual Uyğunluq Statistikaları ===

#' Sual uyğunluq statistikaları (Chi-square)
item_fit_statistics <- function(responses, theta_estimates, item_params) {
  n <- length(responses)
  a <- item_params$irt_a; b <- item_params$irt_b; c_param <- item_params$irt_c %||% 0

  expected <- sapply(theta_estimates, function(t) irt_3pl_probability(t, a, b, c_param))
  observed <- responses

  # Chi-square
  chi_sq <- sum((observed - expected)^2 / (expected * (1 - expected) + 1e-10))
  df <- max(1, n - 3)
  p_value <- 1 - pchisq(chi_sq, df)

  # RMSEA
  rmsea <- sqrt(max(0, (chi_sq/df - 1) / (n - 1)))

  # Infit/Outfit
  residuals <- (observed - expected) / sqrt(expected * (1 - expected) + 1e-10)
  outfit <- mean(residuals^2)

  variance <- expected * (1 - expected)
  infit <- sum(residuals^2 * variance) / sum(variance)

  list(chi_sq = chi_sq, df = df, p_value = p_value, rmsea = rmsea, infit = infit, outfit = outfit)
}

# === Shiny Modul ===

#' IRT Analiz UI
irt_analysis_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(column(12, h2(icon("calculator"), "IRT Analizi"), hr())),
    fluidRow(
      column(4, selectInput(ns("model_type"), "IRT Model:", choices = c("1PL (Rasch)" = "1PL", "2PL" = "2PL", "3PL" = "3PL"))),
      column(4, selectInput(ns("subject_filter"), "Fənn:", choices = c("Hamısı" = "", SUBJECTS))),
      column(4, actionButton(ns("btn_analyze"), "Analiz Et", icon = icon("play"), class = "btn-primary", style = "margin-top:25px"))
    ),
    fluidRow(
      column(6, wellPanel(h4("Sual Xarakteristik Əyrisi (ICC)"), plotlyOutput(ns("icc_plot"), height = "400px"))),
      column(6, wellPanel(h4("Test İnformasiya Funksiyası (TIF)"), plotlyOutput(ns("tif_plot"), height = "400px")))
    ),
    fluidRow(column(12, wellPanel(h4("Sual Parametrləri və Uyğunluq"), DTOutput(ns("item_params_table"))))),
    fluidRow(
      column(6, wellPanel(h4("Çətinlik Paylanması"), plotlyOutput(ns("difficulty_dist"), height = "300px"))),
      column(6, wellPanel(h4("Ayrıd Etmə Paylanması"), plotlyOutput(ns("discrimination_dist"), height = "300px")))
    )
  )
}

#' IRT Analiz Server
irt_analysis_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    items_data <- reactive({
      query <- "SELECT * FROM items WHERE is_active = TRUE"
      if (!is_empty(input$subject_filter)) {
        query <- paste0(query, " AND subject_id = (SELECT id FROM subjects WHERE name = '", safe_html(input$subject_filter), "')")
      }
      db_query(db_pool, query)
    })

    # ICC Plot
    output$icc_plot <- renderPlotly({
      items <- items_data()
      if (nrow(items) == 0) return(plotly_empty())
      theta_seq <- seq(-4, 4, by = 0.1)
      p <- plot_ly()
      for (i in seq_len(min(10, nrow(items)))) {
        probs <- sapply(theta_seq, function(t) irt_2pl_probability(t, items$irt_a[i], items$irt_b[i]))
        p <- add_trace(p, x = theta_seq, y = probs, type = "scatter", mode = "lines",
                       name = paste("Sual", items$id[i]))
      }
      p %>% layout(xaxis = list(title = "Bacarıq (θ)"), yaxis = list(title = "P(θ)", range = c(0, 1)),
                   title = "Sual Xarakteristik Əyriləri")
    })

    # TIF Plot
    output$tif_plot <- renderPlotly({
      items <- items_data()
      if (nrow(items) == 0) return(plotly_empty())
      theta_seq <- seq(-4, 4, by = 0.1)
      info <- sapply(theta_seq, function(t) test_information(t, items))
      plot_ly(x = theta_seq, y = info, type = "scatter", mode = "lines",
              fill = "tozeroy", fillcolor = "rgba(52,152,219,0.3)") %>%
        layout(xaxis = list(title = "Bacarıq (θ)"), yaxis = list(title = "İnformasiya"),
               title = "Test İnformasiya Funksiyası")
    })

    output$item_params_table <- renderDT({
      items <- items_data()
      if (nrow(items) == 0) return(datatable(data.frame()))
      display <- items %>% select(id, irt_a, irt_b, irt_c, difficulty, bloom_level)
      names(display) <- c("ID", "Ayrıd etmə (a)", "Çətinlik (b)", "Təxmin (c)", "Çətinlik", "Bloom")
      datatable(display, options = default_dt_options())
    })

    output$difficulty_dist <- renderPlotly({
      items <- items_data()
      if (nrow(items) == 0) return(plotly_empty())
      plot_ly(x = items$irt_b, type = "histogram", marker = list(color = "#3498db")) %>%
        layout(xaxis = list(title = "Çətinlik (b)"), yaxis = list(title = "Sual sayı"))
    })

    output$discrimination_dist <- renderPlotly({
      items <- items_data()
      if (nrow(items) == 0) return(plotly_empty())
      plot_ly(x = items$irt_a, type = "histogram", marker = list(color = "#e74c3c")) %>%
        layout(xaxis = list(title = "Ayrıd etmə (a)"), yaxis = list(title = "Sual sayı"))
    })
  })
}
