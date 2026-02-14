FROM debian:bullseye

EXPOSE 3306

RUN apt update && apt upgrade -y && apt install -y mariadb-server && \
    rm -rf /var/lib/mysql/*

COPY conf/50-server.cnf /etc/mysql/mariadb.conf.d/.
COPY tools/script.sh .

RUN mkdir -p /run/mysqld && \
    chown mysql:mysql /run/mysqld && \
    chmod +x script.sh

CMD ["./script.sh"]
