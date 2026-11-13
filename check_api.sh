#!/usr/bin/env bash
#
# check_api.sh — проверка доступности API.
# Использование: ./check_api.sh <URL>
# Код возврата: 0 — API доступен (HTTP 200), 1 — ошибка.

set -u

if [ "$#" -ne 1 ] || [ -z "$1" ]; then
    echo "Использование: $0 <URL>" >&2
    echo "Пример: $0 https://httpbin.org/status/200" >&2
    exit 1
fi

URL="$1"

# Проверяем, что аргумент похож на URL (http:// или https://)
if ! [[ "$URL" =~ ^https?://[^[:space:]]+$ ]]; then
    echo "API недоступен, код ответа: 000 (некорректный URL: $URL)"
    exit 1
fi

# -s  — без прогресса, -o /dev/null — тело ответа не нужно,
# -w  — печатаем только HTTP-код, --retry — повтор при временных сбоях (5xx)
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    --max-time 15 --retry 3 --retry-delay 2 "$URL")

if [ "$HTTP_CODE" -eq 200 ]; then
    echo "API доступен"
    exit 0
else
    echo "API недоступен, код ответа: $HTTP_CODE"
    exit 1
fi
