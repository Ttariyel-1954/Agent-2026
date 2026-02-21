# 🎤 ARTİ-2026: Səsli Komandalar Təlimatı

## İstifadə qaydası
```bash
cd ~/Desktop/Arti_2026/voice_agent
python3 main.py           # Səs rejimi (mikrofonla)
python3 main.py --text     # Mətn rejimi (klaviatura ilə)
```

---

## 1. TƏTBİQİ İDARƏ ETMƏ

| Nə deyirsiniz | Nə baş verir |
|---|---|
| "Tətbiqi işə sal" | `R -e "shiny::runApp('~/Desktop/Arti_2026', port=3838)"` |
| "Tətbiqi dayandır" | `lsof -ti:3838 \| xargs kill -9` |
| "Tətbiqi yenidən başlat" | Dayandırır + işə salır |
| "Port 4040-da işə sal" | `R -e "shiny::runApp('.', port=4040)"` |
| "Bütün portları təmizlə" | `lsof -ti:3838 \| xargs kill -9; lsof -ti:4040 \| xargs kill -9` |
| "Tətbiq işləyir?" | `lsof -i:3838` |

---

## 2. GİT ƏMƏLİYYATLARI

| Nə deyirsiniz | Nə baş verir |
|---|---|
| "Git status göstər" | `git status` |
| "Git log göstər" | `git log --oneline -10` |
| "Dəyişiklikləri commit et" | `git add -A && git commit -m "update"` |
| "GitHub-a push et" | `git push origin main` |
| "Son commiti göstər" | `git log -1` |
| "Dəyişiklikləri geri al" | `git checkout -- .` |
| "Yeni branch yarat: test" | `git checkout -b test` |
| "Main branch-a keç" | `git checkout main` |
| "Branch-ları göstər" | `git branch -a` |
| "Son dəyişiklikləri göstər" | `git diff` |

---

## 3. FAYL ƏMƏLİYYATLARI

| Nə deyirsiniz | Nə baş verir |
|---|---|
| "Fayl strukturunu göstər" | `tree -I 'node_modules\|.git\|__pycache__' -L 2` |
| "Bütün faylları göstər" | `find . -type f \| head -50` |
| "R fayllarını göstər" | `find . -name "*.R" -type f` |
| "Python fayllarını göstər" | `find . -name "*.py" -type f` |
| "SQL fayllarını göstər" | `find . -name "*.sql" -type f` |
| "App.R faylını göstər" | `cat app.R` |
| "Müəllim UI faylını göstər" | `cat modules/teacher/teacher_ui.R` |
| "Müəllim server faylını göstər" | `cat modules/teacher/teacher_server.R` |
| "Şagird modulunu göstər" | `cat modules/student/student_ui.R` |
| "Sabitləri göstər" | `cat R/constants.R` |
| "Env faylını göstər" | `cat .env` |
| "Config faylını göstər" | `cat config.yml` |
| "Log faylını göstər" | `tail -50 logs/arti_2026.log` |
| "Son 20 log sətri" | `tail -20 logs/arti_2026.log` |
| "Xəta loglarını göstər" | `grep ERROR logs/arti_2026.log` |

---

## 4. MODUL İDARƏETMƏSİ

| Nə deyirsiniz | Nə baş verir |
|---|---|
| "Müəllim modulunun fayllarını göstər" | `ls -la modules/teacher/` |
| "Şagird modulunun fayllarını göstər" | `ls -la modules/student/` |
| "Qiymətləndirmə modulunu göstər" | `ls -la modules/assessment/` |
| "Kurikulum modulunu göstər" | `ls -la modules/curriculum/` |
| "Analitika modulunu göstər" | `ls -la modules/analytics/` |
| "Sertifikasiya modulunu göstər" | `ls -la modules/certification/` |
| "İnstitut modulunu göstər" | `ls -la modules/institute/` |
| "Bütün modulları göstər" | `ls -la modules/` |
| "AI inteqrasiyanı göstər" | `ls -la ai_integration/` |

---

## 5. VERİLƏNLƏR BAZASI

