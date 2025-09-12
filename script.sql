
/*
   _____           _       __     ____             __                 _____ ____    __ 
  / ___/__________(_)___  / /_   / __ \____  _____/ /_____ _________ / ___// __ \  / / 
  \__ \/ ___/ ___/ / __ \/ __/  / /_/ / __ \/ ___/ __/ __ `/ ___/ _ \\__ \/ / / / / /  
 ___/ / /__/ /  / / /_/ / /_   / ____/ /_/ (__  ) /_/ /_/ / /  /  __/__/ / /_/ / / /___
/____/\___/_/  /_/ .___/\__/  /_/    \____/____/\__/\__, /_/   \___/____/\___\_\/_____/
                /_/                                /____/                              
*/

---------------------------------------------------------------------------------------- TIMEZONE
ALTER DATABASE bd2ano SET TIMEZONE TO 'America/Sao_Paulo';



---------------------------------------------------------------------------------------- EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_cron";



---------------------------------------------------------------------------------------- DROPS
DROP TABLE IF EXISTS Table_Log CASCADE;
DROP TABLE IF EXISTS Sheet CASCADE;
DROP TABLE IF EXISTS Shift CASCADE;
DROP TABLE IF EXISTS User_Account_Photo CASCADE;
DROP TABLE IF EXISTS Role CASCADE;
DROP TABLE IF EXISTS Company CASCADE;
DROP TABLE IF EXISTS Factory CASCADE;
DROP TABLE IF EXISTS Payment_Method CASCADE;
DROP TABLE IF EXISTS Subscription CASCADE;
DROP TABLE IF EXISTS Payment CASCADE;
DROP TABLE IF EXISTS Gender CASCADE;
DROP TABLE IF EXISTS User_Account CASCADE;
DROP TABLE IF EXISTS Address CASCADE;
DROP TABLE IF EXISTS User_Account_Factory CASCADE;
DROP FUNCTION IF EXISTS current_datetime;
DROP FUNCTION IF EXISTS trg_changed_at;
DROP FUNCTION IF EXISTS trg_table_log;
DROP FUNCTION IF EXISTS get_current_shift;
DROP FUNCTION IF EXISTS get_user_accounts_by_factory;
DROP PROCEDURE IF EXISTS relate_user_account_factory;



---------------------------------------------------------------------------------------- TABLES
CREATE TABLE User_Account 
( 
 pk_uuid UUID PRIMARY KEY DEFAULT uuid_generate_v4(),  
 created_at TIMESTAMP NOT NULL DEFAULT current_timestamp,  
 changed_at TIMESTAMP,  
 deactivated_at TIMESTAMP,  
 name VARCHAR(50) NOT NULL,  
 email VARCHAR(50) NOT NULL,  
 password VARCHAR(20) NOT NULL,  
 birth_date DATE NOT NULL,
 position VARCHAR(80) NOT NULL,
 access_level INT NOT NULL CHECK (access_level > 0)
); 

CREATE TABLE User_Account_Factory
(
 created_at TIMESTAMP NOT NULL DEFAULT current_timestamp,
 user_account_uuid UUID NOT NULL,
 factory_id INT NOT NULL
);

CREATE TABLE Payment 
( 
 pk_id SERIAL PRIMARY KEY,  
 paid_at TIMESTAMP NOT NULL,  
 total MONEY NOT NULL,  
 expires_on DATE NOT NULL,  
 is_expired BOOLEAN NOT NULL,  
 subscription_id INT NOT NULL,  
 user_account_uuid UUID NOT NULL,  
 payment_method_id INT NOT NULL 
); 

CREATE TABLE Subscription 
( 
 pk_id SERIAL PRIMARY KEY,  
 created_at TIMESTAMP NOT NULL DEFAULT current_timestamp,  
 deactivated_at TIMESTAMP,
 name VARCHAR(20) NOT NULL,  
 price MONEY NOT NULL,  
 description TEXT NOT NULL,
 monthly_duration INT NOT NULL  
); 

