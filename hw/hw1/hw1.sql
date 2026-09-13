DROP SCHEMA IF EXISTS hw1 CASCADE;
CREATE SCHEMA hw1;
SET search_path TO hw1;

CREATE TABLE "User" (
    "id" SERIAL PRIMARY KEY, -- SERIAL: автоматически увеличивающийся идентификатор
    "name" VARCHAR(100) NOT NULL, -- VARCHAR(100): строка длиной до 100 символов, NOT NULL: значение обязательно
    "email" VARCHAR(255) NOT NULL UNIQUE, -- UNIQUE: значение должно быть уникальным
    "role" VARCHAR(8) NOT NULL, -- student or teacher
    "created_at" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP -- TIMESTAMP: дата и время, DEFAULT CURRENT_TIMESTAMP: значение по умолчанию - текущая дата и время
);

CREATE TABLE Course (
    "id" SERIAL PRIMARY KEY,
    "title" VARCHAR(200) NOT NULL,
    "description" TEXT, -- TEXT: строка произвольной длины для описания курса
    "price" DECIMAL(10,2) NOT NULL, -- DECIMAL(10,2): десятичное число, 10 знаков всего, 2 знака в дробной части
    "teacher_id" INTEGER NOT NULL REFERENCES "User"("id"), -- INTEGER: целое число, REFERENCES "User"(id): ссылка на таблицу "User" по полю id
    "created_at" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE Lesson (
    "id" SERIAL PRIMARY KEY, 
    "course_id" INTEGER NOT NULL REFERENCES Course("id"), -- REFERENCES Course(id): ссылка на таблицу "Course" по полю id
    "title" VARCHAR(200) NOT NULL,
    "content" TEXT, -- TEXT: строка произвольной длины для описания урока
    "position" INTEGER NOT NULL 
);

CREATE TABLE Enrollment (
    "id" SERIAL PRIMARY KEY, 
    "user_id" INTEGER NOT NULL REFERENCES "User"("id"), --  REFERENCES "User"(id): ссылка на таблицу "User" по полю id
    "course_id" INTEGER NOT NULL REFERENCES Course("id"), --  REFERENCES Course(id): ссылка на таблицу "Course" по полю id
    "enrolled_at" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, 
    "status" VARCHAR(20) NOT NULL 
);

CREATE TABLE Review (
    "id" SERIAL PRIMARY KEY, 
    "user_id" INTEGER NOT NULL REFERENCES "User"("id"), --  REFERENCES "User"(id): ссылка на таблицу "User" по полю id
    "course_id" INTEGER NOT NULL REFERENCES Course("id"), --  REFERENCES Course(id): ссылка на таблицу "Course" по полю id
    "rating" INTEGER NOT NULL CHECK ("rating" BETWEEN 1 AND 5), -- CHECK ("rating" BETWEEN 1 AND 5): проверка, что рейтинг находится в диапазоне от 1 до 5
    "comment" TEXT, -- TEXT: строка произвольной длины для сообщения отзыва
    "created_at" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP 
);

CREATE TABLE Payment (
    "id" SERIAL PRIMARY KEY, 
    "user_id" INTEGER NOT NULL REFERENCES "User"("id"), --  REFERENCES "User"(id): ссылка на таблицу "User" по полю id
    "course_id" INTEGER NOT NULL REFERENCES Course("id"), --  REFERENCES Course(id): ссылка на таблицу "Course" по полю id
    "amount" DECIMAL(10,2) NOT NULL CHECK ("amount" >= 0),
    "platform_fee" DECIMAL(5,2) NOT NULL CHECK ("platform_fee" BETWEEN 0 AND 100),  -- DECIMAL(5,2): десятичное число, 5 знаков всего, 2 знака в дробной части, например 10.00 - 10% от суммы платежа 
    "paid_at" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP 
);


CREATE INDEX idx_course_teacher_id ON Course ("teacher_id");
CREATE INDEX idx_lesson_course_id ON Lesson ("course_id");

CREATE INDEX idx_enrollment_user_id ON Enrollment ("user_id");
CREATE INDEX idx_enrollment_course_id ON Enrollment ("course_id");

CREATE INDEX idx_review_user_id ON Review ("user_id");
CREATE INDEX idx_review_course_id ON Review ("course_id");

CREATE INDEX idx_payment_user_id ON Payment ("user_id");
CREATE INDEX idx_payment_course_id ON Payment ("course_id");
