-- =============================================
-- ARTI-2026: Verilənlər Bazası Sxemi
-- PostgreSQL 15+
-- =============================================

-- UUID genersiya üçün
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =============================================
-- 1. İstifadəçilər və Autentifikasiya
-- =============================================

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(20) NOT NULL CHECK (role IN ('admin', 'teacher', 'student', 'parent', 'inspector')),
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    avatar_url TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    last_login TIMESTAMP,
    failed_attempts INTEGER DEFAULT 0,
    locked_until TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE user_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    token TEXT NOT NULL,
    ip_address VARCHAR(45),
    user_agent TEXT,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE login_attempts (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50),
    ip_address VARCHAR(45),
    success BOOLEAN DEFAULT FALSE,
    attempted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- 2. Məktəblər
-- =============================================

CREATE TABLE schools (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    code VARCHAR(20) UNIQUE NOT NULL,
    type VARCHAR(50) CHECK (type IN ('ümumi', 'lisey', 'gimnaziya', 'peşə', 'xüsusi')),
    region VARCHAR(100),
    city VARCHAR(100),
    address TEXT,
    phone VARCHAR(20),
    email VARCHAR(255),
    director_name VARCHAR(200),
    student_capacity INTEGER,
    established_year INTEGER,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- 3. Siniflər
-- =============================================

CREATE TABLE classes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    school_id UUID REFERENCES schools(id) ON DELETE CASCADE,
    grade INTEGER NOT NULL CHECK (grade BETWEEN 1 AND 11),
    section VARCHAR(5) NOT NULL,
    academic_year VARCHAR(9) NOT NULL,
    homeroom_teacher_id UUID,
    capacity INTEGER DEFAULT 30,
    education_level VARCHAR(20) GENERATED ALWAYS AS (
        CASE
            WHEN grade BETWEEN 1 AND 4 THEN 'ibtidai'
            WHEN grade BETWEEN 5 AND 9 THEN 'ümumi_orta'
            WHEN grade BETWEEN 10 AND 11 THEN 'tam_orta'
        END
    ) STORED,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(school_id, grade, section, academic_year)
);

-- =============================================
-- 4. Şagirdlər
-- =============================================

CREATE TABLE students (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id),
    fin VARCHAR(7) UNIQUE,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    father_name VARCHAR(100),
    birth_date DATE NOT NULL,
    gender VARCHAR(10) CHECK (gender IN ('kişi', 'qadın')),
    nationality VARCHAR(50) DEFAULT 'Azərbaycan',
    class_id UUID REFERENCES classes(id),
    school_id UUID REFERENCES schools(id),
    enrollment_date DATE DEFAULT CURRENT_DATE,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'graduated', 'transferred', 'expelled')),
    photo_url TEXT,
    medical_notes TEXT,
    address TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE student_parents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id UUID REFERENCES students(id) ON DELETE CASCADE,
    parent_type VARCHAR(10) CHECK (parent_type IN ('ata', 'ana', 'qəyyum')),
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    email VARCHAR(255),
    workplace VARCHAR(255),
    is_primary_contact BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- 5. Müəllimlər
-- =============================================

CREATE TABLE teachers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id),
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    father_name VARCHAR(100),
    birth_date DATE,
    gender VARCHAR(10) CHECK (gender IN ('kişi', 'qadın')),
    phone VARCHAR(20),
    email VARCHAR(255),
    school_id UUID REFERENCES schools(id),
    category VARCHAR(30) CHECK (category IN ('ali', 'birinci', 'ikinci', 'kateqoriyasız')),
    education_degree VARCHAR(50),
    specialization VARCHAR(100),
    experience_years INTEGER DEFAULT 0,
    hire_date DATE,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'retired', 'on_leave')),
    photo_url TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE teacher_subjects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    teacher_id UUID REFERENCES teachers(id) ON DELETE CASCADE,
    subject_id UUID REFERENCES subjects(id) ON DELETE CASCADE,
    is_primary BOOLEAN DEFAULT TRUE,
    UNIQUE(teacher_id, subject_id)
);

