FROM debian:wheezy
MAINTAINER GeekDev <geekdev@geekpolis.com>
ENV DEBIAN_FRONTEND noninteractive
RUN rm /bin/sh && ln -s /bin/bash /bin/sh

# Install packages.
RUN apt-get update
RUN apt-get install -y \
    mysql-server \
    pwgen

RUN apt-get clean

# Exposed ENV
ENV CREATE_DB yes

# Setup MySQL, bind on all addresses.
RUN sed -i -e 's/^bind-address\s*=\s*127.0.0.1/#bind-address = 127.0.0.1/' /etc/mysql/my.cnf

# Add MySQL scripts
ADD start.sh /start.sh
RUN chmod 755 /start.sh


EXPOSE 3306
CMD ["/start.sh"]
