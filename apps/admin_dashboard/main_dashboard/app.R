# 
# ============================================================

library(shiny)
library(shinydashboard)
library(plotly)
library(DT)
library(dplyr)
library(tidyr)
library(lubridate)

# ===== NÜMUNƏ MƏLUMATLAR =====

set.seed(2026)

# Məktəb məlumatları
mektebler <- data.frame(
  mekteb_id = paste0("SCH_", sprintf("%03d", 1:50)),
  mekteb_adi = paste0(
    sample(c("Bakı", "Gəncə", "Sumqayıt", "Mingəçevir", "Şəki",
             "Lənkəran", "Naxçıvan", "Şirvan", "Quba", "Şamaxı"), 50, replace = TRUE),
    " ", sample(c("Lisey", "Gimnaziya", "Məktəb"), 50, replace = TRUE),
    " #", sample(1:30, 50, replace = TRUE)
  ),
  mekteb_tipi = sample(c("Lisey", "Gimnaziya", "Ümumi"), 50, replace = TRUE, prob = c(0.3, 0.25, 0.45)),
  region = sample(c("Bakı", "Gəncə", "Sumqayıt", "Mingəçevir", "Şəki",
                     "Lənkəran", "Naxçıvan", "Şirvan", "Quba", "Şamaxı"), 50, replace = TRUE),
  shagird_sayi = sample(200:800, 50),
  muellim_sayi = sample(20:60, 50, replace = TRUE),
  ort_bal = round(runif(50, 35, 85), 1),
  kechid_faizi = round(runif(50, 40, 95), 1),
  stringsAsFactors = FALSE
)

# Aylıq test statistikası
aylar <- c("Yan", "Fev", "Mar", "Apr", "May", "İyn",
           "İyl", "Avq", "Sen", "Okt", "Noy", "Dek")

aylig_stat <- data.frame(
  ay = factor(aylar, levels = aylar),
  cat_test = c(120, 145, 180, 210, 250, 80, 30, 50, 190, 230, 260, 200),
  mst_test = c(80, 95, 130, 150, 170, 60, 20, 35, 140, 160, 180, 140),
  sertifikasiya = c(0, 50, 0, 0, 80, 0, 0, 0, 60, 0, 0, 40),
  ishe_qebul = c(0, 0, 100, 0, 0, 120, 0, 0, 0, 80, 0, 0)
)

# Fənlər üzrə nəticələr
fenler <- data.frame(
  fen = c("Riyaziyyat", "Fizika", "Kimya", "Biologiya", "İnformatika",
          "Azərb. dili", "Tarix", "Coğrafiya", "İngilis dili"),
  ort_bal = c(62.3, 55.8, 58.1, 64.5, 71.2, 68.4, 60.7, 63.9, 57.6),
  test_sayi = c(2400, 1800, 1500, 1600, 1200, 2200, 1400, 1100, 1900),
  sual_sayi = c(1200, 800, 700, 750, 600, 900, 650, 500, 850),
  stringsAsFactors = FALSE
)

# Son fəaliyyətlər
son_fealiyyet <- data.frame(
  tarix = format(Sys.Date() - sample(0:14, 10), "%d.%m.%Y"),
  hadise = c(
    "CAT testi keçirildi - Bakı Lisey #6",
    "Sertifikasiya imtahanı başa çatdı",
    "Yeni 150 sual bazaya əlavə edildi",
    "MST testi - Gəncə Gimnaziya #2",
    "Müəllim işə qəbul nəticələri elan edildi",
    "STEAM olimpiada qeydiyyatı başladı",
    "Kurikulum yeniləmə təsdiqləndi",
    "Server ehtiyat nüsxəsi yaradıldı",
    "Onlayn təlim proqramı başladı",
    "CAT testi - Sumqayıt Məktəb #15"
  ),
  status = sample(c("Tamamlandı", "Davam edir", "Gözlənilir"), 10, replace = TRUE, prob = c(0.6, 0.25, 0.15)),
  stringsAsFactors = FALSE
)


# ===== UI =====

