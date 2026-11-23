-- =====================================================================
-- Платформа онлайн-курсів: створення схеми (PostgreSQL)
-- Запуск: psql -d online_courses -f sql/01_schema.sql
-- =====================================================================

DROP VIEW  IF EXISTS v_student_courses;
DROP TABLE IF EXISTS enrollments CASCADE;
DROP TABLE IF EXISTS courses     CASCADE;
DROP TABLE IF EXISTS categories  CASCADE;
DROP TABLE IF EXISTS teachers    CASCADE;
DROP TABLE IF EXISTS students    CASCADE;
DROP FUNCTION IF EXISTS trg_check_rating_after_end();

-- ---------- Студенти ----------
CREATE TABLE students (
    student_id  INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name  VARCHAR(50)  NOT NULL,
    last_name   VARCHAR(50)  NOT NULL,
    birth_date  DATE         NOT NULL,
    email       VARCHAR(100) NOT NULL UNIQUE,
    CONSTRAINT chk_students_birth_date CHECK (birth_date <= CURRENT_DATE),
    CONSTRAINT chk_students_email      CHECK (email LIKE '_%@_%._%')
);

-- ---------- Викладачі ----------
CREATE TABLE teachers (
    teacher_id       INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name       VARCHAR(50) NOT NULL,
    last_name        VARCHAR(50) NOT NULL,
    experience_years SMALLINT    NOT NULL DEFAULT 0,
    CONSTRAINT chk_teachers_experience CHECK (experience_years >= 0)
);

-- ---------- Категорії ----------
CREATE TABLE categories (
    category_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        VARCHAR(80) NOT NULL UNIQUE
);

-- ---------- Курси ----------
CREATE TABLE courses (
    course_id      INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code           VARCHAR(10)   NOT NULL UNIQUE,          -- напр. PY101
    title          VARCHAR(120)  NOT NULL,
    price          NUMERIC(10,2) NOT NULL,
    duration_weeks SMALLINT      NOT NULL,
    category_id    INTEGER       NOT NULL REFERENCES categories(category_id)
                                 ON UPDATE CASCADE ON DELETE RESTRICT,
    teacher_id     INTEGER       NOT NULL REFERENCES teachers(teacher_id)
                                 ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_courses_code     CHECK (code ~ '^[A-Z]{2,4}[0-9]{3}$'),
    CONSTRAINT chk_courses_price    CHECK (price >= 0),
    CONSTRAINT chk_courses_duration CHECK (duration_weeks > 0)
);

-- ---------- Записи на курси (зв'язок M:N студенти <-> курси) ----------
-- Дата завершення НЕ зберігається (її можна обчислити:
-- start_date + duration_weeks * 7), це дозволяє уникнути надлишковості (3НФ).
CREATE TABLE enrollments (
    enrollment_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    student_id    INTEGER  NOT NULL REFERENCES students(student_id)
                           ON UPDATE CASCADE ON DELETE CASCADE,
    course_id     INTEGER  NOT NULL REFERENCES courses(course_id)
                           ON UPDATE CASCADE ON DELETE RESTRICT,
    start_date    DATE     NOT NULL,
    rating        SMALLINT NULL,                            -- NULL = ще не оцінено
    CONSTRAINT uq_enrollment_student_course UNIQUE (student_id, course_id),
    CONSTRAINT chk_enrollments_rating CHECK (rating BETWEEN 1 AND 100)
);

CREATE INDEX idx_courses_category   ON courses(category_id);
CREATE INDEX idx_courses_teacher    ON courses(teacher_id);
CREATE INDEX idx_enrollments_course ON enrollments(course_id);

-- ---------- Тригер: оцінку можна поставити лише після завершення курсу ----------
CREATE FUNCTION trg_check_rating_after_end() RETURNS trigger AS $$
DECLARE
    v_end_date DATE;
BEGIN
    IF NEW.rating IS NOT NULL THEN
        SELECT NEW.start_date + c.duration_weeks * 7
          INTO v_end_date
          FROM courses c
         WHERE c.course_id = NEW.course_id;

        IF v_end_date > CURRENT_DATE THEN
            RAISE EXCEPTION 'Оцінку можна поставити лише після завершення курсу (завершення: %)', v_end_date;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_enrollments_rating
    BEFORE INSERT OR UPDATE ON enrollments
    FOR EACH ROW EXECUTE FUNCTION trg_check_rating_after_end();
