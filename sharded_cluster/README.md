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

Настройка Minio
```sh
docker compose exec -it minio bash
# Создаем яльяс для minio cli
mc alias set myminio http://localhost:9000 minio minioadmin
# Пользователь для clickhouse
mc admin user add myminio ch_user ch_password
mc mb myminio/clickhouse
mc admin policy add myminio ch_policy /root/.minio/clickhouse-policy.json
# mc admin policy attach myminio ch_policy ch_user
mc admin user setpolicy myminio ch_user ch_policy
# Проверить назначенные доступы
mc admin policy list myminio
```
