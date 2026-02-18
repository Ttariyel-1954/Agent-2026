-- =============================================
-- ARTI-2026: Müəllim Genişləndirilmiş Göstəriciləri
-- Miqrasiya 006: TALIS/PISA/OECD göstəriciləri
-- =============================================

BEGIN;

-- =============================================
-- 1. teachers cədvəlinə yeni sütunlar
-- =============================================
ALTER TABLE teachers ADD COLUMN IF NOT EXISTS honorary_title VARCHAR(255);
ALTER TABLE teachers ADD COLUMN IF NOT EXISTS certification_score NUMERIC(5,2);
ALTER TABLE teachers ADD COLUMN IF NOT EXISTS certification_date DATE;
ALTER TABLE teachers ADD COLUMN IF NOT EXISTS ict_competency_level VARCHAR(30);
ALTER TABLE teachers ADD COLUMN IF NOT EXISTS mentoring_status VARCHAR(30) DEFAULT 'none';
ALTER TABLE teachers ADD COLUMN IF NOT EXISTS research_publications_count INTEGER DEFAULT 0;
ALTER TABLE teachers ADD COLUMN IF NOT EXISTS national_registry_id VARCHAR(50);

-- Yoxlama məhdudiyyətləri
ALTER TABLE teachers ADD CONSTRAINT chk_certification_score
    CHECK (certification_score IS NULL OR (certification_score >= 0 AND certification_score <= 100));

ALTER TABLE teachers ADD CONSTRAINT chk_ict_competency_level
    CHECK (ict_competency_level IS NULL OR ict_competency_level IN ('başlanğıc', 'orta', 'irəliləmiş', 'ekspert'));

ALTER TABLE teachers ADD CONSTRAINT chk_mentoring_status
    CHECK (mentoring_status IN ('mentor', 'mentee', 'both', 'none'));

-- =============================================
-- 2. teacher_awards — Mükafatlar cədvəli
-- =============================================
CREATE TABLE IF NOT EXISTS teacher_awards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    teacher_id UUID NOT NULL REFERENCES teachers(id) ON DELETE CASCADE,
    title VARCHAR(500) NOT NULL,
    awarding_body VARCHAR(255) NOT NULL,
    award_type VARCHAR(50) NOT NULL,
    award_date DATE NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_teacher_awards_teacher ON teacher_awards(teacher_id);
CREATE INDEX idx_teacher_awards_date ON teacher_awards(award_date);

-- =============================================
-- 3. teacher_talis_indicators — TALIS göstəriciləri
-- =============================================
CREATE TABLE IF NOT EXISTS teacher_talis_indicators (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    teacher_id UUID NOT NULL REFERENCES teachers(id) ON DELETE CASCADE,
    assessment_year VARCHAR(9) NOT NULL,

    -- Öz-effektivlik və məmnuniyyət (1-10 şkala)
    self_efficacy NUMERIC(4,2),
    job_satisfaction NUMERIC(4,2),
    classroom_management NUMERIC(4,2),

    -- Peşəkar inkişaf
    cpd_hours INTEGER DEFAULT 0,
    cpd_impact_score NUMERIC(4,2),
    collaboration_score NUMERIC(4,2),
    team_teaching_hours INTEGER DEFAULT 0,

    -- Şagird nəticələri
    student_avg_score NUMERIC(5,2),
    student_pass_rate NUMERIC(5,2),
    value_added_score NUMERIC(5,2),

    -- İKT istifadəsi
    ict_usage_frequency VARCHAR(30),
    digital_content_count INTEGER DEFAULT 0,

    -- İnklüziv təhsil
    inclusive_education_training BOOLEAN DEFAULT FALSE,
    special_needs_student_count INTEGER DEFAULT 0,

    -- Həftəlik yük bölgüsü (saatlarla)
    weekly_teaching_hours NUMERIC(4,1),
    weekly_admin_hours NUMERIC(4,1),
    weekly_preparation_hours NUMERIC(4,1),

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(teacher_id, assessment_year)
);

CREATE INDEX idx_talis_teacher ON teacher_talis_indicators(teacher_id);
CREATE INDEX idx_talis_year ON teacher_talis_indicators(assessment_year);

-- =============================================
-- 4. teacher_publications — Nəşrlər cədvəli
-- =============================================
CREATE TABLE IF NOT EXISTS teacher_publications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    teacher_id UUID NOT NULL REFERENCES teachers(id) ON DELETE CASCADE,
    title VARCHAR(500) NOT NULL,
    publication_type VARCHAR(50) NOT NULL,
    journal_name VARCHAR(255),
    publication_date DATE,
    doi VARCHAR(100),
    is_peer_reviewed BOOLEAN DEFAULT FALSE,
    co_authors TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_teacher_publications_teacher ON teacher_publications(teacher_id);
CREATE INDEX idx_teacher_publications_type ON teacher_publications(publication_type);

COMMIT;
