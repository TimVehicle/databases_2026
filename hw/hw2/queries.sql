SET search_path TO hw2;

-- 1. История платежей пользователя. Замените email в CTE при необходимости.
WITH params AS (SELECT 'alice@example.com'::VARCHAR AS email)
SELECT c.title, p.amount, p.platform_fee, p.paid_at
FROM payments p JOIN users u ON u.id = p.user_id JOIN courses c ON c.id = p.course_id
JOIN params x ON x.email = u.email
ORDER BY p.paid_at DESC;

-- 2. Курсы с наибольшей суммой комиссий платформы.
SELECT c.code, c.title, COALESCE(SUM(p.amount * p.platform_fee / 100), 0) AS platform_commission
FROM courses c LEFT JOIN payments p ON p.course_id = c.id
GROUP BY c.id, c.code, c.title
ORDER BY platform_commission DESC, c.title;

-- 3. Суммы платежей и комиссий за период.
WITH params AS (SELECT DATE '2026-02-01' AS date_from, DATE '2026-04-01' AS date_to)
SELECT COALESCE(SUM(p.amount), 0) AS payment_total,
       COALESCE(SUM(p.amount * p.platform_fee / 100), 0) AS commission_total
FROM payments p CROSS JOIN params x
WHERE p.paid_at >= x.date_from AND p.paid_at < x.date_to;

-- 4. Студенты, записанные более чем на один курс.
SELECT u.name, u.email, COUNT(*) AS enrolled_courses
FROM enrollments e JOIN users u ON u.id = e.user_id
WHERE u.role = 'student'
GROUP BY u.id, u.name, u.email
HAVING COUNT(*) > 1
ORDER BY enrolled_courses DESC, u.name;

-- 5. Курсы, у которых ещё нет отзывов.
SELECT c.code, c.title
FROM courses c LEFT JOIN reviews r ON r.course_id = c.id
WHERE r.id IS NULL
ORDER BY c.title;

-- 6. Прогресс указанного студента по урокам указанного курса.
WITH params AS (SELECT 'alice@example.com'::VARCHAR AS email, 'PY-101'::VARCHAR AS course_code)
SELECT l.position, l.title AS lesson_title, lp.status, lp.completed_at
FROM lesson_progress lp
JOIN enrollments e ON e.id = lp.enrollment_id
JOIN users u ON u.id = e.user_id
JOIN courses c ON c.id = lp.course_id
JOIN lessons l ON l.id = lp.lesson_id
JOIN params x ON x.email = u.email AND x.course_code = c.code
ORDER BY l.position;

-- 7. Выплаты указанному преподавателю с данными исходного платежа и курса.
WITH params AS (SELECT 'anna.teacher@example.com'::VARCHAR AS email)
SELECT po.id AS payout_id,
       c.code,
       c.title,
       p.amount AS payment_amount,
       po.amount AS payout_amount,
       po.paid_at
FROM payouts po
JOIN users teacher ON teacher.id = po.teacher_id
JOIN payments p ON p.id = po.payment_id
JOIN courses c ON c.id = p.course_id
JOIN params x ON x.email = teacher.email
ORDER BY po.paid_at DESC;
