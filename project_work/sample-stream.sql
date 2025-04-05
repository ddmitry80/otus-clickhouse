create database stg ON CLUSTER c2sh2rep;

-- Создаем реплицированную таблицу как подложку для шардированной
DROP TABLE stg.samplekafka2CH_rep2  ON CLUSTER c2sh2rep;
CREATE TABLE stg.samplekafka2CH_rep2 ON CLUSTER c2sh2rep
(
    dttm timestamp,
    txt text
)
ENGINE = ReplicatedMergeTree('/clickhouse/shard_{shard_c2sh2rep}/{database}/{table}','{replica_c2sh2rep}')
ORDER BY dttm;

-- Распределенная таблица поверх реплицированной
DROP TABLE IF EXISTS stg.samplekafka2CH_sh ON CLUSTER c2sh2rep;
CREATE TABLE stg.samplekafka2CH_sh ON CLUSTER c2sh2rep
AS stg.samplekafka2CH_rep2
ENGINE = Distributed(c2sh2rep, stg, samplekafka2CH_rep2, rand());

-- Смотрим, что залилось
SELECT * FROM stg.samplekafka2CH_sh ORDER BY dttm DESC;
