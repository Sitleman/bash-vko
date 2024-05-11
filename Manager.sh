#!/bin/bash
set -u
# set -x
source config.sh
source db.sh

function print_help() {
	echo "usage: ./Manager.sh COMMAND [STATION...]
    COMMANDS:
    	start
    	stop
    	status
    	init_db
    	watch_db

    STATIONS:	Можно взаимодействовать с одной или несколькими станциями по выбору. (По умолчанию, все)
    	$STATION_RLS1
    	$STATION_RLS2
    	$STATION_RLS3
    	$STATION_ZRDN1
    	$STATION_ZRDN2
    	$STATION_ZRDN3
    	$STATION_SPRO
    	$STATION_KP"
}

function get_station_options(){
	local station_name=$1
	echo $(echo -e $STATIONS_OPTIONS | grep -E "($SCRIPT_STATION|$SCRIPT_KP) $station_name")
}

function command_start() {
	echo "" > ./logs/errors.log
	for station_name in "$@"; do
		station_options=$(get_station_options $station_name)
		if [ "${#station_options}" -eq 0 ]; then
			echo "Неизвестная STATION=$station_name. Пропускаем ее запуск."
		else 
			echo "Запускается $station_name..."
			$station_options 2>&1 | sed -u "s/^/${station_name}: /" >> ./logs/errors.log &
		fi
	done
}

function command_stop() {
	for station_name in "$@"; do
		station_options=$(get_station_options $station_name)
		if [ "${#station_options}" -eq 0 ]; then
			echo "Неизвестная STATION=$station_name. Пропускаем ее остановку."
		else 
			if [ "$(ps aux | grep -E "$station_options" | grep -v grep | wc -l)" -gt 0 ]; then
				echo "Останавливается $station_name..."
			fi
			pkill -f "$station_options"
		fi
	done
}

function commnad_status() {
	echo "USER PID STATION"
	total_process=""
	for station_name in "$@"; do
		station_options=$(get_station_options $station_name)
		if [ "${#station_options}" -eq 0 ]; then
			echo "Неизвестная STATION=$station_name. Пропускаем ее проверку статуса."
		else 
			process=$(ps --format user,pid,command | grep -E "$station_name" | grep -v grep | head -1)
			if [ ${#process} -gt 0 ]; then
				total_process+="$process\n"
			fi
		fi
	done
	echo -e $total_process
}

function check_permission() {
	if [ "$(id -u)" -eq 0 ]; then
	    echo "Запрешено запускать с root правами."
	    exit 1
	fi

	if [[ ! -v BASH_VERSION ]]; then
	    echo "Запрещено запускать в интерпретаторе отличном от Bash."
	    exit 1
	fi

	if [ "$(uname)" != "Linux" ]; then
	    echo "Запрещено запускать в ОС отличной от Linux."
	    exit 1
	fi
}
check_permission

if [ "$#" -eq 0 ]; then
    print_help
    exit 0
fi

st_args=${@:2}
if [ "$#" -eq 1 ]; then
    st_args=$STATIONS
fi
st_args=$(echo $st_args | tr ' ' '\n' | sort | uniq | tr '\n' ' ')


if [ "$1" == "start" ]; then
	if [ $(is_db_init) -eq 0 ]; then
		echo "База не была создана. init_db..."
		init_db
	fi
	echo "starting..."
	command_stop $st_args
	command_start $st_args

elif [ "$1" == "stop" ]; then
	echo "stoping..."
	command_stop $st_args

elif [ "$1" == "status" ]; then
	echo "status..."
	commnad_status $st_args
elif [ "$1" == "init_db" ]; then
	echo "init_db..."
	init_db
elif [ "$1" == "watch_db" ]; then
	echo "watch_db..."
	watch_db
else
	print_help
fi
 