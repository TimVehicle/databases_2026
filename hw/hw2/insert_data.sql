-- Запускать после schema.sql. Все ссылки получают идентификаторы из стабильных business keys.
SET search_path TO hw2;

INSERT INTO users (name, email, role) VALUES
    ('Анна Преподаватель', 'anna.teacher@example.com', 'teacher'),
    ('Игорь Преподаватель', 'igor.teacher@example.com', 'teacher'),
    ('Алиса Студент', 'alice@example.com', 'student'),
    ('Борис Студент', 'boris@example.com', 'student'),
    ('Вера Студент', 'vera@example.com', 'student');

INSERT INTO courses (code, title, description, price, teacher_id) VALUES
    ('SQL-101', 'Основы SQL', 'Реляционные базы данных и SQL.', 4900.00,
        (SELECT id FROM users WHERE email = 'anna.teacher@example.com')),
    ('PY-101', 'Python для начинающих', 'Базовый курс Python.', 3900.00,
        (SELECT id FROM users WHERE email = 'igor.teacher@example.com')),
    ('DB-DESIGN', 'Проектирование баз данных', 'Курс без отзывов для проверки запроса.', 5500.00,
        (SELECT id FROM users WHERE email = 'anna.teacher@example.com'));

INSERT INTO lessons (course_id, title, content, position) VALUES
    ((SELECT id FROM courses WHERE code = 'SQL-101'), 'SELECT и WHERE', 'Выборка данных.', 1),
    ((SELECT id FROM courses WHERE code = 'SQL-101'), 'JOIN', 'Соединение таблиц.', 2),
    ((SELECT id FROM courses WHERE code = 'PY-101'), 'Переменные', 'Переменные и типы.', 1),
    ((SELECT id FROM courses WHERE code = 'PY-101'), 'Функции', 'Объявление функций.', 2),
    ((SELECT id FROM courses WHERE code = 'DB-DESIGN'), 'Нормализация', 'Нормальные формы.', 1);

INSERT INTO enrollments (user_id, course_id, enrolled_at, status) VALUES
    ((SELECT id FROM users WHERE email = 'alice@example.com'), (SELECT id FROM courses WHERE code = 'SQL-101'), '2026-02-01 10:00:00', 'completed'),
    ((SELECT id FROM users WHERE email = 'alice@example.com'), (SELECT id FROM courses WHERE code = 'PY-101'), '2026-03-01 10:00:00', 'active'),
    ((SELECT id FROM users WHERE email = 'boris@example.com'), (SELECT id FROM courses WHERE code = 'SQL-101'), '2026-03-10 10:00:00', 'active'),
    ((SELECT id FROM users WHERE email = 'vera@example.com'), (SELECT id FROM courses WHERE code = 'DB-DESIGN'), '2026-04-01 10:00:00', 'active');

INSERT INTO reviews (user_id, course_id, rating, comment, created_at) VALUES
    ((SELECT id FROM users WHERE email = 'alice@example.com'), (SELECT id FROM courses WHERE code = 'SQL-101'), 5, 'Понятный курс.', '2026-02-20 12:00:00'),
    ((SELECT id FROM users WHERE email = 'boris@example.com'), (SELECT id FROM courses WHERE code = 'SQL-101'), 4, 'Полезные примеры.', '2026-03-20 12:00:00'),
    ((SELECT id FROM users WHERE email = 'alice@example.com'), (SELECT id FROM courses WHERE code = 'PY-101'), 5, 'Хорошее введение.', '2026-03-15 12:00:00');

INSERT INTO payments (user_id, course_id, amount, platform_fee, paid_at) VALUES
    ((SELECT id FROM users WHERE email = 'alice@example.com'), (SELECT id FROM courses WHERE code = 'SQL-101'), 4900.00, 15.00, '2026-02-01 10:05:00'),
    ((SELECT id FROM users WHERE email = 'alice@example.com'), (SELECT id FROM courses WHERE code = 'PY-101'), 3900.00, 15.00, '2026-03-01 10:05:00'),
    ((SELECT id FROM users WHERE email = 'boris@example.com'), (SELECT id FROM courses WHERE code = 'SQL-101'), 4900.00, 15.00, '2026-03-10 10:05:00'),
    ((SELECT id FROM users WHERE email = 'vera@example.com'), (SELECT id FROM courses WHERE code = 'DB-DESIGN'), 5500.00, 10.00, '2026-04-01 10:05:00');

INSERT INTO lesson_progress (enrollment_id, course_id, lesson_id, status, completed_at) VALUES
    ((SELECT e.id FROM enrollments e JOIN users u ON u.id = e.user_id JOIN courses c ON c.id = e.course_id WHERE u.email = 'alice@example.com' AND c.code = 'SQL-101'),
     (SELECT id FROM courses WHERE code = 'SQL-101'),
     (SELECT l.id FROM lessons l JOIN courses c ON c.id = l.course_id WHERE c.code = 'SQL-101' AND l.position = 1), 'completed', '2026-02-05 11:00:00'),
    ((SELECT e.id FROM enrollments e JOIN users u ON u.id = e.user_id JOIN courses c ON c.id = e.course_id WHERE u.email = 'alice@example.com' AND c.code = 'SQL-101'),
     (SELECT id FROM courses WHERE code = 'SQL-101'),
     (SELECT l.id FROM lessons l JOIN courses c ON c.id = l.course_id WHERE c.code = 'SQL-101' AND l.position = 2), 'completed', '2026-02-10 11:00:00'),
    ((SELECT e.id FROM enrollments e JOIN users u ON u.id = e.user_id JOIN courses c ON c.id = e.course_id WHERE u.email = 'alice@example.com' AND c.code = 'PY-101'),
     (SELECT id FROM courses WHERE code = 'PY-101'),
     (SELECT l.id FROM lessons l JOIN courses c ON c.id = l.course_id WHERE c.code = 'PY-101' AND l.position = 1), 'completed', '2026-03-03 11:00:00'),
    ((SELECT e.id FROM enrollments e JOIN users u ON u.id = e.user_id JOIN courses c ON c.id = e.course_id WHERE u.email = 'alice@example.com' AND c.code = 'PY-101'),
     (SELECT id FROM courses WHERE code = 'PY-101'),
     (SELECT l.id FROM lessons l JOIN courses c ON c.id = l.course_id WHERE c.code = 'PY-101' AND l.position = 2), 'in_progress', NULL);

INSERT INTO payouts (payment_id, teacher_id, amount, paid_at)
SELECT p.id,
       c.teacher_id,
       p.amount * (1 - p.platform_fee / 100),
       '2026-02-11 09:00:00'
FROM payments p
JOIN courses c ON c.id = p.course_id
WHERE p.user_id = (SELECT id FROM users WHERE email = 'alice@example.com')
  AND c.code = 'SQL-101';
