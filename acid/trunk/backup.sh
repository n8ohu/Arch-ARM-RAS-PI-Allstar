#!/bin/sh
cd /root
echo "Backing up asterisk config files, and node name sound files..."
tar cf /root/backup.tar /etc/zaptel.conf /etc/asterisk/* /var/lib/asterisk/sounds/rpt/nodenames/*
rm -rf backup.tgz
echo "Compressing tar archive...."
gzip -9 backup.tar
mv backup.tar.gz backup.tgz
echo "Cleaning up..."
echo "Done. Backup file backup.tgz is in /root" 
