#! /bin/bash

# Determine the repository from the URL embedded in rc.local at initial load

if [ -e /etc/rc.d/acidrepo ]
then
	REPO=$(cat /etc/rc.d/acidrepo)
else
	REPO=$(grep http /etc/rc.d/rc.local | cut -d ' ' -f8 | cut -d '/' -f-3)
	echo $REPO >/etc/rc.d/acidrepo
fi

echo "****** Phase 1 post install ******"
sleep 1
echo "Importing centos 5 gpg key..."
rpm --import http://mirror.centos.org/centos/RPM-GPG-KEY-CentOS-5
if [ $? -gt 0 ]
then
	echo "Failure: Unable to retrieve GPG KEY from mirror.centos.org"
	sleep 30
	exit 255
fi
echo "Updating system..."
yum -y update 
if [ $? -gt 0 ]
then
	echo "Failure: Unable to update Centos to latest binaries"
	sleep 30
	exit 255
fi

echo "Installing ntp..."
yum -y install ntp
if [ $? -gt 0 ]
then
        echo "Failure: Unable to install ntp"
	sleep 30
        exit 255
fi

echo "Installing screen..."
yum -y install screen
if [ $? -gt 0 ]
then
        echo "Failure: Unable to install screen"
	sleep 30
        exit 255
fi

echo "Installing sox..."
yum -y install sox
if [ $? -gt 0 ]
then
        echo "Failure: Unable to install sox"
	sleep 30
        exit 255
fi

echo "Installing Development Tools..."
yum -y groupinstall "Development Tools"
if [ $? -gt 0 ]
then
	echo "Failure: Unable install development tools"
	sleep 30
	exit 255
fi
echo "Installing Devel Headers for Libraries..."
yum -y install zlib-devel kernel-devel alsa-lib-devel ncurses-devel libusb-devel newt-devel openssl-devel
if [ $? -gt 0 ]
then
	echo "Failure: Unable install development library headers"
	sleep 30
	exit 255
fi
cp -f /etc/rc.d/rc.local.orig /etc/rc.d/rc.local
cat <<EOF >>/etc/rc.d/rc.local
(cd /etc/rc.d; rm -f phase2.sh; wget -q $REPO/installcd/phase2.sh) 
if [ -e /etc/rc.d/phase2.sh ]
then
chmod 755 /etc/rc.d/phase2.sh
/etc/rc.d/phase2.sh
else
echo "Unable to download post install script phase2.sh!"
echo "Installation aborted"
sleep 3
fi
EOF
sync
reboot



