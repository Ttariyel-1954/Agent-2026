#!/bin/bash
# ============================================
# ARTI 2026 - Ehtiyat Nusxe Skripti
# Cron ile ishledir: 0 2 * * * /path/to/backup.sh
# ============================================

set -e

BACKUP_DIR="/backups/arti"
DB_NAME="arti_2026"
DB_USER="arti_admin"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30

echo "[$(date)] ARTI 2026 Ehtiyat nusxe bashlayir..."

# Qovluq yarat
mkdir -p "$BACKUP_DIR"

# PostgreSQL ehtiyat nusxe
echo "PostgreSQL ehtiyat nusxe..."
pg_dump -U "$DB_USER" -d "$DB_NAME" --format=custom --compress=9 \
    -f "$BACKUP_DIR/db_${TIMESTAMP}.dump"

# Redis ehtiyat nusxe
echo "Redis ehtiyat nusxe..."
redis-cli BGSAVE
cp /var/lib/redis/dump.rdb "$BACKUP_DIR/redis_${TIMESTAMP}.rdb" 2>/dev/null || true

# Konfiqurasiya fayllar
echo "Konfiqurasiya ehtiyat nusxe..."
tar -czf "$BACKUP_DIR/config_${TIMESTAMP}.tar.gz" \
    docker-compose.yml .env infrastructure/

# Kohne ehtiyat nusxeleri sil
echo "Kohne ehtiyat nusxeler silinir (${RETENTION_DAYS} gunden kohne)..."
find "$BACKUP_DIR" -type f -mtime +$RETENTION_DAYS -delete

echo "[$(date)] Ehtiyat nusxe tamamlandi."
echo "  Yer: $BACKUP_DIR"
echo "  Fayllar:"
ls -lh "$BACKUP_DIR"/*_${TIMESTAMP}* 2>/dev/null || echo "  (fayllar demo rejimde yaradilmir)"
