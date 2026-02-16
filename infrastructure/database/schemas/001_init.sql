-- ============================================
-- ARTI 2026 - PostgreSQL Verilener Bazasi Sxemi
-- Esas cedveller ve munasibetler
-- ============================================

-- Uzanti
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ===== ISTIFADECHILER =====

CREATE TABLE users (
    user_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL CHECK (role IN (
        'admin', 'teacher', 'student', 'examiner',
        'researcher', 'school_admin', 'parent'
    )),
    phone VARCHAR(20),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ===== MEKTEBLER =====

CREATE TABLE schools (
    school_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    school_name VARCHAR(255) NOT NULL,
    school_type VARCHAR(50) CHECK (school_type IN (
        'umumi', 'lisey', 'gimnaziya', 'ibtidai', 'ozel'
    )),
    region VARCHAR(100),
    district VARCHAR(100),
    address TEXT,
    phone VARCHAR(20),
    email VARCHAR(255),
    director_name VARCHAR(255),
    student_count INT DEFAULT 0,
    teacher_count INT DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ===== MUELLEMLER =====

CREATE TABLE teachers (
    teacher_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(user_id),
    school_id UUID REFERENCES schools(school_id),
    subject VARCHAR(100) NOT NULL,
    qualification VARCHAR(100),
    experience_years INT DEFAULT 0,
    certification_level VARCHAR(50),
    certification_date DATE,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ===== SHAGIRDLER =====

CREATE TABLE students (
    student_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(user_id),
    school_id UUID REFERENCES schools(school_id),
    grade_level INT CHECK (grade_level BETWEEN 1 AND 11),
    class_name VARCHAR(10),
    full_name VARCHAR(255) NOT NULL,
    birth_date DATE,
    gender VARCHAR(10),
    parent_phone VARCHAR(20),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ===== SUAL BAZASI =====

CREATE TABLE items (
    item_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    item_code VARCHAR(50) UNIQUE NOT NULL,
    subject VARCHAR(100) NOT NULL,
    topic VARCHAR(200),
    grade_level INT,
    difficulty VARCHAR(20) CHECK (difficulty IN ('easy', 'medium', 'hard')),
    bloom_level VARCHAR(50),
    question_text TEXT NOT NULL,
    options JSONB NOT NULL,       -- ["A variant", "B variant", "C variant", "D variant"]
    correct_answer INT NOT NULL,
    explanation TEXT,
    -- IRT parametrleri
    irt_a FLOAT,                 -- Ayird etme
    irt_b FLOAT,                 -- Chesinlik
    irt_c FLOAT,                 -- Tesedufi tapma
    irt_calibrated BOOLEAN DEFAULT false,
    -- Metadata
    status VARCHAR(20) DEFAULT 'draft' CHECK (status IN (
        'draft', 'review', 'approved', 'active', 'retired'
    )),
    usage_count INT DEFAULT 0,
    created_by UUID REFERENCES users(user_id),
    reviewed_by UUID REFERENCES users(user_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ===== IMTAHANLAR =====

CREATE TABLE exams (
    exam_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    exam_code VARCHAR(50) UNIQUE NOT NULL,
    exam_type VARCHAR(50) NOT NULL CHECK (exam_type IN (
        'cat', 'mst', 'classic', 'recruitment', 'certification'
    )),
    title VARCHAR(255) NOT NULL,
    subject VARCHAR(100),
    grade_level INT,
    total_questions INT,
    duration_minutes INT,
    passing_score FLOAT,
    is_active BOOLEAN DEFAULT true,
    scheduled_date TIMESTAMP,
    created_by UUID REFERENCES users(user_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ===== IMTAHAN SESSIYALARI =====

CREATE TABLE exam_sessions (
    session_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    exam_id UUID REFERENCES exams(exam_id),
    student_id UUID REFERENCES students(student_id),
    school_id UUID REFERENCES schools(school_id),
    -- Neticeler
    theta FLOAT,
    raw_score INT,
    max_score INT,
    percentage FLOAT,
    se FLOAT,                    -- Standart xeta
    performance_level VARCHAR(50),
    -- Zaman
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    duration_seconds INT,
    -- Melumat
    items_administered INT,
    responses JSONB,             -- Detalli cavablar
    theta_history JSONB,         -- CAT theta tarixi
    path JSONB,                  -- MST yol
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN (
        'active', 'completed', 'expired', 'cancelled'
    )),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ===== SERTIFIKASIYA =====

CREATE TABLE certifications (
    certification_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    teacher_id UUID REFERENCES teachers(teacher_id),
    certification_type VARCHAR(50) NOT NULL,
    certificate_number VARCHAR(100) UNIQUE,
    -- Merheleler
    stage_results JSONB,         -- Her merhele neticesi
    final_score FLOAT,
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN (
        'pending', 'in_progress', 'passed', 'failed', 'expired'
    )),
    issued_date DATE,
    expiry_date DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ===== TELIM / PESHKAR INKISHAF =====

CREATE TABLE training_programs (
    program_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    program_type VARCHAR(50),    -- online, face_to_face, blended
    subject_area VARCHAR(100),
    duration_hours INT,
    max_participants INT,
    start_date DATE,
    end_date DATE,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE training_enrollments (
    enrollment_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    program_id UUID REFERENCES training_programs(program_id),
    teacher_id UUID REFERENCES teachers(teacher_id),
    status VARCHAR(20) DEFAULT 'enrolled',
    pre_score FLOAT,
    post_score FLOAT,
    completion_date DATE,
    certificate_issued BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ===== TEDQIQAT =====

CREATE TABLE research_projects (
    project_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(500) NOT NULL,
    description TEXT,
    project_type VARCHAR(50),
    lead_researcher UUID REFERENCES users(user_id),
    status VARCHAR(20) DEFAULT 'proposal',
    start_date DATE,
    end_date DATE,
    budget DECIMAL(12,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE publications (
    publication_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(500) NOT NULL,
    authors TEXT,
    publication_type VARCHAR(50), -- journal, article, report, book
    journal_name VARCHAR(255),
    abstract TEXT,
    doi VARCHAR(100),
    published_date DATE,
    project_id UUID REFERENCES research_projects(project_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ===== OLIMPIADALAR =====

CREATE TABLE olympiads (
    olympiad_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(255) NOT NULL,
    subject VARCHAR(100),
    level VARCHAR(50),           -- school, regional, national, international
    academic_year VARCHAR(20),
    registration_deadline DATE,
    competition_date DATE,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE olympiad_participants (
    participant_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    olympiad_id UUID REFERENCES olympiads(olympiad_id),
    student_id UUID REFERENCES students(student_id),
    school_id UUID REFERENCES schools(school_id),
    score FLOAT,
    rank INT,
    medal VARCHAR(20),           -- gold, silver, bronze
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ===== INDEKSLER =====

CREATE INDEX idx_items_subject ON items(subject);
CREATE INDEX idx_items_grade ON items(grade_level);
CREATE INDEX idx_items_status ON items(status);
CREATE INDEX idx_items_difficulty ON items(difficulty);
CREATE INDEX idx_exam_sessions_exam ON exam_sessions(exam_id);
CREATE INDEX idx_exam_sessions_student ON exam_sessions(student_id);
CREATE INDEX idx_exam_sessions_school ON exam_sessions(school_id);
CREATE INDEX idx_students_school ON students(school_id);
CREATE INDEX idx_teachers_school ON teachers(school_id);
CREATE INDEX idx_certifications_teacher ON certifications(teacher_id);
CREATE INDEX idx_schools_region ON schools(region);
CREATE INDEX idx_schools_type ON schools(school_type);

-- ===== GORUNUSLER (VIEWS) =====

CREATE VIEW v_school_performance AS
SELECT
    s.school_id,
    s.school_name,
    s.school_type,
    s.region,
    COUNT(DISTINCT es.student_id) as tested_students,
    ROUND(AVG(es.percentage)::numeric, 1) as avg_score,
    ROUND(AVG(es.theta)::numeric, 3) as avg_theta,
    ROUND((COUNT(CASE WHEN es.percentage >= 50 THEN 1 END)::float /
           NULLIF(COUNT(*), 0) * 100)::numeric, 1) as pass_rate
FROM schools s
LEFT JOIN exam_sessions es ON s.school_id = es.school_id
WHERE es.status = 'completed'
GROUP BY s.school_id, s.school_name, s.school_type, s.region;

CREATE VIEW v_teacher_certification_status AS
SELECT
    t.teacher_id,
    u.full_name,
    t.subject,
    s.school_name,
    t.experience_years,
    c.status as certification_status,
    c.final_score,
    c.certificate_number,
    c.expiry_date
FROM teachers t
JOIN users u ON t.user_id = u.user_id
JOIN schools s ON t.school_id = s.school_id
LEFT JOIN certifications c ON t.teacher_id = c.teacher_id;
