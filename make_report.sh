#!/bin/bash
set -euo pipefail


#####################################
#            НАСТРОЙКИ              #
#####################################

# --- Параметры входного файла ---
URL="https://raw.githubusercontent.com/GreatMedivack/files/master/list.out"
OUTFILE="list.out"

# --- Параметры запуска ---
SERVER=${1:-ServerNotDefined}
DATE=$(date +%d_%m_%Y)

# --- Имена файлов ---
RUN_FILE="${SERVER}_${DATE}_running.out"
FAIL_FILE="${SERVER}_${DATE}_failed.out"
REPORT="${SERVER}_${DATE}_report.out"

ARCHDIR="archives"
ARCHIVE="${ARCHDIR}/${SERVER}_${DATE}.tar.gz"


#####################################
#              СКРИПТ               #
#####################################

# --- 1) Скачиваем входной файл ---
if ! wget -q -O "$OUTFILE" "$URL"
then
    echo "Ошибка: не удалось скачать $URL" >&2
    exit 1
fi

# --- 2) Формируем список Running ---
awk '
    NR > 1 && $3 == "Running" {
        name = $1
        sub(/-[^-]{9,10}-[^-]{5}$/, "", name)
        print name
    }
' "$OUTFILE" > "$RUN_FILE"

# --- 3) Формируем список Error / CrashLoopBackOff ---
awk '
    NR > 1 && ($3 == "Error" || $3 == "CrashLoopBackOff") {
        name = $1
        sub(/-[^-]{9,10}-[^-]{5}$/, "", name)
        print name
    }
' "$OUTFILE" > "$FAIL_FILE"

# --- 4) Формируем отчет ---
USER_NAME=$(whoami)
running_count=$(wc -l < "$RUN_FILE" || echo 0)
failed_count=$(wc -l < "$FAIL_FILE" || echo 0)

{
    echo "Количество работающих сервисов: $running_count"
    echo "Количество сервисов с ошибками: $failed_count"
    echo "Имя системного пользователя: $USER_NAME"
    echo "Дата: $(date +%d/%m/%y)"
} > "$REPORT"

chmod a+r "$REPORT"

# --- 5) Архивация ---
mkdir -p "$ARCHDIR"

if [ -e "$ARCHIVE" ]
then
    echo "Архив уже существует, перезапись не производится: $ARCHIVE"
    exit 2
else
    tar -czf "$ARCHIVE" "$OUTFILE" "$RUN_FILE" "$FAIL_FILE" "$REPORT"
fi

# --- 6) Удаляем временные файлы ---
rm -f "$OUTFILE" "$RUN_FILE" "$FAIL_FILE" "$REPORT"

# --- 7) Проверка архива ---
if tar -tzf "$ARCHIVE" > /dev/null 2>&1
then
    echo "Архив успешно создан и проверен: $ARCHIVE"
else
    echo "Ошибка: архив повреждён или не читается: $ARCHIVE" >&2
    exit 3
fi
