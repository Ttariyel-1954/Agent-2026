# ============================================================
# ARTI 2026 - SUAL BAZASI İDARƏETMƏ PANELİ
# IRT parametrləri, sual keyfiyyəti, kalibrasiya
# ============================================================

library(shiny)
library(shinydashboard)
library(plotly)
library(DT)
library(dplyr)

# ===== NÜMUNƏ MƏLUMATLAR =====

set.seed(2026)
n_items <- 500

fenler <- c("Riyaziyyat", "Fizika", "Kimya", "Biologiya", "İnformatika",
            "Azərb. dili", "Tarix", "Coğrafiya", "İngilis dili")

movzular <- list(
  "Riyaziyyat" = c("Cəbr", "Həndəsə", "Statistika", "Funksiyalar", "Tənliklər"),
  "Fizika" = c("Mexanika", "Optika", "Elektrik", "Termodinamika", "Dalğalar"),
  "Kimya" = c("Atom quruluşu", "Reaksiyalar", "Həllər", "Üzvi kimya"),
  "Biologiya" = c("Hüceyrə", "Genetika", "Ekologiya", "Anatomiya"),
  "İnformatika" = c("Alqoritmlər", "Proqramlaşdırma", "Şəbəkələr", "DB"),
  "Azərb. dili" = c("Fonetika", "Leksika", "Morfologiya", "Sintaksis"),
  "Tarix" = c("Qədim", "Orta əsrlər", "Yeni dövr", "Müasir dövr"),
  "Coğrafiya" = c("Fiziki", "İqtisadi", "Azərbaycan coğ."),
  "İngilis dili" = c("Grammar", "Vocabulary", "Reading", "Writing")
)

suallar <- data.frame(
  sual_id = paste0("Q_", sprintf("%05d", 1:n_items)),
  fen = sample(fenler, n_items, replace = TRUE),
  sinif = sample(5:11, n_items, replace = TRUE),
  cetinlik = sample(c("Asan", "Orta", "Çətin"), n_items, replace = TRUE, prob = c(0.3, 0.45, 0.25)),
  bloom = sample(c("Bilik", "Anlama", "Tətbiq", "Analiz", "Sintez", "Qiymətləndirmə"),
                 n_items, replace = TRUE, prob = c(0.15, 0.2, 0.3, 0.2, 0.1, 0.05)),
  a = round(runif(n_items, 0.2, 3.0), 2),
  b = round(rnorm(n_items, 0, 1.5), 2),
  c = round(runif(n_items, 0.05, 0.30), 2),
  istifade_sayi = sample(0:600, n_items, replace = TRUE),
  duzgun_faiz = round(runif(n_items, 15, 92), 1),
  point_biserial = round(runif(n_items, -0.1, 0.7), 2),
  status = sample(c("Aktiv", "Təsdiq gözləyir", "Qaralama", "Deaktiv"),
                  n_items, replace = TRUE, prob = c(0.55, 0.2, 0.15, 0.1)),
  kalibrasiya = sample(c("Bəli", "Xeyr"), n_items, replace = TRUE, prob = c(0.6, 0.4)),
  yaradilma = format(as.Date("2024-01-01") + sample(0:730, n_items, replace = TRUE), "%d.%m.%Y"),
  stringsAsFactors = FALSE
)

# Mövzu əlavə et
suallar$movzu <- sapply(suallar$fen, function(f) sample(movzular[[f]], 1))

# Uyğunluq
suallar$uygunluq <- ifelse(suallar$a >= 0.5 & suallar$a <= 2.5 & suallar$point_biserial >= 0.2,
                           "Yaxşı", ifelse(suallar$point_biserial >= 0.1, "Orta", "Zəif"))


# ===== UI =====

