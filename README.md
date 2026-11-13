# infra-monitoring-project

Итоговое домашнее задание: мониторинг доступности API, анализ логов,
контейнеризация и CI/CD.

**Автор:** Дунаев Ислам Романович, группа РИМ-160980к

## Структура проекта

```
infra-monitoring-project/
├── .github/workflows/ci.yml   # пайплайн GitHub Actions
├── nginx/default.conf         # конфиг nginx (прокси на api:8080)
├── traffic/capture_http.pcapng# дамп HTTP-трафика из Wireshark
├── check_api.sh               # скрипт мониторинга API
├── analyze_logs.sh            # генерация и анализ access.log
├── docker-compose.yml         # стек api + proxy
├── .gitignore
└── README.md
```

## Требования

- Bash 3.2+ (macOS) или 4+ (Linux), `curl`, `grep`, `awk`, `sort`, `uniq`
- Docker и Docker Compose

## Скрипты

### check_api.sh — мониторинг API

```bash
chmod +x check_api.sh
./check_api.sh https://httpbin.org/status/200   # API доступен, код возврата 0
./check_api.sh https://httpbin.org/status/404   # API недоступен, код ответа: 404, код возврата 1
```

Скрипт принимает URL аргументом, делает запрос через `curl`, сравнивает код
ответа с 200 и возвращает `0` при успехе и `1` при ошибке (в том числе при
отсутствии аргумента или некорректном URL).

### analyze_logs.sh — анализ логов

```bash
chmod +x analyze_logs.sh
./analyze_logs.sh                 # access.log, 300 строк
./analyze_logs.sh my.log 1000     # свой файл и количество строк
```

Скрипт генерирует `access.log` (не меньше 300 строк) и с помощью
`grep`, `awk`, `sort`, `uniq` выводит:

- общее количество запросов;
- топ-3 IP-адреса по числу запросов (IP извлекаются регулярным выражением
  `^([0-9]{1,3}\.){3}[0-9]{1,3}`);
- количество ответов с кодами 4xx и 5xx.

## Docker Compose

```bash
docker-compose up -d
docker-compose ps
curl http://localhost:80          # Monitoring Service Active
docker-compose down
```

- `api` — образ `hashicorp/http-echo`, отвечает текстом
  «Monitoring Service Active» на порту 8080 (порт доступен только внутри сети);
- `proxy` — `nginx:alpine`, принимает запросы на порту 80 и проксирует их на
  `http://api:8080`;
- оба сервиса подключены к внутренней bridge-сети `monitoring-net`, где `api`
  доступен по имени сервиса.

## CI/CD

Пайплайн `.github/workflows/ci.yml` запускается при создании Pull Request в
`main` и выполняет:

1. `bash -n check_api.sh` и `bash -n analyze_logs.sh` — проверку синтаксиса;
2. `./check_api.sh https://httpbin.org/status/200` — ожидается код возврата 0;
3. негативный тест `check_api.sh` (код 404 → код возврата 1);
4. запуск `analyze_logs.sh` и проверку, что в логе не меньше 300 строк;
5. `docker compose config` — проверку синтаксиса `docker-compose.yml`.

## Деплой на удалённый сервер (SSH и SCP)

### 1. Генерация SSH-ключей

```bash
ssh-keygen -t ed25519 -C "deploy@infra-monitoring" -f ~/.ssh/id_ed25519_deploy
```

Создаются закрытый ключ `~/.ssh/id_ed25519_deploy` (никому не передаётся) и
открытый `~/.ssh/id_ed25519_deploy.pub`.

### 2. Копирование публичного ключа на сервер

```bash
ssh-copy-id -i ~/.ssh/id_ed25519_deploy.pub user@203.0.113.10
ssh -i ~/.ssh/id_ed25519_deploy user@203.0.113.10   # проверка входа без пароля
```

Для удобства можно добавить хост в `~/.ssh/config`:

```
Host monitoring-server
    HostName 203.0.113.10
    User user
    IdentityFile ~/.ssh/id_ed25519_deploy
```

После этого достаточно писать `ssh monitoring-server`. Рекомендуется
отключить вход по паролю на сервере (`PasswordAuthentication no` в
`/etc/ssh/sshd_config`).

### 3. Передача проекта на сервер

Вариант А — архив и `scp`:

```bash
tar -czf infra-monitoring-project.tar.gz --exclude=.git --exclude='*.log' .
scp infra-monitoring-project.tar.gz monitoring-server:/opt/
ssh monitoring-server "mkdir -p /opt/infra-monitoring-project && \
  tar -xzf /opt/infra-monitoring-project.tar.gz -C /opt/infra-monitoring-project"
```

Вариант Б — `tar` через `ssh` без промежуточного файла:

```bash
tar -czf - --exclude=.git --exclude='*.log' . | \
  ssh monitoring-server "mkdir -p /opt/infra-monitoring-project && \
  tar -xzf - -C /opt/infra-monitoring-project"
```

### 4. Запуск на сервере

```bash
ssh monitoring-server "cd /opt/infra-monitoring-project && \
  docker compose pull && docker compose up -d && docker compose ps"
ssh monitoring-server "/opt/infra-monitoring-project/check_api.sh http://localhost:80"
```

## Анализ сетевого трафика

Дамп `traffic/capture_http.pcapng` снят в Wireshark (интерфейс VPN-туннеля
`utun4`, фильтр `http`) во время запросов `curl` к `http://httpbin.org`.
Подробный разбор — в отчёте.
