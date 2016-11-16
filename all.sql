DROP PROCEDURE IF EXISTS ResetDB;
DELIMITER @@
CREATE PROCEDURE ResetDB ()
BEGIN
DROP TABLE IF EXISTS Doc_area_specialization;
DROP TABLE IF EXISTS Review;
DROP TABLE IF EXISTS Doctor;
DROP TABLE IF EXISTS Friendship;
DROP TABLE IF EXISTS Patient;

	CREATE TABLE Patient (
		alias   		VARCHAR(20) PRIMARY KEY,
		first_name	  	VARCHAR(100) NOT NULL,
		last_name	 	VARCHAR(100) NOT NULL,
		email			VARCHAR(256),
		province		VARCHAR(30),
		city			VARCHAR(50)
	);

	CREATE TABLE Doctor (
	  	alias			VARCHAR(20) PRIMARY KEY,
	 	first_name		VARCHAR(100) NOT NULL,
	  	last_name 		VARCHAR(100),
	  	gender			VARCHAR(20),
	  	street_address	VARCHAR(256),
	  	city			VARCHAR(50),
	  	province		VARCHAR(30),
	  	postal_code   	CHAR(6),
	  	licensed		DATE
	);

	CREATE TABLE Doc_area_specialization (
	  alias		VARCHAR(20),
	  area		VARCHAR(20),
	  PRIMARY KEY (alias, area),
	  FOREIGN KEY (alias) REFERENCES Doctor(alias)
	);

	CREATE TABLE Review (
	  patient		VARCHAR(20),
	  doctor		VARCHAR(20),
	  review_date	DATETIME,
	  star_rating	DECIMAL(2,1),
	  comments		VARCHAR(1000),
	  CHECK(star_rating >=0 AND star_rating <=5),
	  FOREIGN KEY (patient) REFERENCES Patient(alias),
	  FOREIGN KEY (doctor) REFERENCES Doctor(alias)
	);

	CREATE TABLE Friendship (
	  friender		VARCHAR(20),
	  friendee		VARCHAR(20),
	  FOREIGN KEY (friender) REFERENCES Patient(alias),
	  FOREIGN KEY (friendee) REFERENCES Patient(alias)
	);

	CREATE INDEX p_fname ON Patient(first_name);
	CREATE INDEX p_lname ON Patient(last_name);
	CREATE INDEX p_province ON Patient(province);
	CREATE INDEX p_city ON Patient(city);

	CREATE INDEX d_gender ON Doctor(gender);
	CREATE INDEX d_city ON Doctor(city);
	CREATE INDEX d_postal ON Doctor(postal_code);
	CREATE INDEX d_licensed ON Doctor(licensed);

	CREATE INDEX review_date ON Review(review_date);
	CREATE INDEX star_rating ON Review(star_rating);

END @@
DELIMITER ;


DROP PROCEDURE IF EXISTS CreatePatient;
DELIMITER @@
CREATE PROCEDURE CreatePatient
(IN alias VARCHAR(20), IN province VARCHAR(30), IN city VARCHAR(50), IN first_name VARCHAR(100), IN last_name VARCHAR(100), IN email VARCHAR(256))
BEGIN
	-- SET autocommit = 0;
	-- START TRANSACTION;
	INSERT INTO Patient (alias, first_name, last_name, email, province, city)
  	VALUES (alias, first_name, last_name, email, province, city);
  	-- COMMIT;
END @@
DELIMITER ;


DROP PROCEDURE IF EXISTS PatientSearch;
DELIMITER @@
CREATE PROCEDURE PatientSearch
(IN alias VARCHAR(20), IN province VARCHAR(30), IN city VARCHAR(50))
BEGIN

	SELECT Patient.alias, Patient.province, Patient.city, COUNT(doctor) as num_reviews, MAX(review_date) as last_review_date FROM Patient LEFT OUTER JOIN Review ON Patient.alias = Review.patient WHERE
	(Patient.alias = alias OR alias IS NULL)
	AND (Patient.province = province OR province IS NULL)
	AND (Patient.city = city OR city IS NULL) GROUP BY Review.patient;

END @@
DELIMITER ;


