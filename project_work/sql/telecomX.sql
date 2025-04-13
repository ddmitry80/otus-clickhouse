CREATE DATABASE stg ON CLUSTER c2sh2rep;

-- client
DESCRIBE TABLE file('/var/lib/clickhouse/user_files/data/TelecomX/telecom10k/client.parquet', Parquet);
SELECT * FROM file('/var/lib/clickhouse/user_files/data/TelecomX/telecom10k/client.parquet', Parquet);

--DROP TABLE stg.tc_client ON CLUSTER c1sh4rep NO DELAY;;
CREATE TABLE stg.tc_client ON CLUSTER c1sh4rep
(
    userId UUID
    , contract String
    , documents String
    , email String
    , idPlan Int64
    , created_at DateTime DEFAULT now()
)
ENGINE = ReplicatedMergeTree('/clickhouse/shard_{shard_c1sh4rep}/{database}/{table}','{replica_c1sh4rep}')
ORDER BY (idPlan, contract);

TRUNCATE stg.tc_client;
INSERT INTO stg.tc_client (userId, contract, documents, email, idPlan)
SELECT Id, Contract, Documents, Email, IdPlan FROM file('/var/lib/clickhouse/user_files/data/TelecomX/telecom10k/client.parquet', Parquet);

select * from stg.tc_client order by idPlan desc

--- Company
SELECT * FROM file('/var/lib/clickhouse/user_files/data/TelecomX/telecom10k/company.parquet', Parquet) limit 100;

--DROP TABLE stg.tc_company ON CLUSTER c1sh4rep NO DELAY;;
CREATE TABLE stg.tc_company ON CLUSTER c1sh4rep
(
    userId UUID
    , contract String
    , documents String
    , email String
    , idPlan Int64
    , name String
    , address String
    , phones String
    , contact String
    , created_at DateTime DEFAULT now()
)
ENGINE = ReplicatedMergeTree('/clickhouse/shard_{shard_c1sh4rep}/{database}/{table}','{replica_c1sh4rep}')
ORDER BY (idPlan, contract);

TRUNCATE stg.tc_company;
INSERT INTO stg.tc_company (userId, contract, documents, email, idPlan, name, address, phones, contact)
SELECT Id, Contract, Documents, Email, IdPlan, Name, Address, Phones, Contact FROM file('/var/lib/clickhouse/user_files/data/TelecomX/telecom10k/company.parquet', Parquet);

select * from stg.tc_company order by name;

-- Physical
SELECT * FROM file('/var/lib/clickhouse/user_files/data/TelecomX/telecom10k/physical.parquet', Parquet) limit 100;

--DROP TABLE stg.tc_physical ON CLUSTER c1sh4rep NO DELAY;;
CREATE TABLE stg.tc_physical ON CLUSTER c1sh4rep
(
    userId UUID
    , contract String
    , documents String
    , email String
    , idPlan Int64
    , name String
    , address String
    , passport String
    , phones String
    , created_at DateTime DEFAULT now()
)
ENGINE = ReplicatedMergeTree('/clickhouse/shard_{shard_c1sh4rep}/{database}/{table}','{replica_c1sh4rep}')
ORDER BY (idPlan, contract);

--TRUNCATE stg.tc_physical;
INSERT INTO stg.tc_physical (userId, contract, documents, email, idPlan, name, address, passport, phones)
SELECT Id, Contract, Documents, Email, IdPlan, Name, Address, Passport, Phones 
FROM file('/var/lib/clickhouse/user_files/data/TelecomX/telecom10k/physical.parquet', Parquet);

SELECT * FROM stg.tc_physical ORDER BY name;

-- Plan
SELECT * FROM file('/var/lib/clickhouse/user_files/data/TelecomX/telecom10k/plan.json', json) limit 100;

--DROP TABLE stg.tc_plan ON CLUSTER c1sh4rep NO DELAY;;
CREATE TABLE stg.tc_plan ON CLUSTER c1sh4rep
(
    id int
    , name String NULL
    , description String NULL
    , createdAt Int64 NULL
    , updatedAt Int64 NULL
    , closedAt Int64 NULL
    , enabled Bool NULL
    , attrs String NULL
    , created_at DateTime DEFAULT now()
)
ENGINE = ReplicatedMergeTree('/clickhouse/shard_{shard_c1sh4rep}/{database}/{table}','{replica_c1sh4rep}')
ORDER BY (id);

