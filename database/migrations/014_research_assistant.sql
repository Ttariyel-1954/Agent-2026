-- =============================================
-- ARTI-2026: Tədqiqat AI Asistent — Miqrasiya
-- =============================================

-- 1. Tədqiqat AI sessiyaları
CREATE TABLE IF NOT EXISTS research_ai_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID REFERENCES research_projects(id) ON DELETE SET NULL,
    user_id UUID REFERENCES users(id),
    research_question TEXT NOT NULL,
    research_field VARCHAR(200),
    session_type VARCHAR(50) CHECK (session_type IN ('literature_review', 'methodology', 'analysis_plan', 'results_draft', 'full_pipeline')),
    status VARCHAR(30) DEFAULT 'active' CHECK (status IN ('active', 'completed', 'archived')),
    
    -- AI nəticələri (JSONB)
    literature_results JSONB,
    methodology_results JSONB,
    analysis_plan_results JSONB,
    results_draft_results JSONB,
    
    -- İstinad formatı
    citation_format VARCHAR(20) DEFAULT 'apa' CHECK (citation_format IN ('apa', 'harvard', 'vancouver', 'chicago')),
    
    -- AI istifadə statistikası
    total_tokens_used INTEGER DEFAULT 0,
    ai_model VARCHAR(50),
    
    -- Audit
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Ədəbiyyat bazası (AI tərəfindən tapılan və istifadəçi əlavə etdiyi mənbələr)
CREATE TABLE IF NOT EXISTS research_literature (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID REFERENCES research_ai_sessions(id) ON DELETE CASCADE,
    project_id UUID REFERENCES research_projects(id) ON DELETE SET NULL,
    
    -- Mənbə məlumatları
    title TEXT NOT NULL,
    authors TEXT,
    year INTEGER,
    journal VARCHAR(500),
    volume VARCHAR(50),
    issue VARCHAR(50),
    pages VARCHAR(50),
    doi VARCHAR(200),
    abstract TEXT,
    
    -- AI analiz
    relevance_score NUMERIC(3,2) CHECK (relevance_score >= 0 AND relevance_score <= 1),
    key_findings TEXT,
    methodology_used VARCHAR(200),
    sample_info VARCHAR(500),
    
    -- İstinad
    citation_apa TEXT,
    citation_harvard TEXT,
    
    -- Status
    is_verified BOOLEAN DEFAULT FALSE,
    source_type VARCHAR(50) DEFAULT 'ai_suggested' CHECK (source_type IN ('ai_suggested', 'manual', 'database')),
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- İndekslər
CREATE INDEX IF NOT EXISTS idx_research_ai_sessions_user ON research_ai_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_research_ai_sessions_project ON research_ai_sessions(project_id);
CREATE INDEX IF NOT EXISTS idx_research_ai_sessions_status ON research_ai_sessions(status);
CREATE INDEX IF NOT EXISTS idx_research_literature_session ON research_literature(session_id);
CREATE INDEX IF NOT EXISTS idx_research_literature_project ON research_literature(project_id);
CREATE INDEX IF NOT EXISTS idx_research_literature_year ON research_literature(year);
