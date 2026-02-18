# ARTI-2026 Layihəsinin Tam Strukturu

## Kök Səviyyə Faylları

| Fayl | Təyinatı |
|------|----------|
| `app.R` | Əsas Shiny tətbiqi — UI + Server, bütün modulları yükləyir |
| `config.yml` | Tətbiq konfiqurasiyası (AI parametrləri, sistem ayarları) |
| `docker-compose.yml` | Docker xidmətlərinin orkestrasiyası (PostgreSQL, Redis, Nginx) |
| `Makefile` | Build/deploy əmrləri (`make run`, `make migrate`, və s.) |
| `.env` | Gizli dəyişənlər (DB parol, API açarları) |
| `.env.example` | `.env` şablonu |
| `requirements.txt` | Python asılılıqları (120+ paket) |
| `CLAUDE.md` | Layihə qaydaları (Claude Code üçün kontekst) |
| `README.md` | Layihə sənədləşdirməsi |

---

## `R/` — Paylaşılan Köməkçi Funksiyalar

| Fayl | Təyinatı |
|------|----------|
| `constants.R` | Bütün sabitlər — şkalalar, fənn adları, rollar, institut tipləri |
| `utils.R` | Ümumi yardımçı funksiyalar (format, hesablama) |
| `db_connection.R` | PostgreSQL bağlantı pool-u yaradır |
| `auth.R` | JWT token yoxlama, autentifikasiya məntiqi |

---

## `modules/` — 15 Funksional Modul

Hər modul `_helpers.R`, `_ui.R`, `_server.R` strukturuna uyğundur:

| Modul | Təyinatı |
|-------|----------|
| `student/` | Şagird idarəetməsi — qeydiyyat, davamiyyət, akademik profil, fərdi plan |
| `teacher/` | Müəllim idarəetməsi — siyahı, dərs yükü, performans |
| `assessment/` | Qiymətləndirmə — IRT/CAT/MST mühərrikləri, sual bankı |
| `curriculum/` | Kurikulum — standartlar, beynəlxalq müqayisə, uyğunluq |
| `analytics/` | Analitika — məktəb dashboard, hesabatlar, prediktiv |
| `certification/` | Sertifikasiya — işə qəbul imtahanları, avtomatlaşdırma |
| `resources/` | Tədris resursları — proqramlar, rəqəmsal kontent, dərsliklər |
| `research/` | Tədqiqat — layihələr, siyasət analizi, doktorantura |
| `development/` | Peşəkar inkişaf — təlimlər, kurslar, mentorluq |
| `international/` | Beynəlxalq — olimpiadalar, STEAM, partnyor proqramları |
| `institute/` | İnstitut strukturu — org chart, resurslar, kontingent, monitorinq |
| `school_network/` | Məktəb şəbəkəsi — məlumat toplama |
| `professional_dev/` | Peşəkar inkişaf (Python tərəfi) |

### Assessment modulunun Python alt-modulları

- `cat/engine/` — CAT mühərriki (Computerized Adaptive Testing)
- `mst/engine/` — MST mühərriki (Multi-Stage Testing)
- `item_bank/creation/` — AI ilə sual generasiyası
- `item_bank/irt_analysis/` — IRT kalibrasiyası (Item Response Theory)
- `online_collection/api/` — Onlayn data toplama API
- `analytics/school/` — Məktəb səviyyəli analitika

---

## `database/` — Verilənlər Bazası

| Qovluq/Fayl | Təyinatı |
|-------------|----------|
| `schema/tables.sql` | Əsas DB sxemi |
| `migrations/001_initial.sql` | İlkin cədvəllər (users, students, teachers) |
| `migrations/002_assessment.sql` | Qiymətləndirmə cədvəlləri |
| `migrations/003_analytics.sql` | Analitika cədvəlləri |
| `migrations/004_new_modules.sql` | Sertifikasiya, tədqiqat, resurs cədvəlləri |
| `migrations/005_institute_structure.sql` | İnstitut strukturu — 7 cədvəl |
| `seeds/sample_data.sql` | Nümunə data |
| `seeds/institute_structure_seed.sql` | ARTİ strukturu seed datası |
| `functions/stored_procedures.sql` | PostgreSQL saxlanılan prosedurlar |