--TRUNCATE stg.tc_plan;
INSERT INTO stg.tc_plan (id, name, description, createdAt, updatedAt, closedAt, attrs)
SELECT Id, Name, Description, CreatedAt, UpdatedAt, ClosedAt, Attrs 
FROM file('/var/lib/clickhouse/user_files/data/TelecomX/telecom10k/plan.json', json);

SELECT * FROM stg.tc_plan ORDER BY id;

-------------
--- CDR -----
-------------
SELECT * FROM file('/var/lib/clickhouse/user_files/data/TelecomX/telecom10k/psx_6*.0_2024-01-01 *:*:*.csv', CSVWithNames) limit 100;

DROP TABLE IF EXISTS stg.tc_cdr_rep  ON CLUSTER c2sh2rep NO DELAY;
CREATE TABLE stg.tc_cdr_rep ON CLUSTER c2sh2rep
(
    idSession Int64
    , idPSX Int
    , idSubscriber Int
    , startSession String
    , endSession String NULL
    , duration Int
    , upTx Int64
    , downTx Int64
    , created_at DateTime DEFAULT now()
)
ENGINE = ReplicatedMergeTree('/clickhouse/shard_{shard_c2sh2rep}/{database}/{table}','{replica_c2sh2rep}')
PARTITION BY toYYYYMMDD(created_at)
ORDER BY startSession;

DROP TABLE IF EXISTS stg.tc_cdr ON CLUSTER c2sh2rep NO DELAY;
CREATE TABLE stg.tc_cdr ON CLUSTER c2sh2rep
AS stg.tc_cdr_rep
ENGINE = Distributed(c2sh2rep, stg, tc_cdr_rep, idSubscriber);


--select * from stg.tc_cdr

-- ODS
CREATE DATABASE ods ON CLUSTER c2sh2rep;

DROP TABLE IF EXISTS ods.tc_cdr_rep  ON CLUSTER c2sh2rep NO DELAY;
CREATE TABLE ods.tc_cdr_rep ON CLUSTER c2sh2rep
(
    idSession Int64
    , idPSX Int
    , idSubscriber Int
    , startSession DateTime
    , endSession DateTime NULL
    , duration Int
    , upTx Int64
    , downTx Int64
    , created_at DateTime
)
ENGINE = ReplicatedMergeTree('/clickhouse/shard_{shard_c2sh2rep}/{database}/{table}','{replica_c2sh2rep}')
PARTITION BY toYYYYMMDD(startSession)
ORDER BY startSession;

DROP TABLE IF EXISTS ods.tc_cdr ON CLUSTER c2sh2rep NO DELAY;
CREATE TABLE ods.tc_cdr ON CLUSTER c2sh2rep
AS ods.tc_cdr_rep
ENGINE = Distributed(c2sh2rep, ods, tc_cdr_rep, idSubscriber);

-- Матвью создаем именно над реплицированной таблицей
--drop view ods.tc_cdr_mv ON CLUSTER c2sh2rep ;
CREATE MATERIALIZED VIEW ods.tc_cdr_mv ON CLUSTER c2sh2rep TO ods.tc_cdr_rep
AS
SELECT
    idSession
    , idPSX
    , idSubscriber
    , parseDateTime(startSession, '%d-%m-%Y %H:%i:%s') as startSession
    , CASE WHEN endSession IS NULL
        THEN NULL
        ELSE parseDateTimeBestEffort(endSession)
    END AS endSession
    , duration
    , upTx
    , downTx
    , created_at
FROM stg.tc_cdr_rep;

TRUNCATE stg.tc_cdr_rep  ON CLUSTER c2sh2rep;  -- транкейтим именно реплицированную таблицу
TRUNCATE ods.tc_cdr_rep  ON CLUSTER c2sh2rep;


INSERT INTO stg.tc_cdr (idSession, idPSX, idSubscriber, startSession, endSession, duration, upTx, downTx)
SELECT IdSession, IdPSX, IdSubscriber, StartSession, EndSession, Duartion, UpTx, DownTx
FROM file('/var/lib/clickhouse/user_files/data/TelecomX/telecom100k/psx_6*.0_2024-01-* *:*:*.csv', CSVWithNames);

SELECT count() FROM ods.tc_cdr;
SELECT * FROM ods.tc_cdr;

select uniq(idSubscriber) from ods.tc_cdr cdr

select DISTINCT (startSession) from stg.tc_cdr order by 1 ;