CREATE TABLE teacher_schedule (
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

CREATE TABLE teacher_trainings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    teacher_id UUID REFERENCES teachers(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    provider VARCHAR(255),
    training_type VARCHAR(50) CHECK (training_type IN ('kurs', 'seminar', 'konfrans', 'sertifikat', 'magistratura')),
    start_date DATE,
    end_date DATE,
    hours INTEGER,
    certificate_number VARCHAR(100),
    status VARCHAR(20) DEFAULT 'completed',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE teacher_evaluations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    teacher_id UUID REFERENCES teachers(id) ON DELETE CASCADE,
    evaluator_id UUID REFERENCES users(id),
    evaluation_date DATE DEFAULT CURRENT_DATE,
    academic_year VARCHAR(9),
    teaching_quality NUMERIC(3,1) CHECK (teaching_quality BETWEEN 1 AND 5),
    student_engagement NUMERIC(3,1) CHECK (student_engagement BETWEEN 1 AND 5),
    professional_development NUMERIC(3,1) CHECK (professional_development BETWEEN 1 AND 5),
    communication NUMERIC(3,1) CHECK (communication BETWEEN 1 AND 5),
    innovation NUMERIC(3,1) CHECK (innovation BETWEEN 1 AND 5),
    overall_score NUMERIC(3,1) CHECK (overall_score BETWEEN 1 AND 5),
    comments TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- 6. Fənnlər
-- =============================================

CREATE TABLE subjects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    code VARCHAR(20) UNIQUE NOT NULL,
    category VARCHAR(50) CHECK (category IN ('dəqiq', 'humanitar', 'təbiət', 'ictimai', 'incəsənət', 'texniki', 'bədən_tərbiyəsi')),
    is_mandatory BOOLEAN DEFAULT TRUE,
    weekly_hours_default INTEGER DEFAULT 2,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- 7. Qiymətlər
-- =============================================

CREATE TABLE grades (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id UUID REFERENCES students(id) ON DELETE CASCADE,
    subject_id UUID REFERENCES subjects(id),
    teacher_id UUID REFERENCES teachers(id),
    class_id UUID REFERENCES classes(id),
    score NUMERIC(5,2) NOT NULL CHECK (score BETWEEN 0 AND 100),
    grade_type VARCHAR(30) CHECK (grade_type IN ('gündəlik', 'ksa', 'bsa', 'yarımill', 'illik', 'imtahan', 'layihə')),
    semester INTEGER CHECK (semester IN (1, 2)),
    academic_year VARCHAR(9),
    grade_date DATE DEFAULT CURRENT_DATE,
    comments TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE grade_components (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    grade_id UUID REFERENCES grades(id) ON DELETE CASCADE,
    component_name VARCHAR(100),
    max_score NUMERIC(5,2),
    achieved_score NUMERIC(5,2),
    weight NUMERIC(3,2) DEFAULT 1.0
);

-- =============================================
-- 8. Davamiyyət
-- =============================================

CREATE TABLE attendance (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id UUID REFERENCES students(id) ON DELETE CASCADE,
    class_id UUID REFERENCES classes(id),
    attendance_date DATE NOT NULL,
    period INTEGER CHECK (period BETWEEN 1 AND 7),
    status VARCHAR(20) NOT NULL CHECK (status IN ('iştirak', 'qayıb', 'gecikmə', 'icazəli', 'xəstəlik')),
    recorded_by UUID REFERENCES users(id),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(student_id, attendance_date, period)
);

-- =============================================
-- 9. Kurikulum Standartları
-- =============================================

CREATE TABLE curriculum_standards (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    subject_id UUID REFERENCES subjects(id),
    grade INTEGER CHECK (grade BETWEEN 1 AND 11),
    code VARCHAR(30) NOT NULL,
    description TEXT NOT NULL,
    bloom_level VARCHAR(30) CHECK (bloom_level IN ('xatırlama', 'anlama', 'tətbiq', 'analiz', 'qiymətləndirmə', 'yaratma')),
    dok_level INTEGER CHECK (dok_level BETWEEN 1 AND 4),
    is_core BOOLEAN DEFAULT TRUE,
    parent_standard_id UUID REFERENCES curriculum_standards(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(subject_id, grade, code)
);

-- =============================================
-- 10. Qiymətləndirmə - Sual Bankı
-- =============================================

CREATE TABLE items (
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
    difficulty VARCHAR(20) CHECK (difficulty IN ('çox_asan', 'asan', 'orta', 'çətin', 'çox_çətin')),
    bloom_level VARCHAR(30),
    dok_level INTEGER CHECK (dok_level BETWEEN 1 AND 4),
    -- IRT parametrləri
    irt_a NUMERIC(6,4) DEFAULT 1.0,  -- Fərqləndirmə
    irt_b NUMERIC(6,4) DEFAULT 0.0,  -- Çətinlik
    irt_c NUMERIC(6,4) DEFAULT 0.2,  -- Təxmin
    irt_model VARCHAR(5) DEFAULT '3PL' CHECK (irt_model IN ('1PL', '2PL', '3PL')),
    -- Statistika
    times_used INTEGER DEFAULT 0,
    p_value NUMERIC(5,4),
    rpbis NUMERIC(5,4),
    is_active BOOLEAN DEFAULT TRUE,
    is_calibrated BOOLEAN DEFAULT FALSE,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE assessment_alignment (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    item_id UUID REFERENCES items(id) ON DELETE CASCADE,
    standard_id UUID REFERENCES curriculum_standards(id) ON DELETE CASCADE,
    dok_level INTEGER CHECK (dok_level BETWEEN 1 AND 4),
    alignment_strength NUMERIC(3,2) DEFAULT 1.0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(item_id, standard_id)
);

-- =============================================
-- 11. Testlər
-- =============================================

CREATE TABLE tests (
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

CREATE TABLE test_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    test_id UUID REFERENCES tests(id) ON DELETE CASCADE,
    item_id UUID REFERENCES items(id),
    item_order INTEGER,
    module_id VARCHAR(20),  -- MST üçün
    stage INTEGER,          -- MST üçün
    UNIQUE(test_id, item_id)
);

CREATE TABLE test_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    test_id UUID REFERENCES tests(id),
    student_id UUID REFERENCES students(id),
    start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    end_time TIMESTAMP,
    status VARCHAR(20) DEFAULT 'in_progress' CHECK (status IN ('in_progress', 'completed', 'abandoned', 'timed_out')),
    theta_estimate NUMERIC(6,4),
    se_estimate NUMERIC(6,4),
    total_score NUMERIC(5,2),
    items_administered INTEGER DEFAULT 0,
    current_module VARCHAR(20),  -- MST üçün
    current_stage INTEGER,       -- MST üçün
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE test_responses (
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

-- =============================================
-- 12. Fərdi İnkişaf Planı (FİP)
-- =============================================

CREATE TABLE individual_plans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id UUID REFERENCES students(id) ON DELETE CASCADE,
    subject_id UUID REFERENCES subjects(id),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    target_score NUMERIC(5,2),
    current_score NUMERIC(5,2),
    start_date DATE,
    end_date DATE,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'completed', 'paused', 'cancelled')),
    progress NUMERIC(5,2) DEFAULT 0,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE plan_notes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    plan_id UUID REFERENCES individual_plans(id) ON DELETE CASCADE,
    note TEXT NOT NULL,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- 13. Bildirişlər
-- =============================================

CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    message TEXT,
    type VARCHAR(20) CHECK (type IN ('info', 'warning', 'error', 'success')),
    is_read BOOLEAN DEFAULT FALSE,
    link TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- 14. Sistem Logları
-- =============================================

CREATE TABLE audit_log (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    action VARCHAR(100) NOT NULL,
    table_name VARCHAR(100),
    record_id UUID,
    old_values JSONB,
    new_values JSONB,
    ip_address VARCHAR(45),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- İndekslər
-- =============================================

CREATE INDEX idx_students_class ON students(class_id);
CREATE INDEX idx_students_school ON students(school_id);
CREATE INDEX idx_students_status ON students(status);
CREATE INDEX idx_grades_student ON grades(student_id);
CREATE INDEX idx_grades_subject ON grades(subject_id);
CREATE INDEX idx_grades_date ON grades(grade_date);
CREATE INDEX idx_attendance_student ON attendance(student_id);
CREATE INDEX idx_attendance_date ON attendance(attendance_date);
CREATE INDEX idx_items_subject ON items(subject_id);
CREATE INDEX idx_items_difficulty ON items(difficulty);
CREATE INDEX idx_items_irt_b ON items(irt_b);
CREATE INDEX idx_test_sessions_student ON test_sessions(student_id);
CREATE INDEX idx_test_responses_session ON test_responses(session_id);
CREATE INDEX idx_curriculum_subject_grade ON curriculum_standards(subject_id, grade);
CREATE INDEX idx_audit_log_user ON audit_log(user_id);
CREATE INDEX idx_audit_log_action ON audit_log(action);
CREATE INDEX idx_notifications_user ON notifications(user_id, is_read);
CREATE INDEX idx_teacher_schedule_teacher ON teacher_schedule(teacher_id);
CREATE INDEX idx_teacher_subjects_teacher ON teacher_subjects(teacher_id);
