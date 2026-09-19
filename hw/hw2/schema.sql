-- ДЗ №2. Самодостаточная модель EdTech-платформы (PostgreSQL).
DROP SCHEMA IF EXISTS hw2 CASCADE;
CREATE SCHEMA hw2;
SET search_path TO hw2;

CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL CONSTRAINT uq_users_email UNIQUE,
    role VARCHAR(10) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_users_role CHECK (role IN ('student', 'teacher'))
);

CREATE TABLE courses (
    id SERIAL PRIMARY KEY,
    code VARCHAR(20) NOT NULL CONSTRAINT uq_courses_code UNIQUE,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    price NUMERIC(10, 2) NOT NULL,
    teacher_id INTEGER NOT NULL REFERENCES users(id),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_courses_price CHECK (price >= 0)
);

CREATE TABLE lessons (
    id SERIAL PRIMARY KEY,
    course_id INTEGER NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    title VARCHAR(200) NOT NULL,
    content TEXT,
    position INTEGER NOT NULL,
    
    CONSTRAINT chk_lessons_position CHECK (position > 0),
    CONSTRAINT uq_lessons_course_position UNIQUE (course_id, position),
    CONSTRAINT uq_lessons_id_course UNIQUE (id, course_id)
);

CREATE TABLE enrollments (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id),
    course_id INTEGER NOT NULL REFERENCES courses(id),
    enrolled_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) NOT NULL DEFAULT 'active',

    CONSTRAINT chk_enrollments_status CHECK (status IN ('active', 'completed', 'cancelled')),
    CONSTRAINT uq_enrollments_user_course UNIQUE (user_id, course_id),
    CONSTRAINT uq_enrollments_id_course UNIQUE (id, course_id)
);

CREATE TABLE reviews (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id),
    course_id INTEGER NOT NULL REFERENCES courses(id),
    rating INTEGER NOT NULL,
    comment TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_reviews_rating CHECK (rating BETWEEN 1 AND 5),
    CONSTRAINT uq_reviews_user_course UNIQUE (user_id, course_id)
);

CREATE TABLE payments (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id),
    course_id INTEGER NOT NULL REFERENCES courses(id),
    amount NUMERIC(10, 2) NOT NULL,
    platform_fee NUMERIC(5, 2) NOT NULL,
    paid_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_payments_amount CHECK (amount > 0),
    CONSTRAINT chk_payments_platform_fee CHECK (platform_fee BETWEEN 0 AND 100)
);

-- Новая сущность: статус прохождения конкретного урока в записи на курс
CREATE TABLE lesson_progress (
    id SERIAL PRIMARY KEY,
    enrollment_id INTEGER NOT NULL,
    course_id INTEGER NOT NULL,
    lesson_id INTEGER NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'not_started',
    completed_at TIMESTAMP,

    CONSTRAINT fk_progress_enrollment_course
        FOREIGN KEY (enrollment_id, course_id)
        REFERENCES enrollments(id, course_id) ON DELETE CASCADE,
    
    CONSTRAINT fk_progress_lesson_course
        FOREIGN KEY (lesson_id, course_id)
        REFERENCES lessons(id, course_id) ON DELETE CASCADE,
    
    CONSTRAINT chk_progress_status CHECK (status IN ('not_started', 'in_progress', 'completed')),
    
    CONSTRAINT chk_progress_completion_time CHECK (
        (status = 'completed' AND completed_at IS NOT NULL)
        OR (status IN ('not_started', 'in_progress') AND completed_at IS NULL)
    ),
    CONSTRAINT uq_progress_enrollment_lesson UNIQUE (enrollment_id, lesson_id)
);

-- Новая сущность: выплаты преподавателю
CREATE TABLE payouts (
    id SERIAL PRIMARY KEY,
    payment_id INTEGER NOT NULL,
    teacher_id INTEGER NOT NULL,
    amount NUMERIC(10, 2) NOT NULL,
    paid_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_payouts_payment
        FOREIGN KEY (payment_id)
        REFERENCES payments(id),

    CONSTRAINT fk_payouts_teacher
        FOREIGN KEY (teacher_id)
        REFERENCES users(id),

    CONSTRAINT uq_payouts_payment
        UNIQUE (payment_id),

    CONSTRAINT chk_payouts_amount
        CHECK (amount > 0)
);

-- Выплата разрешена только преподавателю, создавшему курс из исходного платежа.
CREATE FUNCTION validate_payout() RETURNS TRIGGER AS $$
DECLARE
    course_teacher_id INTEGER;
    teacher_role VARCHAR(10);
    maximum_payout NUMERIC(10, 2);
BEGIN
    SELECT c.teacher_id, p.amount * (1 - p.platform_fee / 100)
    INTO course_teacher_id, maximum_payout
    FROM payments p
    JOIN courses c ON c.id = p.course_id
    WHERE p.id = NEW.payment_id;

    SELECT role INTO teacher_role
    FROM users
    WHERE id = NEW.teacher_id;

    IF teacher_role IS DISTINCT FROM 'teacher' THEN
        RAISE EXCEPTION 'Получателем выплаты может быть только преподаватель';
    END IF;

    IF NEW.teacher_id IS DISTINCT FROM course_teacher_id THEN
        RAISE EXCEPTION 'Получатель выплаты должен быть преподавателем оплаченного курса';
    END IF;

    IF NEW.amount > maximum_payout THEN
        RAISE EXCEPTION 'Сумма выплаты не может превышать сумму платежа за вычетом комиссии платформы';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validate_payout
BEFORE INSERT OR UPDATE OF payment_id, teacher_id, amount ON payouts
FOR EACH ROW EXECUTE FUNCTION validate_payout();

-- Индексы под частые запросы из ДЗ №1.

-- Ускоряет LEFT JOIN для поиска курсов без отзывов и расчёт рейтинга курса.
CREATE INDEX idx_reviews_course_id ON reviews(course_id);

-- Ускоряет историю платежей конкретного пользователя с сортировкой по дате.
CREATE INDEX idx_payments_user_paid_at ON payments(user_id, paid_at DESC);

-- Ускоряет отчёт ДЗ №1 по платежам и комиссиям за период.
CREATE INDEX idx_payments_paid_at ON payments(paid_at);

-- Ускоряет вывод выплат конкретного преподавателя в обратном хронологическом порядке.
CREATE INDEX idx_payouts_teacher_paid_at ON payouts(teacher_id, paid_at DESC);
