#!/bin/bash

set -u

source config.sh
source messenger.sh

# Args
PID=1
ST_NAME=$1
ST_TYPE=$2
ST_X=$3
ST_Y=$4
ST_RADIUS=$5
ST_DIRECTION_ANGLE=$6
ST_VIEWING_ANGLE=$7

# Consts
SLEEP=0.5
TARGETS_COUNT=30
DIR_TARGETS=/tmp/GenTargets/Targets
DIR_DESTROY=/tmp/GenTargets/Destroy
DIR_TARGETS_TRACKING=./temp/Targets/$ST_NAME

# Object types
TARGET_TYPE_BALISTIC_BLOCK="Бал.блок"
TARGET_TYPE_CRUISE_MISSLE="Крыл.ракета"
TARGET_TYPE_PLANE="Самолет"

# Missle stocks
MISSLE_STOCK_ZRDN=20
MISSLE_STOCK_SPRO=10

PI=$(echo "4*a(1)" | bc -l)


function find_speed() {
	local x=$1
	local y=$2
	local prev_x=$3
	local prev_y=$4
	echo "scale=0;sqrt(($x-($prev_x))^2 + ($y-($prev_y))^2)" | bc -l
}

function find_target_type() {
	local speed=$1
	if [[ "$speed" -ge 8000 && "$speed" -le 10000 ]]; then
	    echo $TARGET_TYPE_BALISTIC_BLOCK 
	elif [[ "$speed" -ge 250 && "$speed" -le 1000 ]]; then
	    echo $TARGET_TYPE_CRUISE_MISSLE
	elif [[ "$speed" -ge 50 && "$speed" -le 250 ]]; then
	    echo $TARGET_TYPE_PLANE
	else
	    echo "unknown"
	fi
}

function target_type_match_station() {
	local target_type=$1
	if [[ "$ST_TYPE" == $STATION_TYPE_RLS && "$target_type" == $TARGET_TYPE_BALISTIC_BLOCK ]]; then
	    echo 1 
	elif [[ "$ST_TYPE" == $STATION_TYPE_SPRO && "$target_type" == $TARGET_TYPE_BALISTIC_BLOCK ]]; then
	    echo 1
	elif [[ "$ST_TYPE" == $STATION_TYPE_ZRDN && ( "$target_type" == $TARGET_TYPE_PLANE || "$target_type" == $TARGET_TYPE_CRUISE_MISSLE ) ]]; then
	    echo 1
	else
	    echo 0
	fi
}

function is_target_in_sector() {
	local target_x=$1
	local target_y=$2
	dx=$(( $target_x - $ST_X ))
    dy=$(( $target_y - $ST_Y ))
    distance=$(echo "scale=0;sqrt($dx^2 + $dy^2)" | bc -l)
    if (( distance > ST_RADIUS )); then
    	echo 0
    	return
    fi 

    lower_bound=$(( (ST_DIRECTION_ANGLE - (ST_VIEWING_ANGLE / 2) + 360) % 360 ))
    upper_bound=$(( (ST_DIRECTION_ANGLE + (ST_VIEWING_ANGLE / 2)) % 360 ))
    if (( dx > 0 )); then
    	# определяю угол с помощью арктангенса от -pi/2 до pi/2
    	angle_rad=$(echo "a($dy/$dx)" | bc -l)
    else 
    	# если dx отрицательная(он находится в 3 или 4й зоне), то прибавляю к углу pi.
    	angle_rad=$(echo "a($dy/$dx) + $PI" | bc -l)
    fi
    angle=$(echo "scale=0;($angle_rad * 180/$PI + 360) % 360" | bc)

    # send_message $ST_NAME $STATION_KP $MESSAGE_TYPE_LOG "Lower:$lower_bound Upper:$upper_bound Angle:$angle X:$target_x Y:$target_y"

    if (( upper_bound < lower_bound )); then # обрабатываем случай когда сектор пересекает угол = 0
    	if (( lower_bound <= angle || angle <= upper_bound )); then
	        echo 1
	    else
	        echo 0
	    fi

    else  # обрабатываем случай когда сектор весь находится от 0 до 360 градусов
		if (( lower_bound <= angle && angle <= upper_bound )); then
	        echo 1
	    else
	        echo 0
	    fi
    fi
}

