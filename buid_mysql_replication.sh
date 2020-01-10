#!/bin/bash

docker-compose down
docker-compose up -d

sleep 10
docker exec -it mysql_master mysql -uroot -pmypass \
  -e "INSTALL PLUGIN rpl_semi_sync_master SONAME 'semisync_master.so';" \
  -e "SET GLOBAL rpl_semi_sync_master_enabled = 1;" \
  -e "SET GLOBAL rpl_semi_sync_master_wait_for_slave_count = 2;" \
  -e "SHOW VARIABLES LIKE 'rpl_semi_sync%';"


sleep 1
docker exec -it mysql_master mysql -uroot -pmypass \
  -e "CREATE USER 'repl'@'%' IDENTIFIED BY 'slavepass';" \
  -e "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';" \
  -e "SHOW MASTER STATUS;"

sleep 1
for N in 1
  do docker exec -it mysql_slave$N mysql -uroot -pmypass \
    -e "INSTALL PLUGIN rpl_semi_sync_slave SONAME 'semisync_slave.so';" \
    -e "SET GLOBAL rpl_semi_sync_slave_enabled = 1;" \
    -e "SHOW VARIABLES LIKE 'rpl_semi_sync%';"
done

sleep 1
MASTER_LOG_FILE='mysql-bin-1.000003'

for N in 1
  do docker exec -it mysql_slave$N mysql -uroot -pmypass \
    -e "CHANGE MASTER TO MASTER_HOST='mysql_master', MASTER_USER='repl', \
      MASTER_PASSWORD='slavepass', MASTER_LOG_FILE='mysql-bin-1.000003';"

  docker exec -it mysql_slave$N mysql -uroot -pmypass -e "START SLAVE;"
done

sleep 1
# Kiem tra slave
docker exec -it mysql_slave1 mysql -uroot -pmypass -e "SHOW SLAVE STATUS\G"

sleep 1
# Test ket qua
docker exec -it mysql_master mysql -uroot -pmypass -e "CREATE DATABASE TEST2; SHOW DATABASES;"

sleep 1
for N in 1
  do docker exec -it mysql_slave$N mysql -uroot -pmypass \
  -e "SHOW VARIABLES WHERE Variable_name = 'hostname';" \
  -e "SHOW DATABASES;"
done
