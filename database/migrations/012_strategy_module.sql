-- =============================================
-- Migration 012: Strategiya Modulu
-- Tarix: 2026-02-20
-- Təsvir: Strateji hesabatlar, what-if scenari,
--          beynəlxalq benchmark cədvəlləri
-- =============================================

BEGIN;

-- === 1. Strateji Hesabatlar ===
CREATE TABLE IF NOT EXISTS strategy_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_type VARCHAR(50) NOT NULL CHECK (report_type IN (
        'swot', 'resource_allocation', 'teacher_optimization',
        'budget_priority', 'comprehensive'
    )),
    school_id UUID REFERENCES schools(id) ON DELETE SET NULL,
    academic_year VARCHAR(20) NOT NULL DEFAULT '2025-2026',
    title VARCHAR(300),
    report_json JSONB NOT NULL,
    summary TEXT,
    ai_model VARCHAR(50),
    tokens_used INTEGER,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_strategy_reports_school
    ON strategy_reports(school_id);
CREATE INDEX IF NOT EXISTS idx_strategy_reports_type
    ON strategy_reports(report_type);
CREATE INDEX IF NOT EXISTS idx_strategy_reports_year
    ON strategy_reports(academic_year);

-- === 2. What-If Scenari Nəticələri ===
CREATE TABLE IF NOT EXISTS strategy_scenarios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    scenario_name VARCHAR(300) NOT NULL,
    scenario_type VARCHAR(50) NOT NULL CHECK (scenario_type IN (
        'teacher_hire', 'budget_change', 'class_restructure',
        'resource_realloc', 'policy_change', 'custom'
    )),
    school_id UUID REFERENCES schools(id) ON DELETE SET NULL,
    parameters JSONB NOT NULL,
    baseline_data JSONB,
    predicted_outcomes JSONB,
    impact_score NUMERIC(5,2),
    risk_level VARCHAR(20) CHECK (risk_level IN ('low', 'medium', 'high')),
    ai_model VARCHAR(50),
    tokens_used INTEGER,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_strategy_scenarios_type
    ON strategy_scenarios(scenario_type);
CREATE INDEX IF NOT EXISTS idx_strategy_scenarios_school
    ON strategy_scenarios(school_id);

-- === 3. Beynəlxalq Benchmark Məlumatları ===
CREATE TABLE IF NOT EXISTS strategy_benchmarks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    country VARCHAR(100) NOT NULL,
    indicator VARCHAR(100) NOT NULL,
    indicator_category VARCHAR(50) CHECK (indicator_category IN (
        'pisa', 'talis', 'education_system', 'resource', 'outcome'
    )),
    value NUMERIC(10,2),
    year INTEGER NOT NULL,
    source VARCHAR(200),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(country, indicator, year)
);

CREATE INDEX IF NOT EXISTS idx_strategy_benchmarks_country
    ON strategy_benchmarks(country);
CREATE INDEX IF NOT EXISTS idx_strategy_benchmarks_indicator
    ON strategy_benchmarks(indicator);

COMMIT;
