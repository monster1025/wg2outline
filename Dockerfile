FROM golang:1.24-bookworm AS builder

RUN apt-get update && apt-get install -y git

# Клонируем репозиторий и собираем приложение
WORKDIR /outline-sdk
RUN git clone https://github.com/OutlineFoundation/outline-sdk.git .
WORKDIR /outline-sdk/x/examples/outline-cli

RUN CGO_ENABLED=1 go build -o /outline-cli -ldflags="-extldflags=-static" .

FROM debian:bookworm
RUN apt-get update && apt-get install -y curl wget
# Устанавливаем необходимые утилиты для работы сети и создаем пустой resolv.conf.head
RUN apt-get update && apt-get install -y iproute2 iptables && \
    rm -rf /var/lib/apt/lists/* && \
    touch /etc/resolv.conf.head

# Копируем собранный бинарный файл из этапа сборки
COPY --from=builder /outline-cli /usr/local/bin/outline-cli

# Обертка-энтрипоинт: готовит DNS и запускает outline-cli
COPY entrypoint.sh /usr/local/bin/outline-entrypoint.sh

# Делаем бинарный файл исполняемым
RUN chmod +x /usr/local/bin/outline-cli /usr/local/bin/outline-entrypoint.sh

# Точка входа
ENTRYPOINT ["/usr/local/bin/outline-entrypoint.sh"]

