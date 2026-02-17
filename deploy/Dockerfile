# =============================================
# ARTI-2026: Dockerfile
# R Shiny Tətbiqi üçün
# =============================================

FROM rocker/shiny:4.3.2

LABEL maintainer="ARTI-2026 <admin@arti2026.az>"
LABEL description="ARTI-2026 Təhsil İdarəetmə Sistemi"

# Sistem asılılıqları
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq-dev \
    libssl-dev \
    libcurl4-openssl-dev \
    libxml2-dev \
    libsodium-dev \
    libfontconfig1-dev \
    libfreetype6-dev \
    libpng-dev \
    libjpeg-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libtiff-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# R paketlərini yüklə
RUN R -e "install.packages(c( \
    'shiny', 'shinydashboard', 'shinydashboardPlus', 'shinyWidgets', \
    'shinyjs', 'bslib', 'waiter', \
    'DT', 'plotly', 'ggplot2', \
    'pool', 'DBI', 'RPostgres', \
    'dplyr', 'tidyr', 'purrr', \
    'httr', 'jsonlite', 'jose', \
    'openxlsx', 'sodium', 'config', \
    'testthat', 'shinytest2', 'dotenv' \
  ), repos='https://cloud.r-project.org/')"

# Tətbiq qovluğu
WORKDIR /srv/shiny-server/arti-2026

# Tətbiq fayllarını kopyala
COPY app.R .
COPY R/ R/
COPY modules/ modules/
COPY database/ database/
COPY ai_integration/ ai_integration/
COPY www/ www/
COPY config.yml .
COPY .env .

# Shiny Server konfiqurasiyası
COPY deploy/shiny-server.conf /etc/shiny-server/shiny-server.conf 2>/dev/null || true

# Log qovluqları
RUN mkdir -p /var/log/shiny-server /srv/shiny-server/arti-2026/logs \
    && chown -R shiny:shiny /srv/shiny-server/arti-2026 \
    && chmod -R 755 /srv/shiny-server/arti-2026

# Data qovluğu (upload-lar üçün)
RUN mkdir -p /srv/shiny-server/arti-2026/data/uploads \
    && chown -R shiny:shiny /srv/shiny-server/arti-2026/data

# Port
EXPOSE 3838

# Sağlamlıq yoxlaması
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:3838/ || exit 1

# Tətbiqi işə sal
USER shiny
CMD ["R", "-e", "shiny::runApp('/srv/shiny-server/arti-2026', host='0.0.0.0', port=3838)"]
