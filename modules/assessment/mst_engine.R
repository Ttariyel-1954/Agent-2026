# =============================================
# ARTI-2026: MST (Multi-Stage Testing) Mühərriki
# Çoxmərhələli Test alqoritmi
# =============================================

#' MST paneli dizayn et
#' @param item_pool Sual hovuzu
#' @param n_stages Mərhələ sayı (default: 3)
#' @param modules_per_stage Hər mərhələdəki modul sayı (default: 1-3-3)
#' @return list - MST panel strukturu
design_mst_panel <- function(item_pool, n_stages = 3, modules_per_stage = c(1, 3, 3),
                              items_per_module = 5) {
  panel <- list(stages = list(), n_stages = n_stages, modules_per_stage = modules_per_stage)

  # Sualları çətinliyə görə sırala
  item_pool <- item_pool[order(item_pool$irt_b), ]
  n_items <- nrow(item_pool)

  for (stage in seq_len(n_stages)) {
    n_modules <- modules_per_stage[stage]
    stage_modules <- list()

    for (mod in seq_len(n_modules)) {
      # Hər modul üçün sual seç
      difficulty_target <- (mod - 1) / max(1, (n_modules - 1)) * 2 - 1  # -1 dan 1-ə
      module_items <- assemble_module(item_pool, items_per_module, difficulty_target)
      stage_modules[[mod]] <- list(
        module_id = paste0("S", stage, "M", mod),
        items = module_items,
        difficulty = difficulty_target,
        label = switch(as.character(mod),
          "1" = "Asan", "2" = "Orta", "3" = "Çətin", paste0("Modul ", mod))
      )
    }
    panel$stages[[stage]] <- stage_modules
  }
  panel
}

#' Modul üçün sual seç
#' @param item_pool Sual hovuzu
#' @param n_items Seçiləcək sual sayı
#' @param target_difficulty Hədəf çətinlik
#' @return data.frame - Seçilmiş suallar
assemble_module <- function(item_pool, n_items, target_difficulty = 0) {
  # Çətinlik fərqinə görə sırala
  distances <- abs(item_pool$irt_b - target_difficulty)
  ordered_idx <- order(distances)
  selected_idx <- ordered_idx[seq_len(min(n_items, length(ordered_idx)))]
  item_pool[selected_idx, ]
}

#' İmtahan verəni növbəti mərhələyə yönləndir
#' @param theta Cari theta qiymətləndirməsi
#' @param stage Cari mərhələ
#' @param panel MST panel strukturu
#' @param method Yönləndirmə metodu ("MLE" və ya "EAP")
#' @return integer - Növbəti modul indeksi
route_examinee <- function(theta, stage, panel, method = "MLE") {
  next_stage <- stage + 1
  if (next_stage > panel$n_stages) return(NULL)

  n_modules <- panel$modules_per_stage[next_stage]
  modules <- panel$stages[[next_stage]]

  # Theta əsasında modul seç
  if (n_modules == 1) return(1)

  # Cut-point-lərə əsasən yönləndir
  cut_points <- seq(-1, 1, length.out = n_modules + 1)
  for (i in seq_len(n_modules)) {
    if (theta < cut_points[i + 1]) return(i)
  }
  return(n_modules)
}

#' Modulu qiymətləndir
#' @param responses Cavablar vektoru
#' @param module Modul obyekti
#' @return list - Bal və theta
score_module <- function(responses, module) {
  items <- module$items
  correct <- sum(responses)
  total <- length(responses)

  # Theta qiymətləndir
  if (total >= 2 && !(all(responses == 1) || all(responses == 0))) {
    result <- estimate_theta_mle(responses, items)
    theta <- result$theta
    se <- result$se
  } else {
    theta <- mean(items$irt_b) + ifelse(correct > total/2, 0.5, -0.5)
    se <- 1
  }

  list(correct = correct, total = total, percent = correct / total * 100, theta = theta, se = se)
}

#' MST hesabatı generasiya et
generate_mst_report <- function(mst_session) {
  list(
    final_theta = mst_session$theta,
    final_se = mst_session$se,
    total_items = sum(sapply(mst_session$stage_results, function(s) s$total)),
    total_correct = sum(sapply(mst_session$stage_results, function(s) s$correct)),
    stages_completed = length(mst_session$stage_results),
    path = mst_session$path,
    duration = difftime(Sys.time(), mst_session$start_time, units = "mins"),
    ability_label = get_grade_label(pnorm(mst_session$theta) * 100)
  )
}

