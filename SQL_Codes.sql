DROP DATABASE IF EXISTS `BoutiqueDeLisboa`;

CREATE DATABASE IF NOT EXISTS `BoutiqueDeLisboa` DEFAULT CHARACTER SET = 'utf8' DEFAULT COLLATE 'utf8_general_ci';

USE `BoutiqueDeLisboa`;

-- Creating Tables
-- Customers
CREATE TABLE IF NOT EXISTS `CUSTOMERS` (
   `customer_id` INT AUTO_INCREMENT PRIMARY KEY,
   `first_name` VARCHAR(50) NOT NULL,
   `last_name` VARCHAR(50) NOT NULL,
   `email` VARCHAR(100) NOT NULL,
   `date_of_birth` DATE NOT NULL, 
   `origin` VARCHAR(50) NOT NULL,
   `phone_number` VARCHAR(20) NOT NULL
);
-- Services
CREATE TABLE IF NOT EXISTS `SERVICES` (
   `service_id` TINYINT NOT NULL PRIMARY KEY,
   `service_name` VARCHAR(255) NOT NULL,
   `price` FLOAT NOT NULL
);

-- Reservations
CREATE TABLE IF NOT EXISTS `RESERVATIONS` (
   `reservation_id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
   `customer_id` INT NOT NULL,
   `service_id` TINYINT NOT NULL,
   `reservation_item_id` TINYINT NOT NULL,
   `room_id` INT NOT NULL,
   `reservation_date` DATETIME NOT NULL,
   `reservation_location` VARCHAR(50) NOT NULL,
   `number_of_stay` INT NOT NULL,
   `checkin_date` DATETIME NOT NULL,
   `checkout_date` DATETIME NOT NULL
);

-- ReservationItems (if a reservation can have multiple services)
CREATE TABLE IF NOT EXISTS `RESERVATIONITEMS` (
   `reservation_item_id` TINYINT NOT NULL PRIMARY KEY,
   `reservation_item_name` VARCHAR(50) NOT NULL,
   `price` float NOT NULL
);

-- Payment
CREATE TABLE IF NOT EXISTS `PAYMENTS` (
   `payment_id` INT AUTO_INCREMENT PRIMARY KEY,
   `customer_id` INT NOT NULL,
   `reservation_id` INT NOT NULL,
   `payment_date` DATETIME NOT NULL,
   `paymenttype_id` TINYINT NOT NULL,
   `amount` FLOAT NOT NULL 
);

CREATE TABLE IF NOT EXISTS `PAYMENT_TYPE` (
   `paymenttype_id` TINYINT PRIMARY KEY,
   `paymenttype_name` VARCHAR(20) NOT NULL
);
-- Rooms 
CREATE TABLE IF NOT EXISTS `ROOMS` (
   `room_id` INT NOT NULL PRIMARY KEY,
   `room_number` INT NOT NULL,
   `room_type` VARCHAR(50) NOT NULL,
   `price_per_night` FLOAT NOT NULL
);

-- Reviews
CREATE TABLE IF NOT EXISTS `REVIEWS` (
   `review_id` INT AUTO_INCREMENT PRIMARY KEY,
   `customer_id` INT NOT NULL,
   `reservation_id` INT NOT NULL,
   `rating` INT NOT NULL,
   `comments` TEXT NOT NULL
);

-- Log
CREATE TABLE IF NOT EXISTS `LOG` (
   `log_id` INTEGER UNSIGNED AUTO_INCREMENT PRIMARY KEY,
   `log_details` TEXT NOT NULL,
   `msg` varchar(255) NOT NULL,
   `log_timestamp` DATETIME NOT NULL
);

-- ForeignKeys-----------
ALTER TABLE `RESERVATIONS`
ADD CONSTRAINT `fk_customer_id`
  FOREIGN KEY (`customer_id`)
  REFERENCES `CUSTOMERS` (`customer_id`)
  ON DELETE RESTRICT
  ON UPDATE CASCADE;


ALTER TABLE `RESERVATIONS`
ADD CONSTRAINT `fk_service_id`
  FOREIGN KEY (`service_id`)
  REFERENCES `SERVICES` (`service_id`)
  ON DELETE RESTRICT
  ON UPDATE CASCADE;

ALTER TABLE `RESERVATIONS`
ADD CONSTRAINT `fk_reservation_item_id`
  FOREIGN KEY (`reservation_item_id`)
  REFERENCES `RESERVATIONITEMS` (`reservation_item_id`)
  ON DELETE RESTRICT
  ON UPDATE CASCADE;

ALTER TABLE `RESERVATIONS`
ADD CONSTRAINT `fk_room_id`
  FOREIGN KEY (`room_id`)
  REFERENCES `ROOMS` (`room_id`)
  ON DELETE RESTRICT
  ON UPDATE CASCADE;

ALTER TABLE `PAYMENTS`
ADD CONSTRAINT `fk_customer_id_payments`
  FOREIGN KEY (`customer_id`)
  REFERENCES `CUSTOMERS` (`customer_id`)
  ON DELETE RESTRICT
  ON UPDATE CASCADE;
  
ALTER TABLE `PAYMENTS`
ADD CONSTRAINT `fk_paymenttype_id_payments`
  FOREIGN KEY (`paymenttype_id`)
  REFERENCES `PAYMENT_TYPE` (`paymenttype_id`)
  ON DELETE RESTRICT
  ON UPDATE CASCADE;

ALTER TABLE `PAYMENTS`
ADD CONSTRAINT `fk_reservation_id_payments`
  FOREIGN KEY (`reservation_id`)
  REFERENCES `RESERVATIONS` (`reservation_id`)
  ON DELETE RESTRICT
  ON UPDATE CASCADE;

ALTER TABLE `REVIEWS`
ADD CONSTRAINT `fk_customer_id_reviews`
  FOREIGN KEY (`customer_id`)
  REFERENCES `CUSTOMERS` (`customer_id`)
  ON DELETE RESTRICT
  ON UPDATE CASCADE;

ALTER TABLE `REVIEWS`
ADD CONSTRAINT `fk_reservation_id_reviews`
  FOREIGN KEY (`reservation_id`)
  REFERENCES `RESERVATIONS` (`reservation_id`)
  ON DELETE RESTRICT
  ON UPDATE CASCADE;
  
   -- Triggers-----------
-- Trigger to log changes to RESERVATIONS table
-- SHOULD BE COMPLETED

-- Trigger to log room reservation
DELIMITER //
CREATE TRIGGER tr_room_reservation_log
AFTER INSERT ON RESERVATIONS
FOR EACH ROW
BEGIN
    -- Log the room reservation details in the LOG table
    INSERT INTO LOG (log_details, msg, log_timestamp)
    VALUES (
        CONCAT('Room Reserved - Reservation ID: ', NEW.reservation_id, ', Room ID: ', NEW.room_id),
        'Room Reserved',
        NOW()
    );
END;
//
DELIMITER ;


DELIMITER //
CREATE TRIGGER check_room_availability
BEFORE INSERT ON RESERVATIONS
FOR EACH ROW
BEGIN
    DECLARE room_count INT;

    -- Check if the room is available for the specified date range
    SELECT COUNT(*) INTO room_count
    FROM RESERVATIONS
    WHERE room_id = NEW.room_id
      AND ((NEW.checkin_date >= checkin_date AND NEW.checkin_date < checkout_date)
           OR (NEW.checkout_date > checkin_date AND NEW.checkout_date <= checkout_date)
           OR (NEW.checkin_date <= checkin_date AND NEW.checkout_date >= checkout_date));

    -- If room_count is greater than 0, then the room is not available
    IF room_count > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Room not available for the specified date range';
    END IF;
END 
//
DELIMITER ;

DELIMITER //

CREATE TRIGGER calculate_amount_trigger BEFORE INSERT ON PAYMENTS
FOR EACH ROW
BEGIN
    DECLARE room_price FLOAT;
    DECLARE reservation_item_price FLOAT;
    DECLARE service_price FLOAT;
    DECLARE nights_stayed INT;

    -- Fetch reservation details for the payment
    SELECT 
        r.room_id, 
        r.reservation_item_id, 
        r.service_id, 
        r.number_of_stay
    INTO 
        room_price, 
        reservation_item_price, 
        service_price, 
        nights_stayed
    FROM RESERVATIONS r
    WHERE r.reservation_id = NEW.reservation_id;

    -- Calculate total amount based on the number of nights stayed and prices
    SET NEW.amount = nights_stayed * (
        (SELECT price_per_night FROM ROOMS WHERE room_id = room_price) +
        (SELECT price FROM RESERVATIONITEMS WHERE reservation_item_id = reservation_item_price) +
        (SELECT price FROM SERVICES WHERE service_id = service_price)
    );
END;
//

DELIMITER ;

DELIMITER //

CREATE TRIGGER ensure_matching_dates_trigger BEFORE INSERT ON PAYMENTS
FOR EACH ROW
BEGIN
    -- Fetch reservation_date for the given reservation_id
    DECLARE reservation_date_check DATETIME;
    SELECT reservation_date INTO reservation_date_check
    FROM RESERVATIONS
    WHERE reservation_id = NEW.reservation_id;

    -- Check if reservation_date matches payment_date or set payment_date to reservation_date
    IF NEW.payment_date IS NULL THEN
        SET NEW.payment_date = reservation_date_check;
    ELSE
        IF NEW.payment_date <> reservation_date_check THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Reservation date must match payment date';
        END IF;
    END IF;
END;
//

DELIMITER ;


 
INSERT INTO `CUSTOMERS` (`first_name`, `last_name`, `email`, `date_of_birth`, `origin`, `phone_number`)
VALUES
('John', 'Doe', 'john.doe@email.com', '1990-01-15', 'USA', '+1 (555) 123-4567'),
('Jane', 'Smith', 'jane.smith@email.com', '1985-03-22', 'Canada', '+1 (555) 234-5678'),
('Alice', 'Johnson', 'alice.johnson@email.com', '1992-07-10', 'UK', '+44 20 7123 4567'),
('Bob', 'Miller', 'bob.miller@email.com', '1988-11-05', 'Australia', '+61 2 9876 5432'),
('Eva', 'Clark', 'eva.clark@email.com', '1995-04-30', 'Germany', '+49 30 8765 4321'),
('Michael', 'Davis', 'michael.davis@email.com', '1980-09-18', 'France', '+33 1 2345 6789'),
('Samantha', 'Brown', 'samantha.brown@email.com', '1993-12-03', 'Brazil', '+55 11 98765 4321'),
('Daniel', 'White', 'daniel.white@email.com', '1983-06-25', 'Mexico', '+52 55 1234 5678'),
('Grace', 'Williams', 'grace.williams@email.com', '1998-02-08', 'Spain', '+34 91 876 5432'),
('Ryan', 'Jones', 'ryan.jones@email.com', '1982-05-12', 'Italy', '+39 02 3456 7890'),
('Olivia', 'Anderson', 'olivia.anderson@email.com', '1996-08-27', 'India', '+91 98765 43210'),
('Matthew', 'Lee', 'matthew.lee@email.com', '1987-10-20', 'Japan', '+81 3 4567 8901'),
('Emma', 'Garcia', 'emma.garcia@email.com', '1991-03-14', 'South Africa', '+27 11 234 5678'),
('William', 'Harris', 'william.harris@email.com', '1986-06-08', 'Argentina', '+54 11 8765 4321'),
('Lily', 'Turner', 'lily.turner@email.com', '1994-09-02', 'Russia', '+7 495 123 4567'),
('Nicholas', 'Wang', 'nicholas.wang@email.com', '1981-12-17', 'China', '+86 10 8765 4321'),
('Sophia', 'Zhang', 'sophia.zhang@email.com', '1997-01-01', 'South Korea', '+82 2 3456 7890'),
('Caleb', 'Liu', 'caleb.liu@email.com', '1984-04-05', 'Mexico', '+52 55 6789 0123'),
('Madison', 'Martin', 'madison.martin@email.com', '1989-07-29', 'Canada', '+1 (555) 345-6789'),
('Isaac', 'Brown', 'isaac.brown@email.com', '1990-10-23', 'Germany', '+49 30 9876 5432'),
('Ava', 'Jackson', 'ava.jackson@email.com', '1995-01-18', 'Australia', '+61 2 8765 4321'),
('Logan', 'Taylor', 'logan.taylor@email.com', '1983-04-12', 'France', '+33 1 2345 6789'),
('Hailey', 'Chen', 'hailey.chen@email.com', '1992-07-06', 'USA', '+1 (555) 456-7890'),
('Ethan', 'Nguyen', 'ethan.nguyen@email.com', '1986-09-30', 'Spain', '+34 91 876 5432'),
('Chloe', 'Lopez', 'chloe.lopez@email.com', '1998-12-15', 'Brazil', '+55 11 98765 4321'),
('Mason', 'Adams', 'mason.adams@email.com', '1981-02-09', 'Italy', '+39 02 3456 7890'),
('Aria', 'Wu', 'aria.wu@email.com', '1996-05-24', 'India', '+91 98765 43210'),
('Elijah', 'Gomez', 'elijah.gomez@email.com', '1987-08-18', 'Japan', '+81 3 4567 8901'),
('Amelia', 'Hernandez', 'amelia.hernandez@email.com', '1993-11-03', 'South Africa', '+27 11 234 5678');

INSERT INTO `SERVICES` (`service_id`,`service_name`, `price`)
VALUES
(1,  'Room Cleaning', 30.00),
(2,  'Airport Shuttle', 50.00),
(3,  'Breakfast Buffet', 15.00),
(4,  'WiFi Access', 10.00),
(5,  'Spa Package', 80.00),
(6,  'Parking Service', 20.00),
(7,  'Room Service', 25.00),
(8,  'Late Checkout', 40.00),
(9, 'Concierge Service', 15.00),
(10,  'Conference Room Rental', 100.00),
(11,  'Laundry Service', 35.00);

INSERT INTO `RESERVATIONITEMS` (`reservation_item_id`, `reservation_item_name`, `price`)
VALUES
(1, 'Swim goggles', 7.00),
(2, 'Book', 1.00),
(3, 'Sunbed', 15.00),
(4, 'Hat', 3.00),
(5, 'Bag', 3.00),
(6, 'Diving Suite', 10.00),
(7, 'Surf Board', 10.00),
(8, 'JBL', 10.00),
(9, 'Jetski', 30.00),
(10, 'Beach Towel', 3.00);

INSERT INTO `ROOMS` (`room_id`,`room_number`, `room_type`, `price_per_night`)
VALUES
   (101,1001, 'Single', 50.00),
   (102,1002,  'Single', 50.00),
   (103,1003,  'Double', 70.00),
   (104,1004,  'Double', 70.00),
   (105,1005,  'Single', 50.00),
   (106,1006,  'Single', 50.00),
   (107,1007,  'Double', 70.00),
   (108,1008,  'Double', 70.00),
   (109,1009,  'Single', 50.00),
   (110, 1010, 'Single', 50.00),
   (201, 2001, 'Suite', 150.00),
   (202, 2002,'Suite', 150.00),
   (203, 2003,'Double', 70.00),
   (204, 2004,'Double', 70.00),
   (205, 2005,'Single', 50.00),
   (206, 2006,'Single', 50.00),
   (207, 2007,'Double', 70.00),
   (208, 2008,'Double', 70.00),
   (209, 2009,'Single', 50.00),
   (210, 2010,'Single', 50.00),
   (301, 3001,'Single', 50.00),
   (302, 3002,'Single', 50.00),
   (303, 3003,'Double', 70.00),
   (304, 3004,'Double', 70.00),
   (305, 3005,'Single', 50.00),
   (306, 3006,'Single', 50.00),
   (307, 3007,'Double', 70.00),
   (308, 3008,'Double', 70.00),
   (309, 3009,'Single', 50.00),
   (310, 3010,'Single', 50.00);
   
   
   INSERT INTO `RESERVATIONS` (`customer_id`, `service_id`, `reservation_item_id`, `room_id`, `reservation_date`, `reservation_location`, `number_of_stay`, `checkin_date`, `checkout_date`)
VALUES
(1, 1, 1, 101, '2023-11-15 10:00:00', 'Hotel B', 3, '2023-12-01 14:00:00', '2023-12-04 12:00:00'),
(2, 2, 2, 102, '2023-12-20 15:30:00', 'Hotel C', 2, '2024-01-10 12:00:00', '2024-01-12 10:00:00'),
(3, 3, 3, 103, '2024-01-05 08:45:00', 'Hotel A', 5, '2024-01-15 18:00:00', '2024-01-20 12:00:00'),
(4, 4, 4, 104, '2024-02-12 12:00:00', 'Hotel B', 1, '2024-02-15 12:00:00', '2024-02-16 10:00:00'),
(5, 5, 5, 105, '2024-03-25 09:15:00', 'Hotel C', 4, '2024-04-01 14:00:00', '2024-04-05 12:00:00'),
(6, 6, 7, 106, '2024-04-10 16:30:00', 'Hotel A', 2, '2024-04-15 12:00:00', '2024-04-17 10:00:00'),
(7, 7, 4, 107, '2024-05-18 11:00:00', 'Hotel B', 3, '2024-06-01 14:00:00', '2024-06-04 12:00:00'),
(8, 8, 6, 108, '2024-06-22 14:45:00', 'Hotel C', 1, '2024-07-10 12:00:00', '2024-07-11 10:00:00'),
(9, 9, 3, 109, '2024-07-03 07:30:00', 'Hotel A', 7, '2024-07-15 18:00:00', '2024-07-22 12:00:00'),
(10, 7, 10, 201, '2024-08-18 10:15:00', 'Hotel B', 2, '2024-09-01 14:00:00', '2024-09-03 12:00:00'),
(11, 1, 1, 202, '2024-09-15 10:00:00', 'Hotel C', 3, '2024-10-01 14:00:00', '2024-10-04 12:00:00'),
(12, 2, 4, 203, '2024-10-20 15:30:00', 'Hotel A', 2, '2024-11-10 12:00:00', '2024-11-12 10:00:00'),
(13, 3, 3, 204, '2024-11-05 08:45:00', 'Hotel B', 5, '2024-11-15 18:00:00', '2024-11-20 12:00:00'),
(14, 4, 7, 205, '2024-12-12 12:00:00', 'Hotel C', 1, '2024-12-15 12:00:00', '2024-12-16 10:00:00'),
(15, 5, 8, 301, '2025-01-25 09:15:00', 'Hotel A', 4, '2025-02-01 14:00:00', '2025-02-05 12:00:00'),
(16, 6, 6, 302, '2025-02-10 16:30:00', 'Hotel B', 2, '2025-02-15 12:00:00', '2025-02-17 10:00:00'),
(17, 7, 7, 303, '2025-03-18 11:00:00', 'Hotel C', 3, '2025-04-01 14:00:00', '2025-04-04 12:00:00'),
(18, 8, 2, 305, '2025-04-22 14:45:00', 'Hotel A', 1, '2025-05-10 12:00:00', '2025-05-11 10:00:00'),
(19, 9, 9, 306, '2025-05-03 07:30:00', 'Hotel B', 7, '2025-05-15 18:00:00', '2025-05-22 12:00:00'),
(20, 9, 3, 309, '2025-06-18 10:15:00', 'Hotel C', 2, '2025-07-01 14:00:00', '2025-07-03 12:00:00');

INSERT INTO `PAYMENT_TYPE` (`paymenttype_id`, `paymenttype_name`)
VALUES
(1,'Visa'),
(2,'MasterCard'),
(3,'Transfer'),
(4,'Coupon');

INSERT INTO `PAYMENTS` (`payment_id`, `customer_id`,`reservation_id`,`paymenttype_id`)
VALUES
(1, 1,1,1),
(2, 2,2,3),
(3, 3,3,2 ),
(4, 4,4,4),
(5, 5,5,1),
(6, 6,6,1),
(7, 7,7,2),
(8, 8,8,1),
(9, 9,9,2),
(10, 10,10,2),
(11, 11,11,1),
(12, 12,12,1),
(13, 13,13,4),
(14, 14,14,3),
(15, 15,15,1),
(16, 16,16,2),
(17, 17,17,1),
(18, 18,18,4),
(19, 19,19,2),
(20, 20,20,3);

INSERT INTO `REVIEWS` (`customer_id`, `reservation_id`, `rating`, `comments`)
VALUES
(1, 1, 4, 'Great experience, friendly staff.'),
(2, 2, 3, 'Average service, could have been better.'),
(3, 3, 5, 'Excellent service, highly recommended.'),
(4, 4, 5, 'Amazing food, great ambience.'),
(5, 5, 3, 'Decent experience, nothing extraordinary.'),
(6, 6, 2, 'Poor service, disappointing.'),
(7, 7, 4, 'Good food, decent prices.'),
(8, 8, 5, 'Outstanding service, worth the price.'),
(9, 9, 1, 'Worst experience ever, avoid at all costs.'),
(10, 10, 4, 'Friendly staff and delicious food.'),
(11, 11, 3, 'Average service, nothing special.'),
(12, 12, 4, 'Great place for a family dinner.'),
(13, 13, 5, 'Highly satisfied with the experience.'),
(14, 14, 5, 'Exceptional service, will surely visit again.'),
(15, 15, 3, 'Not up to expectations, needs improvement.'),
(16, 16, 2, 'Disappointing service, not recommend.'),
(17, 17, 4, 'Delicious food, good value for money.'),
(18, 18, 5, 'Extremely satisfied with everything.'),
(19, 19, 1, 'Horrible experience, never going back.'),
(20, 20, 4, 'Prompt service and tasty food.');

SELECT * FROM PAYMENTS 

-- QUERIES------------

-- FIRST 
SELECT 
    customers.first_name,
    customers.last_name
FROM CUSTOMERS
INNER JOIN reservations ON customers.customer_id = reservations.customer_id
WHERE reservations.reservation_date BETWEEN '2023-01-01 00:00:00' AND '2025-01-01 00:00:00';

--- SECOND
SELECT 
    c.first_name,
    c.last_name,
    SUM(p.amount) AS total_payment_amount
FROM 
    CUSTOMERS c
INNER JOIN 
    PAYMENTS p ON c.customer_id = p.customer_id
GROUP BY 
    c.customer_id
ORDER BY 
    total_payment_amount DESC
LIMIT 3;

-- THIRD ONE
SELECT 
    '01/2023 - 10/2025' AS PeriodOfSales,
    COUNT(amount) AS TotalSales,
    TIMESTAMPDIFF(YEAR, MIN(payment_date), MAX(payment_date)) + 1 AS Years,
    ROUND(SUM(amount) / (TIMESTAMPDIFF(YEAR, MIN(payment_date), MAX(payment_date)) + 1), 2) AS YearlyAverage,
    ROUND(SUM(amount) / TIMESTAMPDIFF(MONTH, MIN(payment_date), MAX(payment_date)), 2) AS MonthlyAverage
FROM 
    PAYMENTS
WHERE 
    payment_date BETWEEN '2023-01-01' AND '2025-10-31';

-- FORTH ONE
SELECT 
	customers.origin,
    COUNT(*) AS TotalTransactions,
    SUM(amount) AS TotalAmount
FROM 
    RESERVATIONS
JOIN 
    PAYMENTS ON RESERVATIONS.reservation_id = PAYMENTS.reservation_id
   JOIN   CUSTOMERS ON customers.customer_id = RESERVATIONS.customer_id
GROUP BY 
    CUSTOMERS.origin
ORDER BY  TotalAmount DESC;
  
-- FIFTH ONE
SELECT 
    r.reservation_location AS Location,
    AVG(rv.rating) AS Average_point
FROM 
    RESERVATIONS r
JOIN 
    REVIEWS rv ON r.reservation_id = rv.reservation_id
GROUP BY 
    r.reservation_location
ORDER BY 
    Average_point desc;
    
SELECT * FROM PAYMENTS
    
    -- VIEW---
-- VIEW FOR CUSTOMER_ID = 1
CREATE VIEW Invoice_Head_Total AS
SELECT 
	c.first_name AS FirstName,
    c.last_name AS LastName,
    c.email,
    c.phone_number AS PhoneNumber,
    ro.room_type AS RoomType,
    ro.price_per_night AS RoomPrice,
    r.number_of_stay AS NumberOfStay,
    s.service_name AS Services,
	s.price AS ServicesPrices,
    ri.reservation_item_name AS AddititionsNames,
    ri.price AS AddititionsPrice,
	p.amount AS TotalAmount
FROM 
    PAYMENTS p
JOIN 
    CUSTOMERS c ON c.customer_id = p.customer_id
JOIN 
	RESERVATIONS r ON r.customer_id = c.customer_id
JOIN 
	SERVICES s ON s.service_id = r.service_id   
JOIN 
	RESERVATIONITEMS  ri ON ri.reservation_item_id = r.reservation_item_id
JOIN 
	ROOMS  ro ON ro.room_id = r.room_id
    
WHERE c.customer_id = 1; 

SELECT * FROM Invoice_Head_Total;
