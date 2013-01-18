#! /bin/bash
INSTALLOG=/root/acid-install.log
REQUIRECENTOSMAJOR=5

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

# Determine the repository from the URL embedded in rc.local at initial load

if [ -e /etc/rc.d/acidrepo ]
then
	REPO=$(cat /etc/rc.d/acidrepo)
else
	REPO=$(grep http /etc/rc.d/rc.local | cut -d ' ' -f8 | cut -d '/' -f-3)
	echo $REPO >/etc/rc.d/acidrepo
fi

logecho "****** Phase 1 post install ******"
logecho "Verifying this is a CentOS distro..."
grep CentOS /etc/redhat-release >/dev/null 2>&1 
if [ $? -ne 0 ]
then
	die "Sorry, this does not seem to be a CentOS distro!"
fi

CENTOSVERS=$(cat /etc/redhat-release | cut -d ' ' -f3)
CENTOSVMAJOR=$(echo "$CENTOSVERS" | cut -d '.' -f1)
CENTOSVMINOR=$(echo "$CENTOSVERS" | cut -d '.' -f2)

logecho "Check to see that we can install on CentOS $CENTOSVERS..."
if [ $CENTOSVMAJOR -ne $REQUIRECENTOSMAJOR ]
then
	die "Install CD out of date! Please download and burn a new disk!" 
fi
logecho "CentOS version OK"

logecho "Repository to use: $REPO"

sleep 1
logecho "Importing centos 5 gpg key..."
rpm --import http://mirror.centos.org/centos/RPM-GPG-KEY-CentOS-5
if [ $? -gt 0 ]
then
	die "Unable to retrieve GPG KEY from mirror.centos.org"
fi
logecho "Updating system..."
yum -y update 
if [ $? -gt 0 ]
then
	die "Unable to update Centos to latest binaries"
fi

logecho "Installing ntp..."
yum -y install ntp
if [ $? -gt 0 ]
then
        die "Unable to install ntp"
fi

logecho "Installing screen..."
yum -y install screen
if [ $? -gt 0 ]
then
        die "Unable to install screen"
fi

logecho "Installing sox..."
yum -y install sox
if [ $? -gt 0 ]
then
        die "Unable to install sox"
fi

logecho "Installing Development Tools..."
yum -y groupinstall "Development Tools"
if [ $? -gt 0 ]
then
	die "Unable install development tools"
	sleep 30
	exit 255
fi
logecho "Installing Devel Headers for Libraries..."
uname -r | grep  PAE >/dev/null 2>&1
if [ $? -ne 0 ]
then
	kdevel=kernel-devel
else
	kdevel=kernel-PAE-devel	
fi
yum -y install zlib-devel "$kdevel" alsa-lib-devel ncurses-devel libusb-devel newt-devel openssl-devel
if [ $? -gt 0 ]
then
	die "Unable install development library headers"
	sleep 30
	exit 255
fi
cp -f /etc/rc.d/rc.local.orig /etc/rc.d/rc.local
cat <<EOF >>/etc/rc.d/rc.local
INSTALLOG=/root/acid-install.log
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
(cd /etc/rc.d; rm -f phase2.sh; wget -q $REPO/installcd/phase2.sh) 
if [ -e /etc/rc.d/phase2.sh ]
then
chmod 755 /etc/rc.d/phase2.sh
/etc/rc.d/phase2.sh
else
logecho "Unable to download post install script phase2.sh!"
die "Installation aborted"
fi
EOF
sync
logecho "phase1.sh done, rebooting..."
reboot