function is_target_in_radius() {
	local target_x=$1
	local target_y=$2
	dx=$(echo "$target_x - $ST_X" | bc)
    dy=$(echo "$target_y - $ST_Y" | bc)
    distance=$(echo "sqrt($dx^2 + $dy^2)" | bc)
    if (( $(echo "$distance > $ST_RADIUS" | bc -l) )); then
    	echo 0
    	return
    fi
    echo 1
}	

function is_target_in_station_visibility_zone(){
	local target_x=$1
	local target_y=$2
	case $ST_TYPE in
		$STATION_TYPE_RLS)
			echo $(is_target_in_sector $target_x $target_y)
			;;
		$STATION_TYPE_ZRDN | $STATION_TYPE_SPRO)
			echo $(is_target_in_radius $target_x $target_y)
			;;
	esac
}

function is_target_direct_to_spro(){
	# находим вектор траектории движения снаряда
	vlx=$(( target_x - target_prev_x ))
	vly=$(( target_y - target_prev_y ))
	# находим вектор к SPRO
	vsx=$(( SPRO_X - target_prev_x ))
	vsy=$(( SPRO_Y - target_prev_y ))
	# если угол между векторами больше 90 градусов, то снаряд летит от spro
	vscal=$(( vlx * vsx + vly * vsy))
	if (( vscal < 0 )); then
		echo 0
		return
	fi

	vllength=$( echo "sqrt($vlx^2 + $vly^2)" | bc -l)
	vslength=$( echo "sqrt($vsx^2 + $vsy^2)" | bc -l)
	# вычисляем косинус угола между векторами
	vanglecos=$( echo "$vscal/($vllength * $vslength)" | bc -l)
	#вычисляем расстояние от траектории снаряда до spro
	hlength=$( echo "$vslength * sqrt(1 - $vanglecos^2)" | bc -l )

	if [ $(echo "$hlength > $SPRO_RADIUS" | bc) -eq 1 ]; then
		echo 0
		return
	fi
	echo 1
}


function get_target_stage() {
	local target_id=$1
	local target_name=$2
	target_prev_file=$(cat "$DIR_TARGETS_TRACKING/$target_id" 2>/dev/null)
	if [ $? -ne 0 ]; then
		stage=0
		return
	fi

	IFS=',' read -r target_prev_x target_prev_y target_prev_name stage _ <<< "$target_prev_file"
	target_prev_x=${target_prev_x:1}
	target_prev_y=${target_prev_y:1}
	# target_prev_name=$(echo $target_prev_file | cut -d',' -f3)	
	if [ "$target_prev_name" == "$target_name" ]; then
		stage=-1
		return
	fi
	# stage=$(echo $target_prev_file | cut -d',' -f4)
}

function save_target_stage() {
	local stage=$1
	echo "X$target_x,Y$target_y,$target_name,$stage" > $DIR_TARGETS_TRACKING/$target_id
}


function shoot() {
	local target_id=$1

	missle_stock=$((missle_stock - 1))
	echo "shoot" > $DIR_DESTROY/$target_id
	send_message $ST_NAME $STATION_KP $MESSAGE_TYPE_LOG "Выстрел по цели ID:$target_id (Осталось ракет: $missle_stock)."
	if [ $missle_stock -eq 0 ]; then
		send_message $ST_NAME $STATION_KP $MESSAGE_TYPE_LOG "Боекомплект израсходован. Переход на режим обнаружения."
	fi
}

function is_can_shoot() {
	if [[ $missle_stock -ge 1 ]]; then 
		echo 1
	else 
		echo 0
	fi
}

function load_missles() {
	missle_stock=0
	if [ "$ST_TYPE" == $STATION_TYPE_SPRO ]; then
		missle_stock=$MISSLE_STOCK_SPRO
	elif [ "$ST_TYPE" == $STATION_TYPE_ZRDN ]; then
		missle_stock=$MISSLE_STOCK_ZRDN
	fi
}

function send_log() {
	send_message $ST_NAME $STATION_KP $MESSAGE_TYPE_LOG "$1"
}