CREATE TABLE Payment_Method 
( 
 pk_id SERIAL PRIMARY KEY,  
 created_at TIMESTAMP NOT NULL DEFAULT current_timestamp,
 deactivated_at TIMESTAMP,
 name VARCHAR(20) NOT NULL
); 

CREATE TABLE Factory 
( 
 pk_id SERIAL PRIMARY KEY,  
 created_at TIMESTAMP NOT NULL DEFAULT current_timestamp,  
 deactivated_at TIMESTAMP,
 name VARCHAR(20) NOT NULL,
 cnpj VARCHAR(14) NOT NULL,  
 domain VARCHAR(20) NOT NULL,  
 address_id INT NOT NULL
);

CREATE TABLE User_Account_Photo 
( 
 pk_id SERIAL PRIMARY KEY,  
 created_at TIMESTAMP NOT NULL DEFAULT current_timestamp,  
 url_blob VARCHAR(100) NOT NULL,  
 user_account_uuid UUID NOT NULL 
);  

CREATE TABLE Address 
( 
 pk_id SERIAL PRIMARY KEY,  
 state VARCHAR(50) NOT NULL,  
 city VARCHAR(50) NOT NULL,  
 neighborhood VARCHAR(50) NOT NULL,  
 cep VARCHAR(8) NOT NULL,  
 building_number INT NOT NULL,  
 street VARCHAR(50) NOT NULL,  
 complement VARCHAR(20)
);

CREATE TABLE Table_Log
(
 pk_id SERIAL PRIMARY KEY,
 table_name VARCHAR(50) NOT NULL,
 operation_made_at TIMESTAMP NOT NULL DEFAULT current_timestamp,
 lines_affected INT NOT NULL,
 db_account VARCHAR(50) NOT NULL,
 operation_type VARCHAR(20) NOT NULL
);



---------------------------------------------------------------------------------------- RELATIONS
ALTER TABLE Payment ADD FOREIGN KEY(subscription_id) REFERENCES Subscription (pk_id);
ALTER TABLE User_Account_Factory ADD FOREIGN KEY(factory_id) REFERENCES Factory (pk_id);
ALTER TABLE User_Account_Factory ADD FOREIGN KEY(user_account_uuid) REFERENCES User_Account (pk_uuid);
ALTER TABLE User_Account_Factory ADD PRIMARY KEY (factory_id, user_account_uuid);
ALTER TABLE Payment ADD FOREIGN KEY(user_account_uuid) REFERENCES User_Account (pk_uuid);
ALTER TABLE Payment ADD FOREIGN KEY(payment_method_id) REFERENCES Payment_Method (pk_id);
ALTER TABLE Factory ADD FOREIGN KEY(address_id) REFERENCES Address (pk_id);
ALTER TABLE User_Account ADD FOREIGN KEY(gender_id) REFERENCES Gender (pk_id);
ALTER TABLE User_Account ADD FOREIGN KEY(role_id) REFERENCES Role (pk_id);
ALTER TABLE User_Account_Photo ADD FOREIGN KEY(user_account_uuid) REFERENCES User_Account (pk_uuid);
ALTER TABLE Sheet ADD FOREIGN KEY(shift_id) REFERENCES Shift (pk_id);
ALTER TABLE Sheet ADD FOREIGN KEY(created_by) REFERENCES User_Account (pk_uuid);
ALTER TABLE Sheet ADD FOREIGN KEY(validated_by) REFERENCES User_Account (pk_uuid);



---------------------------------------------------------------------------------------- FUNCTIONS
CREATE OR REPLACE FUNCTION get_current_shift ()
RETURNS INT
LANGUAGE plpgsql AS $$
BEGIN
	RETURN (SELECT id FROM Shift WHERE curent_datetime()::TIME > starts_at AND current_datime()::TIME < ends_at);
END;
$$;