---

## `ai_integration/` — AI İnteqrasiya

| Fayl | Təyinatı |
|------|----------|
| `claude_api.R` | Anthropic Claude API çağırışları |
| `gpt_api.R` | OpenAI GPT API çağırışları |
| `response_parser.R` | AI cavablarının emalı |
| `prompt_templates/` | Sual generasiyası, geri bildiriş, analiz şablonları |

---

## `agent/` — AI Agent Sistemi (Python)

| Fayl | Təyinatı |
|------|----------|
| `core/main.py` | Agent giriş nöqtəsi |
| `core/engine.py` | Agent mühərriki |
| `core/router.py` | Sorğu yönləndirməsi |
| `core/state.py` | Vəziyyət idarəetməsi |
| `config/settings.py` | Agent konfiqurasiyası |
| `plugins/base_plugin.py` | Plugin baza sinfi |
| `skills/base_skill.py` | Bacarıq baza sinfi |

---

## `infrastructure/` — İnfrastruktur

| Qovluq | Təyinatı |
|--------|----------|
| `api/gateway/main.py` | FastAPI gateway (əsas API endpoint) |
| `security/authentication/auth_service.py` | JWT autentifikasiya xidməti |
| `backup/strategies/backup_config.py` | Yedəkləmə konfiqurasiyası |
| `monitoring/prometheus/prometheus.yml` | Prometheus monitorinq |
| `database/schemas/` | DB infrastruktur sxemləri |

---

## `deploy/` — Deployment

| Fayl | Təyinatı |
|------|----------|
| `Dockerfile` | Docker image |
| `docker-compose.yml` | Xidmət orkestrasiyası |
| `nginx.conf` | Nginx reverse proxy |
| `scripts/deploy.sh` | Deploy skripti |
| `scripts/backup.sh` | Yedəkləmə skripti |

---

## `apps/` — 8 Admin Dashboard

| Dashboard | Təyinatı |
|-----------|----------|
| `main_dashboard/` | Əsas admin paneli |
| `assessment_dashboard/` | Qiymətləndirmə analitikası |
| `certification_dashboard/` | Sertifikasiya paneli |
| `item_bank_dashboard/` | Sual bankı idarəetməsi |
| `research_dashboard/` | Tədqiqat analitikası |
| `school_network_dashboard/` | Məktəb şəbəkəsi |
| `server_monitor_dashboard/` | Server monitorinqi |
| `training_dashboard/` | Təlim proqramları |

---

## Digər Qovluqlar

| Qovluq | Təyinatı |
|--------|----------|
| `www/css/custom.css` | Xüsusi CSS stilləri (org chart, KPI bar daxil) |
| `www/js/custom.js` | Xüsusi JavaScript |
| `www/img/logo.png` | Tətbiq logosu |
| `tests/` | Testlər — `test_cat.R`, `test_irt.R`, `test_database.R` |
| `docs/` | Sənədlər — arxitektura, API referans, istifadəçi təlimatı |
| `data/sample/` | Nümunə JSON-lar (şagirdlər, müəllimlər, məktəblər, suallar) |
| `scripts/` | Setup və maintenance skriptləri |
| `logs/` | Tətbiq logları (`arti_2026.log`) |

---

## Ümumi Statistika

| Metrika | Dəyər |
|---------|-------|
| Qovluq sayı | ~90 |
| Fayl sayı | ~107 |
| R faylları | ~40 |
| Python faylları | ~50 |
| SQL miqrasiyaları | 5 |
| Modullar | 15 |
| Texnologiyalar | R Shiny, Python, PostgreSQL, Redis, Docker, Nginx, Claude/GPT API |
