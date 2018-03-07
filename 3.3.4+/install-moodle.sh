#!/usr/bin/with-contenv /bin/bash

#Default runtime variables if none is supplied
NGINX_MAX_BODY_SIZE=${NGINX_MAX_BODY_SIZE:='1M'}
PHPFPM_UPLOAD_MAX_FILESIZE=${PHPFPM_UPLOAD_MAX_FILESIZE:='2M'}
CRON_MOODLE_INTERVAL=${CRON_MOODLE_INTERVAL:='15'}
MOODLECFG_SSLPROXY=${MOODLECFG_SSLPROXY:='false'}

MOODLE_LANG=${MOODLE_LANG:='en'}
MOODLE_WWWROOT=${MOODLE_WWWROOT:='http://localhost'}
MOODLE_DBHOST=${MOODLE_DBHOST:='moodle-postgres'}
MOODLE_DBNAME=${MOODLE_DBNAME:='moodle'}
MOODLE_DBUSER=${MOODLE_DBUSER:='moodle'}
MOODLE_DBPASS=${MOODLE_DBPASS:='moodle'}
MOODLE_DBPORT=${MOODLE_DBPORT:='5432'}
MOODLE_PREFIX=${MOODLE_PREFIX:='_mdl'}
MOODLE_FULLNAME=${MOODLE_FULLNAME:='Some Moodle Site Full Name'}
MOODLE_SHORTNAME=${MOODLE_SHORTNAME:='Some Moodle Site Short Name'}
MOODLE_SUMMARY=${MOODLE_SUMMARY:='Some Moodle Summary'}
MOODLE_ADMINUSER=${MOODLE_ADMINUSER:='admin'}
MOODLE_ADMINPASS=${MOODLE_ADMINPASS:='password'}
MOODLE_ADMINEMAIL=${MOODLE_ADMINEMAIL:='support@example.com'}

#This is terrible, TODO to actually wait until the DB is up. For now this works but wastes 30 seconds if recreating the container.
sleep 30;

#Moodle CLI to install Moodle with runtime variables
/usr/bin/php /var/www/html/admin/cli/install.php \
  --chmod=2777 \
  --lang=$MOODLE_LANG \
  --wwwroot=$MOODLE_WWWROOT \
  --dataroot=/var/www/moodledata \
  --dbtype=pgsql \
  --dbhost=$MOODLE_DBHOST \
  --dbname=$MOODLE_DBNAME \
  --dbuser=$MOODLE_DBUSER \
  --dbpass=$MOODLE_DBPASS \
  --dbport=$MOODLE_DBPORT \
  --prefix=$MOODLE_PREFIX \
  --fullname="$MOODLE_FULLNAME" \
  --shortname="$MOODLE_SHORTNAME" \
  --summary="$MOODLE_SUMMARY" \
  --adminuser=$MOODLE_ADMINUSER \
  --adminpass=$MOODLE_ADMINPASS \
  --adminemail=$MOODLE_ADMINEMAIL \
  --agree-license \
  --non-interactive

chown -R www-data:www-data /var/www/html

#Indicates this has already been run, and to only update SSL and RootURL's when recreating the config in the core install.
if [ -f /var/www/moodledata/do_not_remove ]; then
 echo "[install-moodle.sh] Breadcrumb file exists, Moodle is probably already installed but missing the config. Recreated config. Self-destructing and exiting."
 sed -i "/\\\*sslproxy\\\*/,+1 d" /var/www/html/config.php
 sed -i "/\\\*wwwroot\\\*/i \$CFG->sslproxy = $MOODLECFG_SSLPROXY;\n" /var/www/html/config.php
 rm -- "$0" && exit 0
fi

#Setup CRON
echo "*/$CRON_MOODLE_INTERVAL * * * * /usr/bin/php /var/www/html/admin/cli/cron.php" > /etc/cron.d/moodle

#Create a breadcrumb file
echo "Presence of this file will prevent execution of the docker install-moodle.sh script if the container is recreated." > /var/www/moodledata/do_not_remove

#Reset some configs with new user defined values (SSL Proxy, Upload Sizes) that are baked in if the container is destroyed
sed -i "/\\\*wwwroot\\\*/i \$CFG->sslproxy = $MOODLECFG_SSLPROXY;\n" /var/www/html/config.php
sed -i "/types_hash_max_size 2048;/a \\\tclient_max_body_size $NGINX_MAX_BODY_SIZE;" /etc/nginx/nginx.conf
sed -i "s/upload_max_filesize = 2M/upload_max_filesize = $PHPFPM_UPLOAD_MAX_FILESIZE/g" /etc/php/7.0/fpm/php.ini

#Self Destruct
echo "[install-moodle.sh] Install complete, self destructing and exiting."
rm -- "$0" && exit 0
