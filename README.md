# wg2outline

WireGuard поверх Outline — Docker-образ, который поднимает WireGuard VPN-сервер и маршрутизирует весь его трафик через Outline (Shadowsocks) туннель.

## Как это работает

[WireGuard Peer] --UDP:51820--> [wg2outline: WireGuard + Outline CLI] --Shadowsocks--> [Outline Server] -- Internet

Outline CLI создаёт зашифрованный Shadowsocks-туннель, через который проходит весь трафик WireGuard-клиентов. Это позволяет обходить блокировки WireGuard'а — Outline трафик выглядит как обычный HTTPS.

## Требования

- Docker + Docker Compose
- Сервер с публичным IP
- Ключ доступа Outline (строка вида `ss://...` из Outline Manager)
- WireGuard модуль ядра (или встроенная поддержка)

## Быстрый старт

```bash
cp .env.sample .env
# Отредактируйте .env:
#   OUTLINE_TRANSPORT — ключ доступа Outline
#   SERVERURL — публичный IP вашего сервера
#   PEERS — количество клиентских конфигов
docker compose up -d
```

Конфигурационные файлы WireGuard для клиентов появятся в `./wireguard-config/peer1/`, `peer2/` и т.д.

## Переменные окружения

| Переменная | Описание |
|---|---|
| `OUTLINE_TRANSPORT` | Shadowsocks access URL от Outline сервера |
| `SERVERURL` | Публичный IP/DNS сервера |
| `PEERS` | Количество генерируемых клиентских конфигов (по умолч. 1) |
| `INTERNAL_SUBNET` | Подсеть WireGuard (по умолч. `10.13.13.0`) |

## Тестирование

```bash
./test-wg-client.sh ./wireguard-config/peer1/peer1.conf
```

Скрипт поднимает временный Alpine-контейнер, подключается к VPN и проверяет доступность внешних ресурсов через Outline.

## Сборка

```bash
docker compose build
```

Или вручную:

```bash
docker build -t wg2outline .
```

## Cтруктура проекта

```
├── Dockerfile              # Мульти-стадийная сборка (outline-cli + linuxserver/wireguard)
├── docker-compose.yml      # Docker Compose конфигурация
├── entrypoint.sh           # Альтернативный entrypoint (без s6-overlay)
├── root/
│   ├── custom-cont-init.d/ # Инициализация (фикс DNS)
│   └── etc/s6-overlay/     # s6 сервисы (svc-outline, svc-wireguard)
├── wireguard-config/
│   └── templates/          # Шаблоны конфигов WireGuard
├── test-wg-client.sh       # Интеграционный тест
└── .env.sample             # Пример переменных окружения
```

## CI/CD

При пуше в `main` или создании тега `v*` GitHub Actions автоматически собирает образ и публикует его на Docker Hub.
