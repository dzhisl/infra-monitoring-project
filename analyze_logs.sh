#!/usr/bin/env bash
#
# analyze_logs.sh — генерирует тестовый access.log и анализирует его.
# Использование: ./analyze_logs.sh [файл_лога] [количество_строк]
#   по умолчанию: access.log, 300 строк.

set -u

LOG_FILE="${1:-access.log}"
LINES="${2:-300}"

if ! [[ "$LINES" =~ ^[0-9]+$ ]] || [ "$LINES" -lt 300 ]; then
    echo "Количество строк должно быть числом не меньше 300" >&2
    exit 1
fi

# ---------- 1. Генерация тестового лога ----------
IPS=(192.168.1.10 192.168.1.15 192.168.1.22 10.0.0.5 10.0.0.12 172.16.0.3 172.16.0.8 203.0.113.7)
REQUESTS=("GET /api/users" "GET /api/orders" "GET /api/health" "POST /api/login" "POST /api/orders" "PUT /api/users/42" "DELETE /api/orders/7")
CODES=(200 200 200 200 201 204 301 400 401 403 404 500 502 503)

generate_log() {
    : > "$LOG_FILE"
    local i ip req code sec h m s
    for ((i = 0; i < LINES; i++)); do
        # Первые IP встречаются чаще — чтобы топ был наглядным
        ip=${IPS[$(( (RANDOM % 4 == 0) ? RANDOM % ${#IPS[@]} : RANDOM % 3 ))]}
        req=${REQUESTS[$((RANDOM % ${#REQUESTS[@]}))]}
        code=${CODES[$((RANDOM % ${#CODES[@]}))]}
        sec=$((10 * 3600 + 15 * 60 + i))
        h=$((sec / 3600)); m=$((sec % 3600 / 60)); s=$((sec % 60))
        printf '%s - - [15/Aug/2026:%02d:%02d:%02d] "%s HTTP/1.1" %s\n' \
            "$ip" "$h" "$m" "$s" "$req" "$code" >> "$LOG_FILE"
    done
}

generate_log
echo "Сгенерирован файл $LOG_FILE ($(wc -l < "$LOG_FILE" | tr -d ' ') строк)"
echo "Пример записей:"
head -n 3 "$LOG_FILE" | sed 's/^/  /'
echo

# ---------- 2. Анализ ----------
# Регулярное выражение для IPv4-адреса в начале строки
IP_REGEX='^([0-9]{1,3}\.){3}[0-9]{1,3}'

TOTAL=$(grep -cE "$IP_REGEX" "$LOG_FILE")
echo "Общее количество запросов: $TOTAL"
echo

echo "Топ-3 IP-адреса по числу запросов:"
grep -oE "$IP_REGEX" "$LOG_FILE" \
    | sort | uniq -c | sort -rn | head -n 3 \
    | awk '{ printf "  %d. %-16s — запросов: %s\n", NR, $2, $1 }'
echo

# Код ответа — последнее поле строки
COUNT_4XX=$(awk '$NF ~ /^4[0-9][0-9]$/ { c++ } END { print c + 0 }' "$LOG_FILE")
COUNT_5XX=$(awk '$NF ~ /^5[0-9][0-9]$/ { c++ } END { print c + 0 }' "$LOG_FILE")
echo "Запросов с кодами 4xx: $COUNT_4XX"
echo "Запросов с кодами 5xx: $COUNT_5XX"
echo "Всего ошибок (4xx + 5xx): $((COUNT_4XX + COUNT_5XX))"
