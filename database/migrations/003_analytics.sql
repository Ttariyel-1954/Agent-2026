-- =============================================
-- Miqrasiya 003: Analitika və Əlavə Modullar
-- Tarix: 2026-01-25
-- Təsvir: Analitika, FİP, cədvəl, təlim cədvəlləri
-- =============================================

BEGIN;

-- Müəllim Cədvəli
CREATE TABLE IF NOT EXISTS teacher_schedule (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    teacher_id UUID REFERENCES teachers(id) ON DELETE CASCADE,
    class_id UUID REFERENCES classes(id) ON DELETE CASCADE,
    subject_id UUID REFERENCES subjects(id),
    day_of_week INTEGER CHECK (day_of_week BETWEEN 1 AND 5),
    period INTEGER CHECK (period BETWEEN 1 AND 7),
    room VARCHAR(20),
    academic_year VARCHAR(9) NOT NULL,
    UNIQUE(teacher_id, day_of_week, period, academic_year)
);

-- Müəllim Təlimləri
CREATE TABLE IF NOT EXISTS teacher_trainings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    teacher_id UUID REFERENCES teachers(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    provider VARCHAR(255),
    training_type VARCHAR(50),
    start_date DATE,
    end_date DATE,
    hours INTEGER,
    certificate_number VARCHAR(100),
    status VARCHAR(20) DEFAULT 'completed',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Müəllim Qiymətləndirmələri
CREATE TABLE IF NOT EXISTS teacher_evaluations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    teacher_id UUID REFERENCES teachers(id) ON DELETE CASCADE,
    evaluator_id UUID REFERENCES users(id),
    evaluation_date DATE DEFAULT CURRENT_DATE,
    academic_year VARCHAR(9),
    teaching_quality NUMERIC(3,1),
    student_engagement NUMERIC(3,1),
    professional_development NUMERIC(3,1),
    communication NUMERIC(3,1),
    innovation NUMERIC(3,1),
    overall_score NUMERIC(3,1),
    comments TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Fərdi İnkişaf Planı
CREATE TABLE IF NOT EXISTS individual_plans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id UUID REFERENCES students(id) ON DELETE CASCADE,
    subject_id UUID REFERENCES subjects(id),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    target_score NUMERIC(5,2),
    current_score NUMERIC(5,2),
    start_date DATE,
    end_date DATE,
    status VARCHAR(20) DEFAULT 'active',
    progress NUMERIC(5,2) DEFAULT 0,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS plan_notes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    plan_id UUID REFERENCES individual_plans(id) ON DELETE CASCADE,
    note TEXT NOT NULL,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Qiymət Komponentləri
CREATE TABLE IF NOT EXISTS grade_components (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    grade_id UUID REFERENCES grades(id) ON DELETE CASCADE,
    component_name VARCHAR(100),
    max_score NUMERIC(5,2),
    achieved_score NUMERIC(5,2),
    weight NUMERIC(3,2) DEFAULT 1.0
);

-- Sessiyalar
CREATE TABLE IF NOT EXISTS user_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    token TEXT NOT NULL,
    ip_address VARCHAR(45),
    user_agent TEXT,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Login cəhdləri
CREATE TABLE IF NOT EXISTS login_attempts (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50),
    ip_address VARCHAR(45),
    success BOOLEAN DEFAULT FALSE,
    attempted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Analitika: Performans Anlıq Görüntüsü (Materialized View)
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_student_performance AS
SELECT
    s.id AS student_id,
    s.first_name,
    s.last_name,
    s.class_id,
    c.grade,
    c.section,
    s.school_id,
    COUNT(DISTINCT g.id) AS total_grades,
    AVG(g.score) AS avg_score,
    MIN(g.score) AS min_score,
    MAX(g.score) AS max_score,
    CASE
        WHEN AVG(g.score) >= 86 THEN 'Əla'
        WHEN AVG(g.score) >= 71 THEN 'Yaxşı'
        WHEN AVG(g.score) >= 51 THEN 'Kafi'
        ELSE 'Qeyri-kafi'
    END AS grade_label
FROM students s
LEFT JOIN classes c ON s.class_id = c.id
LEFT JOIN grades g ON g.student_id = s.id
WHERE s.status = 'active'
GROUP BY s.id, s.first_name, s.last_name, s.class_id, c.grade, c.section, s.school_id;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_student_perf ON mv_student_performance(student_id);

-- Analitika: Davamiyyət Xülasəsi
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_attendance_summary AS
SELECT
    s.id AS student_id,
    s.first_name,
    s.last_name,
    s.class_id,
    COUNT(*) AS total_records,
    COUNT(*) FILTER (WHERE a.status = 'iştirak') AS present_count,
    COUNT(*) FILTER (WHERE a.status = 'qayıb') AS absent_count,
    COUNT(*) FILTER (WHERE a.status = 'gecikmə') AS late_count,
    COUNT(*) FILTER (WHERE a.status = 'icazəli') AS excused_count,
    ROUND(
        COUNT(*) FILTER (WHERE a.status = 'iştirak')::NUMERIC / NULLIF(COUNT(*), 0) * 100, 1
    ) AS attendance_rate
FROM students s
LEFT JOIN attendance a ON a.student_id = s.id
WHERE s.status = 'active'
GROUP BY s.id, s.first_name, s.last_name, s.class_id;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_attendance ON mv_attendance_summary(student_id);

-- Əlavə indekslər
CREATE INDEX IF NOT EXISTS idx_teacher_schedule_teacher ON teacher_schedule(teacher_id);
CREATE INDEX IF NOT EXISTS idx_teacher_schedule_class ON teacher_schedule(class_id);
CREATE INDEX IF NOT EXISTS idx_teacher_subjects_teacher ON teacher_subjects(teacher_id);
CREATE INDEX IF NOT EXISTS idx_individual_plans_student ON individual_plans(student_id);
CREATE INDEX IF NOT EXISTS idx_grades_type ON grades(grade_type);
CREATE INDEX IF NOT EXISTS idx_grades_academic_year ON grades(academic_year);

INSERT INTO schema_migrations (version, description) VALUES ('003', 'Analitika və əlavə modullar');

COMMIT;
