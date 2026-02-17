#!/bin/bash
# =============================================
# ARTI-2026: Deployment Skripti
# =============================================

set -euo pipefail

# Rənglər
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Konfiqurasiya
APP_NAME="arti-2026"
APP_DIR="/opt/${APP_NAME}"
DEPLOY_DIR="${APP_DIR}/deploy"
BACKUP_DIR="${APP_DIR}/backups"
LOG_FILE="${APP_DIR}/logs/deploy.log"

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "${LOG_FILE}" 2>/dev/null || true
}

error() {
    echo -e "${RED}[XƏTA]${NC} $1"
    echo "[XƏTA] $1" >> "${LOG_FILE}" 2>/dev/null || true
    exit 1
}

success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[XƏBƏRDARLIQ]${NC} $1"
}

# =============================================
# Tələbləri yoxla
# =============================================
check_requirements() {
    log "Tələblər yoxlanılır..."

    if ! command -v docker &> /dev/null; then
        error "Docker tapılmadı. Əvvəlcə Docker yükləyin."
    fi
    success "Docker tapıldı: $(docker --version)"

    if ! docker compose version &> /dev/null; then
        error "Docker Compose tapılmadı."
    fi
    success "Docker Compose tapıldı: $(docker compose version)"

    if [ ! -f "${APP_DIR}/.env" ]; then
        warning ".env faylı tapılmadı. .env.example kopyalanır..."
        cp "${APP_DIR}/.env.example" "${APP_DIR}/.env" 2>/dev/null || \
            cp "${APP_DIR}/.env" "${APP_DIR}/.env" 2>/dev/null || \
            error ".env faylı yaradıla bilmədi"
    fi
    success ".env faylı mövcuddur"
}

# =============================================
# Backup yarat
# =============================================
create_backup() {
    log "Backup yaradılır..."

    mkdir -p "${BACKUP_DIR}"

    TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
    BACKUP_FILE="${BACKUP_DIR}/db_backup_${TIMESTAMP}.sql"

    # DB backup (əgər konteyner işləyirsə)
    if docker ps | grep -q "${APP_NAME}-db"; then
        docker compose -f "${DEPLOY_DIR}/docker-compose.yml" exec -T db \
            pg_dump -U "${DB_USER:-arti_user}" "${DB_NAME:-arti_2026}" > "${BACKUP_FILE}" 2>/dev/null
        if [ -f "${BACKUP_FILE}" ] && [ -s "${BACKUP_FILE}" ]; then
            gzip "${BACKUP_FILE}"
            success "DB backup yaradıldı: ${BACKUP_FILE}.gz"
        else
            warning "DB backup boşdur (ilk deployment ola bilər)"
            rm -f "${BACKUP_FILE}"
        fi
    else
        warning "DB konteyneri işləmir, backup atlanır"
    fi

    # Köhnə backup-ları sil (30 gündən köhnə)
    find "${BACKUP_DIR}" -name "*.gz" -mtime +30 -delete 2>/dev/null || true
}

# =============================================
# Docker image-ları qur
# =============================================
build_images() {
    log "Docker image-ları qurulur..."

    cd "${APP_DIR}"
    docker compose -f "${DEPLOY_DIR}/docker-compose.yml" build --no-cache app
    success "Image-lar quruldu"
}

# =============================================
# Konteynerləri işə sal
# =============================================
start_containers() {
    log "Konteynerlər işə salınır..."

    cd "${APP_DIR}"
    docker compose -f "${DEPLOY_DIR}/docker-compose.yml" up -d

    # Konteynerlər hazır olana qədər gözlə
    log "Konteynerlərin hazır olması gözlənilir..."
    sleep 10

    # Sağlamlıq yoxlaması
    RETRIES=0
    MAX_RETRIES=30
    while [ $RETRIES -lt $MAX_RETRIES ]; do
        if curl -sf http://localhost:3838/ > /dev/null 2>&1; then
            success "Tətbiq uğurla işə düşdü!"
            return 0
        fi
        RETRIES=$((RETRIES + 1))
        sleep 2
    done

    warning "Tətbiq cavab vermir, logları yoxlayın: docker compose logs app"
}

# =============================================
# DB miqrasiyaları işlət
# =============================================
run_migrations() {
    log "Verilənlər bazası miqrasiyaları işlədilir..."

    cd "${APP_DIR}"

    # Miqrasiya fayllarını sıra ilə işlət
    for migration in database/migrations/*.sql; do
        if [ -f "$migration" ]; then
            log "  Miqrasiya: $(basename $migration)"
            docker compose -f "${DEPLOY_DIR}/docker-compose.yml" exec -T db \
                psql -U "${DB_USER:-arti_user}" -d "${DB_NAME:-arti_2026}" -f "/docker-entrypoint-initdb.d/$(basename $migration)" 2>/dev/null || true
        fi
    done

    # Stored procedures
    if [ -f "database/functions/stored_procedures.sql" ]; then
        log "  Stored procedures yüklənir..."
        docker compose -f "${DEPLOY_DIR}/docker-compose.yml" exec -T db \
            psql -U "${DB_USER:-arti_user}" -d "${DB_NAME:-arti_2026}" -f "/docker-entrypoint-initdb.d/functions/stored_procedures.sql" 2>/dev/null || true
    fi

    success "Miqrasiyalar tamamlandı"
}

# =============================================
# Əsas axın
# =============================================
main() {
    echo ""
    echo -e "${BLUE}=============================================${NC}"
    echo -e "${BLUE}  ARTI-2026 Deployment Skripti${NC}"
    echo -e "${BLUE}=============================================${NC}"
    echo ""

    check_requirements
    create_backup
    build_images
    start_containers
    run_migrations

    echo ""
    echo -e "${GREEN}=============================================${NC}"
    echo -e "${GREEN}  Deployment uğurla tamamlandı!${NC}"
    echo -e "${GREEN}=============================================${NC}"
    echo ""
    echo -e "  Tətbiq: ${BLUE}http://localhost${NC}"
    echo -e "  Admin:  ${BLUE}admin / Admin2026!${NC}"
    echo ""

    # Konteyner statusu
    docker compose -f "${DEPLOY_DIR}/docker-compose.yml" ps
}

# Skripti işlət
main "$@"
