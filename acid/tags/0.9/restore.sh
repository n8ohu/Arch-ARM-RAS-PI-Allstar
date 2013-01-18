#!/bin/bash
ASTERISK_STOPPED=0
if [ -e /root/backup.tgz ]
then
	if [ -e /var/run/asterisk.ctl ]
	then
		echo "Stopping asterisk..."
		killall safe_asterisk; service asterisk stop
		sleep 1
		ASTERISK_STOPPED=1
	fi

	echo "Restoring from /root/backup.tgz..."
	(cd /; tar xzf /root/backup.tgz)
	echo "Files restored."
	if [ $ASTERISK_STOPPED -ne 0 ]
	then
		echo "Starting asterisk...";
		ztcfg
		sleep 1
		service asterisk start
	fi
	if [ -e /tmp/irlp_backup.tgz ]
	then
		echo "Note: IRLP backup is in /tmp/irlp_backup.tgz"
	fi
else
	echo "/root/backup.tgz does not exist!"
fi

