#! /bin/bash
if [ -e /var/run/asterisk.ctl ]
then
	echo "Restarting Asterisk..."
        asterisk -rx "restart now"
else
	echo "Asterisk is not running!"
fi

