#!/bin/bash
# ═══════════════════════════════════════════════════
# ARTI-2026: DEMO REJİM DÜZƏLİŞ SKRİPTİ
# Bu skript DB olmadan tətbiqin işləməsini təmin edir
# ═══════════════════════════════════════════════════

cd ~/Desktop/Arti_2026 || { echo "XƏTA: Arti_2026 qovluğu tapılmadı!"; exit 1; }

echo "══════════════════════════════════════"
echo "  ARTI-2026 DEMO REJİM DÜZƏLİŞİ"
echo "══════════════════════════════════════"

# 1. Tətbiqi dayandır
echo ""
echo "[1/5] Tətbiq dayandırılır..."
lsof -ti:3838 2>/dev/null | xargs kill -9 2>/dev/null
echo "  ✓ Port 3838 azad edildi"

# 2. safe_query funksiyalarını R/db_connection.R-a əlavə et
echo ""
echo "[2/5] safe_query funksiyaları əlavə edilir..."

# Əvvəlcə artıq əlavə olunubmu yoxla
if grep -q "safe_query" R/db_connection.R 2>/dev/null; then
  echo "  ✓ safe_query artıq mövcuddur"
else
  cat >> R/db_connection.R << 'RCODE'

# ═══ DEMO REJİM: NULL-safe DB funksiyaları ═══
safe_query <- function(pool, query, params = NULL) {
  if (is.null(pool)) return(data.frame())
  tryCatch({
    if (is.null(params)) pool::dbGetQuery(pool, query)
    else pool::dbGetQuery(pool, query, params = params)
  }, error = function(e) {
    log_error(paste("Sorgu xetasi:", e$message))
    data.frame()
  })
}

safe_execute <- function(pool, query, params = NULL) {
  if (is.null(pool)) return(0)
  tryCatch({
    if (is.null(params)) pool::dbExecute(pool, query)
    else pool::dbExecute(pool, query, params = params)
  }, error = function(e) {
    log_error(paste("Icra xetasi:", e$message))
    0
  })
}
RCODE
  echo "  ✓ safe_query və safe_execute əlavə edildi"
fi

# 3. Bütün modullarda dbGetQuery → safe_query
echo ""
echo "[3/5] dbGetQuery → safe_query əvəzləmə..."
COUNT=0
for f in $(grep -rl "dbGetQuery(" modules/ ai_integration/ R/utils.R R/auth.R R/constants.R 2>/dev/null --include="*.R"); do
  # db_connection.R-a toxunma
  if [[ "$f" == *"db_connection.R"* ]]; then
    continue
  fi
  sed -i '' 's/dbGetQuery(/safe_query(/g' "$f" 2>/dev/null || sed -i 's/dbGetQuery(/safe_query(/g' "$f" 2>/dev/null
  COUNT=$((COUNT + 1))
done
echo "  ✓ $COUNT faylda dbGetQuery əvəz edildi"

COUNT=0
for f in $(grep -rl "dbExecute(" modules/ ai_integration/ 2>/dev/null --include="*.R"); do
  if [[ "$f" == *"db_connection.R"* ]]; then
    continue
  fi
  sed -i '' 's/dbExecute(/safe_execute(/g' "$f" 2>/dev/null || sed -i 's/dbExecute(/safe_execute(/g' "$f" 2>/dev/null
  COUNT=$((COUNT + 1))
done
echo "  ✓ $COUNT faylda dbExecute əvəz edildi"

# 4. app.R-da poolClose düzəlişi
echo ""
echo "[4/5] poolClose(NULL) düzəldilir..."
if grep -q "if (!is.null(db_pool)) poolClose" app.R 2>/dev/null; then
  echo "  ✓ poolClose artıq düzəldilibdir"
else
  sed -i '' 's/poolClose(db_pool)/if (!is.null(db_pool)) poolClose(db_pool)/g' app.R 2>/dev/null || \
  sed -i 's/poolClose(db_pool)/if (!is.null(db_pool)) poolClose(db_pool)/g' app.R 2>/dev/null
  echo "  ✓ poolClose düzəldildi"
fi

# 5. format() big.mark düzəlişi
echo ""
echo "[5/5] format() big.mark düzəldilir..."
for f in $(grep -rl 'big.mark = "\\."' app.R modules/ 2>/dev/null --include="*.R"); do
  sed -i '' 's/big\.mark = "\\."/big.mark = ","/g' "$f" 2>/dev/null || \
  sed -i 's/big\.mark = "\\."/big.mark = ","/g' "$f" 2>/dev/null
done
echo "  ✓ big.mark düzəldildi"

# Nəticə
echo ""
echo "══════════════════════════════════════"
echo "  BÜTÜN DÜZƏLİŞLƏR TAMAMLANDI!"
echo "══════════════════════════════════════"
echo ""
echo "Yoxlama:"
echo "  safe_query: $(grep -c 'safe_query' R/db_connection.R) dəfə db_connection.R-da"
echo "  Modullarda safe_query: $(grep -rl 'safe_query(' modules/ 2>/dev/null | wc -l | tr -d ' ') faylda"
echo ""
echo "İndi tətbiqi başladın:"
echo "  R -e \"shiny::runApp('.', port=3838, host='0.0.0.0')\""
echo ""
