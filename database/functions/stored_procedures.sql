-- =============================================
-- ARTI-2026: Saxlanılan Prosedurlar və Funksiyalar
-- =============================================

-- =============================================
-- 1. Şagird GPA Hesablama
-- =============================================
CREATE OR REPLACE FUNCTION calculate_student_gpa(p_student_id UUID, p_academic_year VARCHAR DEFAULT NULL)
RETURNS NUMERIC AS $$
DECLARE
    v_gpa NUMERIC;
BEGIN
    SELECT AVG(score) INTO v_gpa
    FROM grades
    WHERE student_id = p_student_id
      AND (p_academic_year IS NULL OR academic_year = p_academic_year);
    RETURN COALESCE(v_gpa, 0);
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- 2. Davamiyyət Faizi Hesablama
-- =============================================
CREATE OR REPLACE FUNCTION calculate_attendance_rate(p_student_id UUID, p_start_date DATE DEFAULT NULL, p_end_date DATE DEFAULT NULL)
RETURNS NUMERIC AS $$
DECLARE
    v_total INTEGER;
    v_present INTEGER;
BEGIN
    SELECT COUNT(*), COUNT(*) FILTER (WHERE status = 'iştirak')
    INTO v_total, v_present
    FROM attendance
    WHERE student_id = p_student_id
      AND (p_start_date IS NULL OR attendance_date >= p_start_date)
      AND (p_end_date IS NULL OR attendance_date <= p_end_date);

    IF v_total = 0 THEN RETURN 0; END IF;
    RETURN ROUND(v_present::NUMERIC / v_total * 100, 1);
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- 3. Sinif Orta Bal
-- =============================================
CREATE OR REPLACE FUNCTION get_class_average(p_class_id UUID, p_subject_id UUID DEFAULT NULL)
RETURNS NUMERIC AS $$
DECLARE
    v_avg NUMERIC;
BEGIN
    SELECT AVG(g.score) INTO v_avg
    FROM grades g
    JOIN students s ON g.student_id = s.id
    WHERE s.class_id = p_class_id
      AND s.status = 'active'
      AND (p_subject_id IS NULL OR g.subject_id = p_subject_id);
    RETURN COALESCE(ROUND(v_avg, 1), 0);
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- 4. Qiymət Etiketi
-- =============================================
CREATE OR REPLACE FUNCTION get_grade_label(p_score NUMERIC)
RETURNS VARCHAR AS $$
BEGIN
    RETURN CASE
        WHEN p_score >= 86 THEN 'Əla'
        WHEN p_score >= 71 THEN 'Yaxşı'
        WHEN p_score >= 51 THEN 'Kafi'
        ELSE 'Qeyri-kafi'
    END;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- 5. Müəllim İş Yükü Hesablama
