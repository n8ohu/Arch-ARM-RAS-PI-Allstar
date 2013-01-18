#! /bin/bash
HWTYPE=usbradio
#HWTYPE=pciradio

echo "****** Asterisk Installation ******"
sleep 1

ntpdate pool.ntp.org

echo "MENUSELECT_MODULES=wcusb xpp" > /etc/zaptel.makeopts

DESTDIR=/usr/src

mkdir -p $DESTDIR
rm -rf $DESTDIR/zaptel $DESTDIR/libpri $DESTDIR/asterisk

cd $DESTDIR

echo "Unpacking files.tar.gz..."

tar xfz files.tar.gz

if [ $? -gt 0 ]
then
	echo "Failure: Unable unpack files.tar.gz"
	exit 255
fi

rm -f $DESTDIR/asterisk/menuselect.makeopts
rm -f $DESTDIR/Makefile

echo "Compiling Zaptel..."
cd zaptel
./configure
if [ $? -gt 0 ]
then
	echo "Failure: Unable to compile Zaptel 1"
	exit 255
fi
make
if [ $? -gt 0 ]
then
	echo "Failure: Unable to compile Zaptel 2"
	exit 255
fi
make install
if [ $? -gt 0 ]
then
	echo "Failure: Unable to compile Zaptel 3"
	exit 255
fi
make config
if [ $? -gt 0 ]
then
	echo "Failure: Unable to compile Zaptel 4"
	exit 255
fi
cd ..

echo "Compiling LIBPri..."
cd libpri
make
if [ $? -gt 0 ]
then
	echo "Failure: Unable to compile LibPRI 1"
	exit 255
fi
make install
if [ $? -gt 0 ]
then
	echo "Failure: Unable to compile LibPRI 2"
	exit 255
fi
cd ..


cd asterisk
echo "Compiling Asterisk..."
./configure
if [ $? -gt 0 ]
then
	echo "Failure: Unable to compile Asterisk 1"
	exit 255
fi

make menuselect.makeopts
if [ $? -gt 0 ]
then
	echo "Failure: Unable to compile Asterisk 2"
	exit 255
fi
sed 's/app_rpt//g;s/chan_usbradio//g;s/MENUSELECT_CFLAGS.*/MENUSELECT_CFLAGS=LOADABLE_MODULES MALLOC_DEBUG RADIO_RELAX/g;s/MENUSELECT_MOH=MOH-FREEPLAY-WAV/MENUSELECT_MOH=/g;s/MENUSELECT_EXTRA_SOUNDS=/MENUSELECT_EXTRA_SOUNDS=EXTRA-SOUNDS-EN-GSM/g' < menuselect.makeopts > foo
if [ $? -ne 0 ]
then
	echo "Failure: Unable to edit menuselect.makeopts"
	exit 255
fi

mv menuselect.makeopts menuselect.makeopts.old
if [ $? -gt 0 ]
then
	echo "Failure: Unable to compile Asterisk 3"
	exit 255
fi
mv foo menuselect.makeopts
if [ $? -gt 0 ]
then
	echo "Failure: Unable to compile Asterisk 4"
	exit 255
fi
make
if [ $? -gt 0 ]
then
	echo "Failure: Unable to compile Asterisk 5"
	exit 255
fi
make install
if [ $? -gt 0 ]
then
	echo "Failure: Unable to compile Asterisk 6"
	exit 255
fi
make config
if [ $? -gt 0 ]
then
	echo "Failure: Unable to compile Asterisk 7" 
	exit 255
fi

echo "Copying rpt sounds..."
cp -a $DESTDIR/sounds/* /var/lib/asterisk/sounds
if [ $? -gt 0 ]
then
	echo "Failure: Unable to copy rpt sounds"
	exit 255
fi
exit 0