ui <- dashboardPage(
  skin = "red",
  dashboardHeader(title = "ARTI - Sual Bazası", titleWidth = 280),

  dashboardSidebar(
    width = 280,
    sidebarMenu(
      menuItem("Ümumi Baxış", tabName = "umumi", icon = icon("database")),
      menuItem("Sual Cədvəli", tabName = "cedvel", icon = icon("table")),
      menuItem("IRT Analizi", tabName = "irt", icon = icon("chart-scatter")),
      menuItem("Keyfiyyət Analizi", tabName = "keyfiyyet", icon = icon("check-double")),
      menuItem("Bloom Taksonomiyası", tabName = "bloom", icon = icon("brain")),
      menuItem("ICC Əyriləri", tabName = "icc", icon = icon("wave-square")),
      hr(),
      selectInput("fen_f", "Fən:", c("Hamısı", fenler)),
      selectInput("sinif_f", "Sinif:", c("Hamısı", 5:11)),
      selectInput("status_f", "Status:", c("Hamısı", "Aktiv", "Təsdiq gözləyir", "Qaralama", "Deaktiv"))
    )
  ),

  dashboardBody(
    tags$head(tags$style(HTML("
      .content-wrapper { background-color: #f4f6f9; }
      .box-header { border-bottom: 2px solid #dd4b39; }
    "))),

    tabItems(
      # ÜMUMİ
      tabItem(tabName = "umumi",
        h3("Sual Bazası - Ümumi Baxış", style = "margin-top: 0;"),
        fluidRow(
          valueBox(n_items, "Ümumi Sual", icon = icon("question-circle"), color = "blue", width = 3),
          valueBox(sum(suallar$status == "Aktiv"), "Aktiv", icon = icon("check"), color = "green", width = 3),
          valueBox(sum(suallar$kalibrasiya == "Bəli"), "Kalibrə olunmuş",
                   icon = icon("bullseye"), color = "yellow", width = 3),
          valueBox(sum(suallar$uygunluq == "Yaxşı"), "Keyfiyyətli",
                   icon = icon("star"), color = "red", width = 3)
        ),
        fluidRow(
          box(title = "Fənlər üzrə Sual Sayı", status = "primary", solidHeader = TRUE, width = 6, height = 420,
              plotlyOutput("fen_sual_bar", height = "360px")),
          box(title = "Status Paylanması", status = "success", solidHeader = TRUE, width = 3, height = 420,
              plotlyOutput("status_pie", height = "360px")),
          box(title = "Çətinlik Paylanması", status = "warning", solidHeader = TRUE, width = 3, height = 420,
              plotlyOutput("cetinlik_pie", height = "360px"))
        ),
        fluidRow(
          box(title = "b (Çətinlik) Parametrinin Paylanması", status = "info",
              solidHeader = TRUE, width = 6, height = 380,
              plotlyOutput("b_hist", height = "320px")),
          box(title = "a (Ayırd etmə) vs b (Çətinlik)", status = "primary",
              solidHeader = TRUE, width = 6, height = 380,
              plotlyOutput("ab_scatter", height = "320px"))
        )
      ),

      # CƏDVƏL
      tabItem(tabName = "cedvel",
        h3("Sual Bazası Cədvəli"),
        box(title = "Suallar", status = "primary", solidHeader = TRUE, width = 12,
            DT::dataTableOutput("sual_full_table"))
      ),

      # IRT
      tabItem(tabName = "irt",
        h3("IRT Parametr Analizi"),
        fluidRow(
          box(title = "Ayırd etmə (a) Paylanması", status = "primary", solidHeader = TRUE, width = 4,
              plotlyOutput("a_hist", height = "300px")),
          box(title = "Çətinlik (b) Paylanması", status = "info", solidHeader = TRUE, width = 4,
              plotlyOutput("b_hist2", height = "300px")),
          box(title = "Təsadüfi Tapma (c) Paylanması", status = "success", solidHeader = TRUE, width = 4,
              plotlyOutput("c_hist", height = "300px"))
        ),
        fluidRow(
          box(title = "Fən üzrə b Parametri", status = "warning", solidHeader = TRUE, width = 12,
              plotlyOutput("b_by_fen", height = "350px"))
        )
      ),

      # KEYFİYYƏT
      tabItem(tabName = "keyfiyyet",
        h3("Sual Keyfiyyət Analizi"),
        fluidRow(
          box(title = "Point-Biserial Korrelyasiya Paylanması", status = "primary",
              solidHeader = TRUE, width = 6,
              plotlyOutput("pb_hist", height = "300px")),
          box(title = "Uyğunluq Paylanması", status = "info", solidHeader = TRUE, width = 6,
              plotlyOutput("uygunluq_bar", height = "300px"))
        ),
        fluidRow(
          box(title = "Düzgün Cavab % vs Point-Biserial", status = "success",
              solidHeader = TRUE, width = 12,
              plotlyOutput("duzgun_pb_scatter", height = "350px"))
        )
      ),

      # BLOOM
      tabItem(tabName = "bloom",
        h3("Bloom Taksonomiyası Analizi"),
        fluidRow(
          box(title = "Bloom Səviyyələri", status = "primary", solidHeader = TRUE, width = 6,
              plotlyOutput("bloom_bar", height = "350px")),
          box(title = "Fən × Bloom", status = "info", solidHeader = TRUE, width = 6,
              plotlyOutput("bloom_fen", height = "350px"))
        )
      ),

      # ICC
      tabItem(tabName = "icc",
        h3("ICC (Item Characteristic Curve) Əyriləri"),
        fluidRow(
          column(4, selectInput("icc_item", "Sual seçin:", suallar$sual_id[1:50])),
          column(4, tags$br(), actionButton("icc_btn", "ICC Göstər", class = "btn-danger"))
        ),
        fluidRow(
          box(title = "ICC Əyrisi", status = "primary", solidHeader = TRUE, width = 8,
              plotlyOutput("icc_plot", height = "400px")),
          box(title = "Sual Məlumatları", status = "info", solidHeader = TRUE, width = 4,
              verbatimTextOutput("icc_info"))
        )
      )
    )
  )
)


# ===== SERVER =====

server <- function(input, output, session) {

  filt <- reactive({
    df <- suallar
    if (input$fen_f != "Hamısı") df <- df %>% filter(fen == input$fen_f)
    if (input$sinif_f != "Hamısı") df <- df %>% filter(sinif == as.integer(input$sinif_f))
    if (input$status_f != "Hamısı") df <- df %>% filter(status == input$status_f)
    df
  })

  # Ümumi
  output$fen_sual_bar <- renderPlotly({
    df <- filt() %>% count(fen) %>% arrange(desc(n))
    plot_ly(df, x = ~reorder(fen, n), y = ~n, type = "bar", marker = list(color = "#dd4b39"),
            text = ~n, textposition = "outside") %>%
      layout(xaxis = list(title = ""), yaxis = list(title = "Sual Sayı"), margin = list(b = 80))
  })

  output$status_pie <- renderPlotly({
    df <- filt() %>% count(status)
    plot_ly(df, labels = ~status, values = ~n, type = "pie",
            marker = list(colors = c("#00a65a", "#dd4b39", "#f39c12", "#999")),
            hole = 0.45, textinfo = "label+percent") %>%
      layout(showlegend = FALSE, margin = list(l = 5, r = 5, t = 20, b = 5))
  })

  output$cetinlik_pie <- renderPlotly({
    df <- filt() %>% count(cetinlik)
    plot_ly(df, labels = ~cetinlik, values = ~n, type = "pie",
            marker = list(colors = c("#00a65a", "#f39c12", "#dd4b39")),
            hole = 0.45, textinfo = "label+percent") %>%
      layout(showlegend = FALSE, margin = list(l = 5, r = 5, t = 20, b = 5))
  })

  output$b_hist <- renderPlotly({
    df <- filt()
    plot_ly(df, x = ~b, type = "histogram", marker = list(color = "#3c8dbc"), nbinsx = 30) %>%
      layout(xaxis = list(title = "b (Çətinlik)"), yaxis = list(title = "Sual Sayı"))
  })

  output$ab_scatter <- renderPlotly({
    df <- filt()
    plot_ly(df, x = ~b, y = ~a, color = ~fen, type = "scatter", mode = "markers",
            marker = list(size = 5, opacity = 0.6),
            text = ~paste0(sual_id, "<br>a=", a, " b=", b)) %>%
      layout(xaxis = list(title = "b (Çətinlik)"), yaxis = list(title = "a (Ayırd etmə)"))
  })

  # Cədvəl
  output$sual_full_table <- DT::renderDataTable({
    df <- filt() %>% select(sual_id, fen, movzu, sinif, cetinlik, bloom, a, b, c,
                            point_biserial, duzgun_faiz, uygunluq, status, kalibrasiya)
    datatable(df,
              colnames = c("ID", "Fən", "Mövzu", "Sinif", "Çətinlik", "Bloom",
                           "a", "b", "c", "rpb", "Düzgün%", "Uyğunluq", "Status", "Kalibr."),
              options = list(pageLength = 15, scrollX = TRUE), rownames = FALSE, filter = "top") %>%
      formatRound(c("a", "b", "c", "point_biserial"), 2) %>%
      formatStyle("uygunluq", backgroundColor = styleEqual(c("Yaxşı", "Orta", "Zəif"), c("#d4edda", "#fff3cd", "#f8d7da"))) %>%
      formatStyle("status", backgroundColor = styleEqual(
        c("Aktiv", "Təsdiq gözləyir", "Qaralama", "Deaktiv"),
        c("#d4edda", "#cce5ff", "#fff3cd", "#f8d7da")))
  })

  # IRT
  output$a_hist <- renderPlotly({
    plot_ly(filt(), x = ~a, type = "histogram", marker = list(color = "#dd4b39"), nbinsx = 25) %>%
      layout(xaxis = list(title = "a"), yaxis = list(title = "Say"))
  })

  output$b_hist2 <- renderPlotly({
    plot_ly(filt(), x = ~b, type = "histogram", marker = list(color = "#3c8dbc"), nbinsx = 25) %>%
      layout(xaxis = list(title = "b"), yaxis = list(title = "Say"))
  })

  output$c_hist <- renderPlotly({
    plot_ly(filt(), x = ~c, type = "histogram", marker = list(color = "#00a65a"), nbinsx = 20) %>%
      layout(xaxis = list(title = "c"), yaxis = list(title = "Say"))
  })

  output$b_by_fen <- renderPlotly({
    plot_ly(filt(), x = ~fen, y = ~b, color = ~fen, type = "box") %>%
      layout(xaxis = list(title = ""), yaxis = list(title = "b (Çətinlik)"), showlegend = FALSE)
  })

  # Keyfiyyət
  output$pb_hist <- renderPlotly({
    df <- filt()
    plot_ly(df, x = ~point_biserial, type = "histogram", marker = list(color = "#605ca8"), nbinsx = 25) %>%
      add_segments(x = 0.2, xend = 0.2, y = 0, yend = 50,
                   line = list(color = "red", dash = "dash", width = 2), name = "Min. hədd") %>%
      layout(xaxis = list(title = "Point-Biserial (rpb)"), yaxis = list(title = "Say"))
  })

  output$uygunluq_bar <- renderPlotly({
    df <- filt() %>% count(uygunluq)
    plot_ly(df, x = ~uygunluq, y = ~n, type = "bar",
            marker = list(color = c("#f39c12", "#dd4b39", "#00a65a")),
            text = ~n, textposition = "outside") %>%
      layout(xaxis = list(title = ""), yaxis = list(title = "Sual Sayı"))
  })

  output$duzgun_pb_scatter <- renderPlotly({
    df <- filt()
    plot_ly(df, x = ~duzgun_faiz, y = ~point_biserial, color = ~uygunluq,
            colors = c("Yaxşı" = "#00a65a", "Orta" = "#f39c12", "Zəif" = "#dd4b39"),
            type = "scatter", mode = "markers", marker = list(size = 5, opacity = 0.6)) %>%
      add_segments(x = 0, xend = 100, y = 0.2, yend = 0.2,
                   line = list(color = "red", dash = "dash"), name = "rpb=0.2") %>%
      layout(xaxis = list(title = "Düzgün Cavab %"), yaxis = list(title = "Point-Biserial"))
  })

  # Bloom
  output$bloom_bar <- renderPlotly({
    df <- filt() %>% count(bloom) %>%
      mutate(bloom = factor(bloom, levels = c("Bilik", "Anlama", "Tətbiq", "Analiz", "Sintez", "Qiymətləndirmə")))
    plot_ly(df, x = ~bloom, y = ~n, type = "bar",
            marker = list(color = c("#3c8dbc", "#00c0ef", "#00a65a", "#f39c12", "#dd4b39", "#605ca8")),
            text = ~n, textposition = "outside") %>%
      layout(xaxis = list(title = ""), yaxis = list(title = "Sual Sayı"))
  })

  output$bloom_fen <- renderPlotly({
    df <- filt() %>% count(fen, bloom) %>%
      mutate(bloom = factor(bloom, levels = c("Bilik", "Anlama", "Tətbiq", "Analiz", "Sintez", "Qiymətləndirmə")))
    plot_ly(df, x = ~fen, y = ~n, color = ~bloom, type = "bar") %>%
      layout(barmode = "stack", xaxis = list(title = ""), yaxis = list(title = "Sual Sayı"),
             legend = list(orientation = "h", y = -0.2), margin = list(b = 80))
  })

  # ICC
  output$icc_plot <- renderPlotly({
    req(input$icc_btn)
    isolate({
      item <- suallar %>% filter(sual_id == input$icc_item)
      theta <- seq(-4, 4, 0.05)
      prob <- item$c + (1 - item$c) / (1 + exp(-item$a * (theta - item$b)))
      info <- (item$a^2 * (prob - item$c)^2 * (1 - prob)) / ((1 - item$c)^2 * prob)

      plot_ly() %>%
        add_trace(x = theta, y = prob, type = "scatter", mode = "lines",
                  line = list(color = "#3c8dbc", width = 3), name = "P(θ)") %>%
        add_trace(x = theta, y = info / max(info), type = "scatter", mode = "lines",
                  line = list(color = "#dd4b39", width = 2, dash = "dash"), name = "I(θ) norm.") %>%
        add_segments(x = item$b, xend = item$b, y = 0, yend = 1,
                     line = list(color = "gray", dash = "dot"), name = paste0("b=", item$b)) %>%
        layout(xaxis = list(title = "θ (Qabiliyyət)"),
               yaxis = list(title = "Ehtimal / İnformasiya"),
               title = paste0("ICC: ", item$sual_id),
               legend = list(x = 0.02, y = 0.98))
    })
  })

  output$icc_info <- renderPrint({
    req(input$icc_btn)
    isolate({
      item <- suallar %>% filter(sual_id == input$icc_item)
      cat("Sual ID:    ", item$sual_id, "\n")
      cat("Fən:        ", item$fen, "\n")
      cat("Mövzu:      ", item$movzu, "\n")
      cat("Sinif:      ", item$sinif, "\n")
      cat("Çətinlik:   ", item$cetinlik, "\n")
      cat("Bloom:      ", item$bloom, "\n")
      cat("---IRT Parametrlər---\n")
      cat("a (ayırd):  ", item$a, "\n")
      cat("b (çətin):  ", item$b, "\n")
      cat("c (tapma):  ", item$c, "\n")
      cat("---Statistika---\n")
      cat("Düzgün %:   ", item$duzgun_faiz, "\n")
      cat("rpb:        ", item$point_biserial, "\n")
      cat("Uyğunluq:   ", item$uygunluq, "\n")
      cat("Status:     ", item$status, "\n")
      cat("İstifadə:   ", item$istifade_sayi, " dəfə\n")
    })
  })
}

shinyApp(ui = ui, server = server)
