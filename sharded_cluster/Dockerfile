FROM clickhouse/clickhouse-server:25.1

# install clickhouse-backup
RUN mkdir clickhouse-backup && cd clickhouse-backup &&\
    wget https://github.com/Altinity/clickhouse-backup/releases/download/v2.6.8/clickhouse-backup_2.6.8_amd64.deb && \
    dpkg -i clickhouse-backup_2.6.8_amd64.deb && \
    rm clickhouse-backup_2.6.8_amd64.deb

# Полезные утилиты
RUN apt update && \
    apt install -y bind9-host bat less iputils-ping && \
    apt clean