load_missles
rm -rf "$DIR_TARGETS_TRACKING"
mkdir -p $DIR_TARGETS_TRACKING
start=$(date +%s.%N)
while true; do
	# process live targets
	# target_names=$(ls -t $DIR_TARGETS 2>/dev/null | head -n 30)
	target_names=$(find $DIR_TARGETS -type f -printf '%T@ %f\n' 2>/dev/null | sort -n -r | head -n $TARGETS_COUNT | sed "s|^[^ ]* ||")
	if [ $? -ne 0 ]; then
		continue
	fi
	target_files=$(cat $(printf "%s\n" "$target_names" | sed "s|^|$DIR_TARGETS/|") 2>/dev/null)
	if [ $? -ne 0 ]; then
		continue
	fi
	targets=$(paste -d, <(echo "$target_names") <(echo "$target_files"))
	for target in $targets; do
		IFS=',' read -r target_name target_x target_y _ <<< "$target"
		target_x=${target_x:1}
		target_y=${target_y:1}
		target_id=${target_name:12:6}

		if [ "$(is_target_in_station_visibility_zone "$target_x" "$target_y")" -eq 0 ]; then
			continue
		fi

		get_target_stage $target_id $target_name
		if [[ $stage -eq -1 ]]; then
			continue # повторный просмотр цели
		fi
		if [[ $stage -eq 0 ]]; then
			save_target_stage "1" # цель, у которой определена 1 координаты
			continue
		fi
		if [[ $stage -eq 2 ]]; then
			save_target_stage "2" # цель, у которой определены 2 координаты
			continue
		fi
		if [[ $stage -eq -2 ]]; then
			save_target_stage "-2" # цель неподходящего типа
			continue
		fi

		# send_log "Определена цель ID:$target_id X:$target_x Y:$target_y XP:$target_prev_x YP:$target_prev_y Stage:$stage."
		target_speed=$(find_speed $target_x $target_y $target_prev_x $target_prev_y)
		target_type=$(find_target_type $target_speed)
		if [ "$(target_type_match_station $target_type)" -eq 0 ]; then
			save_target_stage "-2" # цель неподходящего типа
			continue
		fi

		if [ $stage -eq 1 ]; then
			send_log "Определена цель ID:$target_id X:$target_x Y:$target_y Speed:$target_speed Type:$target_type."
			if [[ $ST_TYPE == $STATION_TYPE_RLS && $(is_target_direct_to_spro) -eq 1 ]]; then
				send_log "Бал.блок ID:$target_id движится в направлении SPRO."
			fi
		elif [ $stage -eq 3 ]; then
			send_log "Промах по цели ID:$target_id."
		fi
		# elif [ $stage -eq 2 ]; then 
		# 	send_log "Веду цель ID:$target_id X:$target_x Y:$target_y Speed:$target_speed Type:$target_type."

		if [ $(is_can_shoot) -eq 1 ]; then
			shoot $target_id
			save_target_stage "3"
			continue
		fi 
		save_target_stage "2"
	done

	# process dead targets
	old_saved_targets=$(find $DIR_TARGETS_TRACKING -type f -not -newermt '-5 seconds' | sed "s|$DIR_TARGETS_TRACKING/||")
	for target_id in $old_saved_targets; do
		get_target_stage $target_id "0"
		if [ $stage -eq 2 ]; then
			send_message $ST_NAME $STATION_KP $MESSAGE_TYPE_LOG "Цель потеряна ID:$target_id."
		elif [ $stage -eq 3 ]; then
			send_message $ST_NAME $STATION_KP $MESSAGE_TYPE_LOG "Цель уничтожена ID:$target_id."
		fi

		# send_message $ST_NAME $STATION_KP $MESSAGE_TYPE_LOG "Удаляем ID:$target_id."
		rm "$DIR_TARGETS_TRACKING/$target_id"
	done

	try_recieve_messages $ST_NAME >> /dev/null

	end=$(date +%s.%N)
	duration=$(echo "$end - $start" | bc)
	# if [ $(echo "$duration > 0.3" | bc) -eq 1 ]; then
		# send_log "Время итерации: $duration." 
	# fi
	sleep $SLEEP
	start=$(date +%s.%N)
done
