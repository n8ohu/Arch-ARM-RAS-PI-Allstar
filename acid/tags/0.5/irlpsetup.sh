#!/bin/sh
if [ -e /etc/rc.d/acidrepo ]
then
        REPO=$(cat /etc/rc.d/acidrepo)
else
        echo "Cannot determine where to download irlp install script from!"
        exit 1
fi 
cd /etc/rc.d
rm -rf irlp-centos*
wget $REPO/installcd/irlp-centos-install
chmod +x irlp-centos-install
./irlp-centos-install
