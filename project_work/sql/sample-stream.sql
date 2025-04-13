CREATE DATABASE stg ON CLUSTER c2sh2rep;

-- Создаем реплицированную таблицу как подложку для шардированной
DROP TABLE IF EXISTS stg.samplekafka2CH_rep3  ON CLUSTER c2sh2rep NO DELAY;
CREATE TABLE stg.samplekafka2CH_rep3 ON CLUSTER c2sh2rep
(
    dttm DateTime
    , txt String
    , created_at DateTime DEFAULT now()
)
ENGINE = ReplicatedMergeTree('/clickhouse/shard_{shard_c2sh2rep}/{database}/{table}','{replica_c2sh2rep}')
PARTITION BY toYYYYMMDD(dttm)
ORDER BY dttm;

-- Распределенная таблица поверх реплицированной
DROP TABLE IF EXISTS stg.samplekafka2CH_sh ON CLUSTER c2sh2rep;
CREATE TABLE stg.samplekafka2CH_sh ON CLUSTER c2sh2rep
AS stg.samplekafka2CH_rep3
ENGINE = Distributed(c2sh2rep, stg, samplekafka2CH_rep3, rand());

-- Количество данных
select count(*) from stg.samplekafka2CH_sh

-- Раскладка данных по шардам
SELECT hostName() AS hostname, shardNum() AS shard_number, count(*) AS cnt FROM stg.samplekafka2CH_sh AS t GROUP BY 1, 2;

-- Смотрим, что залилось
SELECT * FROM stg.samplekafka2CH_sh ORDER BY created_at DESC limit 10;
