# =============================================
# Beynəlxalq Əməkdaşlıq Modulu - UI
# =============================================

# --- Olimpiadalar ---
intl_olympiads_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(
      column(12, h2(icon("trophy"), "Olimpiadalar"), hr())
    ),
    fluidRow(
      column(3,
        selectInput(ns("filter_oly_subject"), "Fənn:",
          choices = c("Hamısı" = "", OLYMPIAD_SUBJECTS))
      ),
      column(3,
        selectInput(ns("filter_oly_level"), "Səviyyə:",
          choices = c("Hamısı" = "", "Məktəb" = "mekteb", "Rayon" = "rayon",
                      "Respublika" = "respublika", "Beynəlxalq" = "beynelxalq"))
      ),
      column(3,
        selectInput(ns("filter_oly_status"), "Status:",
          choices = c("Hamısı" = "", "Planlaşdırılmış" = "planned",
                      "Qeydiyyat" = "registration", "Aktiv" = "active",
                      "Tamamlanmış" = "completed"))
      ),
      column(3,
        actionButton(ns("btn_add_olympiad"), "Yeni Olimpiada", icon = icon("plus"),
                     class = "btn-primary", style = "margin-top: 25px;")
      )
    ),
    fluidRow(
      column(12, DTOutput(ns("olympiads_table")))
    ),
    fluidRow(
      column(12,
        box(
          title = "Medal Statistikası", status = "warning", solidHeader = TRUE,
          width = 12, collapsible = TRUE, collapsed = TRUE,
          fluidRow(
            valueBoxOutput(ns("gold_box"), width = 3),
            valueBoxOutput(ns("silver_box"), width = 3),
            valueBoxOutput(ns("bronze_box"), width = 3),
            valueBoxOutput(ns("total_participants_box"), width = 3)
          ),
          plotlyOutput(ns("medals_chart"), height = "300px")
        )
      )
    ),
    fluidRow(
      column(12,
        box(
          title = "İştirakçılar", status = "info", solidHeader = TRUE,
          width = 12, collapsible = TRUE, collapsed = TRUE,
          DTOutput(ns("participants_table")),
          tags$hr(),
          actionButton(ns("btn_add_participant"), "İştirakçı Əlavə Et",
                       icon = icon("user-plus"), class = "btn-info")
        )
      )
    ),
    uiOutput(ns("olympiad_modal"))
  )
}

# --- STEAM Layihələri ---
intl_steam_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(
      column(12, h2(icon("rocket"), "STEAM Layihələri"), hr())
    ),
    fluidRow(
      column(3,
        selectInput(ns("filter_steam_type"), "Layihə Növü:",
          choices = c("Hamısı" = "", "Elm" = "science", "Texnologiya" = "technology",
                      "Mühəndislik" = "engineering", "Sənət" = "arts",
                      "Riyaziyyat" = "mathematics"))
      ),
      column(3,
        selectInput(ns("filter_steam_status"), "Status:",
          choices = c("Hamısı" = "", "Planlaşdırılmış" = "planned",
                      "Aktiv" = "active", "Tamamlanmış" = "completed",
                      "Dayandırılmış" = "suspended"))
      ),
      column(3,
        actionButton(ns("btn_steam_refresh"), "Yenilə", icon = icon("refresh"),
                     class = "btn-default", style = "margin-top: 25px;")
      ),
      column(3,
        actionButton(ns("btn_add_steam"), "Yeni Layihə", icon = icon("plus"),
                     class = "btn-success", style = "margin-top: 25px;")
      )
    ),
    fluidRow(
      column(12, DTOutput(ns("steam_table")))
    ),
    uiOutput(ns("steam_modal"))
  )
}

# --- Partnyor Proqramları ---
intl_partners_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(
      column(12, h2(icon("handshake"), "Partnyor Proqramları"), hr())
    ),
    fluidRow(
      column(3,
        selectInput(ns("filter_partner_type"), "Partnyor Növü:",
          choices = c("Hamısı" = "", "Universitet" = "university",
                      "Təşkilat" = "organization", "Hökumət" = "government",
                      "QHT" = "ngo"))
      ),
      column(3,
        selectInput(ns("filter_partner_status"), "Status:",
          choices = c("Hamısı" = "", "Aktiv" = "active",
                      "Tamamlanmış" = "completed", "Gözləmədə" = "pending"))
      ),
      column(3,
        actionButton(ns("btn_partner_refresh"), "Yenilə", icon = icon("refresh"),
                     class = "btn-default", style = "margin-top: 25px;")
      ),
      column(3,
        actionButton(ns("btn_add_partner"), "Yeni Proqram", icon = icon("plus"),
                     class = "btn-primary", style = "margin-top: 25px;")
      )
    ),
    fluidRow(
      column(12, DTOutput(ns("partners_table")))
    ),
    fluidRow(
      column(12,
        box(
          title = "Partnyor Xəritəsi", status = "primary", solidHeader = TRUE,
          width = 12, collapsible = TRUE, collapsed = TRUE,
          plotlyOutput(ns("partner_countries_chart"), height = "300px")
        )
      )
    ),
    uiOutput(ns("partner_modal"))
  )
}
