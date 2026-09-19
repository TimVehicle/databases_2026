-- Запускать после schema.sql и insert_data.sql. Ровно пять демонстраций ошибок.
SET search_path TO hw2;

-- 1. CHECK: оценка отзыва не может выйти за диапазон 1..5.
DO $$
BEGIN
    INSERT INTO reviews (user_id, course_id, rating)
    VALUES ((SELECT id FROM users LIMIT 1),
            (SELECT id FROM courses LIMIT 1), 
            6);
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Нельзя поставить оценку 6 %', SQLERRM;
END;
$$;

-- 2. FOREIGN KEY: нельзя записать студента на отсутствующий курс.
DO $$
BEGIN
    INSERT INTO enrollments (user_id, course_id, status)
    VALUES ((SELECT id FROM users LIMIT 1), 999999, 'active');
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Несуществующий курс %', SQLERRM;
END;
$$;

-- 3. UNIQUE: один email соответствует только одному пользователю.
DO $$
BEGIN
    INSERT INTO users (name, email, role) 
    VALUES ('Клон Алисы', 'alice@example.com', 'student');
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Такой email уже зарегистрирован %', SQLERRM;
END;
$$;

-- 4. NOT NULL: у курса обязательно должно быть название.
DO $$
BEGIN
    INSERT INTO courses (code, title, price, teacher_id)
    VALUES ('EMPTY-TITLE', NULL, 1000, (SELECT id FROM users WHERE email = 'anna.teacher@example.com'));
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Нельзя создать курс без названия %', SQLERRM;
END;
$$;

-- 5. PRIMARY KEY: идентификатор урока должен быть уникальным.
DO $$
BEGIN
    INSERT INTO lessons (id, course_id, title, position)
    VALUES ((SELECT id FROM lessons LIMIT 1),
            (SELECT id FROM courses WHERE code = 'SQL-101'), 'Дублирующий урок', 99);
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Нельзя создать второй урок с тем же идентификатором %', SQLERRM;
END;
$$;