DROP PROCEDURE IF EXISTS AddFriend;
DELIMITER @@
CREATE PROCEDURE AddFriend
(IN requestor_alias VARCHAR(20), IN requestee_alias VARCHAR(20))
BEGIN
	-- SET autocommit = 0;
	-- START TRANSACTION;
	IF ((requestor_alias IN (SELECT alias FROM Patient)) AND
	(requestee_alias IN (SELECT alias FROM Patient)) AND
	(requestee_alias != requestor_alias)) THEN
		INSERT INTO Friendship
		VALUES (requestor_alias, requestee_alias);
	END IF;
	-- COMMIT;

END @@
DELIMITER ;


DROP PROCEDURE IF EXISTS ViewFriendRequests;
DELIMITER @@
CREATE PROCEDURE ViewFriendRequests
(IN alias VARCHAR(20))
BEGIN
	
	SELECT Patient.alias, Patient.email
	FROM Friendship JOIN Patient
	ON Friendship.friender = Patient.alias
	WHERE (Friendship.friendee = alias
		AND Friendship.friender NOT IN
			(SELECT friendee FROM Friendship
			WHERE friender = alias));

END @@
DELIMITER ;


DROP PROCEDURE IF EXISTS ViewFriends;
DELIMITER @@
CREATE PROCEDURE ViewFriends
(IN alias VARCHAR(20))
BEGIN

	SELECT friend, email
	FROM Patient inner join (
		SELECT friendee as friend
		FROM Friendship
		WHERE friender = alias AND 
		friendee in (SELECT friender
			FROM Friendship
			WHERE friendee = alias)
		) as T ON (Patient.alias = friend);

END @@
DELIMITER ;


DROP PROCEDURE IF EXISTS AreFriends;
DELIMITER @@
CREATE PROCEDURE AreFriends
(IN alias1 VARCHAR(20), IN alias2 VARCHAR(20), OUT are_friends BOOLEAN)
BEGIN

	IF EXISTS (SELECT * FROM Friendship WHERE friendee = alias1 AND friender = alias2) AND EXISTS (SELECT * FROM Friendship WHERE friendee = alias2 AND friender = alias1) THEN
		SET are_friends = 1;
		ELSE SET are_friends = 0;
	END IF;

END @@
DELIMITER ;


DROP FUNCTION IF EXISTS SPLIT_STR;

CREATE FUNCTION SPLIT_STR(x VARCHAR(1024), delim VARCHAR(12), pos INT)
RETURNS VARCHAR(255)
	RETURN REPLACE(SUBSTRING(SUBSTRING_INDEX(x, delim, pos), LENGTH(SUBSTRING_INDEX(x, delim, pos -1)) + 1), delim, '');


DROP PROCEDURE IF EXISTS CreateDoctor;
DELIMITER @@
CREATE PROCEDURE CreateDoctor
(IN alias VARCHAR(20), IN province VARCHAR(30), IN city VARCHAR(50), IN postal_code CHAR(6), IN street_address VARCHAR(256), IN first_name VARCHAR(100), IN last_name VARCHAR(100), IN licensed DATE, IN gender VARCHAR(20), IN specializations VARCHAR(1024))
BEGIN
	-- SET autocommit = 0;
	-- START TRANSACTION;
	DECLARE cnt INT DEFAULT 0;
	DECLARE split_string VARCHAR(20);

	INSERT INTO Doctor (alias, first_name, last_name, gender, street_address, city, province, postal_code, licensed)
	VALUES (alias, first_name, last_name, gender, street_address, city, province, postal_code, licensed);

	do_loop: LOOP
		SET cnt = cnt + 1;
		SET split_string = SPLIT_STR(specializations, ",", cnt);
		IF split_string = "" THEN
			LEAVE do_loop;
		END IF;

		INSERT INTO Doc_area_specialization (alias, area)
		VALUES (alias, split_string);
	END LOOP do_loop;
	-- COMMIT;

END @@
DELIMITER ;