CREATE OR REPLACE FUNCTION get_user_account_by_factory(
	input_factory_id INT,
	input_search TEXT DEFAULT NULL,
	include_deactivated BOOL DEFAULT false,
	take INT DEFAULT 20,
	skip INT DEFAULT 0
)
RETURNS TABLE(
	pk_uuid UUID, 
	created_at TIMESTAMP WITHOUT TIME ZONE, 
	changed_at TIMESTAMP WITHOUT TIME ZONE, 
	deactivated_at TIMESTAMP WITHOUT TIME ZONE, 
	name varchar(50), 
	email varchar(20), 
	birth_date date, 
	gender_id int, 
	gender varchar(20),
	role_id int,
	role varchar(20)
)
LANGUAGE plpgsql AS $$
DECLARE
	query TEXT;
BEGIN
	query := '
		SELECT ua.pk_uuid, ua.created_at, ua.changed_at, ua.deactivated_at, ua.name, ua.email, ua.birth_date, ua.gender_id, g.name as gender, ua.role_id, r.name as role 
		FROM User_Account ua
		JOIN User_Account_Factory uac on ua.pk_uuid = uac.user_account_uuid
		JOIN Gender g on g.pk_id = ua.gender_id
		JOIN Role r on r.pk_id = ua.role_id
		WHERE uac.factory_id = ' || quote_literal(input_factory_id);
	
	IF (input_search IS NOT NULL) THEN
		query := query || ' AND (lower(ua.name) ILIKE ' || quote_literal(lower(input_search)) || ' OR lower(ua.email) ILIKE '|| quote_literal(lower(input_search)) ||')';
	END IF;
	
	IF (NOT include_deactivated) THEN
		query := query || ' AND ua.deactivated_at IS NULL';
	END IF;
	
	query := query || ' LIMIT ' || quote_literal(take);
	query := query || ' OFFSET' || quote_literal(skip);
	
	RETURN QUERY EXECUTE query;
END;
$$;



---------------------------------------------------------------------------------------- PROCEDURES
CREATE OR REPLACE PROCEDURE create_payment(
	input_user_account_uuid UUID,
	input_subscription_id INT,
	input_payment_method INT
) LANGUAGE plpgsql as $$
BEGIN
	IF NOT EXISTS (SELECT pk_uuid FROM User_Account WHERE pk_uuid = input_user_account_uuid) THEN
		RAISE EXCEPTION 'Usuário não encontrado';
		ELSE IF NOT EXISTS (SELECT ua.pk_uuid FROM User_Account ua JOIN Role r on r.pk_id = ua.role_id WHERE ua.pk_uuid = input_user_account_uuid AND r.name = 'Super Admin') THEN
			RAISE EXCEPTION 'Usuário sem permissão';
		END IF;
	END IF;
	
	IF NOT EXISTS (SELECT pk_id FROM Subscription WHERE pk_id = input_subscription_id) THEN 
		RAISE EXCEPTION 'Plano não encontrado';
	END IF;
	
	IF NOT EXISTS (SELECT pk_id FROM Payment_Method WHERE pk_id = input_payment_method) THEN
		RAISE EXCEPTION 'Método de pagamento não encontrado';
	END IF;
	
	IF NOT EXISTS (SELECT ) 
	
	IF NOT EXISTS (SELECT input_payment_method)

CREATE OR REPLACE PROCEDURE create_user_account_factory(
    input_user_account_uuid UUID,
    input_factory_id INT
)
LANGUAGE plpgsql AS $$
BEGIN
    IF EXISTS (SELECT pk_id FROM Factory WHERE id = input_factory_id) THEN
        IF EXISTS (SELECT pk_uuid FROM User_Account WHERE pk_uuid = input_user_account_uuid) THEN
			IF EXISTS (SELECT user_account_uuid FROM User_Account_Factory WHERE user_account_uuid = input_user_account_uuid) THEN
				RAISE EXCEPTION 'O usuário já pertence a uma fábrica';
			END IF;
			IF NOT EXISTS (SELECT user_account_uuid FROM User_Account_Factory WHERE user_account_uuid = input_user_account_uuid AND factory_id = input_factory_id) THEN
				INSERT INTO User_Account_Factory (user_account_uuid, factory_id) VALUES (input_user_account_uuid, input_factory_id);
				RAISE NOTICE 'Relacionamento criado com sucesso';
			ELSE
				RAISE EXCEPTION 'Este relacionamento já existe';
			END IF;
		ELSE
			RAISE EXCEPTION 'Usuário não encontrado';
		END IF;
	ELSE
		RAISE EXCEPTION 'Fábrica não encontrada';
	END IF;
	EXCEPTION
		WHEN OTHERS THEN
        	RAISE EXCEPTION 'Erro ao executar procedure: %', SQLERRM;
