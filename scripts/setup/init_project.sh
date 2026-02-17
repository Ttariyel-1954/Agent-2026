#!/bin/bash
# ============================================
# ARTI 2026 - Layihenin ilk qurashdirilmasi
# Bu skripti ishga salin: bash scripts/setup/init_project.sh
# ============================================

set -e

echo "============================================"
echo "  ARTI 2026 - Layihe Qurashdirilir..."
echo "============================================"
echo ""

# 1. Python virtual muhit
echo "[1/6] Python virtual muhit yaradilir..."
if [ ! -d "venv" ]; then
    python3 -m venv venv
    echo "  Virtual muhit yaradildi."
else
    echo "  Virtual muhit artiq movcuddur."
fi

# 2. Asililqlar
echo "[2/6] Python asililqlari qurashdirilir..."
source venv/bin/activate
pip install --quiet --upgrade pip
pip install --quiet -r requirements.txt
echo "  Asililqlar qurashdirildi."

# 3. Environment
echo "[3/6] Muhit deyishenleri hazirlanir..."
if [ ! -f ".env" ]; then
    cp .env.example .env
    echo "  .env fayli yaradildi. Zehmet olmasa redakte edin."
else
    echo "  .env fayli artiq movcuddur."
fi

# 4. Git
echo "[4/6] Git repozitoriyasi hazirlanir..."
if [ ! -d ".git" ]; then
    git init
    git add .gitignore
    git commit -m "Initial commit - ARTI 2026"
    echo "  Git repozitoriyasi yaradildi."
else
    echo "  Git repozitoriyasi artiq movcuddur."
fi

# 5. Verilener bazasi
echo "[5/6] Docker xidmetleri yoxlanilir..."
if command -v docker &> /dev/null; then
    echo "  Docker movcuddur."
    echo "  Verilener bazasini ishga salmaq ucun: docker-compose up -d postgresql redis"
else
    echo "  Docker qurashdirilmayib. Sonra qurashdirilmalidir."
fi

# 6. Yekun
echo "[6/6] Qurashditma yekunda..."
echo ""
echo "============================================"
echo "  ARTI 2026 ugurla qurashdirildi!"
echo "============================================"
echo ""
echo "  Novbeti addimlar:"
echo "    1. .env faylini redakte edin"
echo "    2. docker-compose up -d postgresql redis"
echo "    3. make dev  (development server)"
echo "    4. make agent (AI Agent)"
echo ""
echo "  Komekchi komandalar: make help"
echo "============================================"
