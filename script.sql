
/*____       _                          
 / ___|  ___| |__   ___ _ __ ___   __ _ 
 \___ \ / __| '_ \ / _ \ '_ ` _ \ / _` |
  ___) | (__| | | |  __/ | | | | | (_| |
 |____/ \___|_| |_|\___|_| |_| |_|\__,_|                                                                                                                                                                                                                   
*/

-- ======================================================================================
-- CONFIGURATIONS
-- ======================================================================================
ALTER DATABASE bd2ano SET TIMEZONE TO 'America/Sao_Paulo';
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";


-- ======================================================================================
-- DROPS
-- ======================================================================================
DROP TABLE IF EXISTS Table_Log CASCADE;
DROP TABLE IF EXISTS User_Account_Photo CASCADE;
DROP TABLE IF EXISTS Factory CASCADE;
DROP TABLE IF EXISTS Payment_Method CASCADE;
DROP TABLE IF EXISTS Subscription CASCADE;
DROP TABLE IF EXISTS Payment CASCADE;
DROP TABLE IF EXISTS Gender CASCADE;
DROP TABLE IF EXISTS User_Account CASCADE;
DROP TABLE IF EXISTS Address CASCADE;
DROP TABLE IF EXISTS Daily_Active_Users CASCADE;
DROP TABLE IF EXISTS Access_Type CASCADE;
DROP FUNCTION IF EXISTS trg_changed_at;
DROP FUNCTION IF EXISTS trg_table_log;
DROP FUNCTION IF EXISTS get_user_accounts_by_factory;
DROP FUNCTION IF EXISTS get_factory_active_payment;
DROP PROCEDURE IF EXISTS create_user_account_role;
DROP PROCEDURE IF EXISTS create_payment;
DROP PROCEDURE IF EXISTS create_daily_active_users;



-- ======================================================================================
-- TABLES
-- ======================================================================================
CREATE TABLE User_Account 
( 
 pk_uuid UUID PRIMARY KEY DEFAULT uuid_generate_v4(),  
 created_at TIMESTAMP NOT NULL DEFAULT current_timestamp,  
 changed_at TIMESTAMP,  
 deactivated_at TIMESTAMP,  
 name VARCHAR(50) NOT NULL,  
 email VARCHAR(50) NOT NULL UNIQUE,  
 password VARCHAR(100) NOT NULL,  
 date_of_birth DATE NOT NULL,  
 gender_id INT NOT NULL,
 user_manager_uuid UUID, 
 factory_id INT NOT NULL
); 

CREATE TABLE User_Account_Access_Type
(
 created_at TIMESTAMP NOT NULL DEFAULT current_timestamp,
 user_account_uuid UUID NOT NULL,
 access_type_id INT NOT NULL
);

CREATE TABLE Gender 
( 
 pk_id SERIAL PRIMARY KEY,  
 created_at TIMESTAMP NOT NULL DEFAULT current_timestamp,
 deactivated_at TIMESTAMP,
 name VARCHAR(50) NOT NULL
); 

CREATE TABLE Payment 
( 
 pk_id SERIAL PRIMARY KEY,  
 paid_at TIMESTAMP NOT NULL,  
 total NUMERIC(10,2) NOT NULL,  
 starts_at DATE NOT NULL,
 expires_on DATE NOT NULL,  
 is_active BOOLEAN NOT NULL,
 is_expired BOOLEAN NOT NULL,
 subscription_id INT NOT NULL,  
 user_account_uuid UUID NOT NULL,  
 factory_id INT NOT NULL,
 payment_method_id INT NOT NULL 
); 

CREATE TABLE Subscription 
( 
 pk_id SERIAL PRIMARY KEY,  
 created_at TIMESTAMP NOT NULL DEFAULT current_timestamp,  
 deactivated_at TIMESTAMP,
 name VARCHAR(20) NOT NULL,
 description VARCHAR(200) NOT NULL,
 price NUMERIC(10,2) NOT NULL,  
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
 name VARCHAR(50) NOT NULL,
 cnpj VARCHAR(14) NOT NULL UNIQUE,  
 domain VARCHAR(20) NOT NULL, 
 description VARCHAR(200)
);  