END;
$$;



---------------------------------------------------------------------------------------- TRIGGERS
CREATE OR REPLACE FUNCTION trg_changed_at()
RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
	new.changed_at = current_timestamp;
END;
$$;

CREATE TRIGGER trg_changed_at
AFTER UPDATE ON User_Account
FOR EACH STATEMENT
EXECUTE FUNCTION trg_changed_at();

CREATE OR REPLACE FUNCTION trg_table_log()
RETURNS trigger 
LANGUAGE plpgsql AS $$
DECLARE
    row_count INTEGER;
BEGIN
    GET DIAGNOSTICS row_count = ROW_COUNT;
    INSERT INTO table_log (table_name, operation_made_at, lines_affected, db_account, operation_type)
    VALUES (TG_TABLE_NAME, current_timestamp, row_count, CURRENT_USER, TG_OP);
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_table_log
AFTER INSERT OR UPDATE OR DELETE ON address
FOR EACH STATEMENT
EXECUTE FUNCTION trg_table_log();

CREATE TRIGGER trg_table_log
AFTER INSERT OR UPDATE OR DELETE ON Company
FOR EACH STATEMENT
EXECUTE FUNCTION trg_table_log();

CREATE TRIGGER trg_table_log
AFTER INSERT OR UPDATE OR DELETE ON Factory
FOR EACH STATEMENT
EXECUTE FUNCTION trg_table_log();

CREATE TRIGGER trg_table_log
AFTER INSERT OR UPDATE OR DELETE ON Gender
FOR EACH STATEMENT
EXECUTE FUNCTION trg_table_log();

CREATE TRIGGER trg_table_log
AFTER INSERT OR UPDATE OR DELETE ON Payment
FOR EACH STATEMENT
EXECUTE FUNCTION trg_table_log();

CREATE TRIGGER trg_table_log
AFTER INSERT OR UPDATE OR DELETE ON Payment_Method
FOR EACH STATEMENT
EXECUTE FUNCTION trg_table_log();

CREATE TRIGGER trg_table_log
AFTER INSERT OR UPDATE OR DELETE ON Role
FOR EACH STATEMENT
EXECUTE FUNCTION trg_table_log();

CREATE TRIGGER trg_table_log
AFTER INSERT OR UPDATE OR DELETE ON Sheet
FOR EACH STATEMENT
EXECUTE FUNCTION trg_table_log();

CREATE TRIGGER trg_table_log
AFTER INSERT OR UPDATE OR DELETE ON Shift
FOR EACH STATEMENT
EXECUTE FUNCTION trg_table_log();

CREATE TRIGGER trg_table_log
AFTER INSERT OR UPDATE OR DELETE ON Subscription
FOR EACH STATEMENT
EXECUTE FUNCTION trg_table_log();

CREATE TRIGGER trg_table_log
AFTER INSERT OR UPDATE OR DELETE ON User_Account
FOR EACH STATEMENT
EXECUTE FUNCTION trg_table_log();

CREATE TRIGGER trg_table_log
AFTER INSERT OR UPDATE OR DELETE ON User_Account_Factory
FOR EACH STATEMENT
EXECUTE FUNCTION trg_table_log();

CREATE TRIGGER trg_table_log
AFTER INSERT OR UPDATE OR DELETE ON User_Account_Photo
FOR EACH STATEMENT
EXECUTE FUNCTION trg_table_log();



---------------------------------------------------------------------------------------- CRONS
SELECT cron.schedule(
    'deactivate_factory',
    '0 0 * * *',
    $$
        WITH Expired_Payments AS (
            SELECT pk_id
            FROM Payment
            WHERE expires_on == current_date
        )
		UPDATE Factory SET deactivated_at = current_timestamp where pk_id in Expired_Payments;
    $$
);
