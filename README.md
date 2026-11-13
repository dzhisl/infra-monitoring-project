# infra-monitoring-project

Итоговое домашнее задание по дисциплине. Дунаев Ислам Романович, группа РИМ-160980к.

В проекте скрипт для проверки доступности API, скрипт для анализа логов, docker-compose с echo-сервером и nginx, пайплайн GitHub Actions и дамп трафика из Wireshark.

## Что есть в репозитории

- check_api.sh - проверка API по URL
- analyze_logs.sh - генерирует access.log и считает по нему статистику
- docker-compose.yml и nginx/default.conf - сервис api и прокси перед ним
- .github/workflows/ci.yml - проверки при pull request в main
- traffic/capture_http.pcapng - дамп HTTP-трафика

Для запуска нужны bash, curl, grep, awk и Docker с docker-compose.

## check_api.sh

Скрипт получает URL, делает запрос через curl и смотрит на код ответа. Если пришёл 200, пишет "API доступен" и выходит с кодом 0. Иначе пишет "API недоступен, код ответа: XXX" и выходит с кодом 1. Если URL не передан или он некорректный, тоже возвращается 1.

```bash
chmod +x check_api.sh
./check_api.sh https://httpbin.org/status/200
./check_api.sh https://httpbin.org/status/404
```

## analyze_logs.sh

Сначала создаёт файл access.log на 300 строк со случайными IP, запросами и кодами ответа. Потом выводит общее количество запросов, три IP с наибольшим числом запросов и сколько было ответов 4xx и 5xx. IP достаются из строк регуляркой `^([0-9]{1,3}\.){3}[0-9]{1,3}`, дальше sort, uniq и awk.

```bash
chmod +x analyze_logs.sh
./analyze_logs.sh
```

Можно передать своё имя файла и число строк, например `./analyze_logs.sh test.log 500`.

## Docker Compose

Два сервиса в общей сети monitoring-net. api запускает hashicorp/http-echo на порту 8080 и отвечает текстом "Monitoring Service Active". proxy это nginx:alpine, он слушает 80 порт и пересылает запросы на api:8080. Наружу открыт только порт 80.

```bash
docker-compose up -d
docker-compose ps
curl http://localhost:80
```

Остановить: `docker-compose down`.

## CI

Пайплайн запускается при pull request в main. Он проверяет синтаксис обоих скриптов через bash -n, запускает `./check_api.sh https://httpbin.org/status/200` и ждёт код 0, проверяет что на 404 скрипт возвращает 1, запускает analyze_logs.sh и проверяет docker-compose.yml командой docker compose config.

## Как перенести проект на сервер

Создаём ключ:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_deploy
```

Копируем публичный ключ на сервер и проверяем, что пускает без пароля (адрес и пользователь для примера):

```bash
ssh-copy-id -i ~/.ssh/id_ed25519_deploy.pub user@203.0.113.10
ssh -i ~/.ssh/id_ed25519_deploy user@203.0.113.10
```

Чтобы не писать каждый раз ключ и адрес, можно добавить в ~/.ssh/config:

```
Host monitoring-server
    HostName 203.0.113.10
    User user
    IdentityFile ~/.ssh/id_ed25519_deploy
```

После этого на сервере лучше выключить вход по паролю (PasswordAuthentication no в /etc/ssh/sshd_config).

Передать проект можно архивом через scp:

```bash
tar -czf project.tar.gz --exclude=.git --exclude='*.log' .
scp project.tar.gz monitoring-server:/opt/
ssh monitoring-server "mkdir -p /opt/infra-monitoring-project && tar -xzf /opt/project.tar.gz -C /opt/infra-monitoring-project"
```

Или сразу через tar и ssh, без промежуточного архива:

```bash
tar -czf - --exclude=.git --exclude='*.log' . | ssh monitoring-server "mkdir -p /opt/infra-monitoring-project && tar -xzf - -C /opt/infra-monitoring-project"
```

Потом запускаем на сервере и проверяем:

```bash
ssh monitoring-server "cd /opt/infra-monitoring-project && docker compose up -d && docker compose ps"
ssh monitoring-server "/opt/infra-monitoring-project/check_api.sh http://localhost:80"
```

## Трафик

Дамп снимал в Wireshark во время запросов curl к http://httpbin.org (GET и POST). Захват шёл на интерфейсе utun4, потому что трафик идёт через VPN. Разбор есть в отчёте.
