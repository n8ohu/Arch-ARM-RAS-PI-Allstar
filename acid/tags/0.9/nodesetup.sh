# !/bin/bash
#
# nodesetup.sh
#
DRY_RUN=0
CONFIGS=/etc/asterisk
TMP=/tmp
SENABLE=1

function die {
	echo "Fatal error: $1"
	exit 255
}

function promptnum
{
	ANSWER=""
	while [ -z $ANSWER  ] || [[ ! $ANSWER =~ [0-9]{3,}$ ]]
	do
        	echo -n "$1: "
        	read ANSWER
	done
}

function promptcall
{
	ANSWER=""
	while [ -z $ANSWER  ] || [[ ! $ANSWER =~ [\/,0-9,a-z,A-Z]{3,}$ ]]
	do
        	echo -n "$1: "
        	read ANSWER
	done
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

function promptny
{
        echo -n "$1 [Y/n]? "
        read ANSWER
	if [ ! -z $ANSWER ]
	then
       		if [ $ANSWER = N ] || [ $ANSWER = n ]
      		then
                	ANSWER=N
        	else
                	ANSWER=Y
        	fi
	else
		ANSWER=Y
	fi
}

echo "*************************************"
echo "*     Simple Node Setup Script      *"
echo "*************************************"
echo
echo "Doing sanity checks on rpt.conf, extensions.conf, iax.conf, and savenode.conf..."

if [ -e $CONFIGS/extensions.conf ]
then
	grep -q -s NODE= $CONFIGS/extensions.conf || die "extensions.conf missing NODE=xxxx"
	NODE=$(grep NODE= /etc/asterisk/extensions.conf | gawk -F'=' '{print $2}')
else
	die "$CONFIGS/extensions.conf not found"
fi
if [ -e $CONFIGS/rpt.conf ]
then
	grep -q -s $NODE $CONFIGS/rpt.conf || die "Node numbers in rpt.conf and extensions.conf are different!"
else
	die "$CONFIGS/rpt.conf not found"
fi
if [ -e $CONFIGS/iax.conf ]
then	
        grep -q -s register\.allstarlink\.org $CONFIGS/iax.conf || die "No allstar link register statement in iax.conf! (old file maybe?)"
	REG1=$(grep register= $CONFIGS/iax.conf | gawk -F'=' '{print $2}')
	REG=$(echo "$REG1" | gawk -F'@' '{print $1}')
	REGNODE=$(echo "$REG" | gawk -F':' '{print $1}')
	REGPSWD=$(echo "$REG" | gawk -F':' '{print $2}')
	if [ $REGNODE != A$NODE ]
	then
		die "Node numbers in rpt.conf and iax.conf are different!"
	fi
else
	die "$CONFIGS/iax.conf not found"
fi
if [ -e $CONFIGS/savenode.conf ]
then
	grep -q -s NODE= $CONFIGS/savenode.conf || die "savenode.conf missing NODE=xxxx"
	grep -q -s PASSWORD= $CONFIGS/savenode.conf || die "savenode.conf missing PASSWORD=xxxx"
	grep -q -s ENABLE= $CONFIGS/savenode.conf || die "savenode.conf missing ENABLE=x"
	SNODE=$(grep NODE= $CONFIGS/savenode.conf | gawk -F'=' '{print $2}')
	SPASSWORD=$(grep PASSWORD= $CONFIGS/savenode.conf | gawk -F'=' '{print $2}')
	SENABLE=$(grep ENABLE= $CONFIGS/savenode.conf | gawk -F'=' '{print $2}')
	if [ $NODE != $SNODE ]
	then
		die "Node numbers in iax.conf and savenode.conf are different!"
	fi
	if [ $REGPSWD != $SPASSWORD ]
	then
		die "Passwords in iax.conf and savenode.conf are different!"
	fi
	if [ -z $SENABLE ]
	then
		die "Enable not fully specified in savenode.conf!"
	fi
fi
	
echo "OK, the format of the files is understandable!"
echo

ANYNEW=0
NEWNODE=""
echo The system node number is: $NODE
promptyn "Would you like to change it?"
if [ "$ANSWER" = "Y" ]
then
	promptnum "Enter the new node number"
	NEWNODE=$ANSWER
	ANYNEW=1
fi

NEWPSWD=""
echo The registration password is: $REGPSWD
promptyn "Would you like to change it?"
if [ "$ANSWER" = "Y" ]
then
	promptnum "Enter the new registration password"
	NEWPSWD=$ANSWER
	ANYNEW=1
fi

ID=""
promptyn "Would you like to enter a callsign for the identifier"
if [ "$ANSWER" = "Y" ]
then
	promptcall "Please enter your callsign"
	ID=$ANSWER
	ANYNEW=1
fi

SAVENODE_ENABLE=1
# if running Limey Linux, ask them
if [ -x /usr/local/sbin/svcfg ]
then
	promptny "Would you like the system to save your configs offline"
	if [ "$ANSWER" = "N" ]
	then
		SAVENODE_ENABLE=0
	fi
fi

if [ $SAVENODE_ENABLE -ne $SENABLE ] 
then
	ANYNEW=1
fi

if  [ $ANYNEW -gt 0 ]
then
	echo "Copying original files to temporary work area..."
	cp $CONFIGS/rpt.conf $TMP/rpt.conf.in || die "Could not copy $CONFIGS/rpt.conf"
	cp $CONFIGS/extensions.conf $TMP/extensions.conf.in || die "Could not copy $CONFIGS/extensions.conf"
	cp $CONFIGS/iax.conf $TMP/iax.conf.in || die "Could not copy $CONFIGS/iax.conf"
	if [ -e $CONFIGS/savenode.conf ]
	then
		cp $CONFIGS/savenode.conf $TMP/savenode.in || die "Could not copy $CONFIGS/savenode.conf"
	fi
else
	echo "Nothing to do!"
	exit 0
fi
	
if [ ! -z $ID ]
then
	echo "Updating rpt.conf with new ID..."
	sed "s~idrecording[ \t]*=[ \t]*|.*~idrecording = |i$ID\t\t\t; Main ID message~" <$TMP/rpt.conf.in >$TMP/rpt.conf.out
	mv -f $TMP/rpt.conf.out $TMP/rpt.conf.in || die "mv 1 failed"
fi

if [ ! -z $NEWNODE ]
then
	echo "Updating rpt.conf iax.conf, and extensions.conf with new node number..."
	sed "s/$NODE/$NEWNODE/g" <$TMP/extensions.conf.in >$TMP/extensions.conf.out
	mv -f $TMP/extensions.conf.out $TMP/extensions.conf.in || die "mv 2 failed"

	sed "s/$NODE/$NEWNODE/g" <$TMP/rpt.conf.in >$TMP/rpt.conf.out
	mv -f $TMP/rpt.conf.out $TMP/rpt.conf.in || die "mv 3 failed"

	sed "s/$NODE/$NEWNODE/g" <$TMP/iax.conf.in >$TMP/iax.conf.out
	mv -f $TMP/iax.conf.out $TMP/iax.conf.in || die "mv 4 failed"

	if [ -e $CONFIGS/savenode.conf ]
	then
		sed "s/$NODE/$NEWNODE/g" <$TMP/savenode.in >$TMP/savenode.out
		mv -f $TMP/savenode.out $TMP/savenode.in || die "mv 5 failed"
	fi
fi

if [ ! -z $NEWPSWD ]
then
	echo "Updating allstar link register statement in iax.conf with new password..."
	sed "s/$REGPSWD/$NEWPSWD/g" <$TMP/iax.conf.in >$TMP/iax.conf.out
	mv -f $TMP/iax.conf.out $TMP/iax.conf.in || die "mv 6 failed"

	if  [ -e $CONFIGS/savenode.conf ]
	then
		sed "s/$REGPSWD/$NEWPSWD/g" <$TMP/savenode.in >$TMP/savenode.out
		mv -f $TMP/savenode.out $TMP/savenode.in || die "mv 7 failed"
	fi
fi

if  [ -e $CONFIGS/savenode.conf ]
then
	sed "s/ENABLE=$SENABLE/ENABLE=$SAVENODE_ENABLE/g" <$TMP/savenode.in >$TMP/savenode.out
	mv -f $TMP/savenode.out $TMP/savenode.in || die "mv 7 failed"
fi

if [ $DRY_RUN -eq 0 ]
then
	echo "Updating original config files..."
	mv -f $TMP/rpt.conf.in $CONFIGS/rpt.conf || die "mv 8 failed"
	mv -f $TMP/extensions.conf.in $CONFIGS/extensions.conf || die "mv 9 failed"
	mv -f $TMP/iax.conf.in $CONFIGS/iax.conf || die "mv 10 failed"
	if  [ -e $CONFIGS/savenode.conf ]
	then
		mv -f $TMP/savenode.in $CONFIGS/savenode.conf || die "mv 11 failed"
		chmod +x $CONFIGS/savenode.conf || die "chmod failed!"
	fi
	echo "Config files updated. Done!!"
	echo
else
	echo "Dry run"
	echo
fi
exit 0
 
