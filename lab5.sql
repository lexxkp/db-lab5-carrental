-- ==========================================
-- ЧАСТЬ 1. СОЗДАНИЕ СТРУКТУРЫ БД
-- ==========================================
CREATE DATABASE IF NOT EXISTS car_rental_db;
USE car_rental_db;

CREATE TABLE categories (
    category_id VARCHAR(10) PRIMARY KEY,
    category_name VARCHAR(50) NOT NULL,
    daily_rate DECIMAL(10, 2) CHECK (daily_rate > 0)
);

CREATE TABLE cars (
    car_id VARCHAR(10) PRIMARY KEY,
    license_plate VARCHAR(15) UNIQUE NOT NULL,
    brand VARCHAR(50) NOT NULL,
    category_id VARCHAR(10),
    CONSTRAINT fk_cars_categories FOREIGN KEY (category_id) REFERENCES categories(category_id) ON DELETE RESTRICT
);

CREATE TABLE clients (
    client_id VARCHAR(10) PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20) NOT NULL
);

CREATE TABLE managers (
    manager_id VARCHAR(10) PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL
);

-- Таблица rentals
CREATE TABLE rentals (
    car_id VARCHAR(10),
    client_id VARCHAR(10),
    start_date DATE NOT NULL DEFAULT (CURRENT_DATE),
    manager_id VARCHAR(10),
    end_date DATE CHECK (end_date > start_date),
    total_amount DECIMAL(10, 2) CHECK (total_amount > 0),
    PRIMARY KEY (car_id, client_id, start_date),
    CONSTRAINT fk_rentals_cars FOREIGN KEY (car_id) REFERENCES cars(car_id),
    CONSTRAINT fk_rentals_clients FOREIGN KEY (client_id) REFERENCES clients(client_id),
    CONSTRAINT fk_rentals_managers FOREIGN KEY (manager_id) REFERENCES managers(manager_id)
);

-- Триггеры для проверки даты
DELIMITER //
CREATE TRIGGER trg_rentals_check_start_date_insert
BEFORE INSERT ON rentals
FOR EACH ROW
BEGIN
    IF NEW.start_date > CURRENT_DATE THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Дата начала аренды не может быть в будущем.';
    END IF;
END //

CREATE TRIGGER trg_rentals_check_start_date_update
BEFORE UPDATE ON rentals
FOR EACH ROW
BEGIN
    IF NEW.start_date > CURRENT_DATE THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Дата начала аренды не может быть в будущем.';
    END IF;
END //
DELIMITER ;

-- ALTER TABLE
ALTER TABLE cars ADD COLUMN temp_comment VARCHAR(50);
ALTER TABLE cars DROP COLUMN temp_comment;

-- INSERT 
INSERT INTO categories (category_id, category_name, daily_rate) VALUES
('C01', 'Эконом', 1500.00),
('C02', 'Комфорт', 2500.00),
('C03', 'Бизнес', 5000.00);

INSERT INTO cars (car_id, license_plate, brand, category_id) VALUES
('CAR001', 'А123ВС77', 'Toyota Camry', 'C02'),
('CAR002', 'В456ОР77', 'Kia Rio', 'C01'),
('CAR003', 'С789КН77', 'Mercedes E-class', 'C03');

INSERT INTO clients (client_id, full_name, phone) VALUES
('CL001', 'Иванов Иван Иванович', '+79001112233'),
('CL002', 'Петров Петр Петрович', '+79004445566'),
('CL003', 'Сидоров Сидор Сидорович', '+79007778899');

INSERT INTO managers (manager_id, full_name) VALUES
('M01', 'Смирнов А.В.'),
('M02', 'Кузнецова Е.М.');

-- Даты вставлены из прошлого (2023), чтобы не сработал триггер
INSERT INTO rentals (car_id, client_id, start_date, manager_id, end_date, total_amount) VALUES
('CAR001', 'CL001', '2023-11-01', 'M01', '2023-11-05', 10000.00),
('CAR002', 'CL002', '2023-11-10', 'M02', '2023-11-12', 3000.00),
('CAR003', 'CL001', '2023-11-15', 'M01', '2023-11-18', 15000.00),
('CAR001', 'CL003', '2023-11-19', 'M02', '2023-11-22', 7500.00);

-- UPDATE
UPDATE categories SET daily_rate = 1600.00 WHERE category_id = 'C01';
UPDATE clients SET phone = '+79111112233' WHERE client_id = 'CL001';

-- DELETE
DELETE FROM rentals WHERE car_id = 'CAR002' AND client_id = 'CL002' AND start_date = '2023-11-10';

-- USERS & GRANTS
CREATE USER IF NOT EXISTS 'manager_user'@'localhost' IDENTIFIED BY 'secure_password_123';
CREATE USER IF NOT EXISTS 'admin_user'@'localhost' IDENTIFIED BY 'admin_password_456';

