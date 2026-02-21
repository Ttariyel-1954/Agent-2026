-- =============================================
-- 011: Müəllim AI Mentor Sistemi
-- Tarix: 2026-02-20
-- TALIS əsaslı zəif sahə aşkarlanması, AI mentor
-- tövsiyələri, irəliləyiş izləmə, attestasiya planı
-- =============================================

BEGIN;

-- 1. AI Mentor Həftəlik Tövsiyələr
CREATE TABLE IF NOT EXISTS teacher_mentor_recommendations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    teacher_id UUID NOT NULL REFERENCES teachers(id) ON DELETE CASCADE,
    week_start DATE NOT NULL,
    weak_area VARCHAR(100) NOT NULL,
    weak_area_score NUMERIC(4,2),
    oecd_benchmark NUMERIC(4,2),
    recommendation_text TEXT NOT NULL,
    strategy_type VARCHAR(50) DEFAULT 'general'
        CHECK (strategy_type IN ('classroom_management', 'teaching_method', 'ict_integration',
               'assessment', 'collaboration', 'professional_dev', 'inclusive', 'general')),
    priority VARCHAR(10) DEFAULT 'medium' CHECK (priority IN ('high', 'medium', 'low')),
    is_completed BOOLEAN DEFAULT FALSE,
    completed_at TIMESTAMP,
    teacher_feedback TEXT,
    feedback_rating INTEGER CHECK (feedback_rating IS NULL OR (feedback_rating >= 1 AND feedback_rating <= 5)),
    tokens_used INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(teacher_id, week_start, weak_area)
);

CREATE INDEX idx_mentor_rec_teacher ON teacher_mentor_recommendations(teacher_id);
CREATE INDEX idx_mentor_rec_week ON teacher_mentor_recommendations(week_start);
CREATE INDEX idx_mentor_rec_area ON teacher_mentor_recommendations(weak_area);

-- 2. Resurs Tövsiyələri (video, məqalə, kurs)
CREATE TABLE IF NOT EXISTS teacher_mentor_resources (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    recommendation_id UUID REFERENCES teacher_mentor_recommendations(id) ON DELETE CASCADE,
    teacher_id UUID NOT NULL REFERENCES teachers(id) ON DELETE CASCADE,
    resource_type VARCHAR(30) NOT NULL
        CHECK (resource_type IN ('video', 'article', 'course', 'book', 'webinar', 'tool')),
    title VARCHAR(500) NOT NULL,
    description TEXT,
    url TEXT,
    source VARCHAR(200),
    domain VARCHAR(100),
    estimated_minutes INTEGER,
    is_viewed BOOLEAN DEFAULT FALSE,
    viewed_at TIMESTAMP,
    rating INTEGER CHECK (rating IS NULL OR (rating >= 1 AND rating <= 5)),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_mentor_res_teacher ON teacher_mentor_resources(teacher_id);
CREATE INDEX idx_mentor_res_rec ON teacher_mentor_resources(recommendation_id);

-- 3. İrəliləyiş İzləmə
CREATE TABLE IF NOT EXISTS teacher_progress_tracking (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    teacher_id UUID NOT NULL REFERENCES teachers(id) ON DELETE CASCADE,
    tracking_date DATE NOT NULL DEFAULT CURRENT_DATE,
    area VARCHAR(100) NOT NULL,
    previous_score NUMERIC(4,2),
    current_score NUMERIC(4,2),
    target_score NUMERIC(4,2),
    change_pct NUMERIC(5,2),
    assessment_year VARCHAR(9),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_progress_teacher ON teacher_progress_tracking(teacher_id);
CREATE INDEX idx_progress_date ON teacher_progress_tracking(tracking_date);

-- 4. Attestasiya Hazırlıq Planı
CREATE TABLE IF NOT EXISTS teacher_attestation_plans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    teacher_id UUID NOT NULL REFERENCES teachers(id) ON DELETE CASCADE,
    target_category VARCHAR(50) NOT NULL,
    current_category VARCHAR(50),
    plan_json JSONB NOT NULL,
    total_weeks INTEGER DEFAULT 12,
    start_date DATE NOT NULL DEFAULT CURRENT_DATE,
    target_date DATE,
    current_readiness NUMERIC(5,2) DEFAULT 0,
    status VARCHAR(20) DEFAULT 'active'
        CHECK (status IN ('active', 'completed', 'paused', 'cancelled')),
    tokens_used INTEGER DEFAULT 0,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_attestation_teacher ON teacher_attestation_plans(teacher_id);
CREATE INDEX idx_attestation_status ON teacher_attestation_plans(status);

COMMIT;