| Nə deyirsiniz | Nə baş verir |
|---|---|
| "Cədvəlləri göstər" | `psql -c "\dt"` (lokal) |
| "Müəllimləri göstər" | `psql -c "SELECT * FROM teachers LIMIT 10"` |
| "Şagirdləri göstər" | `psql -c "SELECT * FROM students LIMIT 10"` |
| "Məktəbləri göstər" | `psql -c "SELECT * FROM schools"` |
| "İstifadəçiləri göstər" | `psql -c "SELECT id, username, role FROM users"` |
| "Neçə şagird var?" | `psql -c "SELECT COUNT(*) FROM students"` |
| "Neçə müəllim var?" | `psql -c "SELECT COUNT(*) FROM teachers"` |
| "Fənləri göstər" | `psql -c "SELECT * FROM subjects"` |
| "Bazanın ölçüsünü göstər" | `psql -c "SELECT pg_size_pretty(pg_database_size(current_database()))"` |
| "Migrasiyaları icra et" | `psql -f database/migrations/001_initial.sql` |

---

## 6. TEST VƏ DİAQNOSTİKA

| Nə deyirsiniz | Nə baş verir |
|---|---|
| "IRT testini icra et" | `Rscript tests/test_irt.R` |
| "CAT testini icra et" | `Rscript tests/test_cat.R` |
| "Baza testini icra et" | `Rscript tests/test_database.R` |
| "Bütün testləri icra et" | `Rscript tests/test_irt.R && Rscript tests/test_cat.R && Rscript tests/test_database.R` |
| "Port 3838 meşğuldur?" | `lsof -i:3838` |
| "R versiyasını göstər" | `R --version \| head -1` |
| "Python versiyasını göstər" | `python3 --version` |
| "Paketləri göstər" | `R -e "installed.packages()[,'Package']"` |
| "Disk sahəsini göstər" | `df -h .` |
| "Yaddaşı göstər" | `top -l 1 \| head -10` |

---

## 7. DEPLOYMENT

| Nə deyirsiniz | Nə baş verir |
|---|---|
| "ShinyApps-a deploy et" | `R -e "rsconnect::deployApp('.')"` |
| "Deploy statusunu göstər" | `R -e "rsconnect::showLogs()"` |
| "Docker build et" | `docker-compose build` |
| "Docker işə sal" | `docker-compose up -d` |
| "Docker dayandır" | `docker-compose down` |
| "Backup al" | `bash deploy/scripts/backup.sh` |

---

## 8. CLAUDE CODE

| Nə deyirsiniz | Nə baş verir |
|---|---|
| "Claude Code-u aç" | `cd ~/Desktop/Arti_2026 && claude` |
| "Claude Code-a de ki..." | Claude Code açılır + mesaj göndərilir |

---

## 9. AXTARIŞ

| Nə deyirsiniz | Nə baş verir |
|---|---|
| "Teacher sözünü axtar" | `grep -rn "teacher" modules/ --include="*.R"` |
| "SUBJECTS sabitini axtar" | `grep -rn "SUBJECTS" R/ modules/` |
| "db_query istifadəsini axtar" | `grep -rn "db_query" modules/ --include="*.R"` |
| "TODO-ları axtar" | `grep -rn "TODO\|FIXME\|HACK" . --include="*.R"` |
| "Xəta mesajlarını axtar" | `grep -rn "error\|Error\|ERROR" logs/` |

---

## 10. SİSTEM

| Nə deyirsiniz | Nə baş verir |
|---|---|
| "Salam" | Salamlaşma cavabı |
| "Necəsən?" | Status məlumatı |
| "Kömək" | Komanda siyahısı |
| "Çıxış" | Proqramdan çıxış |
| "Dayandır" | Proqramdan çıxış |
| "Tarix göstər" | `date` |
| "İnternet varmı?" | `ping -c 1 google.com` |

---

## QEYDLƏR

- **Mətn rejimi** daha etibarlıdır: `python3 main.py --text`
- **Səs rejimində** aydın danışın, arxa fon səsi olmasın
- Hər əmrdən əvvəl **təsdiq** soruşulur (y/n)
- **Təhlükəli əmrlər** avtomatik bloklanır (rm -rf, drop database və s.)
- Azərbaycan və İngilis hər ikisində danışa bilərsiniz