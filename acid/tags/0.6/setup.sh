# !/bin/bash
#
# setup.sh
#
SSHDCONF=/etc/ssh/sshd_config
SSHDPORT=222
TMP=/tmp


function die {
	echo "Fatal error: $1"
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

echo "**************************************"
echo "*   Setup script for app_rpt/Centos  *"
echo "**************************************"
echo
echo "You must change the root password to something stronger..."
passwd root

echo "Changing SSHD port number to $SSHDPORT..."
sed "s/^#Port[ \t]*[0-9]*/Port 222/" <$SSHDCONF >$TMP/sshd_config
mv -f $TMP/sshd_config $SSHDCONF || die "mv 1 failed"
echo "Enabling SSHD and Asterisk to start on next boot..."
chkconfig sshd on
chkconfig iptables off
chkconfig asterisk on

if [ -e /root/nodesetup.sh ]
then
	/root/nodesetup.sh || die "Could not modify config files!"
fi

echo "Script done, rebooting..."
reboot
