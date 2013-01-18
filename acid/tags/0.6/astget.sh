#!/bin/bash
REPO=$(cat /etc/rc.d/acidrepo)
RCD=/etc/rc.d
DESTDIR=/usr/src
TMPDIR=/tmp
FORCEDL=0
IGNOREHASH=0


echo "Checking for updates to Asterisk...."

#
# Calculate local copy of sha256sum
#

if [ -e $DESTDIR/files.tar.gz ]
then
	sha256sum $DESTDIR/files.tar.gz | cut -d ' ' -f 1 >$DESTDIR/files.tar.gz.sha256sum
else
	FORCEDL=1
fi

wget -q $REPO/installcd/files.tar.gz.sha256sum -O $TMPDIR/files.tar.gz.sha256sum

if [ $? -gt 0 ]
then
	IGNOREHASH=1
	FORCEDL=1;
fi

#
# Compare the local and repo SHA256 hashes
#

if [ $FORCEDL -eq 0 ]
then
	diff -q $DESTDIR/files.tar.gz.sha256sum $TMPDIR/files.tar.gz.sha256sum 2>/dev/null >/dev/null
	if [ $? -ne 0 ]
	then
		FORCEDL=1
	fi
fi

#
# If hashes identical, then no update is required.
#

if [ $FORCEDL -eq 0 ]
then
	echo "Asterisk at latest version. No update required."
	rm -f $TMPDIR/files.tar.gz.sha256sum
	exit 0;
else
	FORCEDL=1
fi

#
# Get a new copy of the sources
#

wget -q $REPO/installcd/files.tar.gz -O $TMPDIR/files.tar.gz
if [ $? -gt 0 ]
then
	echo "Cannot download a copy of files.tar.gz!"
        exit 1;
fi

#
# Calculate SHA256 hash on downloaded image and verify it matches
#

if [ $IGNOREHASH -eq 0 ]
then
	sha256sum $TMPDIR/files.tar.gz | cut -d ' ' -f 1 >$TMPDIR/files.tar.gz.repo.sha256sum
	diff -q $TMPDIR/files.tar.gz.sha256sum $TMPDIR/files.tar.gz.repo.sha256sum 2>/dev/null >/dev/null
	if [ $? -ne 0 ]
	then
		echo "SHA256 check failed!"
		exit 1;
	fi
fi

#
# Get a newer astinstall.sh
#

rm $RCD/astinstall.sh
wget -q $REPO/installcd/astinstall.sh -O $RCD/astinstall.sh
if [ $? -gt 0 ]
then
	echo "Cannot download a copy of astinstall.sh!"
        exit 1;
fi
if [ -e $RCD/astinstall.sh ]
then
	chmod 770 $RCD/astinstall.sh
else
	echo "Cannot find astinstall.sh!"
	exit 1
fi

#
# Copy the source files to the destination
#
rm -f $DESTDIR/files.tar.*
mv -f $TMPDIR/files.tar.gz $DESTDIR
(cd $DESTDIR; rm -rf asterisk libpri zaptel allstar configs irlp* Makefile) 
(cd /usr/lib/asterisk/modules; rm  -f *.so)
#
# Exec install script
#
$RCD/astinstall.sh
#
# Restart asterisk if it is running
#
if [ -e /var/run/asterisk.ctl ]
then
	echo "Restarting Asterisk...."
	asterisk -rx "restart now"
fi

