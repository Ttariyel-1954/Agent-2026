# ARTI-2026 - Təhsil İnstitutunun İdarəetmə Sistemi

## Layihə Haqqında
ARTI-2026 Azərbaycan təhsil institutları üçün hərtərəfli idarəetmə agentidir.
R/Shiny əsaslı, PostgreSQL verilənlər bazası ilə işləyir.

## Texnologiya Yığını
- **Frontend**: R Shiny (bslib, shinydashboardPlus)
- **Backend**: R (plumber API, shiny server)
- **Database**: PostgreSQL 15+
- **AI**: Claude API (Anthropic), GPT API (OpenAI)
- **Deployment**: Docker + Nginx
- **Testing**: testthat, shinytest2

## Layihə Strukturu
- `app.R` — Əsas giriş nöqtəsi
- `modules/` — Funksional Shiny modulları (student, teacher, assessment, curriculum, analytics)
- `database/` — SQL sxemlər, miqrasiyalar, seed data
- `R/` — Paylaşılan köməkçi funksiyalar
- `ai_integration/` — Claude/GPT API inteqrasiyası
- `www/` — Statik resurslar (CSS, JS, şəkillər)
- `deploy/` — Docker və deployment konfiqurasiyaları
- `tests/` — Testlər

## Kodlama Qaydaları
- Azərbaycan dilində şərhlər yazın
- Dəyişən adları snake_case olsun
- Hər modul `_ui.R`, `_server.R`, `_helpers.R` strukturuna uyğun olmalıdır
- SQL injection-dan qorunmaq üçün parametrli sorğulardan istifadə edin
- Bütün API açarları `.env` faylında saxlanılmalıdır
- `config.yml` vasitəsilə mühit konfiqurasiyası aparılır

## Vacib Qeydlər
- `.env` faylını heç vaxt git-ə əlavə etməyin
- Verilənlər bazası miqrasiyaları ardıcıl nömrələnməlidir
- IRT/CAT/MST hesablamaları `modules/assessment/` altında saxlanılır
- AI prompt şablonları `ai_integration/prompt_templates/` qovluğundadır
