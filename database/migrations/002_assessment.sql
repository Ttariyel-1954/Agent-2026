-- =============================================
-- Miqrasiya 002: Qiymətləndirmə Modulu
-- Tarix: 2026-01-20
-- Təsvir: IRT/CAT/MST cədvəlləri
-- =============================================

BEGIN;

-- Kurikulum Standartları
CREATE TABLE IF NOT EXISTS curriculum_standards (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    subject_id UUID REFERENCES subjects(id),
    grade INTEGER CHECK (grade BETWEEN 1 AND 11),
    code VARCHAR(30) NOT NULL,
    description TEXT NOT NULL,
    bloom_level VARCHAR(30),
    dok_level INTEGER CHECK (dok_level BETWEEN 1 AND 4),
    is_core BOOLEAN DEFAULT TRUE,
    parent_standard_id UUID REFERENCES curriculum_standards(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(subject_id, grade, code)
);

-- Sual Bankı
CREATE TABLE IF NOT EXISTS items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    subject_id UUID REFERENCES subjects(id),
    grade_level INTEGER CHECK (grade_level BETWEEN 1 AND 11),
    question_text TEXT NOT NULL,
    question_type VARCHAR(20) CHECK (question_type IN ('mcq', 'true_false', 'short_answer', 'essay', 'matching')),
    option_a TEXT,
    option_b TEXT,
    option_c TEXT,
    option_d TEXT,
    option_e TEXT,
    correct_answer VARCHAR(5) NOT NULL,
    difficulty VARCHAR(20),
    bloom_level VARCHAR(30),
    dok_level INTEGER CHECK (dok_level BETWEEN 1 AND 4),
    irt_a NUMERIC(6,4) DEFAULT 1.0,
    irt_b NUMERIC(6,4) DEFAULT 0.0,
    irt_c NUMERIC(6,4) DEFAULT 0.2,
    irt_model VARCHAR(5) DEFAULT '3PL',
    times_used INTEGER DEFAULT 0,
    p_value NUMERIC(5,4),
    rpbis NUMERIC(5,4),
    is_active BOOLEAN DEFAULT TRUE,
    is_calibrated BOOLEAN DEFAULT FALSE,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Standart-Sual Uyğunluğu
CREATE TABLE IF NOT EXISTS assessment_alignment (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    item_id UUID REFERENCES items(id) ON DELETE CASCADE,
    standard_id UUID REFERENCES curriculum_standards(id) ON DELETE CASCADE,
    dok_level INTEGER CHECK (dok_level BETWEEN 1 AND 4),
    alignment_strength NUMERIC(3,2) DEFAULT 1.0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(item_id, standard_id)
);

-- Testlər
CREATE TABLE IF NOT EXISTS tests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(255) NOT NULL,
    subject_id UUID REFERENCES subjects(id),
    class_id UUID REFERENCES classes(id),
    teacher_id UUID REFERENCES teachers(id),
    test_type VARCHAR(20) CHECK (test_type IN ('cat', 'mst', 'fixed', 'practice')),
    time_limit_minutes INTEGER,
    max_items INTEGER,
    is_active BOOLEAN DEFAULT TRUE,
    start_date TIMESTAMP,
    end_date TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Test Sualları
CREATE TABLE IF NOT EXISTS test_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    test_id UUID REFERENCES tests(id) ON DELETE CASCADE,
    item_id UUID REFERENCES items(id),
    item_order INTEGER,
    module_id VARCHAR(20),
    stage INTEGER,
    UNIQUE(test_id, item_id)
);

-- Test Sessiyaları
CREATE TABLE IF NOT EXISTS test_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    test_id UUID REFERENCES tests(id),
    student_id UUID REFERENCES students(id),
    start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    end_time TIMESTAMP,
    status VARCHAR(20) DEFAULT 'in_progress',
    theta_estimate NUMERIC(6,4),
    se_estimate NUMERIC(6,4),
    total_score NUMERIC(5,2),
    items_administered INTEGER DEFAULT 0,
    current_module VARCHAR(20),
    current_stage INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Cavablar
CREATE TABLE IF NOT EXISTS test_responses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID REFERENCES test_sessions(id) ON DELETE CASCADE,
    item_id UUID REFERENCES items(id),
    response VARCHAR(5),
    is_correct BOOLEAN,
    response_time_seconds INTEGER,
    theta_after NUMERIC(6,4),
    se_after NUMERIC(6,4),
    item_order INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- IRT Kalibrasiya Tarixçəsi
CREATE TABLE IF NOT EXISTS irt_calibration_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    item_id UUID REFERENCES items(id) ON DELETE CASCADE,
    calibration_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    sample_size INTEGER,
    model VARCHAR(5),
    old_a NUMERIC(6,4),
    old_b NUMERIC(6,4),
    old_c NUMERIC(6,4),
    new_a NUMERIC(6,4),
    new_b NUMERIC(6,4),
    new_c NUMERIC(6,4),
    fit_statistic NUMERIC(8,4),
    notes TEXT
);

-- Exposure Control
CREATE TABLE IF NOT EXISTS item_exposure (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    item_id UUID REFERENCES items(id) ON DELETE CASCADE,
    test_id UUID REFERENCES tests(id),
    exposure_rate NUMERIC(5,4) DEFAULT 0,
    control_parameter NUMERIC(5,4) DEFAULT 1.0,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(item_id, test_id)
);

-- Qiymətləndirmə indeksləri
CREATE INDEX IF NOT EXISTS idx_items_subject ON items(subject_id);
CREATE INDEX IF NOT EXISTS idx_items_irt_b ON items(irt_b);
CREATE INDEX IF NOT EXISTS idx_items_active ON items(is_active);
CREATE INDEX IF NOT EXISTS idx_test_sessions_student ON test_sessions(student_id);
CREATE INDEX IF NOT EXISTS idx_test_sessions_status ON test_sessions(status);
CREATE INDEX IF NOT EXISTS idx_test_responses_session ON test_responses(session_id);
CREATE INDEX IF NOT EXISTS idx_curriculum_subject_grade ON curriculum_standards(subject_id, grade);
CREATE INDEX IF NOT EXISTS idx_alignment_item ON assessment_alignment(item_id);
CREATE INDEX IF NOT EXISTS idx_alignment_standard ON assessment_alignment(standard_id);

INSERT INTO schema_migrations (version, description) VALUES ('002', 'Qiymətləndirmə modulu cədvəlləri');

COMMIT;