# === Shiny Modul ===

mst_test_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(column(12, h2(icon("layer-group"), "Çoxmərhələli Test (MST)"), hr())),
    fluidRow(
      column(4, selectInput(ns("subject"), "Fənn:", choices = c("Seçin..." = "", SUBJECTS))),
      column(4, selectInput(ns("n_stages"), "Mərhələ sayı:", choices = c("2" = 2, "3" = 3), selected = 3)),
      column(4, actionButton(ns("btn_start"), "Testi Başla", icon = icon("play"), class = "btn-success btn-lg", style = "margin-top:25px"))
    ),
    fluidRow(
      column(8, wellPanel(
        h4("Sual"), uiOutput(ns("question_display")),
        radioButtons(ns("answer"), "Cavab:", choices = c("A", "B", "C", "D", "E"), inline = TRUE),
        actionButton(ns("btn_next"), "Növbəti", icon = icon("arrow-right"), class = "btn-primary")
      )),
      column(4,
        wellPanel(h4("Mərhələ Tərəqqisi"), uiOutput(ns("stage_progress")),
          tags$hr(),
          tags$p(tags$strong("Cari mərhələ:"), textOutput(ns("current_stage"), inline = TRUE)),
          tags$p(tags$strong("Modul:"), textOutput(ns("current_module"), inline = TRUE)),
          tags$p(tags$strong("Theta:"), textOutput(ns("mst_theta"), inline = TRUE))
        ),
        wellPanel(h4("Test Yolu"), uiOutput(ns("test_path")))
      )
    ),
    fluidRow(column(12, uiOutput(ns("mst_report"))))
  )
}

mst_test_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    mst_session <- reactiveVal(NULL)

    observeEvent(input$btn_start, {
      req(input$subject)
      items <- db_query(db_pool,
        "SELECT i.* FROM items i JOIN subjects s ON i.subject_id = s.id
         WHERE s.name = $1 AND i.is_active = TRUE",
        params = list(input$subject))
      if (nrow(items) < 20) { notify_error("Kifayət qədər sual yoxdur (minimum 20)"); return() }

      panel <- design_mst_panel(items, n_stages = as.integer(input$n_stages))
      sess <- list(
        panel = panel, current_stage = 1, current_module = 1,
        current_item_idx = 1, responses = list(), stage_results = list(),
        path = c("S1M1"), theta = 0, se = Inf, start_time = Sys.time(), status = "active"
      )
      mst_session(sess)
    })

    output$current_stage <- renderText({ mst_session()$current_stage %||% "-" })
    output$current_module <- renderText({ mst_session()$current_module %||% "-" })
    output$mst_theta <- renderText({ round(mst_session()$theta %||% 0, 3) })

    output$stage_progress <- renderUI({
      sess <- mst_session()
      if (is.null(sess)) return(tags$p("Test başlamayıb"))
      total_stages <- sess$panel$n_stages
      current <- sess$current_stage
      tags$div(lapply(seq_len(total_stages), function(i) {
        cls <- if (i < current) "badge badge-success" else if (i == current) "badge badge-primary" else "badge badge-secondary"
        tags$span(class = cls, style = "margin:2px; padding:8px;", paste("Mərhələ", i))
      }))
    })

    output$test_path <- renderUI({
      sess <- mst_session()
      if (is.null(sess)) return(NULL)
      tags$div(lapply(sess$path, function(p) tags$span(class = "badge badge-info", style = "margin:2px", p)))
    })

    output$question_display <- renderUI({
      sess <- mst_session()
      if (is.null(sess)) return(tags$p("Testi başlatmaq üçün fənn seçin."))
      if (sess$status == "completed") return(tags$h3(class = "text-success", "MST tamamlandı!"))
      module <- sess$panel$stages[[sess$current_stage]][[sess$current_module]]
      if (sess$current_item_idx > nrow(module$items)) return(tags$p("Moduldakı bütün suallar cavablandı."))
      item <- module$items[sess$current_item_idx, ]
      tags$div(tags$h4(paste("Mərhələ", sess$current_stage, "- Sual", sess$current_item_idx)),
               tags$p(class = "lead", item$content))
    })
  })
}
