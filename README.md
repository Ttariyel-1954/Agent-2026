# ARTI 2026 - Azərbaycan Respublikası Təhsil İnstitutu
# Vahid Rəqəmsal Təhsil Platforması və AI Agent Sistemi

## Haqqında
Bu layihə Azərbaycan Respublikası Təhsil İnstitutunun (ARTİ) bütün fəaliyyət
sahələrini əhatə edən vahid rəqəmsal platforma və AI Agent sistemidir.

**Qurum:** Azərbaycan Respublikası Təhsil İnstitutu (ARTİ)
**Sayt:** https://arti.edu.az/
**Yaradılma tarixi:** 14 Noyabr 2016, Prezident Fərmanı №1107

---

## Layihə Strukturu

```
Arti_2026/
|
|-- agent/                  # AI Agent sistemi (nüvə)
|   |-- core/               # Agent mühərriki
|   |-- plugins/            # Plugin sistemi
|   |-- skills/             # Agent bacarıqları
|   |-- config/             # Konfiqurasiya
|   |-- memory/             # Agent yaddaşı
|
|-- modules/                # Funksional modullar
|   |-- assessment/         # Qiymətləndirmə (CAT, MST)
|   |-- certification/      # Sertifikasiya və işə qəbul
|   |-- curriculum/         # Kurikulum və kontent
|   |-- research/           # Tədqiqat və analitika
|   |-- professional_dev/   # Peşəkar inkişaf
|   |-- school_network/     # Məktəb şəbəkəsi
|   |-- international/      # Beynəlxalq əməkdaşlıq
|
|-- infrastructure/         # Server infrastrukturu
|   |-- server/             # Server konfiqurasiyası
|   |-- database/           # Verilənlər bazası
|   |-- api/                # API xidmətləri
|   |-- security/           # Təhlükəsizlik
|   |-- backup/             # Ehtiyat nüsxə
|   |-- monitoring/         # Monitorinq
|
|-- apps/                   # Tətbiqlər
|   |-- web_portal/         # Veb portal
|   |-- admin_dashboard/    # Admin paneli
|   |-- mobile/             # Mobil tətbiq
|   |-- exam_platform/      # İmtahan platforması
|
|-- data/                   # Məlumat
|-- docs/                   # Sənədləşdirmə
|-- tests/                  # Testlər
|-- scripts/                # Köməkçi skriptlər
```

---

## ARTİ Mərkəzləri (5 Mərkəz)

| # | Mərkəz | Ünvan |
|---|--------|-------|
| 1 | Tədris Resursları Mərkəzi | Afiyəddin Cəlilov 86 |
| 2 | Metodik Dəstək və Peşəkar İnkişaf Mərkəzi | Mir Cəlal Paşayev 71 |
| 3 | İnsan Resursları Mərkəzi | Mir Cəlal Paşayev 71 |
| 4 | Elmi-Pedaqoji Tədqiqat Mərkəzi | Zərifə Əliyeva 96 |
| 5 | Təhsil Texnologiyaları Mərkəzi | Fətəli Xan Xoyski 109 |

---

## Əsas Fəaliyyət Sahələri

### 1. Qiymətləndirmə və Test Sistemi
- **CAT** (Computerized Adaptive Testing) - Kompüter Adaptiv Test
- **MST** (Multi-Stage Testing) - Çoxsəviyyəli Test
- Lisey və gimnaziyalarda onlayn test keçirmə
- Nəticələrin real vaxtda toplanması və analizi

### 2. Sertifikasiya və İşə Qəbul
- Müəllim işə qəbul imtahanları
- Sertifikasiya imtahanları
- Sual bazalarının yaradılması
- İmtahanların avtomatlaşdırılması

### 3. Kurikulum və Tədris Resursları
- Tədris proqramları
- Rəqəmsal kontent yaradılması
- Dərsliklər və metodik vəsaitlər

### 4. Tədqiqat və Analitika
- Elmi-pedaqoji tədqiqatlar
- Təhsil siyasəti analizi
- Doktorantura proqramları

### 5. Peşəkar İnkişaf
- Müəllim təlimləri
- Onlayn kurslar
- Mentorluq proqramları

### 6. Beynəlxalq Əməkdaşlıq
- Olimpiadalar
- STEAM layihələri
- Partnyor proqramları

---

## Server İnfrastrukturu (Perspektiv)
- Öz serverinin yaradılması
- PostgreSQL + Redis + MongoDB
- Docker/Kubernetes ilə idarə
- SSL/TLS təhlükəsizlik
- Avtomatik ehtiyat nüsxə
- Real vaxt monitorinq

---

## Texnologiyalar

| Sahə | Texnologiya |
|------|-------------|
| Backend | Python (FastAPI, Django) |
| Frontend | React.js, Next.js |
| Mobile | React Native |
| AI/ML | PyTorch, scikit-learn, LangChain |
| Database | PostgreSQL, Redis, MongoDB |
| DevOps | Docker, Kubernetes, Nginx |
| Testing | pytest, Jest, Cypress |
| Monitoring | Prometheus, Grafana |
| CI/CD | GitHub Actions |

---

## Quraşdırma

```bash
# 1. Reponu klonlayın
git clone https://github.com/arti-edu-az/arti-2026.git
cd Arti_2026

# 2. Virtual mühit yaradın
python -m venv venv
source venv/bin/activate

# 3. Asılılıqları quraşdırın
pip install -r requirements.txt

# 4. Mühit dəyişənlərini konfiqurasiya edin
cp .env.example .env

# 5. Verilənlər bazasını işə salın
docker-compose up -d db redis

# 6. Miqrasiyaları işə salın
python manage.py migrate

# 7. Sistemi işə salın
python manage.py runserver
```

---

## Lisenziya
ARTİ 2026 - Bütün hüquqlar qorunur.
Azərbaycan Respublikası Təhsil İnstitutu © 2026