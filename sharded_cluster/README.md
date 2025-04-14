# Реализация шардированного/реплицированного кластера Clickhouse в Docker


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

## S3

Реализовано посредством Minio https://min.io/

Подключение к WebUI Minio: http://localhost:9111/  
Имя пользователя/пароль: `minio/minioadmin`

### Настройка Minio

Внимание! При ненастроенном S3 (Minio) кластер Clickhouse не сможет стартовать. Решение проблемы - произвести настройку S3 (указано ниже), либо отключить проброс конфигурации S3 в кластер в разделе `volumes` каждой ноды кластера.

Подключаемся к контейнеру
```sh
docker compose exec -it minio bash
```

Конфигурируем Minio из командной строки
```sh
# Создаем яльяс для minio cli
mc alias set myminio http://localhost:9000 minio minioadmin
# Пользователь для clickhouse
mc admin user add myminio ch_user ch_password
# Бакет для CH
mc mb myminio/clickhouse
# Политики доступа к бакету
mc admin policy create myminio ch_policy /root/.minio/clickhouse-policy.json
mc admin policy attach myminio ch_policy --user ch_user
# Проверить назначенные доступы
mc admin policy list myminio
```

## Postgres

Подключаться снаружи по порту 6432.

Запуск `psql':
```sh
docker compose exec -it postgres psql -d postgres -U postgres
docker compose exec -it postgres bash
```

### Загрузка демо датасета

```sh
cd postgres
wget https://edu.postgrespro.com/demo-big-en.zip
unzip demo-big-en.zip -d ./datasets/
docker compose exec -T postgres psql -d postgres -U postgres < datasets/demo-big-en-20170815.sql
```

## Мониторинг

### Prometheus

Запускается автоматически. Доступен по http://localhost:9090/

### Grafana

Запускается автоматически. Пароль по умолчанию admin/admin, далее потребуется сменить.

Точка входа http://localhost:3000

Рекомендованый конфиг grafana_14192_rev4.json.

Для настройки сначала подключаем prometheus: Connections -> Add new connection -> Prometheus -> Add new datasource. Connection url: http://prometheus:9090 -> Save & test

Далее - подключаем дашборд Clickhouse: Dashboards -> New -> Import -> указать содержимое файла `grafana_14192_rev4.json` -> Указать ранее подключенный Prometheus.

