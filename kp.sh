#!/bin/bash

set -u

source config.sh
source messenger.sh

#Options
ST_NAME=$1

# Log
LOG_DIR=./logs

# Health
HEALTH_CHECK_INTERVAL=5 #seconds
HEALTH_FILE=./temp/health.txt
HEALTS_STATUS_ACTIVE=1
HEALTS_STATUS_WAIT=0
HEALTS_STATUS_BAD=-1

#Consts
SLEEP=0.5

function write_log() {
	local from=$1
	local text=$2

	local date=$(date +"%Y-%m-%d")
	local timestamp=$(date +"%Y-%m-%dT%H-%M-%S")
	echo "$timestamp $from \"$text\"" >> "$LOG_DIR/$from-$date.log"
	echo "$timestamp $from \"$text\"" >> "$LOG_DIR/all-$date.log"
	sqlite3 "$DB_FILE" "INSERT INTO messages VALUES ('$timestamp', '$from', '$text');"
}

function process_pong_message() {
	local from=$1
	update_health_status $from $HEALTS_STATUS_ACTIVE
}

function check_health() {
	for station in $STATIONS; do
		if [ "$station" != "$ST_NAME" ]; then
			send_message $STATION_KP $station $MESSAGE_TYPE_PING ""
			update_health_status $station $HEALTS_STATUS_WAIT
		fi
	done
}

function update_health_status() {
	local station=$1
	local new_health_status=$2

	cur_health_status=$(cat $HEALTH_FILE | grep "^$station " | cut -d' ' -f2)
	if [ -z "$cur_health_status" ]; then
		cur_health_status=$HEALTS_STATUS_BAD
	fi
	if [[ "$cur_health_status" -eq $HEALTS_STATUS_WAIT && "$new_health_status" -eq $HEALTS_STATUS_WAIT ]]; then
		new_health_status=$HEALTS_STATUS_BAD
		write_log $STATION_KP "Элемент системы $station. Работоспособность потеряна."
	elif [[ "$cur_health_status" == $HEALTS_STATUS_BAD && "$new_health_status" == $HEALTS_STATUS_ACTIVE ]]; then 
		write_log $STATION_KP "Элемент системы $station. Работоспособность восстановлена."
	elif [[ "$cur_health_status" == $HEALTS_STATUS_BAD && "$new_health_status" == $HEALTS_STATUS_WAIT ]]; then 
		new_health_status=$HEALTS_STATUS_BAD
	fi

	health=$(cat $HEALTH_FILE | grep -v "$station ")
	echo "$health" > $HEALTH_FILE 
	echo "$station $new_health_status" >> $HEALTH_FILE
}

write_log $STATION_KP "######################################"
write_log $STATION_KP "Запущен $ST_NAME."
echo "" > $HEALTH_FILE
last_check_health_time=0
while true; do
	messages=$(try_recieve_messages $ST_NAME)
	# echo -e $messages
	# for message in $messages; do
	echo -e $messages | while IFS= read -r message; do
		message_type=$(echo $message | cut -d' ' -f1)
		message_from=$(echo $message | cut -d' ' -f2)
		message_text=$(echo $message | cut -d' ' -f3-)
		if [ "$message_type" == $MESSAGE_TYPE_LOG ]; then 
			write_log "$message_from" "$message_text"
		elif [ "$message_type" == $MESSAGE_TYPE_PONG ]; then
			process_pong_message "$message_from"
		fi
	done

	current_time=$(date +%s)
	if (( $current_time >= $last_check_health_time + $HEALTH_CHECK_INTERVAL )); then
    	check_health
    	last_check_health_time=$current_time
  	fi

	sleep $SLEEP
done
