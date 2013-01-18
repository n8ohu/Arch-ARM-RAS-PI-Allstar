#! /bin/bash
if [ -e /var/run/asterisk.ctl ]
then
	echo "Asterisk is currently running!"
else
	echo "Starting asterisk..."
	service asterisk start	
fi

