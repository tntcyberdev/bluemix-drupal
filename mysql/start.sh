#!/bin/bash

VOLUME_HOME="/var/lib/mysql"
CONF_FILE="/etc/mysql/conf.d/my.cnf"
LOG="/var/log/mysql/error.log"

# Set permission of config file
chmod 644 ${CONF_FILE}
chmod 644 /etc/mysql/conf.d/mysqld_charset.cnf

# Start MySQL
/usr/bin/mysqld_safe > /dev/null 2>&1 &

# Time out in 1 minute for start mysql
LOOP_LIMIT=13
for (( i=0 ; ; i++ )); do
  if [ ${i} -eq ${LOOP_LIMIT} ]; then
    echo "Time out. Error log is shown as below:"
    tail -n 100 ${LOG}
    exit 1
  fi
  echo "=> Waiting for confirmation of MySQL service startup, trying ${i}/${LOOP_LIMIT} ..."
  sleep 5
  mysql -uroot -e "status" > /dev/null 2>&1 && break
done

# Import default data
if [ "$CREATE_DB" = "yes" ]; then
  echo "=> Create database"

  # Create database drupal
  echo "Creating MySQL database drupal"
  mysql -uroot -e "CREATE DATABASE IF NOT EXISTS drupal;"
  echo "Database created!"

  # Create user and password for database drupal
  echo "=> Creating MySQL user drupal with drupal password"
  mysql -uroot -e "CREATE USER drupal;"
  mysql -uroot -e "GRANT ALL ON drupal.* TO 'drupal'@'%' IDENTIFIED BY 'drupal';"
  echo "=> Done!"
fi

mysqladmin -uroot shutdown

tail -F $LOG &
exec mysqld_safe
