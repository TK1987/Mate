#!/usr/bin/sudo /bin/bash

# Terminal Größe ermitteln
	COLUMNS=$(stty -a | head -n1|tr ';' '\n'|awk '$1 == "columns" { print $2 }')
	ROWS=$(stty -a | head -n1|tr ';' '\n'|awk '$1 == "rows" { print $2 }')

# W-Lan Adapter suchen
	for A in /sys/class/net/*/wireless; do ADAPTER=$(basename $(dirname $A));done

# SSID Liste erzeugen
	COUNT=0
	if [ ! -z $ADAPTER ]
		then
			for SCAN in $(iwlist $ADAPTER scan| grep -i essid|cut -d':' -f2);
				COUNT=$[ COUNT + 1 ]
				do SSID+=($COUNT $SCAN)
				done
		fi

whiptail --menu "W-Lan Netwerk auswählen" $COLUMNS $ROWS 10 ${SSID[@]}
