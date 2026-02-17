# ARTI-2026: Təhsil İnstitutunun Hərtərəfli İdarəetmə Sistemi

## Haqqında

**ARTI-2026** — Azərbaycan Respublikasının Təhsil İnstitutları üçün nəzərdə tutulmuş
müasir, süni intellekt dəstəkli, hərtərəfli idarəetmə platformasıdır.

Sistem aşağıdakı əsas funksionallıqları təmin edir:

- **Şagird İdarəetməsi** — qeydiyyat, davamiyyət, akademik profil, fərdi inkişaf planı
- **Müəllim İdarəetməsi** — kadr uçotu, dərs yükü, peşəkar inkişaf, performans qiymətləndirmə
- **Qiymətləndirmə Mühərriki** — IRT, CAT, MST əsaslı adaptiv test sistemi
- **Kurikulum İdarəetməsi** — standartlar, beynəlxalq müqayisə, uyğunluq analizi
- **Analitika və Hesabat** — məktəb dashboardu, prediktiv analitika, avtomatik hesabatlar
- **AI İnteqrasiya** — Claude və GPT ilə sual generasiyası, kurikulum analizi, geri bildirim

## Texnologiya Yığını

| Komponent | Texnologiya |
|-----------|-------------|
| Frontend | R Shiny + bslib + shinydashboardPlus |
| Backend | R + plumber |
| Database | PostgreSQL 15+ |
| AI | Claude API + GPT API |
| Cache | Redis |
| Deployment | Docker + Nginx |
| Test | testthat + shinytest2 |

## Tez Başlanğıc

### Tələblər
- R >= 4.3.0
- PostgreSQL >= 15
- Docker & Docker Compose (deployment üçün)

### Quraşdırma

```bash
# Reponu klonlayın
git clone https://github.com/your-org/Arti_2026.git
cd Arti_2026

# .env faylını konfiqurasiya edin
cp .env.example .env
# .env faylını öz parametrlərinizlə doldurun

# R paketlərini quraşdırın
Rscript -e "source('R/utils.R'); install_dependencies()"

# Verilənlər bazasını yaradın
psql -U postgres -f database/schema/tables.sql
psql -U postgres -f database/seeds/sample_data.sql

# Tətbiqi işə salın
Rscript app.R
```

### Docker ilə işə salma

```bash
docker-compose up -d
```

Tətbiq `http://localhost:3838` ünvanında əlçatan olacaq.

## Modul Strukturu

```
modules/
├── student/        # Şagird idarəetməsi
├── teacher/        # Müəllim idarəetməsi
├── assessment/     # IRT/CAT/MST qiymətləndirmə
├── curriculum/     # Kurikulum idarəetməsi
└── analytics/      # Analitika və hesabatlar
```

## Lisenziya

Bu layihə Azərbaycan Respublikası Təhsil Nazirliyi tərəfindən dəstəklənir.
Bütün hüquqlar qorunur (c) 2026 ARTI Komandası.
