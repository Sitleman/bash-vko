#!/bin/bash
# Version 2.2
declare -a TargetsId
MaxKolTargets=29      #+1
Probability=7         #вероятность поражения 10-90%

RangeX=13000000 # RangeX=13000000       #метры
RangeY=9000000 # RangeY=9000000        #метры

#скорость М/с min, разница между масимумом и минимумом
SpeedBm=(8000 2000)   #8000-10000
SpeedPl=(50 199)      #50 249
SpeedCm=(250 750)     #250-1000

TtlBmMax=300          #Максимальное время жизни
TtlPlMax=200
TtlCmMax=200
Sleeptime=1           #задержка 1c
TempDirectory=/tmp/GenTargets
DirectoryTargets="$TempDirectory/Targets"
DestroyDirectory="$TempDirectory/Destroy"
LogFile=$TempDirectory/GenTargets.log
mkdir $TempDirectory >/dev/null 2>/dev/null;  mkdir $DirectoryTargets >/dev/null 2>/dev/null; mkdir $DestroyDirectory >/dev/null 2>/dev/null
echo "Запуск в " `date` >>$LogFile
cd "$DirectoryTargets/"
rm -rf $DestroyDirectory/* 2>/dev/null
rm -rf $DirectoryTargets/* 2>/dev/null
let NoTarget=$MaxKolTargets+1
while :
do
  let NoTarget-=1
  if [ $NoTarget -lt 0 ]
    then
      NoTarget=$MaxKolTargets
      sleep $Sleeptime
      find -mmin +1 -delete 2>/dev/null
      #map
      if [ "$1" == "map" ] || [ "$1" == "-map" ]
       then
         for i in `seq   0 $MaxKolTargets`
           do
	    if [ ${TargetsId[3+10*$i]} -ge 0 ]
	    then
		test ${TargetsId[4+10*$i]} -ge 0 && destinXY=$(echo -e '\U00002197') || destinXY=$(echo -e '\U00002198')
	    else
		test ${TargetsId[4+10*$i]} -ge 0 && destinXY=$(echo -e '\U00002196') || destinXY=$(echo -e '\U00002199')
	    fi
            case ${TargetsId[6+10*$i]} in
              "Бал.блок" )
		tsign="^"; maps[$((TargetsId[8+10*i]+TargetsId[9+10*i]*130))]=$tsign
              ;;
              "Самолет" )
		tsign=">"; maps[$((TargetsId[8+10*i]+TargetsId[9+10*i]*130))]=$tsign
              ;;
              "К.ракета" )
                tsign="-"; maps[$((TargetsId[8+10*i]+TargetsId[9+10*i]*130))]=$tsign
            esac
	    info="${mapsid[$((TargetsId[9+10*i]*130))]} $destinXY$tsign ${TargetsId[0+10*$i]} X$((${TargetsId[1+10*$i]}/1000)):${TargetsId[3+10*$i]} Y$((${TargetsId[2+10*$i]}/1000)):${TargetsId[4+10*$i]} "
    	    mapsid[$((TargetsId[9+10*i]*130))]=${info:0:128}
    	    done
          clear
        for y in `seq  44 -1 0`
          do
            for x in `seq 0 130`
              do

                echo -n "${maps[$(($x+$y*130))]}"
                maps[$(($x+$y*130))]="'"
              done
            echo "${mapsid[$(($y*130)) ]}"
            mapsid[$(($y*130)) ]=""
          done
	  ls "$DestroyDirectory/" 2>/dev/null
      fi
  fi
    #/map

  if [[ "${#TargetsId[0+10*$NoTarget]}" -lt 1 ]]   #Генерация цели
    then
      tip_target=$((RANDOM%3))   #0-br 1-plan 2-cmiss
      destX=$(($RANDOM%2*2-1))
      destY=$(($RANDOM%2*2-1))
      XYminus="0.2"
      #tip_target=0 ; destX=-1 ; destY=-1
      case $tip_target in
       0 )
          SpeedMin=${SpeedBm[0]}
          SpeedPlus=${SpeedBm[1]}
          ttl=$((RANDOM%TtlBmMax+10))
          tip_target="Бал.блок"
          XYminus=0
        ;;
       1 )
          SpeedMin=${SpeedPl[0]}
          SpeedPlus=${SpeedPl[1]}
          ttl=$((RANDOM%TtlPlMax+10))
          tip_target="Самолет"
        ;;
       2 )
          SpeedMin=${SpeedCm[0]}
          SpeedPlus=${SpeedCm[1]}
          ttl=$((RANDOM%TtlCmMax+10))
          tip_target="К.ракета"
      esac
        Speed=$(($RANDOM%(SpeedPlus-2)+SpeedMin+1))
        SpeedY=$(( $RANDOM%($Speed)*$destY ))
        SpeedX=$(bc <<< "scale=0; sqrt($Speed^2-($SpeedY)^2)*$destX")

        if [ $destX == 1 ]
          then
                Xmin=$( bc <<< "scale=0; (0 + ($RangeX*$XYminus))/1 ")
                Xmax=$( bc <<< "scale=0; (($RangeX - ($RangeX*$XYminus)) - ($RangeX*0.3))/1" )
          else
                Xmin=$( bc <<< "scale=0; (($RangeX*0.3) + ($RangeX*$XYminus))/1" )
                Xmax=$( bc <<< "scale=0; ($RangeX - ($RangeX*$XYminus))/1")
        fi

        if [ $destY == 1 ]
          then
                Ymin=$( bc <<< "scale=0; (0 + ($RangeY*$XYminus))/1 ")
                Ymax=$( bc <<< "scale=0; (($RangeY - ($RangeY*$XYminus))-($RangeY*0.3))/1" )
          else
                Ymin=$( bc <<< "scale=0; (($RangeY*0.3)+($RangeY*$XYminus))/1" )
                Ymax=$( bc <<< "scale=0; ($RangeY - ($RangeY*$XYminus))/1")
        fi

        Xplus=$(($Xmax-$Xmin)) ; Yplus=$(($Ymax-$Ymin))
        Xkoord=$(($RANDOM%($Xplus/1000)*1000+$Xmin )) ; Ykoord=$(($RANDOM%($Yplus/1000)*1000+$Ymin ))
	#Xkoord=$((12900000   ))
	#Ykoord=$((1   ))
	BASE_STR=$(mcookie) ;NameTarget=${BASE_STR:11:6};
        echo -e "$tip_target \t$NameTarget\t$NoTarget\t\t Koord $Xkoord\t$Ykoord\t\tSpeed $SpeedX\t$SpeedY\tTtl$ttl"
        echo -e `date +%d.%m\ %T` " $tip_target \t$NameTarget\t$NoTarget\t\t Koord $Xkoord\t$Ykoord\t\tSpeed $SpeedX\t $SpeedY \tTtl $ttl" >>$LogFile
        TargetsId[0+10*$NoTarget]=$NameTarget
        TargetsId[1+10*$NoTarget]=$Xkoord
        TargetsId[2+10*$NoTarget]=$Ykoord
        TargetsId[3+10*$NoTarget]=$SpeedX
        TargetsId[4+10*$NoTarget]=$SpeedY
        TargetsId[5+10*$NoTarget]=$ttl
        TargetsId[6+10*$NoTarget]=$tip_target
        TargetsId[7+10*$NoTarget]=$NoTarget
        TargetsId[8+10*$NoTarget]=$((Xkoord/100000))
        TargetsId[9+10*$NoTarget]=$((Ykoord/200000))
    else  #Обновление цели
      if [ -e "$DestroyDirectory/${TargetsId[0+10*$NoTarget]}"  ]    #Уничтожение цели по запросу
        then
          rm "$DestroyDirectory/${TargetsId[0+10*$NoTarget]}"
          if [  $((RANDOM%$Probability)) -ge 1 ]
            then
              echo  -e "${TargetsId[6+10*$NoTarget]} \t${TargetsId[0+10*$NoTarget]} уничт." "\t\t Koord ${TargetsId[1+10*$NoTarget]}\t${TargetsId[2+10*$NoTarget]}"
              echo  -e `date +%d.%m\ %T` " ${TargetsId[6+10*$NoTarget]} \t${TargetsId[0+10*$NoTarget]} уничт." "\t\t Koord ${TargetsId[1+10*$NoTarget]}\t${TargetsId[2+10*$NoTarget]}">>$LogFile
              TargetsId[0+10*$NoTarget]=""
              continue
            else
              echo  -e "${TargetsId[6+10*$NoTarget]} \t${TargetsId[0+10*$NoTarget]} промах" "\t\t Koord ${TargetsId[1+10*$NoTarget]}\t${TargetsId[2+10*$NoTarget]}"
              echo  -e `date +%d.%m\ %T` " ${TargetsId[6+10*$NoTarget]} \t${TargetsId[0+10*$NoTarget]} промах" "\t\t Koord ${TargetsId[1+10*$NoTarget]}\t${TargetsId[2+10*$NoTarget]}">>$LogFile
          fi
      fi
    (( TargetsId[1+10*$NoTarget]+=${TargetsId[3+10*$NoTarget]} ))   #Координаты + скорость
    (( TargetsId[2+10*$NoTarget]+=${TargetsId[4+10*$NoTarget]} ))
    (( TargetsId[5+10*$NoTarget]+=-1 ))	#уменьшение времени жизни
    rand=$(mcookie)
    echo "X${TargetsId[1+10*$NoTarget]},Y${TargetsId[2+10*$NoTarget]}" >"$DirectoryTargets/${rand:20}${TargetsId[0+10*$NoTarget]}" 2>/dev/null

    if [ ${TargetsId[5+10*$NoTarget]} -le 0 ]    #Время жизни цели истекло
      then
        echo -e "${TargetsId[6+10*$NoTarget]} \t${TargetsId[0+10*$NoTarget]} мертва" "\t\t Koord ${TargetsId[1+10*$NoTarget]}\t${TargetsId[2+10*$NoTarget]}"
        echo -e `date +%d.%m\ %T` " ${TargetsId[6+10*$NoTarget]} \t${TargetsId[0+10*$NoTarget]} мертва" "\t\t Koord ${TargetsId[1+10*$NoTarget]}\t${TargetsId[2+10*$NoTarget]}">>$LogFile
        TargetsId[0+10*$NoTarget]=""
     fi
   fi
done

