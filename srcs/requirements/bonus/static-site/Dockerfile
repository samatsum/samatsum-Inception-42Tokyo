FROM debian:bookworm

RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-flask \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY app/ /app/
COPY tools/script.sh /script.sh

RUN chmod +x /script.sh

EXPOSE 5000

CMD ["/script.sh"]
