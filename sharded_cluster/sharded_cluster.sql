SELECT version();
SHOW clusters;
--system reload config;
SELECT * FROM system.zookeeper WHERE path = '/clickhouse/task_queue/replicas/'  

SHOW CREATE USER 'default';
SELECT * FROM system.replicas ; 

-- Проверяем работу кластера
DROP TABLE rep_table  ON CLUSTER c1sh4rep;
CREATE TABLE rep_table ON CLUSTER c1sh4rep
(
    `id` UInt64,
    `column1` String
)
ENGINE = ReplicatedMergeTree('/clickhouse/shard_{shard_c1sh4rep}/{database}/{table}','{replica_c1sh4rep}')
ORDER BY id;

INSERT INTO rep_table (id, column1) VALUES (1, 'abc'), (2, 'def');
SELECT * FROM rep_table;

-- Соберем данные с кластера
SELECT getMacro('replica_c1sh4rep') as "replica", * 
FROM remote('clickhouse1,clickhouse2,clickhouse3,clickhouse4', system.parts, 'default', '123456' )
WHERE table = 'rep_table';
-- FORMAT JSONEachRow;


-- Загрузка исходных данных для экспериментов - trips
CREATE TABLE trips (
    trip_id             UInt32,
    pickup_datetime     DateTime,
    dropoff_datetime    DateTime,
    pickup_longitude    Nullable(Float64),
    pickup_latitude     Nullable(Float64),
    dropoff_longitude   Nullable(Float64),
    dropoff_latitude    Nullable(Float64),
    passenger_count     UInt8,
    trip_distance       Float32,
    fare_amount         Float32,
    extra               Float32,
    tip_amount          Float32,
    tolls_amount        Float32,
    total_amount        Float32,
    payment_type        Enum('CSH' = 1, 'CRE' = 2, 'NOC' = 3, 'DIS' = 4, 'UNK' = 5),
    pickup_ntaname      LowCardinality(String),
    dropoff_ntaname     LowCardinality(String)
)
ENGINE = MergeTree
PRIMARY KEY (pickup_datetime, dropoff_datetime);

INSERT INTO trips
SELECT
    trip_id,
    pickup_datetime,
    dropoff_datetime,
    pickup_longitude,
    pickup_latitude,
    dropoff_longitude,
    dropoff_latitude,
    passenger_count,
    trip_distance,
    fare_amount,
    extra,
    tip_amount,
    tolls_amount,
    total_amount,
    payment_type,
    pickup_ntaname,
    dropoff_ntaname
FROM s3(
    'https://datasets-documentation.s3.eu-west-3.amazonaws.com/nyc-taxi/trips_{0..2}.gz',
    'TabSeparatedWithNames'
);

SELECT count(), uniqExact(trip_id) FROM trips;  -- оцениваем уникальность trip_id


----------------------------------------------
-- Полностью реплицированный кластер c1sh4rep
CREATE TABLE trips_replicated ON CLUSTER c1sh4rep
AS trips 
ENGINE=ReplicatedMergeTree('/clickhouse/shard_{shard_c1sh4rep}/{database}/{table}','{replica_c1sh4rep}');

INSERT INTO trips_replicated SELECT * FROM trips;

-- 
select count(*), uniqExact(trip_id) from trips_replicated;

SELECT hostName() AS hostname, shardNum() AS shard_number, count(*) AS cnt FROM trips_replicated AS t GROUP BY 1, 2;

SELECT * FROM system.clusters; 

SELECT cluster, shard_num, replica_num, host_name FROM system.clusters;

SHOW CREATE TABLE trips_replicated;


----------------------------------------------
-- Полностью шардированный кластер c4ch1rep
CREATE TABLE trips_full_sharded_source ON CLUSTER c4sh1rep AS trips;

CREATE TABLE trips_full_sharded ON CLUSTER c4sh1rep
AS trips_full_sharded_source
ENGINE = Distributed(c4sh1rep, default, trips_full_sharded_source, trip_id);

INSERT INTO trips_full_sharded SELECT * FROM trips;

-- агрегированный запрос на шардированном кластере
SELECT count(), uniq(trip_id), uniqExact(trip_id) FROM trips_full_sharded;  

-- Раскладка данных по шардам
SELECT hostName() AS hostname, shardNum() AS shard_number, count(*) AS cnt FROM trips_full_sharded AS t GROUP BY 1, 2 ORDER BY 2;


----------------------------------------------
-- Смешанный кластер c2sh2rep
-- Создаем реплицированную таблицу как подложку для шардированной
DROP TABLE IF EXISTS trips_c2sh2rep_source ON CLUSTER c2sh2rep;
CREATE TABLE trips_c2sh2rep_source ON CLUSTER c2sh2rep
AS trips 
ENGINE = ReplicatedMergeTree('/clickhouse/shard_{shard_c2sh2rep}/{database}/{table}','{replica_c2sh2rep}');

show table trips_c2sh2rep_source;
select * from system.zookeeper where path in ('/clickhouse/shard_01/', '/clickhouse/shard_02/')

-- Распределенная таблица поверх реплицированной
CREATE TABLE trips_c2sh2rep ON CLUSTER c2sh2rep
AS trips_c2sh2rep_source
ENGINE = Distributed(c2sh2rep, default, trips_c2sh2rep_source, trip_id);

-- Заливаем данные
INSERT INTO trips_c2sh2rep SELECT * FROM trips;

-- Смотрим, нет ли дублей (правильно ли разложилось)
SELECT count(), uniq(trip_id), uniqExact(trip_id) FROM trips_c2sh2rep;

-- раскладка по шардам
SELECT hostName() AS hostname, shardNum() AS shard_number, count(*) AS cnt FROM trips_c2sh2rep AS t GROUP BY 1, 2;

truncate trips_c2sh2rep;
truncate trips_c2sh2rep_source;
delete from trips_c2sh2rep where true;
ALTER TABLE trips_c2sh2rep_source DELETE where true ;
optimize table trips_c2sh2rep_source final;

----------------------------------------------
-- Соберем данные с кластера
SELECT 
    getMacro('replica_c1sh4rep') as "replica"
    --, * 
    , name
    , part_type
    , active
    , marks
    , rows
    , bytes_on_disk
    , table
    , engine
FROM remote('clickhouse1,clickhouse2,clickhouse3,clickhouse4', system.parts, 'default', '123456' )
WHERE table LIKE 'trips%'
ORDER BY table, replica;