DROP PROCEDURE IF EXISTS DoctorSearch;
DELIMITER @@
CREATE PROCEDURE DoctorSearch
(IN province VARCHAR(30), IN city VARCHAR(50), IN postal_code CHAR(6), IN name_keyword VARCHAR(100), IN num_years_licensed INT, IN gender VARCHAR(20), IN specialization VARCHAR(20), IN avg_star_rating_at_least DECIMAL(2,1), IN reviewed_by_friend BOOLEAN, IN caller_alias VARCHAR(20))
BEGIN

	DROP TABLE IF EXISTS tmp;
	CREATE TEMPORARY TABLE tmp SELECT * FROM Doctor;

	IF province IS NOT NULL THEN
		DELETE FROM tmp WHERE tmp.province != province;
	END IF;

	IF city IS NOT NULL THEN
		DELETE FROM tmp WHERE tmp.city != city;
	END IF;

	IF gender IS NOT NULL THEN
		DELETE FROM tmp WHERE tmp.gender != gender;
	END IF;

	IF specialization IS NOT NULL THEN
		DELETE FROM tmp WHERE tmp.alias NOT IN (SELECT alias FROM Doc_area_specialization WHERE area = specialization);
	END IF;

	IF postal_code IS NOT NULL THEN
		DELETE FROM tmp WHERE tmp.postal_code != postal_code;
	END IF;

	IF name_keyword IS NOT NULL THEN
		DELETE FROM tmp WHERE CONCAT(tmp.first_name, ' ', tmp.last_name) NOT LIKE CONCAT('%', name_keyword, '%');
	END IF;

	IF num_years_licensed IS NOT NULL THEN
		DELETE FROM tmp WHERE DATEDIFF(NOW(), tmp.licensed) <= num_years_licensed*365;
	END IF;

	IF avg_star_rating_at_least IS NOT NULL THEN
		DELETE FROM tmp WHERE avg_star_rating_at_least > (SELECT avg(star_rating) FROM Review WHERE doctor = tmp.alias GROUP BY doctor);
	END IF; 

	IF reviewed_by_friend = 1 THEN
		DELETE FROM tmp WHERE tmp.alias NOT IN (
		SELECT Review.doctor
		FROM Review JOIN (
		SELECT friend
		FROM Patient INNER JOIN (
			SELECT friendee as friend
			FROM Friendship
			WHERE friender = alias AND 
				friendee IN (SELECT friender
					FROM Friendship
					WHERE friendee = alias)
				) as T ON (Patient.alias = friend)
			) as F ON (Review.patient = friend)
		);
	END IF;

	SELECT alias FROM tmp;
	DROP TABLE IF EXISTS tmp;

END @@
DELIMITER ;


DROP PROCEDURE IF EXISTS ViewDoctorA;
DELIMITER @@
CREATE PROCEDURE ViewDoctorA
(IN alias VARCHAR(20))
BEGIN

	SELECT first_name, last_name, province, city, street_address, postal_code, (YEAR(NOW()) - YEAR(licensed)) as num_years_licensed, AVG(star_rating) as avg_star_rating, COUNT(*) as num_reviews 
	FROM Doctor JOIN Review ON Doctor.alias = Review.doctor AND Doctor.alias = alias;

END @@
DELIMITER ;


DROP PROCEDURE IF EXISTS ViewDoctorB;
DELIMITER @@
CREATE PROCEDURE ViewDoctorB
(IN alias VARCHAR(20))
BEGIN

	SELECT area as specialization
	FROM Doc_area_specialization
	WHERE Doc_area_specialization.alias = alias;

END @@
DELIMITER ;


DROP PROCEDURE IF EXISTS CreateReview;
DELIMITER @@
CREATE PROCEDURE CreateReview
(IN patient_alias VARCHAR(20), IN doctor_alias VARCHAR(20), IN star_rating DECIMAL(2,1), IN comments VARCHAR(1024))
BEGIN

	-- SET autocommit = 0;
	-- START TRANSACTION;
	IF (star_rating >= 0 AND star_rating <= 5 AND comments IS NOT NULL AND comments != ' ') THEN
		INSERT INTO Review (patient, doctor, star_rating, comments, review_date)
		VALUES (patient_alias, doctor_alias, FLOOR(star_rating * 2)/2, comments, NOW());
	END IF;
	-- COMMIT;

END @@
DELIMITER ;


DROP PROCEDURE IF EXISTS ViewReviews;
DELIMITER @@
CREATE PROCEDURE ViewReviews
(IN doctor_alias VARCHAR(20), IN from_datetime DATETIME, IN to_datetime DATETIME)
BEGIN

	SELECT review_date as date, star_rating, comments
	FROM Review
	WHERE doctor = doctor_alias AND review_date >= from_datetime AND review_date <= to_datetime
	ORDER BY date;

END @@
DELIMITER ;