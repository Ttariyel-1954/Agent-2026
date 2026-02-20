-- =============================================
-- 009: FİP (Fərdi İnkişaf Planı) Genişləndirmə
-- Tarix: 2026-02-20
-- AI əsaslı fərdi inkişaf planı sistemi
-- =============================================

BEGIN;

-- 1. AI generasiya olunan tam planlar
CREATE TABLE IF NOT EXISTS idp_ai_plans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    academic_year VARCHAR(9) NOT NULL,
    plan_json JSONB NOT NULL,
    overall_assessment TEXT,
    overall_level VARCHAR(20) CHECK (overall_level IN ('əla', 'yaxşı', 'kafi', 'qeyri-kafi')),
    parent_summary TEXT,
    generation_number INTEGER DEFAULT 1,
    tokens_used INTEGER DEFAULT 0,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'superseded', 'archived')),
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_idp_ai_plans_student ON idp_ai_plans(student_id, academic_year);
CREATE INDEX idx_idp_ai_plans_status ON idp_ai_plans(status);

-- 2. Fənn üzrə bacarıq cache
CREATE TABLE IF NOT EXISTS idp_ability_profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    subject_id UUID REFERENCES subjects(id),
    subject_name VARCHAR(100),
    academic_year VARCHAR(9) NOT NULL,
    avg_score NUMERIC(5,2),
    min_score NUMERIC(5,2),
    max_score NUMERIC(5,2),
    grade_count INTEGER DEFAULT 0,
    theta_estimate NUMERIC(6,4),
    theta_se NUMERIC(6,4),
    trend_direction VARCHAR(10) CHECK (trend_direction IN ('up', 'down', 'stable')),
    trend_slope NUMERIC(8,4),
    ability_level VARCHAR(20) CHECK (ability_level IN ('əla', 'yaxşı', 'kafi', 'qeyri-kafi')),
    attendance_rate NUMERIC(5,2),
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(student_id, subject_id, academic_year)
);

CREATE INDEX idx_idp_ability_student ON idp_ability_profiles(student_id, academic_year);

-- 3. Həftəlik tapşırıqlar
CREATE TABLE IF NOT EXISTS idp_weekly_tasks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    plan_id UUID NOT NULL REFERENCES idp_ai_plans(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    subject_id UUID REFERENCES subjects(id),
    subject_name VARCHAR(100),
    week_number INTEGER NOT NULL,
    week_start DATE,
    task_title TEXT NOT NULL,
    task_description TEXT,
    task_type VARCHAR(30) DEFAULT 'practice' CHECK (task_type IN ('practice', 'reading', 'project', 'research', 'review', 'test')),
    estimated_minutes INTEGER DEFAULT 30,
    is_completed BOOLEAN DEFAULT FALSE,
    completed_at TIMESTAMP,
    teacher_feedback TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_idp_tasks_plan ON idp_weekly_tasks(plan_id);
CREATE INDEX idx_idp_tasks_student ON idp_weekly_tasks(student_id, week_number);

-- 4. Müəllim tövsiyələri
CREATE TABLE IF NOT EXISTS idp_teacher_recommendations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    teacher_id UUID REFERENCES teachers(id),
    subject_id UUID REFERENCES subjects(id),
    subject_name VARCHAR(100),
    academic_year VARCHAR(9) NOT NULL,
    recommendation_text TEXT NOT NULL,
    recommendation_type VARCHAR(30) DEFAULT 'general' CHECK (recommendation_type IN ('general', 'academic', 'behavioral', 'resource', 'parent_meeting')),
    priority VARCHAR(10) DEFAULT 'medium' CHECK (priority IN ('high', 'medium', 'low')),
    is_ai_generated BOOLEAN DEFAULT FALSE,
    plan_id UUID REFERENCES idp_ai_plans(id) ON DELETE SET NULL,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'completed', 'dismissed')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_idp_recs_student ON idp_teacher_recommendations(student_id, academic_year);

-- 5. Valideyn hesabat snapshot-ları
CREATE TABLE IF NOT EXISTS idp_parent_reports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    academic_year VARCHAR(9) NOT NULL,
    report_month INTEGER NOT NULL CHECK (report_month BETWEEN 1 AND 12),
    report_json JSONB,
    summary_text TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(student_id, academic_year, report_month)
);

CREATE INDEX idx_idp_parent_reports_student ON idp_parent_reports(student_id, academic_year);

COMMIT;
