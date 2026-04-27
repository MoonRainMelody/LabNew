CREATE DATABASE IF NOT EXISTS mall_db DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE mall_db;

CREATE TABLE product (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    price DECIMAL(10, 2) NOT NULL
);

INSERT INTO product (name, price) VALUES
('机械键盘', 499.00),
('电竞鼠标', 299.00),
('27寸显示器', 1599.00),
('降噪耳机', 899.00),
('人体工学椅', 1299.00);
