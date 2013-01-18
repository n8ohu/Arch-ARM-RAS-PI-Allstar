#! /bin/bash
HWTYPE=usbradio
#HWTYPE=pciradio
REPO=$(cat /etc/rc.d/acidrepo)
SSHDCONF=/etc/ssh/sshd_config
SSHDPORT=222
TMP=/tmp
INSTALLOG=/root/acid-install.log
SCRIPTLOC=/usr/local/sbin
ZSYNCVERS=zsync-0.6.1
ZSYNCSOURCEKIT=$ZSYNCVERS.tar.bz2

function log {
        local tstamp=$(/bin/date)
        echo "$tstamp:$1" >>$INSTALLOG
}

function logecho {
        echo "$1"
        log "$1"
}

function die {
        logecho "Fatal error: $1"
        exit 255
}

function promptyn
{
        echo -n "$1 [y/N]? "
        read ANSWER
        if [ ! -z $ANSWER ]
        then
                if [ $ANSWER = Y ] || [ $ANSWER = y ]
                then
                        ANSWER=Y
                else
                        ANSWER=N
                fi
        else
                ANSWER=N
        fi
}

logecho "****** Phase 2 post install ******"
sleep 1

DESTDIR=/usr/src
cd $DESTDIR

logecho "Getting asterisk install script from $REPO..."
wget -q $REPO/installcd/astinstall.sh -O /etc/rc.d/astinstall.sh
if [ $? -gt 0 ]
then
        die "Unable to download Asterisk install script"
else
	chmod 755 /etc/rc.d/astinstall.sh
fi

logecho "Getting files.tar.gz from $REPO..."

wget -q $REPO/installcd/files.tar.gz -O $DESTDIR/files.tar.gz

if [ $? -gt 0 ]
then
	die "Unable to download files.tar.gz"
fi

if [ -e /etc/rc.d/astinstall.sh ]
then
	/etc/rc.d/astinstall.sh 
	if [ $? -gt 0 ]
	then
		die "Unable to install Asterisk!"
	fi
else
	die "exec of /etc/rc.d/astinstall.sh failed!"
fi

#Download, compile and install zsync

logecho "Downloading zsync from $REPO"
wget -q -O /tmp/$ZSYNCSOURCEKIT $REPO/installcd/$ZSYNCSOURCEKIT
if [ $? -gt 0 ]
then
        die "Unable to download $ZSYNCVERS"
fi
cd /usr/src
tar xvjf /tmp/$ZSYNCSOURCEKIT
if [ $? -gt 0 ]
then
        die "Unable to unpack $ZSYNCVERS"
fi
cd /usr/src/$ZSYNCVERS
./configure
make
if [ $? -gt 0 ]
then
        die "Unable to make $ZSYNCVERS"
fi
make install
if [ $? -gt 0 ]
then
        die "Unable to install $ZSYNCVERS"
fi
rm -f /tmp/$ZSYNCSOURCEKIT

cd $DESTDIR


logecho "Setting up config..."
rm -rf /etc/asterisk
mkdir -p /etc/asterisk

cp configs/*.conf /etc/asterisk
if [ $? -gt 0 ]
then
	die "Unable to copy configs 1"
fi
cp configs/$HWTYPE/*.conf /etc/asterisk
if [ $? -gt 0 ]
then
	die "Unable to copy configs 2"
fi
mv /etc/asterisk/zaptel.conf /etc
if [ $? -gt 0 ]
then
	die "Unable to copy configs 3"
fi

logecho "Getting misc files..."

wget -q $REPO/installcd/acidvers -O /etc/rc.d/acidvers
if [ $? -ne 0 ]
then
	die "Could set ACID version"
fi

wget -q $REPO/installcd/savenode.conf -O /etc/asterisk/savenode.conf

logecho "Getting control and helper scripts..."

wget -q $REPO/installcd/scrget.sh -O /tmp/scrget.sh
if [ $? -ne 0 ]
then
	die "Download of scrget.sh failed!"
fi

chmod 750 /tmp/scrget.sh
/tmp/scrget.sh

if [ $? -ne 0 ]
then
	die "Could not execute script /tmp/scrget.sh"
fi

rm -f /tmp/scrget.sh

logecho "Installing rc.updatenodelist in /usr/local"

mv -f /etc/rc.d/rc.local.orig /etc/rc.d/rc.local; sync
egrep updatenodelist /etc/rc.d/rc.local
if [ $? -gt 0 ]
then
	echo "/etc/rc.d/rc.updatenodelist &" >> /etc/rc.d/rc.local
fi

sync

logecho "Turning off unused services..."
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

echo "**************************************"
echo "*   Setup for app_rpt/Centos  *"
echo "**************************************"
echo
echo "You must supply a root password..."
passwd root
logecho "Password set"
logecho "Changing SSHD port number to $SSHDPORT..."
sed "s/^#Port[ \t]*[0-9]*/Port 222/" <$SSHDCONF >$TMP/sshd_config
mv -f $TMP/sshd_config $SSHDCONF || die "mv sshd_config failed"
logecho "Enabling SSHD and Asterisk to start on next boot..."
chkconfig sshd on
chkconfig iptables off
logecho "Running nodesetup.sh..."
if [ -e $SCRIPTLOC/nodesetup.sh ]
then
        $SCRIPTLOC/nodesetup.sh || die "Could not modify asterisk config files!"
fi


echo "Script done. Please plug in your modified USB fob or URI now!"
sleep 10
logecho "Rebooting...."
reboot
exit

