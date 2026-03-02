FROM debian:bookworm

RUN apt update && apt upgrade -y && apt install -y \
    php8.2 \
    php8.2-fpm \
    php8.2-mysql \
    php8.2-redis \
    curl \
    wget \
    unzip \
    default-mysql-client

COPY conf/www.conf /etc/php/7.4/fpm/pool.d/.
COPY tools/script.sh .

RUN mkdir /run/php && \
    mkdir -p /var/www/html/wp-content/plugins && \
    wget -P /var/www/html/wp-content/plugins/ https://downloads.wordpress.org/plugin/redis-cache.latest-stable.zip && \
    cd /var/www/html/wp-content/plugins/ && \
    unzip redis-cache.latest-stable.zip && \
    rm redis-cache.latest-stable.zip

RUN echo "pm.status_path = /status" >> /etc/php/8.2/fpm/pool.d/www.conf

RUN chmod +x script.sh

CMD ["./script.sh"]
