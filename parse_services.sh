#!/bin/bash

SERVER=${1:-default_server}
DATE_FMT1=$(date +"%d_%m_%Y")   # для имен файлов
DATE_FMT2=$(date +"%d/%m/%y")   # для отчета
INPUT_FILE="list.out"
URL="https://raw.githubusercontent.com/GreatMedivack/files/master/list.out"

FAILED_FILE="${SERVER}_${DATE_FMT1}_failed.out"
RUNNING_FILE="${SERVER}_${DATE_FMT1}_running.out"
REPORT_FILE="${SERVER}_${DATE_FMT1}_report.out"
ARCHIVE_DIR="archives"
ARCHIVE_NAME="${SERVER}_${DATE_FMT1}.tar.gz"
ARCHIVE_PATH="${ARCHIVE_DIR}/${ARCHIVE_NAME}"

#1. Скачивание исходного файла
curl -s -o "$INPUT_FILE" "$URL"
if [ $? -ne 0 ]; then
    echo "Ошибка при скачивании файла $URL"
    exit 1
fi

#2. Определяем номера столбцов
HEADER=$(head -n 1 "$INPUT_FILE")
NAME_IDX=$(echo "$HEADER" | awk '{for(i=1;i<=NF;i++) if($i=="NAME") print i}')
STATUS_IDX=$(echo "$HEADER" | awk '{for(i=1;i<=NF;i++) if($i=="STATUS") print i}')

if [ -z "$NAME_IDX" ] || [ -z "$STATUS_IDX" ]; then
    echo "Не найдены заголовки NAME или STATUS"
    exit 1
fi

# Чистим предыдущие файлы
> "$FAILED_FILE"
> "$RUNNING_FILE"

#3. Обработка данных
tail -n +2 "$INPUT_FILE" | while read -r line; do
    NAME=$(echo "$line" | awk -v idx="$NAME_IDX" '{print $idx}')
    STATUS=$(echo "$line" | awk -v idx="$STATUS_IDX" '{print $idx}')
    CLEAN_NAME=$(echo "$NAME" | sed -E 's/-[a-z0-9]+-[a-z0-9]+$//')

    case "$STATUS" in
        "Error"|"CrashLoopBackOff")
            echo "$CLEAN_NAME" >> "$FAILED_FILE"
            ;;
        "Running")
            echo "$CLEAN_NAME" >> "$RUNNING_FILE"
            ;;
    esac
done

#4. Создание отчета
FAILED_COUNT=$(wc -l < "$FAILED_FILE")
RUNNING_COUNT=$(wc -l < "$RUNNING_FILE")
USER_NAME=$(whoami)

{
    echo "Количество работающих сервисов: $RUNNING_COUNT"
    echo "Количество сервисов с ошибками: $FAILED_COUNT"
    echo "Имя системного пользователя: $USER_NAME"
    echo "Дата: $DATE_FMT2"
} > "$REPORT_FILE"

chmod 644 "$REPORT_FILE"

#5. Архивация
mkdir -p "$ARCHIVE_DIR"
if [ ! -f "$ARCHIVE_PATH" ]; then
    tar -czf "$ARCHIVE_PATH" "$FAILED_FILE" "$RUNNING_FILE" "$REPORT_FILE"
    echo "Архив создан: $ARCHIVE_PATH"
else
    echo "Архив уже существует: $ARCHIVE_PATH (новый архив не создан)"
fi

#6. Проверка архива
echo "Проверка архива на повреждение..."
if tar -tzf "$ARCHIVE_PATH" > /dev/null 2>&1; then
    echo "Архив в порядке: $ARCHIVE_PATH"

    # Удаляем всё кроме папки archives
    for item in *; do
        if [ "$item" != "$ARCHIVE_DIR" ]; then
            rm -rf "$item"
        fi
    done

    echo "Все временные файлы удалены, кроме папки $ARCHIVE_DIR"
    echo "Скрипт успешно завершил работу."

else
    echo "Архив повреждён или не может быть прочитан."
    echo "Временные файлы НЕ удалены. Проверь архив вручную: $ARCHIVE_PATH"
    exit 2
fi