ui <- dashboardPage(
  skin = "blue",

  # Başlıq
  dashboardHeader(
    title = tags$span(
      tags$img(src = "", height = "30px", style = "margin-right: 10px;"),
      "ARTI 2026"
    ),
    titleWidth = 280,
    tags$li(class = "dropdown",
            tags$a(href = "#", style = "color: white; padding: 15px;",
                   icon("bell"), tags$span(class = "label label-warning", "5")))
  ),

  # Sol panel
  dashboardSidebar(
    width = 280,
    sidebarMenu(
      id = "tabs",
      menuItem("Ana Səhifə", tabName = "ana", icon = icon("home")),
      menuItem("Qiymətləndirmə", tabName = "qiymet", icon = icon("chart-bar"),
               badgeLabel = "CAT/MST", badgeColor = "green"),
      menuItem("Sertifikasiya", tabName = "sertif", icon = icon("certificate")),
      menuItem("Məktəb Şəbəkəsi", tabName = "mekteb", icon = icon("school")),
      menuItem("Fənlər", tabName = "fen", icon = icon("book")),
      menuItem("Fəaliyyət Jurnalı", tabName = "jurnal", icon = icon("list")),
      hr(),
      menuItem("Digər Dashboard-lar", icon = icon("th"),
               menuSubItem("Qiymətləndirmə Paneli", icon = icon("chart-line"), href = "#"),
               menuSubItem("Sertifikasiya Paneli", icon = icon("id-card"), href = "#"),
               menuSubItem("Məktəb Paneli", icon = icon("building"), href = "#"),
               menuSubItem("Sual Bazası", icon = icon("database"), href = "#"),
               menuSubItem("Tədqiqat Paneli", icon = icon("flask"), href = "#"),
               menuSubItem("Təlim Paneli", icon = icon("graduation-cap"), href = "#"),
               menuSubItem("Server Paneli", icon = icon("server"), href = "#")
      )
    ),
    tags$div(style = "padding: 15px; color: #b8c7ce; font-size: 11px; position: absolute; bottom: 10px;",
             tags$p("ARTI - Təhsil İnstitutu"),
             tags$p(paste0("Tarix: ", format(Sys.Date(), "%d.%m.%Y")))
    )
  ),

  # Əsas məzmun
  dashboardBody(
    # Xüsusi CSS
    tags$head(tags$style(HTML("
      .content-wrapper { background-color: #f4f6f9; }
      .small-box .icon { font-size: 60px; top: 5px; }
      .info-box { min-height: 90px; }
      .box-header { border-bottom: 2px solid #3c8dbc; }
      .skin-blue .main-header .logo { font-weight: bold; font-size: 18px; }
      .nav-tabs-custom > .tab-content { padding: 15px; }
      .dataTables_wrapper { font-size: 13px; }
      .main-header .navbar { margin-left: 280px; }
      .main-header .logo { width: 280px; }
      .main-sidebar { width: 280px; }
      .content-wrapper, .right-side, .main-footer { margin-left: 280px; }
    "))),

    tabItems(
      # ===== ANA SƏHİFƏ =====
      tabItem(tabName = "ana",
        # Yuxarı kartlar
        fluidRow(
          valueBox(
            value = format(sum(mektebler$shagird_sayi), big.mark = " "),
            subtitle = "Ümumi Şagird",
            icon = icon("users"),
            color = "blue", width = 3
          ),
          valueBox(
            value = nrow(mektebler),
            subtitle = "Qeydiyyatlı Məktəb",
            icon = icon("school"),
            color = "green", width = 3
          ),
          valueBox(
            value = format(sum(fenler$test_sayi), big.mark = " "),
            subtitle = "Keçirilmiş Test",
            icon = icon("file-alt"),
            color = "yellow", width = 3
          ),
          valueBox(
            value = format(sum(fenler$sual_sayi), big.mark = " "),
            subtitle = "Sual Bazası",
            icon = icon("database"),
            color = "red", width = 3
          )
        ),

        # Qrafiklər
        fluidRow(
          box(
            title = "Aylıq Test Statistikası", status = "primary",
            solidHeader = TRUE, width = 8, height = 420,
            plotlyOutput("aylig_qrafik", height = "350px")
          ),
          box(
            title = "Məktəb Tipləri", status = "info",
            solidHeader = TRUE, width = 4, height = 420,
            plotlyOutput("mekteb_tip_pie", height = "350px")
          )
        ),

        fluidRow(
          box(
            title = "Fənlər üzrə Orta Bal", status = "success",
            solidHeader = TRUE, width = 6, height = 400,
            plotlyOutput("fen_bar", height = "330px")
          ),
          box(
            title = "Regionlar üzrə Məktəb Sayı", status = "warning",
            solidHeader = TRUE, width = 6, height = 400,
            plotlyOutput("region_bar", height = "330px")
          )
        ),

        # Son fəaliyyətlər
        fluidRow(
          box(
            title = "Son Fəaliyyətlər", status = "primary",
            solidHeader = TRUE, width = 12,
            DT::dataTableOutput("son_fealiyyet_table")
          )
        )
      ),

      # ===== QİYMƏTLƏNDİRMƏ =====
      tabItem(tabName = "qiymet",
        fluidRow(
          infoBox("CAT Testlər", sum(aylig_stat$cat_test), icon = icon("laptop"),
                  color = "blue", width = 3, subtitle = "Bu il"),
          infoBox("MST Testlər", sum(aylig_stat$mst_test), icon = icon("layer-group"),
                  color = "green", width = 3, subtitle = "Bu il"),
          infoBox("Orta Theta", "+0.42", icon = icon("chart-line"),
                  color = "yellow", width = 3, subtitle = "Milli orta"),
          infoBox("Orta SE", "0.31", icon = icon("bullseye"),
                  color = "red", width = 3, subtitle = "Standart xəta")
        ),
        fluidRow(
          box(
            title = "CAT vs MST Test Sayı (Aylıq)", status = "primary",
            solidHeader = TRUE, width = 8,
            plotlyOutput("cat_mst_compare", height = "350px")
          ),
          box(
            title = "Test Növü Paylanması", status = "info",
            solidHeader = TRUE, width = 4,
            plotlyOutput("test_nov_pie", height = "350px")
          )
        ),
        fluidRow(
          box(
            title = "Performans Seviyyəsi Paylanması", status = "success",
            solidHeader = TRUE, width = 12,
            plotlyOutput("performans_bar", height = "300px")
          )
        )
      ),

      # ===== SERTİFİKASİYA =====
      tabItem(tabName = "sertif",
        fluidRow(
          infoBox("İşə Qəbul", sum(aylig_stat$ishe_qebul), icon = icon("user-plus"),
                  color = "blue", width = 3, subtitle = "Namizəd"),
          infoBox("Sertifikasiya", sum(aylig_stat$sertifikasiya), icon = icon("certificate"),
                  color = "green", width = 3, subtitle = "Namizəd"),
          infoBox("Keçid %", "67.3%", icon = icon("check-circle"),
                  color = "yellow", width = 3, subtitle = "Orta keçid faizi"),
          infoBox("Sual Bazası", "4,500", icon = icon("question-circle"),
                  color = "red", width = 3, subtitle = "Aktiv sual")
        ),
        fluidRow(
          box(
            title = "Sertifikasiya və İşə Qəbul (Aylıq)", status = "primary",
            solidHeader = TRUE, width = 8,
            plotlyOutput("sertif_aylig", height = "350px")
          ),
          box(
            title = "Nəticə Paylanması", status = "info",
            solidHeader = TRUE, width = 4,
            plotlyOutput("sertif_pie", height = "350px")
          )
        )
      ),

      # ===== MƏKTƏB ŞƏBƏKƏSİ =====
      tabItem(tabName = "mekteb",
        fluidRow(
          box(
            title = "Məktəb Şəbəkəsi", status = "primary",
            solidHeader = TRUE, width = 12,
            fluidRow(
              column(3, selectInput("region_filter", "Region:",
                                    c("Hamısı", unique(mektebler$region)))),
              column(3, selectInput("tip_filter", "Məktəb Tipi:",
                                    c("Hamısı", unique(mektebler$mekteb_tipi)))),
              column(3, sliderInput("bal_filter", "Min. Orta Bal:", 0, 100, 0)),
              column(3, tags$br(), actionButton("filter_btn", "Filtrlə",
                                                 class = "btn-primary", style = "margin-top: 0px;"))
            ),
            DT::dataTableOutput("mekteb_table")
          )
        ),
        fluidRow(
          box(
            title = "Orta Bal Paylanması", status = "success",
            solidHeader = TRUE, width = 6,
            plotlyOutput("mekteb_hist", height = "300px")
          ),
          box(
            title = "Şagird vs Orta Bal", status = "warning",
            solidHeader = TRUE, width = 6,
            plotlyOutput("mekteb_scatter", height = "300px")
          )
        )
      ),

      # ===== FƏNLƏR =====
      tabItem(tabName = "fen",
        fluidRow(
          box(
            title = "Fənlər üzrə Ətraflı Statistika", status = "primary",
            solidHeader = TRUE, width = 12,
            DT::dataTableOutput("fen_table")
          )
        ),
        fluidRow(
          box(
            title = "Test və Sual Sayı Müqayisəsi", status = "info",
            solidHeader = TRUE, width = 12,
            plotlyOutput("fen_compare", height = "350px")
          )
        )
      ),

      # ===== FƏALİYYƏT JURNALI =====
      tabItem(tabName = "jurnal",
        fluidRow(
          box(
            title = "Sistem Fəaliyyət Jurnalı", status = "primary",
            solidHeader = TRUE, width = 12,
            DT::dataTableOutput("jurnal_table")
          )
        )
      )
    )
  )
)


# ===== SERVER =====

server <- function(input, output, session) {

  # --- Ana Səhifə Qrafikləri ---

  output$aylig_qrafik <- renderPlotly({
    plot_ly(aylig_stat, x = ~ay) %>%
      add_trace(y = ~cat_test, name = "CAT", type = "scatter", mode = "lines+markers",
                line = list(color = "#3c8dbc", width = 3),
                marker = list(size = 8)) %>%
      add_trace(y = ~mst_test, name = "MST", type = "scatter", mode = "lines+markers",
                line = list(color = "#00a65a", width = 3),
                marker = list(size = 8)) %>%
      add_trace(y = ~sertifikasiya, name = "Sertifikasiya", type = "bar",
                marker = list(color = "#f39c12", opacity = 0.6)) %>%
      add_trace(y = ~ishe_qebul, name = "İşə Qəbul", type = "bar",
                marker = list(color = "#dd4b39", opacity = 0.6)) %>%
      layout(
        xaxis = list(title = ""),
        yaxis = list(title = "Test Sayı"),
        barmode = "group",
        legend = list(orientation = "h", y = -0.15),
        margin = list(b = 60),
        hovermode = "x unified"
      )
  })

  output$mekteb_tip_pie <- renderPlotly({
    tip_data <- mektebler %>% count(mekteb_tipi)
    plot_ly(tip_data, labels = ~mekteb_tipi, values = ~n, type = "pie",
            textinfo = "label+percent",
            marker = list(colors = c("#3c8dbc", "#00a65a", "#f39c12")),
            hole = 0.4) %>%
      layout(showlegend = FALSE,
             margin = list(l = 20, r = 20, t = 20, b = 20))
  })

  output$fen_bar <- renderPlotly({
    fenler_sorted <- fenler %>% arrange(desc(ort_bal))
    colors <- ifelse(fenler_sorted$ort_bal >= 65, "#00a65a",
                     ifelse(fenler_sorted$ort_bal >= 55, "#f39c12", "#dd4b39"))
    plot_ly(fenler_sorted, x = ~reorder(fen, ort_bal), y = ~ort_bal, type = "bar",
            marker = list(color = colors),
            text = ~paste0(ort_bal, "%"), textposition = "outside") %>%
      layout(
        xaxis = list(title = ""),
        yaxis = list(title = "Orta Bal (%)", range = c(0, 90)),
        margin = list(b = 80)
      )
  })

  output$region_bar <- renderPlotly({
    region_data <- mektebler %>% count(region) %>% arrange(desc(n))
    plot_ly(region_data, x = ~reorder(region, n), y = ~n, type = "bar",
            marker = list(color = "#3c8dbc"),
            text = ~n, textposition = "outside") %>%
      layout(
        xaxis = list(title = ""),
        yaxis = list(title = "Məktəb Sayı"),
        margin = list(b = 80)
      )
  })

  output$son_fealiyyet_table <- DT::renderDataTable({
    datatable(son_fealiyyet,
              colnames = c("Tarix", "Hadisə", "Status"),
              options = list(pageLength = 5, dom = "tp", ordering = FALSE),
              rownames = FALSE) %>%
      formatStyle("status",
                  backgroundColor = styleEqual(
                    c("Tamamlandı", "Davam edir", "Gözlənilir"),
                    c("#d4edda", "#fff3cd", "#f8d7da")
                  ))
  })

  # --- Qiymətləndirmə ---

  output$cat_mst_compare <- renderPlotly({
    plot_ly(aylig_stat, x = ~ay) %>%
      add_trace(y = ~cat_test, name = "CAT", type = "bar",
                marker = list(color = "#3c8dbc")) %>%
      add_trace(y = ~mst_test, name = "MST", type = "bar",
                marker = list(color = "#00a65a")) %>%
      layout(barmode = "group",
             xaxis = list(title = ""),
             yaxis = list(title = "Test Sayı"),
             legend = list(orientation = "h", y = -0.15))
  })

  output$test_nov_pie <- renderPlotly({
    data <- data.frame(
      nov = c("CAT", "MST", "Klassik"),
      say = c(sum(aylig_stat$cat_test), sum(aylig_stat$mst_test), 450)
    )
    plot_ly(data, labels = ~nov, values = ~say, type = "pie",
            textinfo = "label+percent",
            marker = list(colors = c("#3c8dbc", "#00a65a", "#f39c12")),
            hole = 0.4) %>%
      layout(showlegend = TRUE, margin = list(l = 10, r = 10, t = 10, b = 10))
  })

  output$performans_bar <- renderPlotly({
    perf <- data.frame(
      seviyye = factor(c("Əla", "Yaxşı", "Orta", "Zəif", "Çox zəif"),
                       levels = c("Çox zəif", "Zəif", "Orta", "Yaxşı", "Əla")),
      faiz = c(15, 28, 35, 16, 6)
    )
    plot_ly(perf, x = ~seviyye, y = ~faiz, type = "bar",
            marker = list(color = c("#dd4b39", "#f39c12", "#3c8dbc", "#00a65a", "#00c0ef")),
            text = ~paste0(faiz, "%"), textposition = "outside") %>%
      layout(xaxis = list(title = ""), yaxis = list(title = "Faiz (%)"))
  })

  # --- Sertifikasiya ---

  output$sertif_aylig <- renderPlotly({
    plot_ly(aylig_stat, x = ~ay) %>%
      add_trace(y = ~sertifikasiya, name = "Sertifikasiya", type = "bar",
                marker = list(color = "#00a65a")) %>%
      add_trace(y = ~ishe_qebul, name = "İşə Qəbul", type = "bar",
                marker = list(color = "#3c8dbc")) %>%
      layout(barmode = "group",
             xaxis = list(title = ""),
             yaxis = list(title = "Namizəd Sayı"),
             legend = list(orientation = "h", y = -0.15))
  })

  output$sertif_pie <- renderPlotly({
    data <- data.frame(
      netice = c("Keçdi", "Keçmədi"),
      say = c(67, 33)
    )
    plot_ly(data, labels = ~netice, values = ~say, type = "pie",
            textinfo = "label+percent",
            marker = list(colors = c("#00a65a", "#dd4b39")),
            hole = 0.5) %>%
      layout(showlegend = TRUE, margin = list(l = 10, r = 10, t = 10, b = 10))
  })

  # --- Məktəb Şəbəkəsi ---

  filtered_mektebler <- reactive({
    df <- mektebler
    if (input$region_filter != "Hamısı") {
      df <- df %>% filter(region == input$region_filter)
    }
    if (input$tip_filter != "Hamısı") {
      df <- df %>% filter(mekteb_tipi == input$tip_filter)
    }
    df <- df %>% filter(ort_bal >= input$bal_filter)
    df
  }) %>% bindEvent(input$filter_btn, ignoreNULL = FALSE)

  output$mekteb_table <- DT::renderDataTable({
    df <- filtered_mektebler() %>%
      select(mekteb_adi, mekteb_tipi, region, shagird_sayi, muellim_sayi, ort_bal, kechid_faizi)
    datatable(df,
              colnames = c("Məktəb", "Tip", "Region", "Şagird", "Müəllim", "Orta Bal", "Keçid %"),
              options = list(pageLength = 10, scrollX = TRUE),
              rownames = FALSE) %>%
      formatStyle("ort_bal",
                  background = styleColorBar(c(0, 100), "#3c8dbc"),
                  backgroundSize = "90% 70%", backgroundRepeat = "no-repeat",
                  backgroundPosition = "left") %>%
      formatStyle("kechid_faizi",
                  color = styleInterval(c(50, 70), c("#dd4b39", "#f39c12", "#00a65a")),
                  fontWeight = "bold")
  })

  output$mekteb_hist <- renderPlotly({
    df <- filtered_mektebler()
    plot_ly(df, x = ~ort_bal, type = "histogram",
            marker = list(color = "#3c8dbc", line = list(color = "white", width = 1)),
            nbinsx = 15) %>%
      layout(xaxis = list(title = "Orta Bal"),
             yaxis = list(title = "Məktəb Sayı"))
  })

  output$mekteb_scatter <- renderPlotly({
    df <- filtered_mektebler()
    plot_ly(df, x = ~shagird_sayi, y = ~ort_bal, color = ~mekteb_tipi,
            type = "scatter", mode = "markers",
            marker = list(size = 10, opacity = 0.7),
            text = ~paste0(mekteb_adi, "<br>Şagird: ", shagird_sayi,
                           "<br>Orta Bal: ", ort_bal),
            hoverinfo = "text") %>%
      layout(xaxis = list(title = "Şagird Sayı"),
             yaxis = list(title = "Orta Bal"),
             legend = list(orientation = "h", y = -0.2))
  })

  # --- Fənlər ---

  output$fen_table <- DT::renderDataTable({
    datatable(fenler,
              colnames = c("Fən", "Orta Bal", "Test Sayı", "Sual Sayı"),
              options = list(pageLength = 10, dom = "t"),
              rownames = FALSE) %>%
      formatStyle("ort_bal",
                  background = styleColorBar(c(0, 100), "#00a65a"),
                  backgroundSize = "90% 70%", backgroundRepeat = "no-repeat",
                  backgroundPosition = "left") %>%
      formatRound("ort_bal", digits = 1)
  })

  output$fen_compare <- renderPlotly({
    plot_ly(fenler, x = ~fen) %>%
      add_trace(y = ~test_sayi, name = "Test Sayı", type = "bar",
                marker = list(color = "#3c8dbc")) %>%
      add_trace(y = ~sual_sayi, name = "Sual Sayı", type = "bar",
                marker = list(color = "#00a65a")) %>%
      layout(barmode = "group",
             xaxis = list(title = ""),
             yaxis = list(title = "Say"),
             legend = list(orientation = "h", y = -0.2))
  })

  # --- Jurnal ---

  output$jurnal_table <- DT::renderDataTable({
    # Genişləndirilmiş jurnal
    jurnal <- data.frame(
      tarix = format(Sys.Date() - sample(0:30, 30, replace = TRUE), "%d.%m.%Y %H:%M"),
      modul = sample(c("CAT", "MST", "Sertifikasiya", "İşə Qəbul", "Sual Bazası",
                        "Server", "Kurikulum", "Təlim"), 30, replace = TRUE),
      hadise = sample(c("Test keçirildi", "Nəticə yükləndi", "Sual əlavə edildi",
                         "İmtahan planlandı", "Ehtiyat nüsxə yaradıldı",
                         "Sistem yeniləndi", "Hesabat yaradıldı"), 30, replace = TRUE),
      istifadechi = sample(c("admin", "examiner01", "teacher05", "researcher02"), 30, replace = TRUE),
      status = sample(c("Uğurlu", "Xəbərdarlıq", "Xəta"), 30, replace = TRUE, prob = c(0.8, 0.15, 0.05)),
      stringsAsFactors = FALSE
    )
    datatable(jurnal,
              colnames = c("Tarix", "Modul", "Hadisə", "İstifadəçi", "Status"),
              options = list(pageLength = 15, order = list(list(0, "desc"))),
              rownames = FALSE) %>%
      formatStyle("status",
                  backgroundColor = styleEqual(
                    c("Uğurlu", "Xəbərdarlıq", "Xəta"),
                    c("#d4edda", "#fff3cd", "#f8d7da")
                  ),
                  fontWeight = "bold")
  })
}


# ===== ISHGA SAL =====
shinyApp(ui = ui, server = server)
