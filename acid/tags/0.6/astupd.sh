#!/bin/bash
REPO=$(cat /etc/rc.d/acidrepo)

rm -f astget.sh
wget -q $REPO/installcd/astget.sh -O astget.sh

if [ $? -gt 0 ]
then
	echo Cannot retreive astget.sh script
	exit 1
fi

if [ -e astget.sh ]
then
	chmod 755 astget.sh
	./astget.sh
fi

rm -f astget.sh


