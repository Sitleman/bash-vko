#!/bin/bash

DIR_MESSAGES="./messages"

#Message types
MESSAGE_TYPE_LOG="log"
MESSAGE_TYPE_PING="ping"
MESSAGE_TYPE_PONG="pong"

function send_message() {
	local from=$1
	local to=$2
	local type=$3
	local message=$4

	if [ "$type" == $MESSAGE_TYPE_PING ]; then
		find $DIR_MESSAGES -regex ".+_${MESSAGE_TYPE_PING}_${from}_${to}\.txt" -exec rm {} \;
	fi
	local timestamp=$(date +"%Y-%m-%dT%H-%M-%S-%N")
	local message_file="$DIR_MESSAGES/${timestamp}_${type}_${from}_${to}.txt"

	echo "$message" | base64 > "$message_file"
}


function try_recieve_messages() {
	local to=$1

	result=""
	message_files=$(ls $DIR_MESSAGES | grep -E ".+_.+_.+_${to}\.txt")
	for message_file in $message_files; do
		type=$(echo $message_file | cut -d'_' -f2)
		from=$(echo $message_file | cut -d'_' -f3)
		
		if [ "$type" == "$MESSAGE_TYPE_PING" ]; then
			send_message $to $from $MESSAGE_TYPE_PONG ""
		else 
			message_text=$(cat "$DIR_MESSAGES/$message_file" | base64 -d)
			result+=$(echo "$type $from $message_text\n")
		fi
		rm $(echo "$DIR_MESSAGES/$message_file")
	done
	echo $result
}
