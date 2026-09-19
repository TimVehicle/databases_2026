# ДЗ №2 — EdTech: целостность, данные и запросы

Решение расширяет модель ДЗ №1 для платформы онлайн-обучения. Работа полностью изолирована в схеме PostgreSQL `hw2` и не меняет `hw1`.

## Инициализация

Выполнить файлы в следующем порядке:

1. `schema.sql` — создаёт модель и индексы.
2. `insert_data.sql` — добавляет демонстрационные данные.
3. `queries.sql` — выполняет пять частых запросов ДЗ №1, запрос к прогрессу по урокам и запрос к выплатам преподавателя.
4. `constraint_violations.sql` — демонстрирует обработку пяти нарушений целостности.

`schema.sql` можно безопасно запускать повторно: 

```sql
DROP SCHEMA IF EXISTS hw2 CASCADE;
CREATE SCHEMA hw2;
```

`CASCADE` удаляет таблицы, ограничения, индексы, последовательности и данные **внутри** `hw2`, после чего схема создаётся заново. Объекты `hw1` и других схем не затрагиваются.

## Модель

Базовые сущности: `users`, `courses`, `lessons`, `enrollments`, `reviews`, `payments`. 

Новые сущности:

`lesson_progress` —  статус прохождения урока в рамках записи на курс
  
`payouts` —  то есть выплата преподавателю, связанная с конкретным платежом за курс.

`payouts` хранит получателя выплаты, сумму и дату. Ограничение `UNIQUE (payment_id)` не допускает две выплаты по одному платежу, а `CHECK (amount > 0)` исключает нулевые и отрицательные суммы:

```sql
payment_id INTEGER NOT NULL,
teacher_id INTEGER NOT NULL,
amount NUMERIC(10, 2) NOT NULL,
CONSTRAINT uq_payouts_payment UNIQUE (payment_id),
CONSTRAINT chk_payouts_amount CHECK (amount > 0)
```

Связи выплаты с платежом и получателем определены через FK:

```sql
FOREIGN KEY (payment_id) REFERENCES payments(id),
FOREIGN KEY (teacher_id) REFERENCES users(id)
```

Роль получателя и связь с курсом проверяет триггер `trg_validate_payout`. Например, функция отклонит выплату студенту, выплату не преподавателю оплаченного курса или сумму выше платежа после вычета комиссии:

```sql
IF teacher_role IS DISTINCT FROM 'teacher' THEN
    RAISE EXCEPTION 'Получателем выплаты может быть только преподаватель';
END IF;
IF NEW.teacher_id IS DISTINCT FROM course_teacher_id THEN
    RAISE EXCEPTION 'Получатель выплаты должен быть преподавателем оплаченного курса';
END IF;
IF NEW.amount > maximum_payout THEN
    RAISE EXCEPTION 'Сумма выплаты не может превышать сумму платежа за вычетом комиссии платформы';
END IF;
```

## Связи

Логическая связь «пользователь учится на курсах» — M:N. Она реализована таблицей `enrollments`: каждая строка хранит два FK и ограничение `UNIQUE (user_id, course_id)`, поэтому повторная запись на тот же курс невозможна

```sql
CONSTRAINT uq_enrollments_user_course UNIQUE (user_id, course_id)
```

`lesson_progress` ссылается одновременно на `(enrollment_id, course_id)` и `(lesson_id, course_id)`. Поэтому, например, нельзя привязать к записи на SQL-курс урок из Python-курса

## Каскады

`ON DELETE CASCADE` задан у уроков курса:

```sql
course_id INTEGER NOT NULL REFERENCES courses(id) ON DELETE CASCADE
```

Поэтому при удалении курса без других блокирующих ссылок, например `DELETE FROM courses WHERE id = 12`, его уроки удаляются автоматически. У каждого урока затем срабатывает второй каскад к `lesson_progress`

```sql
FOREIGN KEY (enrollment_id, course_id)
    REFERENCES enrollments(id, course_id) ON DELETE CASCADE,
FOREIGN KEY (lesson_id, course_id)
    REFERENCES lessons(id, course_id) ON DELETE CASCADE
```

Аналогично, удаление записи студента на курс удаляет её прогресс по FK `fk_progress_enrollment_course`.

Удаление пользователя осознанно не каскадируется: код `user_id INTEGER NOT NULL REFERENCES users(id)` в `enrollments` задан без `ON DELETE CASCADE`. Поэтому команда `DELETE FROM users WHERE id = 3` будет отклонена, пока существуют записи на курсы; так сохраняется история обучения. 

У `payouts` также не указан `ON DELETE CASCADE`, поэтому для внешних ключей `payment_id` и `teacher_id` используется поведение `NO ACTION`. Это не позволяет удалить платеж или пользователя, если на соответствующую запись ссылается выплата. Сначала необходимо удалить или изменить связанную запись payouts

## Частые запросы ДЗ №1 и индексы

### 1. История платежей конкретного пользователя

Фрагмент из `queries.sql`
```sql
FROM payments p JOIN users u ON u.id = p.user_id
WHERE u.email = 'alice@example.com'
ORDER BY p.paid_at DESC;
```

Индекс `idx_payments_user_paid_at ON payments(user_id, paid_at DESC)` позволяет быстро найти платежи выбранного пользователя уже в нужном порядке. Уникальное ограничение `uq_users_email` также создаёт индекс для поиска пользователя по `email`.