GRANT SELECT, INSERT, UPDATE ON car_rental_db.rentals TO 'manager_user'@'localhost';
GRANT SELECT, INSERT, UPDATE ON car_rental_db.cars TO 'manager_user'@'localhost';
GRANT SELECT, INSERT, UPDATE ON car_rental_db.clients TO 'manager_user'@'localhost';
GRANT ALL PRIVILEGES ON car_rental_db.* TO 'admin_user'@'localhost';

-- DESCRIBE
DESCRIBE rentals;

-- ==========================================
-- ЧАСТЬ 2. ЗАПРОСЫ
-- ==========================================

-- 1. Неявное соединение с WHERE и ORDER BY
SELECT c.brand, cl.full_name, r.total_amount, r.start_date
FROM cars c, clients cl, rentals r
WHERE c.car_id = r.car_id AND cl.client_id = r.client_id AND r.total_amount > 5000
ORDER BY r.start_date DESC;

-- 2. Явное соединение (JOIN)
SELECT r.start_date, cl.full_name AS client, c.brand, cat.category_name, r.total_amount
FROM rentals r
JOIN cars c ON r.car_id = c.car_id
JOIN clients cl ON r.client_id = cl.client_id
JOIN categories cat ON c.category_id = cat.category_id
ORDER BY r.start_date;

-- 3. Агрегация, GROUP BY, HAVING
SELECT cat.category_name, 
       COUNT(r.car_id) AS total_rentals, 
       SUM(r.total_amount) AS total_revenue, 
       AVG(r.total_amount) AS avg_check,
       MAX(r.total_amount) AS max_check,
       MIN(r.total_amount) AS min_check
FROM categories cat
JOIN cars c ON cat.category_id = c.category_id
JOIN rentals r ON c.car_id = r.car_id
GROUP BY cat.category_name
HAVING SUM(r.total_amount) > 10000;

-- 4. Вложенный запрос с IN
SELECT full_name FROM clients 
WHERE client_id IN (
    SELECT r.client_id FROM rentals r
    JOIN cars c ON r.car_id = c.car_id
    JOIN categories cat ON c.category_id = cat.category_id
    WHERE cat.category_name IN ('Комфорт', 'Бизнес')
);

-- 5. Вложенный запрос с ALL
SELECT brand FROM cars c
JOIN categories cat ON c.category_id = cat.category_id
WHERE cat.daily_rate > ALL (
    SELECT daily_rate FROM categories WHERE category_name = 'Эконом'
);

-- 6. Функции управления потоком (CASE)
SELECT r.start_date, r.end_date, 
       DATEDIFF(r.end_date, r.start_date) AS days,
       CASE 
           WHEN DATEDIFF(r.end_date, r.start_date) <= 2 THEN 'Короткая аренда'
           WHEN DATEDIFF(r.end_date, r.start_date) <= 5 THEN 'Стандартная аренда'
           ELSE 'Длительная аренда'
       END AS rental_type
FROM rentals r;

-- 7. Представление (VIEW)
CREATE VIEW v_active_rentals AS
SELECT cl.full_name AS client, c.brand, r.start_date, r.end_date
FROM rentals r
JOIN cars c ON r.car_id = c.car_id
JOIN clients cl ON r.client_id = cl.client_id;

-- 8. Временное представление (WITH)
WITH manager_stats AS (
    SELECT m.full_name AS manager, SUM(r.total_amount) AS revenue
    FROM managers m
    JOIN rentals r ON m.manager_id = r.manager_id
    GROUP BY m.full_name
)
SELECT * FROM manager_stats WHERE revenue > 10000;

-- 9. Анализ и оптимизация (EXPLAIN и CREATE INDEX)
CREATE INDEX idx_rentals_start_date ON rentals(start_date);
EXPLAIN SELECT * FROM rentals WHERE start_date = '2023-11-19';

-- 10. Транзакция (START TRANSACTION)
START TRANSACTION;
    INSERT INTO rentals (car_id, client_id, start_date, manager_id, end_date, total_amount)
    VALUES ('CAR002', 'CL003', CURRENT_DATE, 'M01', DATE_ADD(CURRENT_DATE, INTERVAL 3 DAY), 4500.00);
COMMIT;

-- 11. Динамический запрос (PREPARE, EXECUTE, DEALLOCATE)
/*
PREPARE stmt FROM 'SELECT * FROM rentals WHERE start_date BETWEEN ? AND ?';
SET @date1 = '2023-11-01';
SET @date2 = '2023-11-30';
EXECUTE stmt USING @date1, @date2;
DEALLOCATE PREPARE stmt;
*/
