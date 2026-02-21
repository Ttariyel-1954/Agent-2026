# ARTI-2026: Tam Istifadeci Telimatı

**Versiya:** 1.0.0
**Tarix:** 19 Fevral 2026
**Muellif:** ARTI-2026 Inkisaf Qrupu

---

## Mundericat

1. [Layihe Haqqında](#1-layihe-haqqında)
2. [Qurasdirma ve Ise Salma](#2-qurasdirma-ve-ise-salma)
3. [Ana Sehife (Dashboard)](#3-ana-sehife-dashboard)
4. [Sagird Idareetmesi](#4-sagird-idareetmesi)
5. [Muellim Idareetmesi](#5-muellim-idareetmesi)
6. [Qiymetlendirme Sistemi](#6-qiymetlendirme-sistemi)
7. [Kurikulum Idareetmesi](#7-kurikulum-idareetmesi)
8. [Analitika ve Hesabatlar](#8-analitika-ve-hesabatlar)
9. [Sertifikasiya ve Imtahanlar](#9-sertifikasiya-ve-imtahanlar)
10. [Tedris Resurslari](#10-tedris-resurslari)
11. [Tedqiqat Idareetmesi](#11-tedqiqat-idareetmesi)
12. [Pesekar Inkisaf](#12-pesekar-inkisaf)
13. [Beynelxalq Emekdasliq](#13-beynelxalq-emekdasliq)
14. [Institut Strukturu](#14-institut-strukturu)
15. [AI Komekci](#15-ai-komekci)
16. [Sesli Idareetme (Voice Agent)](#16-sesli-idareetme-voice-agent)
17. [Idareetme Paneli (Admin)](#17-idareetme-paneli-admin)
18. [Verilenlerin Bazasi](#18-verilenlerin-bazasi)
19. [Konfiqurasiya](#19-konfiqurasiya)
20. [Deploy (ShinyApps.io ve Docker)](#20-deploy)
21. [Tehlukesizlik](#21-tehlukesizlik)
22. [Problem Hell (Troubleshooting)](#22-problem-hell)
23. [Texniki Arxitektura](#23-texniki-arxitektura)

---

## 1. Layihe Haqqında

### 1.1 Ne Ucundur?

ARTI-2026 Azerbaycan Respublikasi tehsil institutlari ucun hazirlanmis herterefli
idareetme sistemidir. Sistem asagidaki meselelleri hell edir:

- **Sagird ve muellim idareetmesi** — qeydiyyat, davamiyyet, performans izleme
- **Qiymetlendirme** — IRT, CAT, MST esasli psixometrik test sistemleri
- **Kurikulum** — standartlar, beynelxalq muqayise, uygunluq analizi
- **Analitika** — prediktiv analitika, risk proqnozu, trend analizi
- **Sertifikasiya** — muellim ise qebul ve sertifikasiya imtahanlari
- **AI inteqrasiya** — Claude ve GPT ile sual generasiyasi, kurikulum analizi
- **Sesli idareetme** — Azerbaycanca ses emrleri ile sistem idaresi

### 1.2 Texnologiya Yigini

| Komponent | Texnologiya |
|-----------|-------------|
| Frontend | R Shiny + shinydashboardPlus |
| Backend | R Server + PostgreSQL |
| AI | Claude API (Anthropic) + GPT API (OpenAI) |
| Ses | Python + Whisper API + PyAudio |
| Deploy | Docker + Nginx + ShinyApps.io |
| Monitorinq | Prometheus + Grafana |

### 1.3 Fayl Strukturu

```
Arti_2026/
├── app.R                    # Esas tetbiq (port 3838)
├── app_debug.R              # Debug versiya (port 4040)
├── config.yml               # Konfiqurasiya parametrleri
├── .env                     # Muhit deyisenleri (API acarlari, DB)
├── R/                       # Paylasilan funksiyalar
│   ├── constants.R          # Sabitler (50+ deyisen)
│   ├── utils.R              # Yardimci funksiyalar
│   ├── db_connection.R      # DB baglanti ve sorgu
│   └── auth.R               # JWT autentifikasiya
├── modules/                 # 11 funksional modul
│   ├── student/             # Sagird (5 alt-sehife)
│   ├── teacher/             # Muellim (4 alt-sehife)
│   ├── assessment/          # Qiymetlendirme (5 alt-sehife)
│   ├── curriculum/          # Kurikulum (3 alt-sehife)
│   ├── analytics/           # Analitika (3 alt-sehife)
│   ├── certification/       # Sertifikasiya (4 alt-sehife)
│   ├── resources/           # Tedris resurslari (3 alt-sehife)
│   ├── research/            # Tedqiqat (3 alt-sehife)
│   ├── development/         # Pesekar inkisaf (3 alt-sehife)
│   ├── international/       # Beynelxalq (3 alt-sehife)
│   └── institute/           # Institut strukturu (4 alt-sehife)
├── ai_integration/          # AI API inteqrasiyasi
├── voice_agent/             # Sesli idareetme (Python)
├── database/                # SQL sxemler ve seed data
├── www/                     # CSS, JS, sekiller
├── deploy/                  # Docker, Nginx
└── tests/                   # Test faylları
```

---

## 2. Qurasdirma ve Ise Salma

### 2.1 Ilkin Telebler

- **R** versiya 4.3+
- **PostgreSQL** 15+ (ve ya Supabase)
- **Python** 3.9+ (sesli agent ucun)
- **Brauzer:** Chrome, Firefox, Safari, Edge

### 2.2 R Paketlerinin Qurasdirmasi

R konsolunda asagidaki emri icra edin:

```r
install.packages(c(
  "shiny", "shinydashboard", "shinydashboardPlus",
  "DBI", "RPostgres", "pool", "dotenv", "shinyjs",
  "DT", "plotly", "ggplot2", "dplyr", "tidyr",
  "lubridate", "jsonlite", "httr2", "openssl",
  "jose", "logger", "waiter", "config"
))
```

### 2.3 .env Faylinin Hazirlanmasi

Layihenin kok qovlugundaki `.env` faylini duzeldin:

```
# Verilenlerin Bazasi (Supabase ve ya lokal PostgreSQL)
DB_HOST=aws-1-ap-south-1.pooler.supabase.com
DB_PORT=5432
DB_NAME=postgres
DB_USER=postgres.XXXXXXXXXXXX
DB_PASSWORD=sizin_sifreniz

# Tetbiq
APP_HOST=0.0.0.0
APP_PORT=3838

# API Acarlari
CLAUDE_API_KEY=sk-ant-api03-...
OPENAI_API_KEY=sk-proj-...

# JWT
JWT_SECRET=guclu-gizli-acar
JWT_EXPIRY_HOURS=24
```

### 2.4 Verilenlerin Bazasini Hazirlama

PostgreSQL-de sxemi yaratmaq ucun:

```bash
psql -h DB_HOST -U DB_USER -d DB_NAME -f database/schema/tables.sql
```

Test datasi yuklemek:
```bash
psql -h DB_HOST -U DB_USER -d DB_NAME -f database/seeds/sample_data.sql
psql -h DB_HOST -U DB_USER -d DB_NAME -f database/seeds/teacher_synthetic_data.sql
```

### 2.5 Tetbiqi Ise Salma

**Usul 1: RStudio-dan**
- `app.R` faylini acin
- "Run App" duymesini basin

**Usul 2: Terminaldan**
```bash
cd ~/Desktop/Arti_2026
Rscript app.R
```

**Usul 3: Debug rejim**
```bash
Rscript app_debug.R    # Port 4040, yalniz student+teacher
```

Tetbiq isleyenden sonra brauzerde: **http://localhost:3838**

### 2.6 Sesli Agentin Qurasdirmasi

```bash
cd ~/Desktop/Arti_2026/voice_agent
brew install portaudio          # macOS ucun
pip install -r requirements.txt
python main.py --test           # Tehlukesizlik testi
python main.py --text           # Metn rejimi (test ucun)
python main.py                  # Sesli rejim
```

---

## 3. Ana Sehife (Dashboard)

Tetbiq acildiqda Ana Sehife gorunur. Burada muessise haqqinda umumi melumatlar var.

### 3.1 Statistik Kartlar (Ust Sira)

| Kart | Reng | Melumat |
|------|------|---------|
| Umumi Sagird | Mavi (aqua) | Butun mekteblerindeki sagird sayi |
| Umumi Muellim | Yasil | Butun muellimlerin sayi |
| Orta Performans | Sari | Butun qiymetlerin orta faizi |
| Aktiv Testler | Qirmizi | Hazirda davam eden test sessiyalari |

### 3.2 Institut Metrikleri (Ikinci Sira)

| Kart | Reng | Melumat |
|------|------|---------|
| Teskilati Vahid | Benovseyi | Merkezler, sobeler, laboratoriyalar |
| Institut Personali | Firuzei | Umumi isci sayi |
| Aktiv Layihe | Narinci | Davam eden tedqiqat layiheleri |
| Fealiyyet Sahesi | Tund qirmizi | Fealiyyet istiqametleri |

### 3.3 Qrafiklər

- **Umumi Performans Trendi** — Son 12 ayin orta ballari (xett qrafik)
- **Son Fealiyyetler** — Sistemdeki son 10 emeliyyat (siyahi)
- **Fenn uzre Orta Ballar** — Her fennin orta bali (sutun qrafik)
- **Davamiyyet Statistikasi** — istirak/qayib/gecikme nisbeti (pasta qrafik)

---

## 4. Sagird Idareetmesi

Sol menyuda **"Sagirdler"** bolmesine klikleyin — 5 alt-sehife acilir.

### 4.1 Sagird Siyahisi

Butun sagirdlerin cedvelini gosterir. **Filtrler:**
- Mekteb, Sinif, Bolme, Status (aktiv/qeyri-aktiv/mezun/kocurulmus)
- Axtaris sahesi — ad/soyada gore

**Cedvelde gorunenler:**
- Ad, Soyad, FIN, Sinif, Mekteb, Status, Qeydiyyat tarixi

**Eksport:** Cedveli Excel faylina yukleme imkani (`btn_export` duymesi).

### 4.2 Sagird Qeydiyyati

Yeni sagird elave etmek ucun form. **Teleb olunan saheler:**
- Ad, Soyad, Ata adi
- Dogum tarixi, Cins
- FIN (7 simvol, avtomatik validasiya)
- Mekteb, Sinif, Bolme
- Valideyn melumatlari (ad, telefon, is yeri)

**Qeyd:** FIN validasiyasi JavaScript terefinden real vaxtda aparilir — yalniz
herfler ve reqemler, 7 simvol.

### 4.3 Davamiyyet

Gundelik davamiyyet qeydi sistemi. **Statuslar:**
- **istirak** — derste istirak edib
- **qayib** — icazesiz gelmeyib
- **gecikme** — derse gec gelib
- **icazeli** — icaze ile gelmeyib
- **xestelik** — tibbi arayo var

**Istifade:**
1. Mekteb, sinif, tarix secin
2. Sagirdlerin siyahisi gorunur
3. Her sagird ucun status secin
4. "Qeyd et" duymesine basin

**Statistika:** Secilmis dovrde davamiyyet faizi avtomatik hesablanir.

### 4.4 Akademik Profil

Ferdi sagirdin butun akademik tarixcesi:
- **Qiymet tarixcesi** — fen ve semester uzre butun ballar
- **Trend qrafiki** — balin deyisim dinamikasi
- **Fen muqayisesi** — guclu ve zeif fenlerin muqayisesi
- **Risk seviyyesi** — proqnozlasdirilmis risk gostericisi (asagi/orta/yuksek)

### 4.5 Ferdi Inkisaf Plani (FIP)

Her sagird ucun ferdilesdirilmis oyrenmə plani:
- **Heddef bal** ve **cari bal** arasindaki mesafe
- **Baslangi/bitis tarixi** ve **proqress faizi**
- **Qeydler** — muellim ve meslehétci serhlerini elave etmek
- **Status:** aktiv / tamamlanmis / durdurulmus / legv edilmis

---

## 5. Muellim Idareetmesi

Sol menyuda **"Muellimlər"** bolmesine klikleyin — 4 alt-sehife acilir.

### 5.1 Muellim Siyahisi

Butun muellimlerin cedveli. **Filtrler:**
- Kateqoriya (ali, birinci, ikinci, kateqoriyasiz)
- Fexri ad (Emekdar muellim, Xalq muellimi)
- IKT seviyyesi (baslangic, orta, irelilesmis, ekspert)
- Axtaris — ada gore

**Cedvelde gorunenler:**
- Ad, Soyad, Ixtisas, Kateqoriya, Tecrube ili, Mekteb,
  IKT seviyyesi, Sertifikasiya bali, Status

### 5.2 Ders Yuku

Muellimin heftelik ders cedvelini gosterir ve idarə edir:

- **Umumi saatlar** — heftelik ders sayi
- **Yuk statusu:**
  - Asagi (< 18 saat) — qirmizi
  - Normal (18-36 saat) — yasil
  - Yuksek (> 36 saat) — sari
- **Cedvel gridi** — 5 gun x 7 ders, her xanada fenn secimi
- **Fenn bolgusu** — pasta qrafik (hansi fennden nece saat)
- **Gunluk bolgu** — sutun qrafik (her gun nece saat)

### 5.3 Pesekar Inkisaf

Muellimin telim ve sertifikat tarixcesi:

- **Telim sayi, sertifikat sayi, umumi saatlar**
- **Telim cedveli** — basliq, nov, teskilatci, baslama/bitme, saat, status
- **Sertifikat cedveli** — ad, tarix, status

**Telim novleri:** kurs, seminar, konfrans, sertifikat, magistratura

### 5.4 Performans

Muellimin herterefli performans analizi:

#### KPI-lar (Esas Gostericiler):
- **Sagird neticeleri** — ortalama sagird bali (%)
- **Davamiyyet** — sagirdlerin derse gelme faizi
- **Pesekar inkisaf** — telim ve oz-inkisaf gostericileri
- **Umumi bal** — butun KPI-larin ortasi

#### TALIS Radar Qrafiki:
Muellimin OECD/TALIS gostericilerini OECD ortasi ile muqayise edir:
- Oz-effektivlik (self-efficacy)
- Is memnuniyyeti (job satisfaction)
- Sinif idareetmesi (classroom management)
- PKI tesiri (CPD impact)
- Emekdasliq (collaboration)
- IKT istifadesi (ICT usage)

**Qirmizi kesik xett** = OECD ortasi, **Mavi sahe** = muellimin gostericileri.

#### Heftelik Yuk Bolgusu (Pasta qrafik):
- Tedris saatlari (mavi)
- Inzibati saatlar (sari)
- Hazirliq saatlari (yasil)

#### Elve TALIS Melumatlari:
- PKI saatlari, sagird orta bali, kecid faizi
- Reqemsal kontent sayi, inkluziv telim statusu

#### Mukafatlar ve Nesrler:
- **Mukafatlar cedveli** — ad, veren qurum, nov, tarix
- **Nesrler cedveli** — basliq, nov, jurnal, DOI, resenziya

#### Qiymetlendirme Formu:
5 meyar uzre 1-5 bal (0.5 addimla):
1. Tedris keyfiyyeti
2. Sagird celbi
3. Unsiyyet
4. Pesekar inkisaf
5. Innovasiya

Umumi bal avtomatik hesablanir ve DB-ye yazilir.

---

## 6. Qiymetlendirme Sistemi

Sol menyuda **"Qiymetlendirme"** — 5 alt-sehife.

### 6.1 Sual Banki

Test suallari bazasi. Her sualin parametrleri:
- **Fenn, sinif** — hansi fenn ve sinif ucundur
- **Sual metni** — sualin ozU
- **Sual novu:** coxsecimli (MCQ), dogru/yanlis, qisa cavab, esse, uygunlasdirma
- **Cavab variantlari** (A-E) ve duzgun cavab
- **Cetinlik:** cox_asan, asan, orta, cetin, cox_cetin
- **Bloom seviyyesi:** xatirlama, anlama, tetbiq, analiz, qiymetlendirme, yaratma
- **DOK seviyyesi:** 1-4 (bilme, tetbiq, strateji dusunce, genislendirmis dusunce)
- **IRT parametrleri:** a (ferqlendirme), b (cetinlik), c (texmin)

**Emeliyyatlar:**
- Yeni sual elave etme
- Movcud suallari redakte
- IRT kalibrasyasi (parametrlerin hesablanmasi)
- Import/Export (toplu emeliyyat)

### 6.2 IRT Analiz

Item Response Theory — sualin keyfiyyetini statistik olaraq olcur:

- **1PL (Rasch) model** — yalniz cetinlik (b) parametri
- **2PL model** — cetinlik (b) + ferqlendirme (a)
- **3PL model** — cetinlik (b) + ferqlendirme (a) + texmin (c)

**Ehtimal formulasi (3PL):**
```
P(θ) = c + (1-c) / (1 + exp(-a(θ-b)))
```

Burada θ = sagirdin qabiliyyet seviyyesi.

**Fisher Information Function:**
Sualin hansi qabiliyyet seviyyesinde en cox melumat verdiyini gosterir.
Yuksek information = o sual hemen o seviyyedeki sagirdleri yaxsi ayird edir.

### 6.3 CAT Test (Kompyuter Adaptiv Test)

CAT her sagirdin seviyyesine uygunlasan test sistemidir:

**Neceisleyir:**
1. Baslangic θ = 0 (orta seviyye)
2. En informativ sual secilir (MFI — Maximum Fisher Information)
3. Sagird cavab verir
4. θ yeniden hesablanir (MLE — Maximum Likelihood Estimation)
5. Standart xeta (SE) hesablanir
6. SE < 0.3 olduqda DAYANIR (kifayet qeder deqiq olcum)

**Parametrler:**
- Minimum sual sayi: 10
- Maksimum sual sayi: 50
- SE hedd: 0.3
- Baslangic θ: 0
- Exposure control: maks 25% (bir sual sagirdlerin max 25%-ne gosterilir)

**Uzunluqleri:**
- Ferdi — her sagird ferqli sayla sual alir
- Deqiq — olcum xetasi minimum saxlanir
- Tehlukesiz — suallar heddinden artiq istifade olunmur

### 6.4 MST Test (Coxmerhele Test)

MST qruplar halinda suallar teklif edir:

**Struktur (3 merhele):**
```
         [Merhele 1]        - 1 modul (butun sagirdler eyni)
         /    |    \
   [Asan] [Orta] [Cetin]   - Merhele 2 (3 modul)
    / | \  / | \  / | \
   [3 modul her birinde]    - Merhele 3 (3 modul)
```

**Yonlendirme (routing):** MLE metoduna esaslanir. Merhele 1-den sonra sagirdin
göstericisine gore Merhele 2-de asan/orta/cetin modullardan biri secilir.

**Panel olcusu:** Her merhelede 5 modul hazirlanir, sagirdin seviyyesine gore secilir.

### 6.5 Neticeler

Test neticelerinin hesabati:
- Sagird uzre bal, θ qiymeti, SE
- Sinif/mekteb uzre umumi statistika
- Sual analizi — hansi suallar cetin oldu, hansilari asan
- Fenn uzre muqayiseli analiz

---

## 7. Kurikulum Idareetmesi

Sol menyuda **"Kurikulum"** — 3 alt-sehife.

### 7.1 Standartlar

Azerbaycan kurikulum standartlarinin idaresi:
- Her fenn + sinif ucun oyrenmə neticeleri
- Standart kodu (mes: RIY.8.1.2)
- Bloom taksonomiyasi seviyyesi
- DOK (Depth of Knowledge) seviyyesi
- Esas (core) ve ya elave standart isaresi
- Iyerarxiya — ust standarta bagli alt standartlar

### 7.2 Beynelxalq Muqayise

Azerbaycan kurikulumunu diger olkelerin kurikulumlari ile muqayise edir:

**Muqayise olunan olkeler:**
| Olke | Sebebi |
|------|--------|
| Finlandiya | Dunyada en yaxsi tehsil sistemi |
| Sinqapur | PISA-da 1-ci yer |
| Cenubi Koreya | Yuksek akademik standartlar |
| Estoniya | Avropanin en ugurlu tehsil reformu |
| Yaponiya | STEM tehsilinde lider |
| Turkiye | Oxsar kurikulum strukturu |

### 7.3 Uygunluq Analizi (Alignment)

Test suallarinin kurikulum standartlarina ne derecede uygun oldugunu olcur:
- Her sual hansi standarta baglidir
- DOK uygunlugu — sualin cetinliyi standartla uyusur mu?
- Alignment gucu — 0-dan 1-e qeder bal
- Etrafli hesabat — hansı standartlar yeterince test olunmur?

---

## 8. Analitika ve Hesabatlar

Sol menyuda **"Analitika"** — 3 alt-sehife.

### 8.1 Mekteb Dashboard

Her mekteb ucun canli gostericiler:
- Sagird/muellim sayi, orta bal, davamiyyet faizi
- Performans trendi (ayliq)
- Fenn uzre muqayise
- Sinif uzre istilik xeritesi (heatmap)

### 8.2 Hesabatlar

Muxtelif formatlarda hesabat generasiyasi:

**Hesabat novleri:**
- Sagird akademik hesabati
- Muellim performans hesabati
- Mekteb umumi hesabati
- Davamiyyet hesabati
- Qiymetlendirme hesabati

**Eksport formatlari:** PDF, Excel (XLSX), CSV, HTML

### 8.3 Prediktiv Analitika

Machine Learning esasli proqnozlasdirma:

- **Risk proqnozu** — hansi sagirdlerin ders buraxma/kesilme riski var
- **Performans proqnozu** — gelecek semestrdeki gozlenilen bal
- **Model:** Random Forest
- **Giris deyisenleri:** keçmis qiymetler, davamiyyet, FIP proqressi, aile melumatlari
- **Risk hedd deyeri:** 0.3 (30%-den yuxari risk = xeberdarliq)

---

## 9. Sertifikasiya ve Imtahanlar

Sol menyuda **"Sertifikasiya"** — 4 alt-sehife.

### 9.1 Ise Qebul Imtahanlari
Muellim vakansiyalarina muraciet edenler ucun imtahan sistemi.

### 9.2 Sertifikasiya Imtahanlari
Calisanmuellimler ucun pesekar sertifikasiya imtahanlari.

### 9.3 Sual Bazasi
Imtahan-spesifik sual hovuzu — ümumi sual bankindan fərqli.

### 9.4 Avtomatlasdiirma
Avtomatik qiymetlendirme ve neticerinin islenmesi.

---

## 10. Tedris Resurslari

Sol menyuda **"Tedris Resurslari"** — 3 alt-sehife.

### 10.1 Tedris Proqramlari
Fenn ve sinif uzre tedris proqramlarinin idaresi.

### 10.2 Reqemsal Kontent
E-oyrenmə materiallari — video, prezentasiya, interaktiv kontent.

### 10.3 Derslikler
Fiziki ve reqemsal dersliklerin idaresi ve paylasdirilmasi.

---

## 11. Tedqiqat Idareetmesi

Sol menyuda **"Tedqiqat"** — 3 alt-sehife.

### 11.1 Tedqiqatlar
Fundamental ve tetbiqi tedqiqat layihelerinin izlenmesi:
- Layihe adi, novU, metodologiya
- Baslama/bitmə tarixi, status
- Tedqiqatci, department

### 11.2 Siyaset Analizi
Tehsil siyaseti uzre tedqiqatlar ve tovsiyeler.

### 11.3 Doktorantura
Doktorantura proqramlarinin idaresi — dissertasiya movzulari, rehberler, neticeleri.

---

## 12. Pesekar Inkisaf

Sol menyuda **"Pesekar Inkisaf"** — 3 alt-sehife.

### 12.1 Muellim Telimleri
Xidmetici telim proqramlari — basliq, teskilatci, muddet, sertifikat.

### 12.2 Onlayn Kurslar
E-oyrenmə kurs platformasi — MOOC formatinda kurslar.

### 12.3 Mentorluq
Mentor-mentee eslesdirme ve izleme sistemi:
- Tecrubelimuellimlər (15+ il) → mentor
- Yeni muellimlər (1-3 il) → mentee
- Goruslerin planlasdirmasi ve qeydiyyati

---

## 13. Beynelxalq Emekdasliq

Sol menyuda **"Beynelxalq"** — 3 alt-sehife.

### 13.1 Olimpiadalar
Beynelxalq fenn olimpiadalarinin idaresi:
- Riyaziyyat, Fizika, Kimya, Biologiya, Informatika,
  Cografiya, Tarix, Edebiiyat, Diller

### 13.2 STEAM Layiheleiri
Beynelxalq STEAM (Science, Technology, Engineering, Arts, Mathematics) layihelelri.

### 13.3 Partnyor Proqramlari
Beynelxalq partnyor teskilatlari ile emekdasliq proqramlari.

---

## 14. Institut Strukturu

Sol menyuda **"Institut Strukturu"** — 4 alt-sehife.

### 14.1 Struktur (Org Chart)
Teskilati iyerarxiyanin vizual gosterilmesi:

```
ARTI-2026 Direktor
├── Elm uzre direktor muavini
│   ├── Tedqiqat merkezi
│   ├── Psixometrika laboratoriyasi
│   └── Statistika sobesi
├── Tedris uzre direktor muavini
│   ├── Kurikulum merkezi
│   └── Qiymetlendirme sobesi
├── Innovasiya uzre direktor muavini
│   ├── IKT merkezi
│   └── STEAM laboratoriyasi
└── ...
```

Vahid novleri: rehberlik, merkez, sobe, laboratoriya, bolme

### 14.2 Resurslar
Butun resurs novlerinin idaresi:
- Budce, Avadanliq, Sahe, Proqram teminati, Neqliyyat

### 14.3 Kontingent
Personal idareetmesi:
- Isci novleri: isci, tedqiqatci, doktorant, muqavileli, stajer
- Iscilerin struktural vahidlere paylanmasi

### 14.4 Monitorinq
KPI izleme ve layihe idareetmesi:
- Her vahidin KPI-lari (hedeef vs faktiki)
- Layihe portfeli — status, prioritet, proqress

---

## 15. AI Komekci

Sol menyuda **"AI Komekci"** (yasil badge: YENI).

### 15.1 Imkanlar

| Tapsiiriq Novu | Ne Edir |
|---------------|---------|
| Sual Generasiyasi | Fenn ve cetinliye gore test suallari yaradir |
| Kurikulum Analizi | Standartlari analiz edir, bosluqlari tapir |
| Sagird Geri Bildirimi | Ferdi sagird ucun ferdilesdiirilmis geri bildirim |
| Ders Plani | Muellim ucun ders plani hazırlayir |
| Hesabat Xulasesi | Uzun hesabatlarin qisa xulasesini cixarir |

### 15.2 Istifade

1. **Tapsiiriq Novunu** secin (dropdowndan)
2. **AI Provayderi** secin — Claude (Anthropic) ve ya GPT (OpenAI)
3. Metni **"Daxil edin"** sahesindeé yazin
4. **"Generasiya Et"** duymesine basin
5. Neticeni gorun ve lazim geldikde **yukleyin** (TXT fayl)

### 15.3 Numune Sorgu

```
Tapsiiriq: Sual Generasiyasi
Metn: "8-ci sinif Riyaziyyat, 'Tenliklerin Helli' movzusu uzre
       3 coxsecimli sual yarat — 1 asan, 1 orta, 1 cetin.
       Her sualda 4 variant olsun. Bloom-un 'Tetbiq' seviyyesi."
```

---

## 16. Sesli Idareetme (Voice Agent) — Etrafli Telimat

### 16.1 Nedir ve Ne Ucundur?

Voice Agent — Python esasli sesli idareetme sistemidir. Azerbaycanca ve ya
Ingilisce danismaqla (ve ya yazmaqla) ARTI-2026 layihesini terminal
emrleri ile idare etmek imkani verir. Istifadeci ses emri verir, sistem
onu shell emrine cevirir, tesdiq alir ve icra edir.

**Esas meqsed:** Layihe ile isleyerken terminalda emrleri elle yazmaq
evezine, sesle ("Tetbiqi ise sal", "Son commitleri goster") idare etmek.

### 16.2 Fayl Strukturu ve Her Faylin Rolu

```
voice_agent/
├── main.py            # Esas giris noqtesi — rejim secimi ve doveriyya
├── config.py          # Butun parametrler, API acarlari, tehlukesizlik qaydalari
├── listener.py        # Mikrofon dinleme, VAD (Voice Activity Detection)
├── transcriber.py     # OpenAI Whisper API ile sesi metne cevirme
├── commander.py       # Claude API ile metni shell emrine cevirme
├── executor.py        # Tehlukesizlik yoxlamasi + emrin icrasi
├── requirements.txt   # Python asililqlari
└── README.md          # Qisa istifade telimatı
```

**Axin diaqrami:**
```
┌──────────────────────────────────────────────────────────────────────┐
│                         main.py (giriş nöqtəsi)                     │
│  --text rejimi: birbaşa yazı   |   default: mikrofon rejimi         │
│  --list-mics: cihaz siyahısı   |   --test: təhlükəsizlik testləri   │
└───────┬──────────────────────────────────┬───────────────────────────┘
        │ (metn rejimi)                    │ (sesli rejim)
        │                          ┌───────▼───────┐
        │                          │  listener.py   │
        │                          │  Mikrofon →    │
        │                          │  PyAudio → WAV │
        │                          └───────┬───────┘
        │                                  │ audio baytlari (WAV)
        │                          ┌───────▼────────┐
        │                          │ transcriber.py  │
        │                          │ Whisper API →   │
        │                          │ metn (az/en)    │
        │                          └───────┬────────┘
        │                                  │ metn
        ├──────────────────────────────────┤
        │                                  │
┌───────▼──────────────────────────────────▼───────┐
│                   commander.py                    │
│  Claude API → metn → shell emri                  │
│  Format: EMR: <emr>  ve ya  AYDIN_DEYIL: <sual>  │
│  Fallback: ```bash ... ``` bloklari da parse edir │
└──────────────────────┬───────────────────────────┘
                       │ {"command": "...", "is_clear": true/false}
               ┌───────▼───────┐
               │  executor.py   │
               │ 1. Tehlukesiz? │ → Bloklanmis sablonlari yoxla
               │ 2. Tesdiq?     │ → Istifadeciden y/n/e al
               │ 3. Icra        │ → subprocess.run(cwd=PROJECT_ROOT)
               └───────────────┘
```

### 16.3 Qurasdirma (Ilk Defe)

**1. Sistem asililqlari (macOS):**
```bash
# portaudio — PyAudio ucun lazimdir
brew install portaudio
```

**2. Python paketleri:**
```bash
cd ~/Desktop/Arti_2026/voice_agent
pip install -r requirements.txt
```

Bu 4 paket qurasdiriacaq:
| Paket | Versiya | Meqsed |
|-------|---------|--------|
| `pyaudio` | >=0.2.14 | Mikrofon ses qebulu |
| `openai` | >=1.0.0 | Whisper API (ses → metn) |
| `anthropic` | >=0.40.0 | Claude API (metn → emr) |
| `python-dotenv` | >=1.0.0 | `.env` faylini yukleme |

**3. API acarlari (.env faylinda):**
Layihenin kok qovlugundaki `.env` faylinda bu 2 acar olmalidir:
```
CLAUDE_API_KEY=sk-ant-api03-...
OPENAI_API_KEY=sk-proj-...
```
Voice agent bu acarlari `config.py` vasitesile avtomatik yukleyir.

**4. Yoxlama:**
```bash
cd ~/Desktop/Arti_2026/voice_agent
python3 main.py --test     # 12 tehlukesizlik testi islesin
python3 main.py --list-mics  # Mikrofon gorunmelidir
```

### 16.4 Istifade Rejmleri

#### 16.4.1 Sesli Rejim (default — mikrofon ile)

```bash
cd ~/Desktop/Arti_2026/voice_agent
python3 main.py
```

**Addim-addim ne bas verir:**
1. Sistem API acarlarini yoxlayir (Claude + Whisper)
2. Banner ve "Hazirdir!" mesaji gorsenir
3. `listener.py` mikrofonu acir, gozleyir
4. Siz danismaga basladiniz → RMS > 500 olduqda qeyd baslayir
5. 1.5 saniye susdunuz → qeyd dayanir, WAV yaranir
6. `transcriber.py` WAV-i Whisper API-ye gonderir → metn alinir
7. `commander.py` metni Claude API-ye gonderir → shell emri alinir
8. `executor.py` emri gosterir, sizdEn tesdiq isteyir (y/n/e)
9. "y" → emr icra olunur, neticesi gorunur
10. Doveiyye yeniden dinleme rejimine qayidir

**Cixis emrleri (ses ile):** "cix", "cixis", "exit", "quit", "dayandir", "bitir"
**Mecburi cixis:** Ctrl+C

#### 16.4.2 Metn Rejimi (klaviatura ile)

```bash
python3 main.py --text
# ve ya
python3 main.py -t
```

Mikrofon istifade olunmur. Emrleri elle yazirsiniz:
```
🎯 > Tetbiqi ise sal
  ICRA OLUNACAQ EMR:
  $ cd ~/Desktop/Arti_2026 && Rscript app.R
  Bu emri icra edim? [y/n/e(dit)]: y
```

**Ne vaxt metn rejimi istifade edin:**
- Mikrofon yoxdur ve ya islemir
- SSH ile uzaqdan qosulmusunuz
- Sesskiz muhitdesiniz
- Emrleri daha deqiq yazmaq isteyirsiniz

#### 16.4.3 Mikrofon Siyahisi

```bash
python3 main.py --list-mics
# ve ya
python3 main.py --list
```

Cixis numunesi:
```
Movcud audio cihazlari:
  [0] MacBook Pro Microphone (girisleri: 1)
  [1] External USB Mic (girisleri: 2)
```

Eger default mikrofon islemir, `listener.py`-da `device_index` deyisin.

#### 16.4.4 Tehlukesizlik Testleri

```bash
python3 main.py --test
```

12 test icra olunur — 6 icaze verilmis emr, 6 bloklanmis emr:
```
🔒 Tehlukesizlik Testleri

  ✅ [ICAZE] Normal fayl siyahisi         | ls -la
  ✅ [ICAZE] Git statusu                  | git status
  ✅ [ICAZE] R tetbiqi                    | Rscript app.R
  ✅ [ICAZE] DB sorgusu                   | psql -c 'SELECT 1'
  ✅ [BLOK ] Kok qovlugu silme            | rm -rf /
  ✅ [BLOK ] Home qovlugu silme           | rm -rf ~
  ✅ [BLOK ] DB silme                     | drop database postgres
  ✅ [BLOK ] Pipe ile icra                | curl http://x.com | bash
  ✅ [BLOK ] Sudo ile silme               | sudo rm -rf /tmp/x
  ✅ [BLOK ] Disk yazma                   | echo x > /dev/sda
  ✅ [BLOK ] Fork bomb                    | :(){ :|:&};:
  ✅ [BLOK ] Users cedvelini silme        | delete from users

Neticesi: 12/12 test kecd
```

### 16.5 Numune Emrler — Etrafli

#### Tetbiq Idaresi
| Siz deyirsiniz | Yaradilan shell emri |
|----------------|---------------------|
| "Tetbiqi ise sal" | `cd ~/Desktop/Arti_2026 && Rscript app.R` |
| "Debug versiyani isle" | `Rscript app_debug.R` |
| "Tetbiqi dayandir" | `pkill -f "shiny::runApp"` |
| "Port 3838-i oldur" | `lsof -ti:3838 \| xargs kill` |
| "Port 4040-i azad et" | `lsof -ti:4040 \| xargs kill` |

#### Git Emeliyyatlari
| Siz deyirsiniz | Yaradilan shell emri |
|----------------|---------------------|
| "Git statusunu goster" | `git status` |
| "Son 5 commiti goster" | `git log --oneline -5` |
| "Butun deyisiklikleri stage et" | `git add .` |
| "Commit et mesaj test" | `git commit -m "test"` |
| "Branch siyahisi" | `git branch -a` |

#### Verilener Bazasi
| Siz deyirsiniz | Yaradilan shell emri |
|----------------|---------------------|
| "Muellim sayini goster" | `psql -c "SELECT COUNT(*) FROM teachers"` |
| "Son 10 sagirdi goster" | `psql -c "SELECT * FROM students ORDER BY ... LIMIT 10"` |
| "DB-ye qosul" | `psql -h ... -d postgres` |

#### Sistem Melumlati
| Siz deyirsiniz | Yaradilan shell emri |
|----------------|---------------------|
| "Disk istifadesini goster" | `df -h` |
| "R yuklenib mi?" | `which R && R --version` |
| "Faylalri goster" | `ls -la` |

### 16.6 Her Modulun Etrafli Izahi

#### 16.6.1 config.py — Konfiqurasiya Merkezi

Bu fayl butun voice agent parametrlerini saxlayir.

**API Acarlari:**
```python
CLAUDE_API_KEY = os.getenv("CLAUDE_API_KEY", "")  # .env-den oxunur
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")  # .env-den oxunur
```

**Whisper Parametrleri:**
```python
WHISPER_MODEL = "whisper-1"     # OpenAI-nin Whisper modeli
WHISPER_LANGUAGE = None          # None = avtomatik dil algılama (az+en)
```
`WHISPER_LANGUAGE = None` olmasi Azerbaycan ve Ingilis dilini avtomatik
taniyir. Eger yalniz Azerbaycanca isteyirsiniz: `WHISPER_LANGUAGE = "az"`.

**Audio Parametrleri:**
```python
SAMPLE_RATE = 16000         # 16kHz — Whisper ucun optimal
CHANNELS = 1                # Mono (tek kanal)
CHUNK_SIZE = 1024           # Her oxunusda 1024 frame
SILENCE_THRESHOLD = 500     # Ses RMS bu deyerden yuxari → "danisir"
SILENCE_DURATION = 1.5      # 1.5 san sesssizlik → qeyd dayanir
MAX_RECORD_SECONDS = 30     # Maksimum 30 san qeyd
```

**SILENCE_THRESHOLD deyerini deyismek:**
- Sessiz otaqda 300-500 yaxsidir
- Kuylulu muhitde 800-1200 qoymaq lazimdir
- Deyismek ucun `config.py`-da `SILENCE_THRESHOLD` deyerini redakte edin

**Claude Parametrleri:**
```python
CLAUDE_MODEL = "claude-sonnet-4-5-20250929"   # Istifade olunan model
CLAUDE_MAX_TOKENS = 1024                       # Cavab uzunlugu limiti
```

**Layihe Konteksti (PROJECT_CONTEXT):**
Claude-a gonderilen sistem mesaji — layihe haqqinda melumat saxlayir:
- Layihenin yeri (PROJECT_ROOT)
- Texnologiyalar (R Shiny, PostgreSQL, Python)
- Esas fayllar (app.R, app_debug.R)
- Modullar (student, teacher, assessment, curriculum, analytics, vs.)
- DB konfiqurasiyasi (Supabase)

Bu kontekst sayesinde Claude emrleri layiheye uygun yaradir.

**Bloklanan Sablonlar (BLOCKED_PATTERNS):**
28 tehlikeli sablon avtomatik bloklanir — tam siyahi:
```
rm -rf /           rm -rf ~          rm -rf /*         rm -rf .
mkfs               dd if=            :()               (){
:|:                chmod -R 777 /    drop database      drop schema
truncate           delete from users  delete from teachers
delete from students   shutdown      reboot             halt
init 0             init 6            > /dev/sda
curl | sh          curl | bash       wget | sh          wget | bash
```

**Icaze Verilen Qovluqlar:**
```python
ALLOWED_DIRECTORIES = [
    str(PROJECT_ROOT),   # ~/Desktop/Arti_2026
    "/tmp",
]
```

#### 16.6.2 listener.py — Mikrofon Dinleme

**RMS (Root Mean Square) hesablama:**
Mikrofondan gelen her ses parcasinin (chunk) gurluyu RMS ile olculur.
```python
def get_rms(data: bytes) -> float:
    # 16-bit audio baytlarini raqemlere cevirir
    # Her raqemin karesini toplayir
    # Ortalamanin kok deyerini qaytarir → seslilik gostericisi
```

**Dinleme doveriysi:**
1. PyAudio ile mikrofon acilir (16kHz, mono, 16-bit)
2. Doveiyye her CHUNK_SIZE (1024) frame oxuyur
3. Eger `RMS > SILENCE_THRESHOLD` (500) → "danisir", qeyde basla
4. Eger danisirdi ve `RMS < 500` → suskunda
5. Eger 1.5 saniye susursa → qeyd dayanir
6. Eger 30 saniye hec ses gelmezse → timeout, None qaytarir
7. Qeyd olunan frameleri WAV formatina cevirir (io.BytesIO)

**Qaytarilan deyer:** WAV bytes ve ya None (ses algilanmadisa)

#### 16.6.3 transcriber.py — Ses → Metn (Whisper)

**Esas funksiya:** `transcribe(audio_bytes) → str | None`

Ne edir:
1. WAV baytlarini BytesIO stream-e cevirir
2. OpenAI Whisper API-ye gonderir (`whisper-1` modeli)
3. `prompt` parametri ile kontekst verir:
   `"ARTI-2026, muellim, sagird, davamiyyet, qiymetlendirme, kurikulum, analitika"`
   Bu prompt Whisper-e layiheye aid sozleri daha duzgun tanimaga komek edir
4. `response_format: "text"` → birba sade metn qaytarir (JSON deyil)
5. Metn boshdursa → None qaytarir

**Dil algilama:**
`WHISPER_LANGUAGE = None` → Whisper avtomatik olaraq dili algliayir.
Azerbaycanca ve Ingilisce qarisgq danismaq olur.

#### 16.6.4 commander.py — Metn → Shell Emri (Claude)

**Esas funksiya:** `text_to_command(user_text) → dict`

Qaytarilan dict strukturu:
```python
{
    "command": str | None,     # Shell emri ("git status") ve ya None
    "explanation": str,        # Azerbaycanca izahat
    "is_clear": bool,          # Emr aydindir? True/False
    "question": str | None     # Aydin deyilse Claude-un suali
}
```

**Claude-a gonderilen prompt formati:**
```
Sistem: [PROJECT_CONTEXT — layihe melumati]
Istifadeci: Bu emri shell emrine cevir: "<metn>"
            Cavab formati (yalniz biri):
            EMR: <shell emri>
            ve ya
            AYDIN_DEYIL: <sual>
            Layihe qovlugu: ~/Desktop/Arti_2026
```

**Cavab parse etme mentiqi (3 ssenari):**

1. **EMR: formatinda cavab** → Birbaşa parse:
   ```
   EMR: git log --oneline -5   →   cmd = "git log --oneline -5"
   ```

2. **AYDIN_DEYIL: formatinda cavab** → Sual qaytarilir:
   ```
   AYDIN_DEYIL: Hansi muellimi nez de tutursunuz?
   →  is_clear=False, question="Hansi muellimi nez de tutursunuz?"
   ```

3. **```bash ... ``` kod bloku (fallback)** → Regex ile parse:
   ```python
   re.search(r"```(?:bash|sh)?\s*\n(.+?)```", reply, re.DOTALL)
   ```
   Claude bezne format yerine kod bloku ile cavab verir. Bu fallback
   onu da duzgun parse edir.

4. **Hec biri uymasa** → Ilk setir goturulur, emre oxsar deyilse
   `is_clear=False` qaytarilir.

#### 16.6.5 executor.py — Tehlukesiz Icra

**3 funksiya:**

**`check_safety(command)` → (bool, str):**
Emrin tehlukesiz olub-olmadigini yoxlayir:
1. `BLOCKED_PATTERNS` siyahisinda hec bir sablon varmı?
2. `/dev/` cihazina yazma varmı? (`> /dev/sda` tipli)
3. `sudo` ile tehlikeli emeliyyat? (rm, mkfs, dd, chmod 777, chown)
4. Pipe ile tehlikeli icra? (`| bash`, `| python`, `| sh`, `| perl`)

**`confirm_command(command)` → bool:**
Istifadeciden tesdiq alir:
```
============================================================
  ICRA OLUNACAQ EMR:
  $ git log --oneline -5
============================================================

  Bu emri icra edim? [y/n/e(dit)]: _
```
Cavablar:
- **y / yes / he / beli** → True (icra et)
- **n / no / xeyr / yox** → False (legv et)
- **e / edit / redakte** → Emri deyismek imkani (yeni emr de safety check-den kecir)

**`execute(command, timeout=120)` → dict:**
1. `check_safety()` cagrilir → tehlikelise dayandrilir
2. `confirm_command()` cagrilir → istifadeci tesdiq vermeldir
3. `subprocess.run()` ile emr icra olunur:
   - `shell=True` → Pipe, redirect isleyir
   - `cwd=PROJECT_ROOT` → Layihe qovlugunda icra olunur
   - `timeout=120` → 2 deqiqe limit
   - `capture_output=True` → stdout/stderr tutulur
4. Cixis gorunur (stdout max 2000 simvol, stderr max 1000 simvol)

Qaytarilan dict:
```python
{
    "success": True/False,
    "stdout": "...",
    "stderr": "...",
    "returncode": 0        # 0=ugurlu, -1=blok, -2=legv, -3=timeout, -4=xeta
}
```

#### 16.6.6 main.py — Giris Noqtesi

4 rejim:
| Arqument | Funksiya | Izah |
|----------|----------|------|
| (hec ne) | `run_voice_mode()` | Mikrofon → Whisper → Claude → Shell |
| `--text` / `-t` | `run_text_mode()` | Klaviatura → Claude → Shell |
| `--list-mics` / `--list` | `list_microphones()` | Movcud mikrofon siyahisi |
| `--test` | `run_safety_test()` | 12 tehlukesizlik testi |
| `--help` / `-h` | Istifade telimatı | |

**`check_api_keys()`** — Baslarkne CLAUDE_API_KEY ve OPENAI_API_KEY movcudlugunu
yoxlayir. Catismayirsa xeta mesaji verir ve cixir.

### 16.7 Tehlukesizlik Sistemi — Etrafli

Voice agent 4 seviyyeli tehlukesizlik sistemi istifade edir:

**Seviyye 1 — Pattern Matching (avtomatik):**
`config.py`-daki 28 sablon yoxlanir. Meselen `rm -rf /`, `drop database`,
`curl | bash`, fork bomb subcadelerinden hec biri emrde ola bilmez.

**Seviyye 2 — Operator Analizi (avtomatik):**
- `/dev/` cihazina yazma bloklanir
- `sudo` ile rm/mkfs/dd/chmod/chown bloklanir
- Pipe ile sh/bash/python/perl icra bloklanir

**Seviyye 3 — Istifadeci Tesdiqi (interaktiv):**
Her emr icra olunmadan evvel istifadeciden tesdiq alinir.
Istifadeci emri gorup y(es), n(o), e(dit) sece biler.
Edit secildikde yeni emr de tehlukesizlik yoxlamasindan kecir.

**Seviyye 4 — Isleyis Sandbox (runtime):**
- Emrler yalniz `PROJECT_ROOT` (`~/Desktop/Arti_2026`) qovlugunda icra olunur
- Timeout: 120 saniye (2 deqiqe) — sonsuz doveiyyeler qarsdisinda qorunma
- stdout 2000, stderr 1000 simvolla kesilir — surec asmasina qarsb qorunma

### 16.8 Xeta Helli (Troubleshooting)

#### "Mikrofon acila bilmedi"
```bash
# 1. portaudio yukle
brew install portaudio

# 2. pyaudio yeniden yukle
pip install --force-reinstall pyaudio

# 3. Mikrofon icazesini yoxla
# macOS: System Preferences → Privacy & Security → Microphone → Terminal → ON

# 4. Movcud cihazlari yoxla
python3 main.py --list-mics
```

#### "Ses algilanmadi"
- `SILENCE_THRESHOLD` cox yuksekdir → `config.py`-da 300-e endir
- Mikrofon yanlisdis → `--list-mics` ile baxin, device_index teyin edin
- Mikrofon muted ola biler → macOS ses parametrlerini yoxlayin

#### "Whisper API xetasi"
- OPENAI_API_KEY duzgun teyin olunub? `.env` yoxlayin
- Kredit qalibdir? OpenAI hesabinda yoxlayin (platform.openai.com)
- Internet baglantisi isleyir mi?

#### "Claude API: credit balance too low"
- Anthropic hesabinda kredit elave edin (console.anthropic.com)
- `CLAUDE_API_KEY` duzgundur mu? `.env` yoxlayin

#### "Emr yaradila bilmedi" / "None qaytarildi"
Bu Claude-un cavabinin parse olunmamasindan qaynaqlana biler.
`commander.py` hal-hazirda 4 formati destekleyir:
1. `EMR: <emr>` — esas format
2. `AYDIN_DEYIL: <sual>` — aydin olmayan emrler
3. ` ```bash\n<emr>\n``` ` — kod bloku
4. Ilk setir (fallback)

Eger hec biri islemirzse, emri daha aydin deyin.

#### "Tehlukesizlik testi fail oldu"
```bash
python3 main.py --test
```
12/12 kecinceye qeder `config.py`-daki `BLOCKED_PATTERNS` siyahisini yoxlayin.

### 16.9 Konfiqurasiya Deyisiklikleri

| Deyismek isteyirsiniz | Fayl | Deyer |
|----------------------|------|-------|
| Seslilik hassasligi | `config.py` | `SILENCE_THRESHOLD = 500` |
| Susma muddeti | `config.py` | `SILENCE_DURATION = 1.5` |
| Maks qeyd muddeti | `config.py` | `MAX_RECORD_SECONDS = 30` |
| Claude modeli | `config.py` | `CLAUDE_MODEL = "claude-sonnet-4-5-20250929"` |
| Claude cavab limiti | `config.py` | `CLAUDE_MAX_TOKENS = 1024` |
| Whisper dili | `config.py` | `WHISPER_LANGUAGE = None` (avtomatik) |
| Layihe konteksti | `config.py` | `PROJECT_CONTEXT` deyiseni |
| Bloklanmis sablonlar | `config.py` | `BLOCKED_PATTERNS` siyahisi |
| Emr icra timeout | `executor.py` | `execute(cmd, timeout=120)` |

### 16.10 API Xerclerinin Idaresi

Her ses emri 2 API cagrisi edir:
1. **Whisper API** (~0.006 $/deqiqe audio) — orta emr ~3 saniye = ~$0.0003
2. **Claude API** (~0.003-0.015 $/sorgu) — sade emrler ~$0.003

**Teqribi xercler:**
| Istifade | Gunluk emr | Ayliq xerc |
|----------|-----------|------------|
| Az | 10 emr/gun | ~$1.50 |
| Orta | 50 emr/gun | ~$7 |
| Aktiv | 200 emr/gun | ~$25 |

**Qenaet ucun:**
- Sade emrler ucun `--text` rejimi istifade edin (Whisper xercini azidir)
- `CLAUDE_MAX_TOKENS`-i 512-ye endirin (daha qisa cavablar)

---

## 17. Idareetme Paneli (Admin)

Sol menyuda **"Idareetme"** — 3 alt-sehife.

### 17.1 Istifadeciler
Sistem istifadecilerinin idaresi:
- Ad, email, rol, status
- Yeni istifadeci elave etme
- Rollari deyisdirme

**Rollar:** admin, director, teacher, student, parent, inspector

### 17.2 Parametrler
Sistem parametrlerini deyisdirme — konfiqurasiya interfeysi.

### 17.3 Loglar
Sistem loqlari — butun emeliyyatlarin audit izi:
- Kim, ne vaxt, ne etdi, hansi cedvel, hansi qeyd

---

## 18. Verilenlerin Bazasi

### 18.1 Cedvel Strukturu

Layihede **20+ cedvel** var. Esas cedveller:

**Istifadeciler:**
- `users` — hesablar (username, email, password_hash, rol)
- `user_sessions` — aktiv sessiyalar (JWT tokenler)
- `login_attempts` — ugursuz giris cehdleri

**Mekteb ve Sinif:**
- `schools` — mekteb melumatlari (ad, nov, region, tutum)
- `classes` — sinifler (mekteb, sinif, bolme, tehsil seviyyesi)

**Sagirdler:**
- `students` — sagird qeydleri (FIN, dogum tarixi, sinif, status)
- `student_parents` — valideyn melumatlari

**Muellimlər:**
- `teachers` — muellim profilleri (kateqoriya, tecrube, ixtisas)
- `teacher_subjects` — muellim-fenn elaqesi
- `teacher_schedule` — heftelik ders cedveli
- `teacher_trainings` — istirak etdiyi telimler
- `teacher_evaluations` — qiymetlendirme nneticeleri
- `teacher_awards` — mukafatlar
- `teacher_talis_indicators` — TALIS gostericileri
- `teacher_publications` — elmi nesrler

**Kurikulum ve Qiymetlendirme:**
- `subjects` — fennler (15 fenn)
- `grades` — qiymetler (bal, fenn, nov, semester)
- `attendance` — davamiyyet qeydleri
- `curriculum_standards` — kurikulum standartlari
- `items` — sual banki (IRT parametrleri ile)
- `tests` — testler (CAT/MST/sabit)
- `test_sessions`, `test_responses` — test neticeleri

### 18.2 Qiymet Novu Sistemi

| Tip | Kod | Izah |
|-----|-----|------|
| Gundelik | gundelik | Sinifde verilmis gundelik bal |
| KSA | ksa | Kicik Summativ Qiymetlendirme |
| BSA | bsa | Boyuk Summativ Qiymetlendirme |
| Yarimilli | yarimil | Yarimil sonu bali |
| Illik | illik | Il sonu yekun bali |
| Imtahan | imtahan | Imtahan bali |
| Layihe | layihe | Layihe isi bali |

### 18.3 Qiymet Skalasi

| Ad | Aralig | Reng |
|----|--------|------|
| Ela | 86-100 | Yasil |
| Yaxsi | 71-85 | Mavi |
| Kafi | 51-70 | Sari |
| Qeyri-kafi | 0-50 | Qirmizi |

---

## 19. Konfiqurasiya

### 19.1 config.yml

Esas konfiqurasiya faylidir. Deisdirilə bilən parametrler:

**Sagird:**
- `max_per_class: 35` — sinifdeki maks sagird sayi
- `min_attendance_percent: 75` — minimum davamiyyet faizi
- `risk_threshold: 0.3` — risk hedd deyeri

**Muellim:**
- `max_weekly_hours: 36` — maks heftelik ders saati
- `min_weekly_hours: 18` — min heftelik ders saati
- `evaluation_period_months: 6` — qiymetlendirme dovru

**Qiymetlendirme:**
- IRT modeli, theta araligi, konvergensiya
- CAT min/maks sual, SE heddi
- MST merhele sayi, modul bolgusu

**AI:**
- `temperature: 0.7` — yaradiciliq seviyyesi (0=deqiq, 1=yaradici)
- `max_retries: 3` — API ugursuzlugunda tekrar cehd
- `timeout_seconds: 30` — API zaman limiti

**Tehlukesizlik:**
- `session_timeout_minutes: 60` — sessiya muddeti
- `max_login_attempts: 5` — maks giris cehdi
- `lockout_duration_minutes: 15` — kilid muddeti

### 19.2 .env Deyisenleri

| Deyisen | Numune | Izah |
|---------|--------|------|
| DB_HOST | aws-1-...supabase.com | DB serveri |
| DB_PORT | 5432 | DB portu |
| DB_NAME | postgres | DB adi |
| DB_USER | postgres.xxx | DB istifadecisi |
| DB_PASSWORD | *** | DB sifresi |
| CLAUDE_API_KEY | sk-ant-... | Anthropic API acari |
| OPENAI_API_KEY | sk-proj-... | OpenAI API acari |
| JWT_SECRET | *** | Token sifresi |
| APP_PORT | 3838 | Tetbiq portu |

---

## 20. Deploy

### 20.1 ShinyApps.io

**Addimlar:**
1. rsconnect paketini qurasdirin:
   ```r
   install.packages("rsconnect")
   ```

2. Hesabi baglasyin:
   ```r
   rsconnect::setAccountInfo(
     name = "hesab_adi",
     token = "token",
     secret = "secret"
   )
   ```

3. Deploy edin:
   ```r
   rsconnect::deployApp(
     appDir = ".",
     appName = "arti-2026",
     appTitle = "ARTI-2026"
   )
   ```

4. ShinyApps.io dashboard-da **Environment Variables** elave edin
   (DB_HOST, DB_USER, DB_PASSWORD, CLAUDE_API_KEY, OPENAI_API_KEY)

**Qeyd:** `.shinyappsignore` fayli movcuddur — agent/, tests/, deploy/ ve s.
deploy olunmur.

### 20.2 Docker

```bash
cd ~/Desktop/Arti_2026
docker-compose up -d
```

**Servisler:**
- Port 80/443 — Nginx (reverse proxy)
- Port 3838 — R Shiny app
- Port 5432 — PostgreSQL
- Port 6379 — Redis
- Port 3000 — Grafana (monitorinq)
- Port 9090 — Prometheus (metrikler)

### 20.3 Lokal Isletme

```bash
# Esas versiya
Rscript app.R              # http://localhost:3838

# Debug versiya (yalniz student+teacher)
Rscript app_debug.R        # http://localhost:4040
```

---

## 21. Tehlukesizlik

### 21.1 Autentifikasiya
- JWT (JSON Web Token) esasli sessiya idaresi
- Token muddeti: 24 saat (konfiqurasiya ile deyisdirile biler)
- Ugursuz giris cehdleri izlenir — 5 ugursuz cehdden sonra 15 deq kilid

### 21.2 SQL Injection Qorunmasi
Butun sorqular **parametrli** formatdadir:
```r
# DOGRU — parametrli sorgu
db_query(pool, "SELECT * FROM users WHERE id = $1", params = list(user_id))

# YANLIS — interpolasiya (hec vaxt istifade etmeyin!)
db_query(pool, paste0("SELECT * FROM users WHERE id = '", user_id, "'"))
```

### 21.3 XSS Qorunmasi
Butun istifadeci girislerinde `htmltools::htmlEscape()` istifade olunur.

### 21.4 Sifre Tehlukesizliyi
- SHA256 + salt ile hashing
- Minimum 8 simvol, boyuk/kicik herf + reqem teleb olunur

### 21.5 Voice Agent Tehlukesizliyi
- **28 tehlikeli sablon** avtomatik bloklanir (rm -rf, drop database, fork bomb, vs.)
- **Sudo qorunmasi:** sudo ile rm/mkfs/dd/chmod/chown bloklanir
- **Pipe qorunmasi:** `| bash`, `| python`, `| sh`, `| perl` pipe-lari bloklanir
- **Cihaz qorunmasi:** `/dev/` cihazlarina yazma bloklanir
- **Her emrden evvel** istifadeci tesdiq vermelidir (y/n/e)
- **Edit imkani:** Istifadeci emri deyise biler, yeni emr de yoxlamadan kecir
- **Sandbox:** Butun emrler `PROJECT_ROOT` qovlugunda icra olunur
- **Timeout:** 120 saniye limitle sonsuz doveriyyeler qarsisinda qorunma
- Tam bloklanmis sablonlar siyahisi: `voice_agent/config.py` → `BLOCKED_PATTERNS`

---

## 22. Problem Hell (Troubleshooting)

### 22.1 "Port already in use" Xetasi

```bash
# Port 3838-i azad et
lsof -ti:3838 | xargs kill

# Port 4040-i azad et
lsof -ti:4040 | xargs kill
```

### 22.2 DB Baglanti Xetasi

**"Tenant or user not found"** — Supabase kredensiallarini yoxlayin:
- DB_HOST, DB_USER, DB_PASSWORD duzgundurmu?
- Supabase Dashboard → Settings → Database → Connection string

**"Connection refused"** — PostgreSQL serveri islemir:
```bash
# Lokal PostgreSQL
brew services start postgresql
```

### 22.3 Paket Xetasi

```r
# Catismayan paketi qurasdirin
install.packages("paket_adi")

# Butun paketleri yeniden qurasdirin
source("R/utils.R")
check_packages()  # catismayanlari gosterir
```

### 22.4 Sidebar Menyu Islemiir

Bu problem `library(bslib)` sebebile yasanirdi — Bootstrap 5 ile
shinydashboard-un Bootstrap 3 arasinda konflik. **Hell:** app.R-dan
`library(bslib)` silinib, artiq bu problem yasanmamalidir.

### 22.5 Muellim Bolmesi Gorunmur

- `library(bslib)` silinib mi? → Yoxlayin
- `user_data` NULL deyil mi? → Default guest user teyin olunub
- `waiter_hide()` cagrilir mi? → `session$onFlushed()` ile temin olunub

### 22.6 Voice Agent Xetalari

**Mikrofon acilmir:**
```bash
brew install portaudio && pip install --force-reinstall pyaudio
python3 main.py --list-mics
# macOS: System Preferences → Privacy & Security → Microphone → Terminal → ON
```

**Ses algilanmir:**
- `config.py` → `SILENCE_THRESHOLD`-i 300-e endirin (sessiz otaq ucun)
- `--list-mics` ile duzgun mikrofonu tapin

**API xetasi (Whisper/Claude):**
- `.env`-de CLAUDE_API_KEY ve OPENAI_API_KEY duzgun teyin olunub?
- Kreditler qalibdir? console.anthropic.com / platform.openai.com
- `python3 main.py --test` — 12/12 test kecmelidir

**Emr None qaytarir:**
- Claude bezne `EMR:` yerine ` ```bash ``` ` bloku qaytarir — bu hal-hazirda
  `commander.py`-da regex ile hell olunub. Daha aydin emr deyin.

### 22.7 AI API Xetasi

**"Credit balance too low"** → Anthropic Console-da kredit elave edin:
https://console.anthropic.com/settings/billing

**"Invalid API key"** → .env faylindaki CLAUDE_API_KEY ve OPENAI_API_KEY
duzgun kopyalanib mi yoxlayin.

---

## 23. Texniki Arxitektura

### 23.1 Modul Pattern-i

Her modul 3 fayldan ibaretdir:

```
modules/modul_adi/
├── modul_adi_ui.R       # UI komponentleri (interfeys)
├── modul_adi_server.R   # Server mentiq (reaktivlik)
└── modul_adi_helpers.R  # DB sorqulari ve yardimci funksiyalar
```

**UI funksiyasi:**
```r
modul_ui <- function(id) {
  ns <- NS(id)  # Namespace — ID-lerin confliktini onleyir
  tagList(
    selectInput(ns("filtr"), "Filtr:", secenekler),
    DTOutput(ns("cedvel")),
    actionButton(ns("elave_et"), "Elave Et")
  )
}
```

**Server funksiyasi:**
```r
modul_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    # Reaktiv melumat
    data <- reactive({
      db_query(db_pool, "SELECT * FROM cedvel WHERE status = $1",
               params = list(input$filtr))
    })

    # Cedvel render
    output$cedvel <- renderDT({ datatable(data()) })

    # Duymeye klik
    observeEvent(input$elave_et, {
      db_execute(db_pool, "INSERT INTO cedvel ...")
      showNotification("Elave edildi!")
    })
  })
}
```

### 23.2 DB Baglanti Pool-u

Tetbiq **connection pooling** istifade edir — DB-ye tek baglanti evezine
bir nece baglanti saxlanir ve paylasilir:

```r
db_pool <- dbPool(
  drv = RPostgres::Postgres(),
  minSize = 1,    # Minimum baglanti
  maxSize = 5,    # Maksimum baglanti
  idleTimeout = 30000  # Bosqalma muddeti (30 san)
)
```

### 23.3 Reaktiv Proqramlama

R Shiny **reaktiv** proqramlama modeli istifade edir:

```
Input deyisir → Reactive yeniden hesablanir → Output yenilenir
```

Numune:
```
[Filtr secilir] → [DB sorgusu isleyir] → [Cedvel yenilenir]
    (input)          (reactive)              (output)
```

### 23.4 Sesli Agent Arxitekturasi

```
┌──────────────┐         ┌───────────────┐         ┌───────────────┐
│  listener.py  │  WAV   │transcriber.py │  metn   │ commander.py  │
│  Mikrofon →   │───────→│  Whisper API  │────────→│  Claude API   │
│  PyAudio+VAD  │  bytes │  ses → metn   │  str    │  metn → emr   │
└──────────────┘         └───────────────┘         └──────┬────────┘
                                                          │ dict
                                                    ┌─────▼────────┐
                                                    │ executor.py   │
                                                    │ 1. Safety chk │
                                                    │ 2. Confirm    │
                                                    │    [y/n/e]    │
                                                    │ 3. subprocess │
                                                    └──────────────┘

Fayllar arasi asiliqliq:
  main.py → config.py (parametrler)
  main.py → listener.py → config.py (audio params)
  main.py → transcriber.py → config.py (Whisper params)
  main.py → commander.py → config.py (Claude params, PROJECT_CONTEXT)
  main.py → executor.py → config.py (BLOCKED_PATTERNS, ALLOWED_DIRS)
```

**Etrafli voice_agent telimatı ucun bax:** Bolme 16 (16.1 — 16.10)

---

## Elave Melumat

- **Layihe qovlugu:** `~/Desktop/Arti_2026`
- **Esas tetbiq:** `app.R` (port 3838)
- **Debug tetbiq:** `app_debug.R` (port 4040)
- **Sesli agent:** `voice_agent/main.py`
- **DB sxem:** `database/schema/tables.sql`
- **Konfiqurasiya:** `config.yml` + `.env`

**Derstek:** https://github.com/anthropics/claude-code/issues

---

*Bu telimat ARTI-2026 v1.0.0 ucundur. Yeni versiyalarda elave funksiyalar ola biler.*
