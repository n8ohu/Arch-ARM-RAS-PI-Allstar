#!/bin/bash
#
# Loader script for scrget.sh
#

REPO=$(cat /etc/rc.d/acidrepo)

rm -f /tmp/scrget.sh

wget -q -O /tmp/scrget.sh $REPO/installcd/scrget.sh 
if [ $? -gt 0 ]
then
	echo Cannot retreive scrget.sh script from $REPO
	exit 1
fi

if [ -e /tmp/scrget.sh ]
then
	chmod 750 /tmp/scrget.sh
	/tmp/scrget.sh
fi
echo "Script update complete. Rebooting your system is advised"
