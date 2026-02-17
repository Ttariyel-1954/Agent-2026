#!/bin/bash
# =============================================
# ARTI-2026: Backup Skripti
# Gündəlik cron işi üçün nəzərdə tutulub
# Cron: 0 2 * * * /opt/arti-2026/deploy/scripts/backup.sh
# =============================================

set -euo pipefail

# Konfiqurasiya
APP_NAME="arti-2026"
APP_DIR="/opt/${APP_NAME}"
DEPLOY_DIR="${APP_DIR}/deploy"
BACKUP_DIR="${APP_DIR}/backups"
LOG_FILE="${APP_DIR}/logs/backup.log"
RETENTION_DAYS=30
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')

# .env faylından dəyişənləri yüklə
if [ -f "${APP_DIR}/.env" ]; then
    set -a
    source "${APP_DIR}/.env"
    set +a
fi

DB_USER="${DB_USER:-arti_user}"
DB_NAME="${DB_NAME:-arti_2026}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${LOG_FILE}"
}

error() {
    log "[XƏTA] $1"
    exit 1
}

# Backup qovluğunu yarat
mkdir -p "${BACKUP_DIR}/daily"
mkdir -p "${BACKUP_DIR}/weekly"

# =============================================
# 1. Verilənlər Bazası Backup
# =============================================
log "Verilənlər bazası backup başlayır..."

DB_BACKUP_FILE="${BACKUP_DIR}/daily/db_${TIMESTAMP}.sql"

docker compose -f "${DEPLOY_DIR}/docker-compose.yml" exec -T db \
    pg_dump -U "${DB_USER}" -d "${DB_NAME}" \
    --no-owner --no-acl --clean --if-exists \
    > "${DB_BACKUP_FILE}" 2>/dev/null

if [ -f "${DB_BACKUP_FILE}" ] && [ -s "${DB_BACKUP_FILE}" ]; then
    gzip "${DB_BACKUP_FILE}"
    DB_SIZE=$(du -h "${DB_BACKUP_FILE}.gz" | cut -f1)
    log "DB backup uğurlu: ${DB_BACKUP_FILE}.gz (${DB_SIZE})"
else
    rm -f "${DB_BACKUP_FILE}"
    error "DB backup uğursuz oldu"
fi

# =============================================
# 2. Tətbiq Faylları Backup
# =============================================
log "Tətbiq faylları backup başlayır..."

APP_BACKUP_FILE="${BACKUP_DIR}/daily/app_${TIMESTAMP}.tar.gz"

tar -czf "${APP_BACKUP_FILE}" \
    -C "${APP_DIR}" \
    --exclude='backups' \
    --exclude='logs' \
    --exclude='.git' \
    --exclude='node_modules' \
    app.R R/ modules/ database/ ai_integration/ config.yml \
    2>/dev/null

if [ -f "${APP_BACKUP_FILE}" ]; then
    APP_SIZE=$(du -h "${APP_BACKUP_FILE}" | cut -f1)
    log "Tətbiq backup uğurlu: ${APP_BACKUP_FILE} (${APP_SIZE})"
else
    error "Tətbiq backup uğursuz oldu"
fi

# =============================================
# 3. Upload-lar Backup (əgər varsa)
# =============================================
UPLOAD_DIR="${APP_DIR}/data/uploads"
if [ -d "${UPLOAD_DIR}" ] && [ "$(ls -A ${UPLOAD_DIR} 2>/dev/null)" ]; then
    log "Upload faylları backup başlayır..."
    UPLOAD_BACKUP="${BACKUP_DIR}/daily/uploads_${TIMESTAMP}.tar.gz"
    tar -czf "${UPLOAD_BACKUP}" -C "${APP_DIR}/data" uploads 2>/dev/null
    log "Upload backup uğurlu: ${UPLOAD_BACKUP}"
fi

# =============================================
# 4. Həftəlik Backup (Bazar günü)
# =============================================
DAY_OF_WEEK=$(date '+%u')
if [ "${DAY_OF_WEEK}" = "7" ]; then
    log "Həftəlik backup yaradılır..."
    WEEKLY_FILE="${BACKUP_DIR}/weekly/full_${TIMESTAMP}.tar.gz"
    tar -czf "${WEEKLY_FILE}" -C "${BACKUP_DIR}" daily/ 2>/dev/null
    log "Həftəlik backup uğurlu: ${WEEKLY_FILE}"
fi

# =============================================
# 5. Köhnə Backup-ları Sil
# =============================================
log "Köhnə backup-lar təmizlənir (${RETENTION_DAYS} gündən köhnə)..."

DELETED_COUNT=$(find "${BACKUP_DIR}/daily" -name "*.gz" -mtime +${RETENTION_DAYS} -delete -print 2>/dev/null | wc -l)
log "  Gündəlik: ${DELETED_COUNT} fayl silindi"

# Həftəlik backup-lar üçün 90 gün
DELETED_WEEKLY=$(find "${BACKUP_DIR}/weekly" -name "*.gz" -mtime +90 -delete -print 2>/dev/null | wc -l)
log "  Həftəlik: ${DELETED_WEEKLY} fayl silindi"

# =============================================
# 6. Disk Sahəsi Yoxlaması
# =============================================
BACKUP_SIZE=$(du -sh "${BACKUP_DIR}" 2>/dev/null | cut -f1)
DISK_FREE=$(df -h "${BACKUP_DIR}" | awk 'NR==2{print $4}')

log "Backup ümumi ölçüsü: ${BACKUP_SIZE}"
log "Boş disk sahəsi: ${DISK_FREE}"

# Disk sahəsi 10%-dən azdırsa xəbərdarlıq
DISK_USAGE=$(df "${BACKUP_DIR}" | awk 'NR==2{print $5}' | tr -d '%')
if [ "${DISK_USAGE}" -gt 90 ]; then
    log "[XƏBƏRDARLIQ] Disk sahəsi ${DISK_USAGE}% istifadədədir!"
fi

log "Backup prosesi tamamlandı."
