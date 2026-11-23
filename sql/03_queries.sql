-- =====================================================================
-- Запити 1–16. Запуск після 01_schema.sql та 02_data.sql
-- Дата завершення курсу = start_date + duration_weeks * 7
-- =====================================================================

-- 1. Імена та прізвища студентів і назви курсів, на які вони записувалися
SELECT s.first_name, s.last_name, c.title
FROM enrollments e
JOIN students s ON s.student_id = e.student_id
JOIN courses  c ON c.course_id  = e.course_id
ORDER BY s.last_name, s.first_name, c.title;

-- 2. Представлення за запитом 1
CREATE OR REPLACE VIEW v_student_courses AS
SELECT s.first_name, s.last_name, c.title
FROM enrollments e
JOIN students s ON s.student_id = e.student_id
JOIN courses  c ON c.course_id  = e.course_id;

SELECT * FROM v_student_courses ORDER BY last_name, first_name, title;

-- 3. Оцінка Олени Коваленко для курсу PY101
SELECT e.rating
FROM enrollments e
JOIN students s ON s.student_id = e.student_id
JOIN courses  c ON c.course_id  = e.course_id
WHERE s.first_name = 'Олена' AND s.last_name = 'Коваленко'
  AND c.code = 'PY101';

-- 4. Студенти, які поставили хоча б одну оцінку нижче 60
SELECT DISTINCT s.student_id, s.first_name, s.last_name
FROM students s
JOIN enrollments e ON e.student_id = s.student_id
WHERE e.rating < 60;

-- 5. Студенти, які записувалися на PY101 та вже залишили оцінку
SELECT s.first_name, s.last_name, e.rating
FROM students s
JOIN enrollments e ON e.student_id = s.student_id
JOIN courses c     ON c.course_id  = e.course_id
WHERE c.code = 'PY101'
  AND e.rating IS NOT NULL;

-- 6. Середня оцінка та кількість записів для кожного студента
--    (включно зі студентами без записів)
SELECT s.student_id, s.first_name, s.last_name,
       ROUND(AVG(e.rating), 2)   AS avg_rating,
       COUNT(e.enrollment_id)    AS enrollments_count
FROM students s
LEFT JOIN enrollments e ON e.student_id = s.student_id
GROUP BY s.student_id, s.first_name, s.last_name
ORDER BY s.student_id;

-- 7. Студенти із середньою оцінкою вище 80
SELECT s.first_name, s.last_name, ROUND(AVG(e.rating), 2) AS avg_rating
FROM students s
JOIN enrollments e ON e.student_id = s.student_id
GROUP BY s.student_id, s.first_name, s.last_name
HAVING AVG(e.rating) > 80;

-- 8. Курси, на які ще ніхто не записувався
SELECT c.course_id, c.code, c.title
FROM courses c
LEFT JOIN enrollments e ON e.course_id = c.course_id
WHERE e.enrollment_id IS NULL;

-- 9. Студенти, які народилися в тому ж місяці, що й Олена Коваленко
--    (саму Олену не включати)
SELECT s.first_name, s.last_name, s.birth_date
FROM students s
WHERE EXTRACT(MONTH FROM s.birth_date) = (
        SELECT EXTRACT(MONTH FROM o.birth_date)
        FROM students o
        WHERE o.first_name = 'Олена' AND o.last_name = 'Коваленко')
  AND NOT (s.first_name = 'Олена' AND s.last_name = 'Коваленко');

-- 10. Студенти із середньою оцінкою вищою, ніж у Олени Коваленко
SELECT s.first_name, s.last_name, ROUND(AVG(e.rating), 2) AS avg_rating
FROM students s
JOIN enrollments e ON e.student_id = s.student_id
GROUP BY s.student_id, s.first_name, s.last_name
HAVING AVG(e.rating) > (
        SELECT AVG(e2.rating)
        FROM enrollments e2
        JOIN students o ON o.student_id = e2.student_id
        WHERE o.first_name = 'Олена' AND o.last_name = 'Коваленко');

-- 11. Курси, вартість яких більша, ніж у курсу PY101
SELECT code, title, price
FROM courses
WHERE price > (SELECT price FROM courses WHERE code = 'PY101');

-- 12. студент | курс | оцінка, де оцінка більша за будь-яку оцінку Олени
--     (тобто більша за кожну з її оцінок — вища за її максимум)
--     Примітка: якщо потрібно «більша хоча б за одну» — замініть ALL на ANY.
SELECT s.first_name || ' ' || s.last_name AS student,
       c.title                            AS course,
       e.rating
FROM enrollments e
JOIN students s ON s.student_id = e.student_id
JOIN courses  c ON c.course_id  = e.course_id
WHERE e.rating > ALL (
        SELECT e2.rating
        FROM enrollments e2
        JOIN students o ON o.student_id = e2.student_id
        WHERE o.first_name = 'Олена' AND o.last_name = 'Коваленко'
          AND e2.rating IS NOT NULL)   -- NULL у ALL зробив би результат порожнім
ORDER BY e.rating DESC;

-- 13. студент | курс | оцінка текстом
SELECT s.first_name || ' ' || s.last_name AS student,
       c.title                            AS course,
       CASE
           WHEN e.rating IS NULL  THEN 'ще не оцінено'
           WHEN e.rating >= 90    THEN 'відмінно'
           WHEN e.rating >= 75    THEN 'добре'
           WHEN e.rating >= 60    THEN 'задовільно'
           ELSE 'незадовільно'
       END AS rating_text
FROM enrollments e
JOIN students s ON s.student_id = e.student_id
JOIN courses  c ON c.course_id  = e.course_id
ORDER BY s.last_name, c.title;

-- 14. Для кожної категорії: кількість курсів, кількість записів, середня оцінка
--     (COUNT(DISTINCT ...) — щоб JOIN із записами не дублював курси)
SELECT cat.name AS category,
       COUNT(DISTINCT c.course_id)   AS courses_count,
       COUNT(e.enrollment_id)        AS enrollments_count,
       ROUND(AVG(e.rating), 2)       AS avg_rating
FROM categories cat
LEFT JOIN courses c     ON c.category_id = cat.category_id
LEFT JOIN enrollments e ON e.course_id   = c.course_id
GROUP BY cat.category_id, cat.name
ORDER BY cat.name;

-- 15. Викладачі, середня оцінка курсів яких вища за середню оцінку всіх курсів платформи
SELECT t.first_name, t.last_name, ROUND(AVG(e.rating), 2) AS avg_rating
FROM teachers t
JOIN courses c     ON c.teacher_id = t.teacher_id
JOIN enrollments e ON e.course_id  = c.course_id
GROUP BY t.teacher_id, t.first_name, t.last_name
HAVING AVG(e.rating) > (SELECT AVG(rating) FROM enrollments);

-- 16. Студенти, які проходять курс зараз: назва курсу, дата завершення, залишок днів
SELECT s.first_name, s.last_name, c.title,
       (e.start_date + c.duration_weeks * 7)                 AS end_date,
       (e.start_date + c.duration_weeks * 7) - CURRENT_DATE  AS days_left
FROM enrollments e
JOIN students s ON s.student_id = e.student_id
JOIN courses  c ON c.course_id  = e.course_id
WHERE e.start_date + c.duration_weeks * 7 > CURRENT_DATE
ORDER BY days_left;
