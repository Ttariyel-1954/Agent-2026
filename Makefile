# ============================================
# ARTI 2026 - Makefile
# Butun emeliyyatlar ucun sadeleşdirilmish komandalar
# ============================================

.PHONY: help setup dev test deploy clean

# Default
help:
	@echo "============================================"
	@echo "  ARTI 2026 - Movcud Komandalar"
	@echo "============================================"
	@echo ""
	@echo "  make setup        - Ilk qurashditma"
	@echo "  make dev          - Development muhitini ishga sal"
	@echo "  make test         - Butun testleri ishga sal"
	@echo "  make migrate      - DB migrasiglari ishga sal"
	@echo "  make seed         - Numune melumatlari yukle"
	@echo "  make agent        - AI Agenti ishga sal"
	@echo "  make cat-demo     - CAT demo ishga sal"
	@echo "  make mst-demo     - MST demo ishga sal"
	@echo "  make exam-demo    - Imtahan demo ishga sal"
	@echo "  make docker-up    - Docker xidmetlerini ishga sal"
	@echo "  make docker-down  - Docker xidmetlerini dayandgr"
	@echo "  make backup       - Ehtiyat nusxe yarat"
	@echo "  make monitor      - Monitorinq panelini ach"
	@echo "  make clean        - Temizle"
	@echo "  make deploy       - Istehsala yerlesdir"
	@echo ""

# Ilk qurashditma
setup:
	python -m venv venv
	. venv/bin/activate && pip install -r requirements.txt
	cp .env.example .env
	@echo "Qurashditma tamamlandi. .env faylini redakte edin."

# Development muhiti
dev:
	docker-compose up -d postgresql redis mongodb
	. venv/bin/activate && python -m uvicorn infrastructure.api.gateway.main:app --reload --port 8000

# AI Agent
agent:
	. venv/bin/activate && python -m agent.core.main

# Testler
test:
	. venv/bin/activate && pytest tests/ -v --cov=. --cov-report=html

# Migrasiglar
migrate:
	. venv/bin/activate && alembic upgrade head

# Numune melumatlar
seed:
	. venv/bin/activate && python scripts/data_tools/seed_database.py

# CAT Demo
cat-demo:
	. venv/bin/activate && python modules/assessment/cat/engine/cat_engine.py

# MST Demo
mst-demo:
	. venv/bin/activate && python modules/assessment/mst/engine/mst_engine.py

# Imtahan Demo
exam-demo:
	. venv/bin/activate && python modules/certification/recruitment_exams/exam_engine/exam_runner.py

# Docker
docker-up:
	docker-compose up -d
	@echo "Butun xidmetler ishe dushdu."

docker-down:
	docker-compose down
	@echo "Butun xidmetler dayandirildgi."

# Ehtiyat nusxe
backup:
	bash scripts/maintenance/backup.sh

# Monitorinq
monitor:
	@echo "Grafana: http://localhost:3000"
	@echo "Prometheus: http://localhost:9090"
	open http://localhost:3000

# Temizleme
clean:
	find . -type d -name __pycache__ -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete
	rm -rf .pytest_cache htmlcov .coverage

# Deploy
deploy:
	bash scripts/deploy/production.sh