-- =============================================
CREATE OR REPLACE FUNCTION get_teacher_workload(p_teacher_id UUID, p_academic_year VARCHAR DEFAULT NULL)
RETURNS TABLE(total_hours INTEGER, unique_classes INTEGER, unique_subjects INTEGER) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COUNT(*)::INTEGER AS total_hours,
        COUNT(DISTINCT class_id)::INTEGER AS unique_classes,
        COUNT(DISTINCT subject_id)::INTEGER AS unique_subjects
    FROM teacher_schedule
    WHERE teacher_id = p_teacher_id
      AND (p_academic_year IS NULL OR academic_year = p_academic_year);
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- 6. Risk Altında Olan Şagirdlər
-- =============================================
CREATE OR REPLACE FUNCTION get_at_risk_students(p_school_id UUID DEFAULT NULL, p_threshold NUMERIC DEFAULT 50)
RETURNS TABLE(
    student_id UUID,
    first_name VARCHAR,
    last_name VARCHAR,
    class_grade INTEGER,
    class_section VARCHAR,
    avg_score NUMERIC,
    attendance_rate NUMERIC,
    risk_level VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        s.id,
        s.first_name,
        s.last_name,
        c.grade,
        c.section,
        COALESCE(ROUND(AVG(g.score), 1), 0),
        calculate_attendance_rate(s.id),
        CASE
            WHEN COALESCE(AVG(g.score), 0) < 30 THEN 'Kritik'
            WHEN COALESCE(AVG(g.score), 0) < p_threshold THEN 'Yüksək'
            ELSE 'Orta'
        END
    FROM students s
    LEFT JOIN classes c ON s.class_id = c.id
    LEFT JOIN grades g ON g.student_id = s.id
    WHERE s.status = 'active'
      AND (p_school_id IS NULL OR s.school_id = p_school_id)
    GROUP BY s.id, s.first_name, s.last_name, c.grade, c.section
    HAVING COALESCE(AVG(g.score), 0) < p_threshold
       OR calculate_attendance_rate(s.id) < 80
    ORDER BY COALESCE(AVG(g.score), 0) ASC;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- 7. Fənn üzrə Performans Statistikası
-- =============================================
CREATE OR REPLACE FUNCTION get_subject_performance(p_subject_id UUID, p_academic_year VARCHAR DEFAULT NULL)
RETURNS TABLE(
    total_students BIGINT,
    avg_score NUMERIC,
    min_score NUMERIC,
    max_score NUMERIC,
    std_dev NUMERIC,
    ela_count BIGINT,
    yaxsi_count BIGINT,
    kafi_count BIGINT,
    qeyri_kafi_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COUNT(DISTINCT g.student_id),
        ROUND(AVG(g.score), 1),
        MIN(g.score),
        MAX(g.score),
        ROUND(STDDEV(g.score), 2),
        COUNT(*) FILTER (WHERE g.score >= 86),
        COUNT(*) FILTER (WHERE g.score >= 71 AND g.score < 86),
        COUNT(*) FILTER (WHERE g.score >= 51 AND g.score < 71),
        COUNT(*) FILTER (WHERE g.score < 51)
    FROM grades g
    WHERE g.subject_id = p_subject_id
      AND (p_academic_year IS NULL OR g.academic_year = p_academic_year);
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- 8. Materialized View Yeniləmə
-- =============================================
CREATE OR REPLACE FUNCTION refresh_analytics_views()
RETURNS VOID AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_student_performance;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_attendance_summary;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- 9. Audit Log Trigger
-- =============================================
CREATE OR REPLACE FUNCTION audit_trigger_func()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO audit_log (action, table_name, record_id, new_values)
        VALUES ('INSERT', TG_TABLE_NAME, NEW.id, to_jsonb(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_log (action, table_name, record_id, old_values, new_values)
        VALUES ('UPDATE', TG_TABLE_NAME, NEW.id, to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO audit_log (action, table_name, record_id, old_values)
        VALUES ('DELETE', TG_TABLE_NAME, OLD.id, to_jsonb(OLD));
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Audit triggerləri
CREATE TRIGGER audit_students AFTER INSERT OR UPDATE OR DELETE ON students FOR EACH ROW EXECUTE FUNCTION audit_trigger_func();
CREATE TRIGGER audit_teachers AFTER INSERT OR UPDATE OR DELETE ON teachers FOR EACH ROW EXECUTE FUNCTION audit_trigger_func();
CREATE TRIGGER audit_grades AFTER INSERT OR UPDATE OR DELETE ON grades FOR EACH ROW EXECUTE FUNCTION audit_trigger_func();

-- =============================================
-- 10. Updated_at Trigger
-- =============================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_students_updated BEFORE UPDATE ON students FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_teachers_updated BEFORE UPDATE ON teachers FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_users_updated BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_items_updated BEFORE UPDATE ON items FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- =============================================
-- 11. IRT Theta MLE Hesablama (PL/pgSQL)
-- =============================================
CREATE OR REPLACE FUNCTION estimate_theta_mle(p_session_id UUID)
RETURNS NUMERIC AS $$
DECLARE
    v_theta NUMERIC := 0;
    v_step NUMERIC;
    v_info NUMERIC;
    v_deriv NUMERIC;
    v_prob NUMERIC;
    rec RECORD;
    v_iter INTEGER := 0;
BEGIN
    FOR v_iter IN 1..30 LOOP
        v_deriv := 0;
        v_info := 0;
        FOR rec IN
            SELECT tr.is_correct, i.irt_a, i.irt_b, i.irt_c
            FROM test_responses tr
            JOIN items i ON tr.item_id = i.id
            WHERE tr.session_id = p_session_id
        LOOP
            v_prob := rec.irt_c + (1 - rec.irt_c) / (1 + EXP(-1.7 * rec.irt_a * (v_theta - rec.irt_b)));
            v_deriv := v_deriv + rec.irt_a * (rec.is_correct::INTEGER - v_prob) * (v_prob - rec.irt_c) / (v_prob * (1 - rec.irt_c));
            v_info := v_info + (1.7 * rec.irt_a)^2 * ((v_prob - rec.irt_c)^2) / ((1 - rec.irt_c)^2 * v_prob * (1 - v_prob));
        END LOOP;

        IF v_info = 0 THEN EXIT; END IF;
        v_step := v_deriv / v_info;
        v_theta := v_theta + v_step;
        v_theta := GREATEST(-4, LEAST(4, v_theta));
        IF ABS(v_step) < 0.001 THEN EXIT; END IF;
    END LOOP;

    RETURN ROUND(v_theta, 4);
END;
$$ LANGUAGE plpgsql;
