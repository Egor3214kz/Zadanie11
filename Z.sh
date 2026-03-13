
#!/bin/bash

# === backup_helper.sh ===
# Скрипт для создания резервных копий

# Цвета для вывода (опционально)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Переменные базовые
BACKUP_DIR="$HOME/backups"
LOG_FILE="$BACKUP_DIR/backup.log"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
MIN_SPACE_MB=100
RETENTION_DAYS=7

# Проверяем аргументы
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  echo "Использование: $0 исходная_директория [директория_для_бэкапа]"
  exit 0
fi

if [ $# -lt 1 ]; then
  echo -e "${RED}Ошибка: укажите директорию для резервного копирования${NC}"
  echo "Пример: ./backup_helper.sh /home/user/test_data /home/user/my_backups"
  exit 1
fi

SOURCE_DIR="$1"

if [ ! -z "$2" ]; then
  BACKUP_DIR="$2"
  LOG_FILE="$BACKUP_DIR/backup.log"
fi

# Проверка, что директории в домашнем каталоге
if [[ "$SOURCE_DIR" != "$HOME"* ]]; then
  echo -e "${RED}Ошибка: исходная директория должна находиться в домашнем каталоге${NC}"
  exit 1
fi

if [[ "$BACKUP_DIR" != "$HOME"* ]]; then
  echo -e "${RED}Ошибка: директория для бэкапов должна находиться в домашнем каталоге${NC}"
  exit 1
fi

# Проверяем существование исходной директории
if [ ! -d "$SOURCE_DIR" ]; then
  echo -e "${RED}Ошибка: исходная директория '$SOURCE_DIR' не существует${NC}"
  exit 1
fi

# Создаем директорию для бэкапа, если нет
mkdir -p "$BACKUP_DIR"

# Функция логирования
log_message() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
  echo -e "$1"
}

log_message "=== Запуск резервного копирования ==="
log_message "Исходник: $SOURCE_DIR"
log_message "Папка для бэкапов: $BACKUP_DIR"

# Проверка свободного места
AVAILABLE_SPACE=$(df "$BACKUP_DIR" | awk 'NR==2 {print $4}')
AVAILABLE_SPACE_MB=$((AVAILABLE_SPACE / 1024))

if (( AVAILABLE_SPACE_MB < MIN_SPACE_MB )); then
  log_message "${YELLOW}Внимание: свободно ${AVAILABLE_SPACE_MB}MB, меньше ${MIN_SPACE_MB}MB${NC}"
  read -r -p "Продолжить? (y/n): " REPLY
  if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
    log_message "Резервное копирование отменено пользователем"
    exit 0
  fi
fi

# Проверяем повторное создание бэкапа за последний час
LAST_BACKUP=$(find "$BACKUP_DIR" -maxdepth 1 -name "backup_*" -mmin -60 | head -n 1)
if [ -n "$LAST_BACKUP" ]; then
  log_message "${YELLOW}Резервная копия создана в последний час: $(basename "$LAST_BACKUP") - скрипт прерван${NC}"
  exit 0
fi

# Удаляем бэкапы старше 7 дней
find "$BACKUP_DIR" -type f -name "backup_*.tar.gz" -mtime +$RETENTION_DAYS -exec rm -f {} \;
log_message "Удалены архивы старше $RETENTION_DAYS дней"

# Имя архива
BASENAME=$(basename "$SOURCE_DIR")
BACKUP_FILE="$BACKUP_DIR/backup_${BASENAME}_$TIMESTAMP.tar.gz"

# Создаем архив
log_message "Создание архива $BACKUP_FILE"
tar -czf "$BACKUP_FILE" -C "$SOURCE_DIR" . >> "$LOG_FILE" 2>&1

if [ $? -ne 0 ]; then
  log_message "${RED}Ошибка при создании архива${NC}"
  exit 1
fi

# Вывод информации об архиве
log_message "Информация о архиве:"
SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
FILES_COUNT=$(tar -tzf "$BACKUP_FILE" | wc -l)
MD5=$(md5sum "$BACKUP_FILE" | cut -d ' ' -f1)

echo "Размер: $SIZE"
echo "Файлов в архиве: $FILES_COUNT"
echo "Контрольная сумма md5: $MD5"

# Отправляем уведомление (имитация)
echo "=== УВЕДОМЛЕНИЕ ===" > "$BACKUP_DIR/last_notification.txt"
echo "Резервная копия $BASENAME создана успешно" >> "$BACKUP_DIR/last_notification.txt"
echo "Время: $(date)" >> "$BACKUP_DIR/last_notification.txt"
echo "Файл: $BACKUP_FILE" >> "$BACKUP_DIR/last_notification.txt"

log_message "Резервное копирование завершено успешно"
log_message "Лог сохранён: $LOG_FILE"

# Вывод последних 5 строк лога
echo -e "\n${YELLOW}Последние 5 записей в логе:${NC}"
tail -5 "$LOG_FILE"
