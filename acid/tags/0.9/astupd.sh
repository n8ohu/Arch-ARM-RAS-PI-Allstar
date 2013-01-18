#!/bin/bash
REPO=$(cat /etc/rc.d/acidrepo)

rm -f /tmp/astget.sh
wget -q $REPO/installcd/astget.sh -O /tmp/astget.sh

if [ $? -gt 0 ]
then
	echo Cannot retreive astget.sh script
	exit 1
fi

if [ -e /tmp/astget.sh ]
then
	chmod 755 /tmp/astget.sh
	/tmp/astget.sh
fi

rm -f /tmp/astget.sh


