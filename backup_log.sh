#!/bin/env bash
# Скрипт для бэкапа всех файлов (кроме архивов) в указанной директории без сохранения полного пути.
# Удаляет файлы архивов старше 7 дней (по умолчанию).

if [[ -d "$1" ]]; then
	LOG_DIR="${1%/}"
else
	echo "ERROR: Provide valid path to log dir"
	exit 1
fi

if [[ -n "$2" ]]; then
	BACKUP_DIR="${2%/}"
else
	BACKUP_DIR=$LOG_DIR
	echo "Setting backup dir to log dir"
fi

DAYS_LIMIT=7
BACKUP_FILE="${BACKUP_DIR}/backup_$(date +%Y%m%d-%M%S).tar.gz"

if [[ $(find "$LOG_DIR" -type f -not -name "*.tar.gz" | wc -l) -eq 0 ]]; then
	echo "No logs in log dir. Quit"
	exit 1
else
	mkdir -p "$BACKUP_DIR"
	find "$LOG_DIR" -type f -not -name "*.tar.gz" -printf '%f\0' | \
		tar -czf "$BACKUP_FILE" -C "$LOG_DIR" --null --files-from -
fi

if [[ $? -eq 0 ]]; then
	echo "Created backup file: $BACKUP_FILE"
	find "$LOG_DIR" -type f -not -name "*.tar.gz" -delete
else
	echo "ERROR: Failed to create backup"
	exit 1
fi

find "$BACKUP_DIR" -type f -name "*.tar.gz" -mtime +"$DAYS_LIMIT" -delete
