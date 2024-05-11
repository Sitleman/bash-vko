#!/bin/bash

source config.sh

function init_db() {
    rm -rf "$DB_FILE"

    sqlite3 "$DB_FILE" "CREATE TABLE IF NOT EXISTS messages (timestamp TEXT, station TEXT, message TEXT);"

    # echo $DB_FILE
    if [ $? -eq 0 ]; then
        echo "База создана."
    else
        echo "Ошибка во время создания базы."
    fi
}

function watch_db() {
    watch -n1 "sqlite3 ./db/messages.db \"SELECT * FROM messages;\" | column -t -s '|' | tail -n 30"
}

function is_db_init() {
    ls $DB_FILE 2>/dev/null | wc -l
}
