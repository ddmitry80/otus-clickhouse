# Проектная работа по курсу OTUS "ClickHouse для инженеров и архитекторов БД"

# Развертывание среды

## Clickhouse

Пользователь `default/123456`

Подлючение к серверам по jdbc:
- `jdbc:clickhouse://localhost:9123`
- `jdbc:clickhouse://localhost:9124`
- `jdbc:clickhouse://localhost:9125`
- `jdbc:clickhouse://localhost:9126`

Через CLI
- `docker compose exec -it clickhouse1 clickhouse-client -u default --password 123456`
- `docker compose exec -it clickhouse2 clickhouse-client -u default --password 123456`
- `docker compose exec -it clickhouse3 clickhouse-client -u default --password 123456`
- `docker compose exec -it clickhouse4 clickhouse-client -u default --password 123456`

## Kafka

Доступна на порту 9092, имя хоста `kafka`  

## Kafka-UI
doc: 
- https://docs.kafka-ui.provectus.io/
- https://habr.com/ru/articles/753398/  

ui: http://localhost:8082/   

При настройке указать:
- Cluster name: `Kafka Cluster` или любое другое
- Bootstrap Servers: `PLAINTEXT://kafka` port `29092`

## NiFi

- docs: https://nifi.apache.org/documentation/  
- url: http://localhost:18443/nifi/  

Файловая система хоста (каталог `nifi/shared-folder`) подключена к `/opt/nifi/nifi-current/ls-target`  

Для подключения из NiFi к сервисам, работающим на локальной машине, вместо `localhost` использовать `host.docker.internal`

### Подключение NiFi к БД

#### PostgreSQL
Расположение драйвера в контейнере: `/opt/nifi/nifi-current/drivers/postgresql-42.7.4.jar ` 

- Строка connection: `jdbc:postgresql://posgtgres:5432/app`  
- Database Driver Class Name: `org.postgresql.Driver`  
- user/password: `postgres`/`postgres`  

##### Clickhouse

- connection (не работает): `jdbc:ch:http://clickhouse1:9000/default`
- connection: `jdbc:clickhouse://clickhouse1:8123`


## Мониторинг

### Prometheus

Запускается автоматически. Доступен по http://localhost:9090/

### Grafana

Запускается автоматически. Пароль по умолчанию admin/admin, далее потребуется сменить.

Точка входа http://localhost:3000

Рекомендованый конфиг grafana_14192_rev4.json.

Для настройки сначала подключаем prometheus: Connections -> Add new connection -> Prometheus -> Add new datasource. Connection url: http://prometheus:9090 -> Save & test

Далее - подключаем дашборд Clickhouse: Dashboards -> New -> Import -> указать содержимое файла `grafana_14192_rev4.json` -> Указать ранее подключенный Prometheus.