### 2. Курсы с наибольшей суммой комиссий
```sql
FROM courses c LEFT JOIN payments p ON p.course_id = c.id
GROUP BY c.id, c.code, c.title
ORDER BY platform_commission DESC;
```

Отдельный индекс для этого запроса не создаётся: агрегация ранжирует **все** курсы по сумме всех их платежей, поэтому PostgreSQL всё равно должен обработать все подходящие строки `payments`. Последовательное чтение в таком сценарии абсолютно нормально

### 3. Суммы платежей и комиссий за период
```sql
WHERE p.paid_at >= DATE '2026-02-01'
  AND p.paid_at < DATE '2026-04-01';
```

Индекс `idx_payments_paid_at ON payments(paid_at)` позволяет PostgreSQL выбрать только платежи нужного периода до вычисления `SUM(amount)` и комиссии.

### 4. Студенты, записанные более чем на один курс


```sql
FROM enrollments e JOIN users u ON u.id = e.user_id
WHERE u.role = 'student'
GROUP BY u.id, u.name, u.email
HAVING COUNT(*) > 1;
```

 

Ограничение `uq_enrollments_user_course` создаёт индекс `UNIQUE (user_id, course_id)`: он исключает дубли записей и поддерживает отдельный сценарий выбора курсов конкретного пользователя, но не гарантирует индексный план для этой глобальной агрегации.

### 5. Курсы без отзывов
```sql
FROM courses c LEFT JOIN reviews r ON r.course_id = c.id
WHERE r.id IS NULL;
```

Индекс `idx_reviews_course_id ON reviews(course_id)` поддерживает проверку наличия отзывов у каждого курса. 

## Индексы новой таблицы*

Запрос прогресса из `queries.sql` соединяет `lesson_progress` с конкретной записью на курс
```sql
FROM lesson_progress lp
JOIN enrollments e ON e.id = lp.enrollment_id
WHERE u.email = 'alice@example.com' AND c.code = 'PY-101';
```

Ограничение `uq_progress_enrollment_lesson UNIQUE (enrollment_id, lesson_id)` создаёт индекс с первым полем `enrollment_id`. После нахождения `enrollments` для выбранных пользователя и курса он поддерживает поиск строк прогресса этой записи.

Запрос выплат из `queries.sql` выбирает выплаты конкретного преподавателя и сортирует их по дате
```sql
FROM payouts po
JOIN users teacher ON teacher.id = po.teacher_id
WHERE teacher.email = 'anna.teacher@example.com'
ORDER BY po.paid_at DESC;
```

Индекс `idx_payouts_teacher_paid_at ON payouts(teacher_id, paid_at DESC)` поддерживает фильтрацию по преподавателю и обратную хронологическую сортировку. В `insert_data.sql` добавлена выплата Анне Преподавателю по платежу Алисы за курс `SQL-101`.


## Документация нарушений

| № | Ограничение | Запрос | Error msg СУБД | Интерпретация | Решение |
| --- | --- | --- | --- | --- | --- |
| 1 | `CHECK chk_reviews_rating` | `INSERT INTO reviews (user_id, course_id, rating) VALUES ((SELECT id FROM users LIMIT 1), (SELECT id FROM courses LIMIT 1), 6);` | `NOTICE:  Нельзя поставить оценку 6 new row for relation "reviews" violates check constraint "chk_reviews_rating"` | Оценка может быть только от 1 до 5. | Передать значение в диапазоне 1–5. |
| 2 | `FK enrollments.course_id` | `INSERT INTO enrollments (user_id, course_id, status) VALUES ((SELECT id FROM users LIMIT 1), 999999, 'active');` | `NOTICE:  Несуществующий курс insert or update on table "enrollments" violates foreign key constraint "enrollments_course_id_fkey"` | Нельзя записаться на отсутствующий курс. | Использовать существующий курс. |
| 3 | `UNIQUE uq_users_email` | `INSERT INTO users (name, email, role) VALUES ('Клон Алисы', 'alice@example.com', 'student');` | `NOTICE:  Такой email уже зарегистрирован duplicate key value violates unique constraint "uq_users_email"` | Этот email уже зарегистрирован. | Указать другой адрес или войти в существующий аккаунт. |
| 4 | `NOT NULL courses.title` | `INSERT INTO courses (code, title, price, teacher_id) VALUES ('EMPTY-TITLE', NULL, 1000, (SELECT id FROM users WHERE email = 'anna.teacher@example.com'));` | `NOTICE:  Нельзя создать курс без названия null value in column "title" of relation "courses" violates not-null constraint` | У курса должно быть название. | Передать непустое название. |
| 5 | `PRIMARY KEY lessons_pkey` | `INSERT INTO lessons (id, course_id, title, position) VALUES ((SELECT id FROM lessons LIMIT 1), (SELECT id FROM courses WHERE code = 'SQL-101'), 'Дублирующий урок', 99);` | `NOTICE:  Нельзя создать второй урок с тем же идентификатором duplicate key value violates unique constraint "lessons_pkey"` | Урок с этим идентификатором уже существует. | Не задавать ID вручную либо использовать новый ID. |

Все пять сценариев в `constraint_violations.sql` используют `DO ... EXCEPTION`, поэтому ошибка перехватывается, в `NOTICE` выводится её бизнес-смысл и исходный текст PostgreSQL из `SQLERRM`.
