#! /bin/sh

if [ -r /etc/asterisk/savenode.conf ]
then
	.  /etc/asterisk/savenode.conf
else
	exit 0
fi

if [ .$ENABLE = "." ]
then
	exit 0
fi

if [ $ENABLE -eq 0 ]
then
	exit 0
fi

echo "Saving Asterisk node configuration to register.allstarlink.org"

cd /
tar czf /tmp/astsave.tgz  etc/zaptel.conf etc/asterisk 
if [ $? -eq 0 ]
then
	wget -q --timeout=60 --tries=1 --post-file=/tmp/astsave.tgz  \
            --http-user=$NODE --http-password=$PASSWORD -O- \
	    http://register.allstarlink.org/savenode.cgi
        if [ $? -ne 0 ]
        then
                echo "Error in transfer"
        fi
fi
rm /tmp/astsave.tgz
