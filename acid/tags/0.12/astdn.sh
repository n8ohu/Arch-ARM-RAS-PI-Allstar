#! /bin/bash
if [ -e /var/run/asterisk.ctl ]
then
	echo "Stopping Asterisk..."
	killall safe_asterisk
	service asterisk stop
else
	echo "Asterisk is not running!"
fi

