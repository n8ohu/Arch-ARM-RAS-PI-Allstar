#! /bin/bash
if [ -e /var/run/asterisk.ctl ]
then
	killall safe_asterisk
	service asterisk stop
	sleep 2
	service asterisk start
else
	echo "Asterisk is not running!"
fi

