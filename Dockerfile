FROM debian:wheezy
MAINTAINER Geekdev <geekdev@geekpolis.com>
ENV DEBIAN_FRONTEND noninteractive
RUN rm /bin/sh && ln -s /bin/bash /bin/sh

# Install packages.
RUN apt-get update
RUN apt-get install -y \
    vim \
    git \
    apache2 \
    php-apc \
    php5-fpm \
    php5-cli \
    php5-mysql \
    php5-gd \
    php5-curl \
    libapache2-mod-php5 \
    curl \
    mysql-server \
    mysql-client \
    phpmyadmin \
    wget \
    supervisor \
    unzip
RUN apt-get clean

# Install Composer.
RUN curl -sS https://getcomposer.org/installer | php
RUN mv composer.phar /usr/local/bin/composer

# Install Drush 7.
RUN composer global require drush/drush:7.*
RUN composer global update
# Unfortunately, adding the composer vendor dir to the PATH doesn't seem to work. So:
RUN ln -s /root/.composer/vendor/bin/drush /usr/local/bin/drush

# Setup PHP.
RUN sed -i 's/display_errors = Off/display_errors = On/' /etc/php5/apache2/php.ini
RUN sed -i 's/display_errors = Off/display_errors = On/' /etc/php5/cli/php.ini

# Setup Blackfire.
# Get the sources and install the Debian packages.
# We create our own start script. If the environment variables are set, we
# simply start Blackfire in the foreground. If not, we create a dummy daemon
# script that simply loops indefinitely. This is to trick Supervisor into
# thinking the program is running and avoid unnecessary error messages.
RUN wget -O - https://packagecloud.io/gpg.key | apt-key add -
RUN echo "deb http://packages.blackfire.io/debian any main" > /etc/apt/sources.list.d/blackfire.list
RUN apt-get update
RUN apt-get install -y blackfire-agent blackfire-php
RUN echo -e '#!/bin/bash\n\
if [[ -z "$BLACKFIREIO_SERVER_ID" || -z "$BLACKFIREIO_SERVER_TOKEN" ]]; then\n\
    while true; do\n\
        sleep 1000\n\
    done\n\
else\n\
    /usr/bin/blackfire-agent -server-id="$BLACKFIREIO_SERVER_ID" -server-token="$BLACKFIREIO_SERVER_TOKEN"\n\
fi\n\
' > /usr/local/bin/launch-blackfire
RUN chmod +x /usr/local/bin/launch-blackfire
RUN mkdir -p /var/run/blackfire

# Setup Apache.
# In order to run our Simpletest tests, we need to make Apache
# listen on the same port as the one we forwarded. Because we use
# 8080 by default, we set it up for that port.
RUN sed -i 's/AllowOverride None/AllowOverride All/' /etc/apache2/sites-available/default
RUN echo "Listen 8080" >> /etc/apache2/ports.conf
RUN sed -i 's/VirtualHost *:80/VirtualHost */' /etc/apache2/sites-available/default
RUN a2enmod rewrite

# Setup PHPMyAdmin
RUN echo -e "\n# Include PHPMyAdmin configuration\nInclude /etc/phpmyadmin/apache.conf\n" >> /etc/apache2/apache2.conf
RUN sed -i -e "s/\/\/ \$cfg\['Servers'\]\[\$i\]\['AllowNoPassword'\]/\$cfg\['Servers'\]\[\$i\]\['AllowNoPassword'\]/g" /etc/phpmyadmin/config.inc.php

# Setup MySQL, bind on all addresses.
RUN sed -i -e 's/^bind-address\s*=\s*127.0.0.1/#bind-address = 127.0.0.1/' /etc/mysql/my.cnf

# Setup Supervisor.
RUN echo -e '[program:apache2]\ncommand=/bin/bash -c "source /etc/apache2/envvars && exec /usr/sbin/apache2 -DFOREGROUND"\nautorestart=true\n\n' >> /etc/supervisor/supervisord.conf
RUN echo -e '[program:mysql]\ncommand=/usr/bin/pidproxy /var/run/mysqld/mysqld.pid /usr/sbin/mysqld\nautorestart=true\n\n' >> /etc/supervisor/supervisord.conf
RUN echo -e '[program:sshd]\ncommand=/usr/sbin/sshd -D\n\n' >> /etc/supervisor/supervisord.conf
RUN echo -e '[program:blackfire]\ncommand=/usr/local/bin/launch-blackfire\n\n' >> /etc/supervisor/supervisord.conf

# Install Drupal.
ADD . /src
RUN rm -rf /var/www

RUN mkdir -p /src/app && \
    cd /src/app && \
    drush make ../drupal.make -y && \
    drush make --no-core  --contrib-destination=./sites/all ../project.make -y && \
    mv ../modules/custom sites/all/modules/custom && \
    mv ../themes/custom sites/all/themes/custom && \
    cd / && mv /src/app /var/www && \
    mkdir -p /var/www/sites/default/files && \
    chmod a+w /var/www/sites/default -R && \
    chown -R www-data:www-data /var/www/

RUN /etc/init.d/mysql start && \
    cd /var/www && \
    drush si -y minimal --db-url=mysql://root:@localhost/drupal --account-pass=admin && \
    drush dl admin_menu devel && \
    drush en -y admin_menu

EXPOSE 80
CMD exec supervisord -n
