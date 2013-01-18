#! /bin/bash
HWTYPE=usbradio
#HWTYPE=pciradio
REPO=$(cat /etc/rc.d/acidrepo)

echo "****** Phase 2 post install ******"
sleep 1

DESTDIR=/usr/src
cd $DESTDIR

echo "Getting asterisk install script from $REPO..."
wget -q $REPO/installcd/astinstall.sh -O /etc/rc.d/astinstall.sh
if [ $? -gt 0 ]
then
        echo "Failure: Unable to download Asterisk install script"
	sleep 30
        exit 255
else
	chmod 755 /etc/rc.d/astinstall.sh
fi

echo "Getting files.tar.gz from $REPO..."

wget -q $REPO/installcd/files.tar.gz -O $DESTDIR/files.tar.gz

if [ $? -gt 0 ]
then
	echo "Failure: Unable to download files.tar.gz"
	sleep 30
	exit 255
fi

if [ -e /etc/rc.d/astinstall.sh ]
then
	/etc/rc.d/astinstall.sh 
	if [ $? -gt 0 ]
	then
		echo "Failure: Unable to install Asterisk!"
		exit 1
	fi
else
	echo "Failure to exec /etc/rc.d/astinstall.sh!"
	exit 1
fi

cd $DESTDIR

echo "Setting up config..."
rm -rf /etc/asterisk
mkdir -p /etc/asterisk

cp configs/*.conf /etc/asterisk
if [ $? -gt 0 ]
then
	echo "Failure: Unable to copy configs 1"
	sleep 30
	exit 255
fi
cp configs/$HWTYPE/*.conf /etc/asterisk
if [ $? -gt 0 ]
then
	echo "Failure: Unable to copy configs 2"
	sleep 30
	exit 255
fi
mv /etc/asterisk/zaptel.conf /etc
if [ $? -gt 0 ]
then
	echo "Failure: Unable to copy configs 3"
	sleep 30
	exit 255
fi

echo "Updating local script(s)..."
cp $DESTDIR/allstar/rc.updatenodelist /etc/rc.d/rc.updatenodelist
chmod +x /etc/rc.d/rc.updatenodelist
if [ $? -gt 0 ]
then
	echo "Failure: Unable to chmod script"
	sleep 30
	exit 255
fi

mv -f /etc/rc.d/rc.local.orig /etc/rc.d/rc.local; sync
egrep updatenodelist /etc/rc.d/rc.local
if [ $? -gt 0 ]
then
	echo "/etc/rc.d/rc.updatenodelist &" >> /etc/rc.d/rc.local
fi


echo "Getting setup scripts..."
wget -q $REPO/installcd/nodesetup.sh -O /root/nodesetup.sh
wget -q $REPO/installcd/setup.sh -O /root/setup.sh
wget -q $REPO/installcd/astupd.sh -O /root/astupd.sh
wget -q $REPO/installcd/irlpsetup.sh -O /root/irlpsetup.sh
chmod 770 /root/setup.sh /root/nodesetup.sh /root/astupd.sh /root/irlpsetup.sh

sync

echo "Turning off unused services..."
chkconfig acpid off
chkconfig apmd off
chkconfig autofs off
chkconfig bluetooth off
chkconfig cpuspeed off
chkconfig cups off
chkconfig gpm off
chkconfig haldaemon off
chkconfig hidd off
chkconfig lvm2-monitor off
chkconfig mcstrans off
chkconfig mdmonitor off
chkconfig netfs off
chkconfig nfslock off
chkconfig pcscd off
chkconfig portmap off
chkconfig rpcgssd off
chkconfig rpcidmapd off
chkconfig avahi-daemon off
chkconfig yum-updatesd off

chkconfig asterisk off 

if [ -e /root/setup.sh ]
then
	(cd /root; ./setup.sh)
	exit
fi
echo "Script done. Rebooting...."
sleep 2
reboot
exit

