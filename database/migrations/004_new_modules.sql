-- =============================================
-- Miqrasiya 004: Yeni Modullar
-- Tarix: 2026-02-17
-- Təsvir: Sertifikasiya, Tədris Resursları, Tədqiqat,
--          Peşəkar İnkişaf, Beynəlxalq Əməkdaşlıq cədvəlləri
-- =============================================

BEGIN;

-- =============================================
-- 1. Sertifikasiya və İşə Qəbul
-- =============================================

CREATE TABLE IF NOT EXISTS certification_exams (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(255) NOT NULL,
    exam_type VARCHAR(50) NOT NULL, -- 'ise_qebul', 'sertifikasiya'
    subject_id UUID REFERENCES subjects(id),
    description TEXT,
    duration_minutes INTEGER DEFAULT 120,
    total_questions INTEGER DEFAULT 50,
    passing_score NUMERIC(5,2) DEFAULT 50.0,
    exam_date DATE,
    start_time TIME,
    end_time TIME,
    location VARCHAR(255),
    max_participants INTEGER,
    status VARCHAR(20) DEFAULT 'planned', -- planned, active, completed, cancelled
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS certification_results (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    exam_id UUID REFERENCES certification_exams(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    score NUMERIC(5,2),
    total_correct INTEGER,
    total_questions INTEGER,
    passed BOOLEAN,
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    certificate_number VARCHAR(100),
    certificate_issued_at TIMESTAMP,
    status VARCHAR(20) DEFAULT 'pending', -- pending, completed, reviewed
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(exam_id, user_id)
);

CREATE TABLE IF NOT EXISTS certification_questions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    exam_id UUID REFERENCES certification_exams(id) ON DELETE CASCADE,
    question_text TEXT NOT NULL,
    question_type VARCHAR(30) DEFAULT 'mcq', -- mcq, true_false, short_answer
    option_a TEXT,
    option_b TEXT,
    option_c TEXT,
    option_d TEXT,
    option_e TEXT,
    correct_answer VARCHAR(10) NOT NULL,
    difficulty VARCHAR(20) DEFAULT 'medium',
    bloom_level VARCHAR(50),
    points NUMERIC(5,2) DEFAULT 1.0,
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- 2. Tədris Resursları
-- =============================================

CREATE TABLE IF NOT EXISTS resource_categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    parent_id UUID REFERENCES resource_categories(id),
    description TEXT,
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS teaching_resources (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(255) NOT NULL,
    resource_type VARCHAR(50) NOT NULL, -- 'tedris_proqrami', 'reqemsal_kontent', 'metodik_vesait'
    category_id UUID REFERENCES resource_categories(id),
    subject_id UUID REFERENCES subjects(id),
    grade_level INTEGER,
    description TEXT,
    file_path VARCHAR(500),
    file_size BIGINT,
    file_type VARCHAR(50),
    url VARCHAR(500),
    author VARCHAR(255),
    publisher VARCHAR(255),
    publish_year INTEGER,
    language VARCHAR(50) DEFAULT 'az',
    download_count INTEGER DEFAULT 0,
    view_count INTEGER DEFAULT 0,
    rating NUMERIC(3,2) DEFAULT 0,
    status VARCHAR(20) DEFAULT 'active',
    uploaded_by UUID REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS textbooks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(255) NOT NULL,
    subject_id UUID REFERENCES subjects(id),
    grade_level INTEGER,
    author VARCHAR(255),
    publisher VARCHAR(255),
    isbn VARCHAR(20),
    publish_year INTEGER,
    edition VARCHAR(50),
    page_count INTEGER,
    description TEXT,
    cover_image VARCHAR(500),
    file_path VARCHAR(500),
    is_approved BOOLEAN DEFAULT FALSE,
    approved_by UUID REFERENCES users(id),
    approved_at TIMESTAMP,
    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- 3. Tədqiqat
-- =============================================

CREATE TABLE IF NOT EXISTS research_projects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(255) NOT NULL,
    research_type VARCHAR(50), -- 'fundamental', 'tetbiqi', 'siyaset_analizi'
    description TEXT,
    objectives TEXT,
    methodology TEXT,
    lead_researcher_id UUID REFERENCES users(id),
    department VARCHAR(255),
    start_date DATE,
    end_date DATE,
    budget NUMERIC(12,2),
    funding_source VARCHAR(255),
    status VARCHAR(20) DEFAULT 'planned', -- planned, active, completed, suspended
    progress NUMERIC(5,2) DEFAULT 0,
    results_summary TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS research_publications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID REFERENCES research_projects(id) ON DELETE SET NULL,
    title VARCHAR(500) NOT NULL,
    authors TEXT NOT NULL,
    journal VARCHAR(255),
    volume VARCHAR(50),
    issue VARCHAR(50),
    pages VARCHAR(50),
    publish_date DATE,
    doi VARCHAR(100),
    abstract TEXT,
    keywords TEXT,
    publication_type VARCHAR(50), -- 'article', 'conference', 'book_chapter', 'report'
    language VARCHAR(50) DEFAULT 'az',
    citation_count INTEGER DEFAULT 0,
    file_path VARCHAR(500),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS doctoral_programs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    program_name VARCHAR(255) NOT NULL,
    department VARCHAR(255),
    specialization_code VARCHAR(20),
    description TEXT,
    duration_years INTEGER DEFAULT 4,
    max_students INTEGER,
    coordinator_id UUID REFERENCES users(id),
    admission_requirements TEXT,
    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS doctoral_students (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    program_id UUID REFERENCES doctoral_programs(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    supervisor_id UUID REFERENCES users(id),
    dissertation_title VARCHAR(500),
    research_area VARCHAR(255),
    admission_date DATE,
    expected_completion DATE,
    defense_date DATE,
    status VARCHAR(20) DEFAULT 'active', -- active, suspended, completed, withdrawn
    progress NUMERIC(5,2) DEFAULT 0,
    publications_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- 4. Peşəkar İnkişaf
-- =============================================

CREATE TABLE IF NOT EXISTS training_programs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(255) NOT NULL,
    training_type VARCHAR(50) NOT NULL, -- 'muellim_telimi', 'seminar', 'workshop', 'konfrans'
    description TEXT,
    objectives TEXT,
    target_audience VARCHAR(255),
    provider VARCHAR(255),
    trainer_name VARCHAR(255),
    start_date DATE,
    end_date DATE,
    duration_hours INTEGER,
    location VARCHAR(255),
    is_online BOOLEAN DEFAULT FALSE,
    max_participants INTEGER,
    registration_deadline DATE,
    certificate_provided BOOLEAN DEFAULT TRUE,
    status VARCHAR(20) DEFAULT 'planned', -- planned, active, completed, cancelled
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS online_courses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    subject_area VARCHAR(255),
    instructor_id UUID REFERENCES users(id),
    duration_hours INTEGER,
    total_modules INTEGER DEFAULT 0,
    difficulty_level VARCHAR(20) DEFAULT 'medium',
    language VARCHAR(50) DEFAULT 'az',
    thumbnail_url VARCHAR(500),
    is_free BOOLEAN DEFAULT TRUE,
    price NUMERIC(8,2) DEFAULT 0,
    certificate_provided BOOLEAN DEFAULT TRUE,
    status VARCHAR(20) DEFAULT 'draft', -- draft, published, archived
    rating NUMERIC(3,2) DEFAULT 0,
    enrollment_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS course_enrollments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    course_id UUID REFERENCES online_courses(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    enrolled_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    progress NUMERIC(5,2) DEFAULT 0,
    score NUMERIC(5,2),
    certificate_number VARCHAR(100),
    status VARCHAR(20) DEFAULT 'active', -- active, completed, dropped
    UNIQUE(course_id, user_id)
);

CREATE TABLE IF NOT EXISTS mentorship_programs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    objectives TEXT,
    start_date DATE,
    end_date DATE,
    max_pairs INTEGER,
    status VARCHAR(20) DEFAULT 'active',
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS mentorship_pairs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    program_id UUID REFERENCES mentorship_programs(id) ON DELETE CASCADE,
    mentor_id UUID REFERENCES users(id) ON DELETE CASCADE,
    mentee_id UUID REFERENCES users(id) ON DELETE CASCADE,
    start_date DATE,
    end_date DATE,
    meeting_frequency VARCHAR(50) DEFAULT 'weekly',
    goals TEXT,
    progress_notes TEXT,
    status VARCHAR(20) DEFAULT 'active', -- active, completed, cancelled
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(program_id, mentor_id, mentee_id)
);

-- =============================================
-- 5. Beynəlxalq Əməkdaşlıq
-- =============================================

CREATE TABLE IF NOT EXISTS olympiads (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    subject VARCHAR(100) NOT NULL,
    olympiad_level VARCHAR(50) NOT NULL, -- 'mekteb', 'rayon', 'respublika', 'beynelxalq'
    description TEXT,
    organizer VARCHAR(255),
    event_date DATE,
    registration_start DATE,
    registration_end DATE,
    location VARCHAR(255),
    country VARCHAR(100) DEFAULT 'Azərbaycan',
    max_participants INTEGER,
    age_min INTEGER,
    age_max INTEGER,
    status VARCHAR(20) DEFAULT 'planned', -- planned, registration, active, completed
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS olympiad_participants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    olympiad_id UUID REFERENCES olympiads(id) ON DELETE CASCADE,
    student_id UUID REFERENCES students(id) ON DELETE CASCADE,
    school_id UUID REFERENCES schools(id),
    coach_id UUID REFERENCES users(id),
    score NUMERIC(8,2),
    rank INTEGER,
    medal VARCHAR(20), -- 'gold', 'silver', 'bronze', 'honorable'
    certificate_number VARCHAR(100),
    status VARCHAR(20) DEFAULT 'registered', -- registered, participated, awarded, disqualified
    registered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(olympiad_id, student_id)
);

CREATE TABLE IF NOT EXISTS steam_projects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    project_type VARCHAR(50), -- 'science', 'technology', 'engineering', 'arts', 'mathematics'
    lead_teacher_id UUID REFERENCES users(id),
    school_id UUID REFERENCES schools(id),
    start_date DATE,
    end_date DATE,
    budget NUMERIC(10,2),
    participants_count INTEGER DEFAULT 0,
    objectives TEXT,
    outcomes TEXT,
    partner_organization VARCHAR(255),
    status VARCHAR(20) DEFAULT 'planned', -- planned, active, completed, suspended
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS partner_programs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    program_name VARCHAR(255) NOT NULL,
    partner_name VARCHAR(255) NOT NULL,
    partner_country VARCHAR(100),
    partner_type VARCHAR(50), -- 'university', 'organization', 'government', 'ngo'
    description TEXT,
    objectives TEXT,
    start_date DATE,
    end_date DATE,
    contact_person VARCHAR(255),
    contact_email VARCHAR(255),
    website VARCHAR(500),
    agreement_number VARCHAR(100),
    status VARCHAR(20) DEFAULT 'active', -- active, completed, suspended, pending
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- İndekslər
-- =============================================

CREATE INDEX IF NOT EXISTS idx_cert_exams_type ON certification_exams(exam_type);
CREATE INDEX IF NOT EXISTS idx_cert_exams_status ON certification_exams(status);
CREATE INDEX IF NOT EXISTS idx_cert_results_exam ON certification_results(exam_id);
CREATE INDEX IF NOT EXISTS idx_cert_results_user ON certification_results(user_id);
CREATE INDEX IF NOT EXISTS idx_cert_questions_exam ON certification_questions(exam_id);

CREATE INDEX IF NOT EXISTS idx_resources_type ON teaching_resources(resource_type);
CREATE INDEX IF NOT EXISTS idx_resources_category ON teaching_resources(category_id);
CREATE INDEX IF NOT EXISTS idx_resources_subject ON teaching_resources(subject_id);
CREATE INDEX IF NOT EXISTS idx_textbooks_subject ON textbooks(subject_id);

CREATE INDEX IF NOT EXISTS idx_research_status ON research_projects(status);
CREATE INDEX IF NOT EXISTS idx_research_lead ON research_projects(lead_researcher_id);
CREATE INDEX IF NOT EXISTS idx_publications_project ON research_publications(project_id);
CREATE INDEX IF NOT EXISTS idx_doctoral_students_program ON doctoral_students(program_id);
CREATE INDEX IF NOT EXISTS idx_doctoral_students_supervisor ON doctoral_students(supervisor_id);

CREATE INDEX IF NOT EXISTS idx_training_type ON training_programs(training_type);
CREATE INDEX IF NOT EXISTS idx_training_status ON training_programs(status);
CREATE INDEX IF NOT EXISTS idx_courses_status ON online_courses(status);
CREATE INDEX IF NOT EXISTS idx_enrollments_course ON course_enrollments(course_id);
CREATE INDEX IF NOT EXISTS idx_enrollments_user ON course_enrollments(user_id);
CREATE INDEX IF NOT EXISTS idx_mentorship_pairs_program ON mentorship_pairs(program_id);

CREATE INDEX IF NOT EXISTS idx_olympiads_subject ON olympiads(subject);
CREATE INDEX IF NOT EXISTS idx_olympiads_level ON olympiads(olympiad_level);
CREATE INDEX IF NOT EXISTS idx_olympiad_participants_olympiad ON olympiad_participants(olympiad_id);
CREATE INDEX IF NOT EXISTS idx_steam_projects_school ON steam_projects(school_id);
CREATE INDEX IF NOT EXISTS idx_partner_programs_status ON partner_programs(status);

INSERT INTO schema_migrations (version, description) VALUES ('004', 'Yeni modullar: sertifikasiya, resurslar, tədqiqat, inkişaf, beynəlxalq');

COMMIT;