CREATE TABLE Access_Type
(
 pk_id SERIAL PRIMARY KEY,
 created_at TIMESTAMP NOT NULL DEFAULT current_timestamp,  
 deactivated_at TIMESTAMP,	
 name VARCHAR(20) NOT NULL,
 description VARCHAR(200) NOT NULL
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
 street VARCHAR(50) NOT NULL,  
 building_number INT NOT NULL,  
 complement VARCHAR(50),
 factory_id INT NOT NULL
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

CREATE TABLE Daily_Active_Users
(
 pk_id SERIAL PRIMARY KEY,
 accessed_on TIMESTAMP NOT NULL DEFAULT current_timestamp,
 user_account_uuid UUID NOT NULL
);



-- ======================================================================================
-- RELATIONS
-- ======================================================================================
ALTER TABLE User_Account ADD FOREIGN KEY (user_manager_uuid) REFERENCES User_Account(pk_uuid);
ALTER TABLE User_Account ADD FOREIGN KEY (factory_id) REFERENCES Factory(pk_id);
ALTER TABLE Payment ADD FOREIGN KEY(subscription_id) REFERENCES Subscription (pk_id);
ALTER TABLE User_Account_Access_Type ADD FOREIGN KEY(user_account_uuid) REFERENCES User_Account (pk_uuid);
ALTER TABLE User_Account_Access_Type ADD FOREIGN KEY(access_type_id) REFERENCES Access_Type (pk_id);
ALTER TABLE User_Account_Access_Type ADD PRIMARY KEY (access_type_id, user_account_uuid);
ALTER TABLE Payment ADD FOREIGN KEY(user_account_uuid) REFERENCES User_Account (pk_uuid);
ALTER TABLE Payment ADD FOREIGN KEY(user_account_uuid) REFERENCES User_Account (pk_uuid);
ALTER TABLE Payment ADD FOREIGN KEY(factory_id) REFERENCES Factory (pk_id);
ALTER TABLE User_Account ADD FOREIGN KEY(gender_id) REFERENCES Gender (pk_id);
ALTER TABLE User_Account_Photo ADD FOREIGN KEY(user_account_uuid) REFERENCES User_Account (pk_uuid);
ALTER TABLE Address ADD FOREIGN KEY(factory_id) REFERENCES Factory (pk_id);



-- ======================================================================================
-- INDEXES
-- ======================================================================================
CREATE INDEX user_acoount_name ON user_account (lower(name));
CREATE INDEX user_account_email ON user_account (lower(email));
CREATE INDEX user_account_deactivated_at ON user_account (deactivated_at);
CREATE INDEX user_account_photo_user_account_uuid ON user_account_photo (user_account_uuid);



-- ======================================================================================
-- FUNCTIONS
-- ======================================================================================
CREATE OR REPLACE FUNCTION get_factory_active_payment(
	input_factory_id INT
)
RETURNS TABLE(
	pk_id INT,
	subscription_name VARCHAR(20),
    starts_at DATE,
    expires_on DATE,
	total NUMERIC(10,2)
) LANGUAGE plpgsql AS $$
BEGIN
	RETURN QUERY (
		SELECT f.pk_id, s.name as subscription_name, p.starts_at, p.expires_on, p.total 
		FROM Factory f 
		JOIN Payment p ON f.pk_id = p.factory_id 
		JOIN Subscription s ON s.pk_id = p.subscription_id
		WHERE f.pk_id = input_factory_id AND p.is_active = true
		LIMIT 1
	);
END;
$$;

CREATE OR REPLACE FUNCTION get_user_accounts_by_factory(
	input_factory_id INT,
	input_search TEXT DEFAULT NULL,
	include_deactivated BOOL DEFAULT FALSE,
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
		query := query || ' AND ((lower(ua.name) ILIKE ' || quote_literal(lower(input_search)) || ' OR lower(ua.email) ILIKE '|| quote_literal(lower(input_search)) ||'))';
	END IF;
	
	IF (NOT include_deactivated) THEN
		query := query || ' AND ua.deactivated_at IS NULL';
	END IF;
	
	query := query || ' LIMIT ' || quote_literal(take);
	query := query || ' OFFSET' || quote_literal(skip);
	
	RETURN QUERY EXECUTE query;
END;
$$;



-- ======================================================================================
-- PROCEDURES
-- ======================================================================================
CREATE OR REPLACE PROCEDURE create_payment(
    input_user_account_uuid UUID,
    input_subscription_id INT,
    input_payment_method INT,
    input_factory_id INT
) LANGUAGE plpgsql AS $$
DECLARE
    calculated_starts_at DATE;
    calculated_total NUMERIC(10,2);
    calculated_is_active BOOLEAN;
    calculated_expires_on DATE;
BEGIN
    IF NOT EXISTS ( SELECT pk_uuid FROM User_Account WHERE pk_uuid = input_user_account_uuid AND deactivated_at IS NULL) THEN
        RAISE EXCEPTION 'Usuário não encontrado ou desativado';
    END IF;

    IF NOT EXISTS (SELECT r.pk_id FROM User_Account ua JOIN Role r ON r.pk_id = ua.role_id WHERE ua.pk_uuid = input_user_account_uuid AND r.name = 'Super Admin') THEN
        RAISE EXCEPTION 'Usuário sem permissão';
    END IF;

    IF NOT EXISTS (SELECT pk_id FROM Payment_Method WHERE pk_id = input_payment_method) THEN
        RAISE EXCEPTION 'Método de pagamento não encontrado';
    END IF;

    IF NOT EXISTS (SELECT pk_id FROM Factory WHERE pk_id = input_factory_id AND deactivated_at IS NULL) THEN
        RAISE EXCEPTION 'Fábrica não encontrada ou desativada';
    END IF;

    IF NOT EXISTS (SELECT factory_id FROM user_account_factory WHERE user_account_uuid = input_user_account_uuid AND factory_id = input_factory_id) THEN
        RAISE EXCEPTION 'Usuário não pertence a essa fábrica';
    END IF;

    calculated_total := (SELECT price FROM Subscription WHERE pk_id = input_subscription_id AND deactivated_at IS NULL);

    IF calculated_total IS NULL THEN
        RAISE EXCEPTION 'Plano não encontrado ou desativado';
    END IF;

    calculated_starts_at := (SELECT expires_on FROM payment WHERE factory_id = input_factory_id AND is_expired = FALSE ORDER BY expires_on DESC LIMIT 1);
    calculated_is_active := FALSE;

    IF calculated_starts_at IS NULL THEN
        calculated_starts_at := current_date;
        calculated_is_active := TRUE;
    END IF;

    calculated_expires_on := (SELECT calculated_starts_at + (monthly_duration * interval '1 month') FROM Subscription WHERE pk_id = input_subscription_id AND deactivated_at IS NULL);

    INSERT INTO payment (paid_at, total, starts_at, expires_on, is_active, is_expired, subscription_id, user_account_uuid, factory_id, payment_method_id) 
	VALUES (current_timestamp, calculated_total, calculated_starts_at, calculated_expires_on, calculated_is_active, FALSE, input_subscription_id, input_user_account_uuid, input_factory_id, input_payment_method);
    RAISE NOTICE 'Pagamento realizado com sucesso';

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Erro ao executar procedure: %', SQLERRM;
END;
$$;

CREATE OR REPLACE PROCEDURE create_user_account_factory(
    input_user_account_uuid UUID,
    input_factory_id INT
)
LANGUAGE plpgsql AS $$
BEGIN
    IF NOT EXISTS (SELECT pk_id FROM Factory WHERE pk_id = input_factory_id AND deactivated_at is NULL) THEN
        RAISE EXCEPTION 'Fábrica não encontrada ou desativada';
    END IF;

    IF NOT EXISTS (SELECT pk_uuid FROM User_Account WHERE pk_uuid = input_user_account_uuid AND deactivated_at is NULL) THEN
        RAISE EXCEPTION 'Usuário não encontrado ou desativado';
    END IF;

    IF EXISTS (SELECT 1 FROM User_Account_Factory WHERE user_account_uuid = input_user_account_uuid AND factory_id = input_factory_id) THEN
        RAISE EXCEPTION 'Este relacionamento já existe';
    END IF;

    IF EXISTS (SELECT 1 FROM User_Account_Factory WHERE user_account_uuid = input_user_account_uuid) THEN
        RAISE EXCEPTION 'O usuário já pertence a uma fábrica';
    END IF;

    INSERT INTO User_Account_Factory (user_account_uuid, factory_id) VALUES (input_user_account_uuid, input_factory_id);
    RAISE NOTICE 'Relacionamento criado com sucesso';

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Erro ao executar procedure: %', SQLERRM;
END;
$$;

CREATE OR REPLACE PROCEDURE create_daily_active_users(
	input_user_account_uuid UUID
)
LANGUAGE plpgsql AS $$
BEGIN
	INSERT INTO daily_active_users (user_account_uuid) values (input_user_account_uuid);
	RAISE NOTICE 'DAU criado com sucesso';
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Erro ao executar procedure: %', SQLERRM;
END;
$$;



-- ======================================================================================
-- TRIGGERS
-- ======================================================================================
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
AFTER INSERT OR UPDATE OR DELETE ON Access_Type
FOR EACH STATEMENT
EXECUTE FUNCTION trg_table_log();

CREATE TRIGGER trg_table_log
AFTER INSERT OR UPDATE OR DELETE ON Address
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
AFTER INSERT OR UPDATE OR DELETE ON Subscription
FOR EACH STATEMENT
EXECUTE FUNCTION trg_table_log();

CREATE TRIGGER trg_table_log
AFTER INSERT OR UPDATE OR DELETE ON User_Account
FOR EACH STATEMENT
EXECUTE FUNCTION trg_table_log();

CREATE TRIGGER trg_table_log
AFTER INSERT OR UPDATE OR DELETE ON User_Account_Photo
FOR EACH STATEMENT
EXECUTE FUNCTION trg_table_log();