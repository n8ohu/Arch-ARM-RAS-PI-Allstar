#!/bin/bash
REPO=$(cat /etc/rc.d/acidrepo)
SCRIPTLOC=/usr/local/sbin
TMPLOC=/tmp/newscript
RCD=/etc/rc.d

IGNOREVERSCK=0

function die {
        echo "Fatal error: $1"
	rm -rf $TMPLOC
#	rm -f /tmp/scrupd.sh
        exit 1
}

#
# Stop people from using scrupd unwisely
#

if [ $IGNOREVERSCK -eq 0 ]
then
	echo "Checking to see if this system can be updated using scrupd..."

	if ! [ -f $RCD/acidvers ]
	then
		die "This version of acid is too old to be updated, an install from scratch will be necessary";
	fi

	wget -q -O /tmp/siteacidvers $REPO/installcd/acidvers
	if [ $? -ne 0 ]
	then
		die "Cannot contact the download site: $SITE, please check your Internet connectivity and/or try again later"
	fi

	CURACIDVERS=$(cat $RCD/acidvers)
	SITEACIDVERS=$(cat /tmp/siteacidvers)
	rm -f /tmp/siteacidvers
	if [ $CURACIDVERS != $SITEACIDVERS ]
	then
		echo "You have ACID version: $CURACIDVERS and the version on $REPO is: $SITEACIDVERS"
		die "scrupd.sh cannot be used, you must re-install ACID to update this system"
	fi
fi
	
mkdir -p $TMPLOC
for file in astdn.sh astres.sh astup.sh backup.sh irlpsetup.sh nodesetup.sh nscheck.sh rc.updatenodelist restore.sh savenode.sh scrupd.sh
do
	wget -q $REPO/installcd/$file -O $TMPLOC/$file
	if [ $? -ne 0 ]
	then
		die "Cannot download $file!"
	fi
done
chmod 770 $TMPLOC/*
mv -f $TMPLOC/rc.updatenodelist $RCD/rc.updatenodelist
cp -f $TMPLOC/* $SCRIPTLOC
rm -rf $TMPLOC
rm -rf /tmp/scrget
exit 0


