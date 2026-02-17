# ARTI-2026 Deployment Təlimatı

## 1. Tələblər

### Sistem Tələbləri
- **OS**: Ubuntu 22.04+ / Debian 12+ / macOS 14+
- **RAM**: Minimum 4GB, Tövsiyə 8GB+
- **Disk**: Minimum 20GB
- **CPU**: 2+ nüvə

### Proqram Tələbləri
- Docker 24+ və Docker Compose v2
- Git
- (İstəyə bağlı) R 4.3+ (yerli işlətmə üçün)

## 2. Sürətli Başlanğıc (Docker)

```bash
# 1. Reponu klonlayın
git clone https://github.com/your-org/arti-2026.git
cd arti-2026

# 2. Mühit dəyişənlərini konfiqurasiya edin
cp .env.example .env
nano .env  # API açarlarını və DB şifrəsini dəyişin

# 3. Docker konteynerləri işə salın
cd deploy
docker compose up -d

# 4. Verilənlər bazasını inisializasiya edin
docker compose exec app Rscript -e "source('R/db_connection.R'); run_migrations(create_db_pool())"

# 5. Nümunə data yükləyin (istəyə bağlı)
docker compose exec db psql -U arti_user -d arti_2026 -f /docker-entrypoint-initdb.d/sample_data.sql

# 6. Brauzerdə açın
open http://localhost
```

## 3. Yerli İşlətmə (Development)

```bash
# 1. R paketlərini yükləyin
Rscript -e "source('R/utils.R'); install_dependencies()"

# 2. PostgreSQL-i konfiqurasiya edin
createdb arti_2026
psql -d arti_2026 -f database/migrations/001_initial.sql
psql -d arti_2026 -f database/migrations/002_assessment.sql
psql -d arti_2026 -f database/migrations/003_analytics.sql
psql -d arti_2026 -f database/functions/stored_procedures.sql
psql -d arti_2026 -f database/seeds/sample_data.sql

# 3. Tətbiqi işə salın
Rscript app.R
# Və ya RStudio-da: shiny::runApp()
```

## 4. Production Deployment

### 4.1 Server Hazırlığı

```bash
# Docker yüklə
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Docker Compose yüklə
apt install docker-compose-plugin

# İstifadəçi yarad
useradd -m -s /bin/bash arti
usermod -aG docker arti
```

### 4.2 SSL Sertifikatı (Let's Encrypt)

```bash
apt install certbot
certbot certonly --standalone -d yourdomain.az
```

Sertifikat yollarını `deploy/nginx.conf`-da yeniləyin.

### 4.3 Deployment

```bash
# deploy skriptini istifadə edin
chmod +x deploy/scripts/deploy.sh
./deploy/scripts/deploy.sh
```

### 4.4 Backup Konfiqurasiyası

```bash
# Gündəlik backup cron işi
chmod +x deploy/scripts/backup.sh
crontab -e
# Əlavə edin:
# 0 2 * * * /opt/arti-2026/deploy/scripts/backup.sh
```

## 5. Mühit Dəyişənləri

| Dəyişən | Təsvir | Default |
|---------|--------|---------|
| DB_HOST | PostgreSQL host | localhost |
| DB_PORT | PostgreSQL port | 5432 |
| DB_NAME | Verilənlər bazası adı | arti_2026 |
| DB_USER | DB istifadəçisi | arti_user |
| DB_PASSWORD | DB şifrəsi | - |
| CLAUDE_API_KEY | Claude API açarı | - |
| GPT_API_KEY | GPT API açarı | - |
| JWT_SECRET | JWT imzalama açarı | - |
| APP_PORT | Tətbiq portu | 3838 |

## 6. Monitoring

### Log Yoxlama
```bash
docker compose logs -f app    # Tətbiq logları
docker compose logs -f db     # DB logları
docker compose logs -f nginx  # Nginx logları
```

### Sağlamlıq Yoxlaması
```bash
curl http://localhost/health
```

### DB Yoxlama
```bash
docker compose exec db pg_isready
```

## 7. Yeniləmə

```bash
cd /opt/arti-2026
git pull origin main
docker compose build app
docker compose up -d
```

## 8. Problemlərin Həlli

| Problem | Həll |
|---------|------|
| DB bağlantı xətası | `.env`-dəki DB məlumatlarını yoxlayın |
| Port istifadədədir | `lsof -i :3838` ilə prosesi tapın |
| Yaddaş problemi | `docker stats` ilə yoxlayın, limiti artırın |
| SSL xətası | Sertifikat yollarını və vaxtını yoxlayın |
