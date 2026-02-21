# ARTI-2026 Səsli Köməkçi v2

Azərbaycan dilində səsli söhbət ilə təhsil idarəetmə sisteminə müraciət edin.

## Yeniliklər (v2)

- **Wake Word** — "ARTİ" və ya "Agent" deyərək aktivləşdirin
- **Təbii söhbət** — shell əmri yox, danışıq dilində sual-cavab
- **DB sorğuları** — canlı PostgreSQL-dən data çəkir
- **TTS** — OpenAI TTS ilə səsli cavab verir
- **Kontekst** — əvvəlki sualları xatırlayır

## Quraşdırma

```bash
cd voice_agent
pip install -r requirements.txt
```

macOS-da PyAudio üçün portaudio lazımdır:
```bash
brew install portaudio
```

## .env faylında lazım olan dəyərlər

```
CLAUDE_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-...
DB_HOST=localhost
DB_PORT=5432
DB_NAME=arti_2026
DB_USER=arti_admin
DB_PASSWORD=...
```

## Rejimlər

### 1. Səsli rejim (əsas)
```bash
python main.py
```
Enter basın → danışın → ARTİ cavab verir (səs + mətn)

### 2. Dövri dinləmə (wake word)
```bash
python main.py --continuous
```
Mikrofon daim açıqdır. "ARTİ, ..." deyərək sual verin.

### 3. Mətn rejimi
```bash
python main.py --text
```
Klaviatura ilə yazışın, ARTİ səslə cavab verir.

### 4. Shell əmr rejimi (v1)
```bash
python main.py --exec
```
Səsi shell əmrinə çevirir (v1 funksionallığı).

### 5. Testlər
```bash
python main.py --test        # Təhlükəsizlik testləri
python main.py --test-tts    # TTS testi
python main.py --test-db     # DB bağlantı testi
python main.py --list-mics   # Mikrofon siyahısı
```

## Nümunə dialoq

```
❓ Siz: "ARTİ, bu həftə neçə şagird qayıb olub?"
🤖 Düşünürəm...
  🔍 DB sorğusu icra olunur...
  ✅ 22 sətir tapıldı
🔊 ARTİ: Bu həftə 22 məktəbdə cəmi 47 şagird qayıb qeydə alınıb.
         Ən çox qayıb Məktəb 12-dədir — 8 şagird.

❓ Siz: "Ən çox hansı fənndən yayınırlar?"
🤖 Düşünürəm...
🔊 ARTİ: Qayıb şagirdlərin əksəriyyəti riyaziyyat dərslərindən
         yayınır — 12 qayıb. İkinci yerdə fizika (8 qayıb).

❓ Siz: "Riyaziyyatdan ümumi orta bal neçədir?"
🤖 Düşünürəm...
🔊 ARTİ: Riyaziyyatdan ümumi orta bal 68.3-dür, bu "Kafi"
         səviyyəsinə uyğundur. Ən yaxşı nəticə Məktəb 3-dədir — 78.1.
```

## Arxitektura (v2)

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│  Mikrofon    │────▶│ Whisper STT  │────▶│ Wake Word   │
│  (PyAudio)   │     │ (az/tr)      │     │ Detect      │
└─────────────┘     └──────────────┘     └──────┬──────┘
                                                │
                    ┌──────────────┐     ┌───────▼──────┐
                    │  PostgreSQL  │◀───▶│ Claude Brain │
                    │  (canlı DB)  │     │ (analiz+cavab)│
                    └──────────────┘     └──────┬──────┘
                                                │
┌─────────────┐     ┌──────────────┐     ┌───────▼──────┐
│  Speaker     │◀───│ OpenAI TTS   │◀───│  Kontekst    │
│  (afplay)    │    │ (nova)       │     │  (yadda saxla)│
└─────────────┘     └──────────────┘     └──────────────┘
```

## Fayl Strukturu

| Fayl | Təyinatı |
|------|---------|
| `main.py` | Əsas giriş nöqtəsi, rejim idarəetməsi |
| `config.py` | Bütün konfiqurasiyalar, sistem promptu |
| `listener.py` | Mikrofon + VAD + wake word detection |
| `transcriber.py` | Whisper STT (AZ/TR optimizasiya) |
| `brain.py` | Claude AI — analiz, DB sorğu, cavab |
| `speaker.py` | OpenAI TTS — səsli oxuma |
| `db_bridge.py` | PostgreSQL sorğu körpüsü |
| `context.py` | Söhbət tarixçəsi idarəetməsi |
| `commander.py` | Shell əmr çeviricisi (v1 uyğunluğu) |
| `executor.py` | Təhlükəsiz shell icra (v1 uyğunluğu) |

## Təhlükəsizlik

- DB: Yalnız SELECT sorğuları icazəlidir
- Shell: 24+ təhlükəli şablon bloklanır
- TTS: Mətn 3500 simvolla məhdudlaşır
- Kontekst: Son 1 saat ərzindəki mesajlar saxlanır
