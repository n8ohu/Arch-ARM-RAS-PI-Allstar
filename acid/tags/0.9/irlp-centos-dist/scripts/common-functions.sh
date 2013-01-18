#!/bin/bash
# This is a shell snippet containing some common functions to do menial tasks,
# Instead of duplicating effort in many places.

# Make sure we are user repeater!!!
if [ "`/usr/bin/whoami`" != "repeater" ] ; then
  echo "This program must be run as user REPEATER!"
  exit 1
fi

# Make sure we have sourced the environment file
if [ "$RUN_ENV" != "TRUE" ] ; then
  # This used to tell the user to manually source the environemnt file
  # which was stupid. It now goes ahead and does it for you.
  . /home/irlp/custom/environment
fi

#If the length of the stantionid is 6 (old three digit), it adds a zero
if [ "${#STATIONID}" = "6" ] ; then
  CONVERTED_STATIONID="${STATIONID}0"
else
  CONVERTED_STATIONID="$STATIONID"
fi

# Figure out where netcat (nc) is located
NETCAT=`which nc 2>/dev/null`
if [ "${NETCAT}" = "" ] ; then
   echo "ERROR: netcat (nc) cannot be found!"
   exit 1
fi

#########################################################################
### Functions

# This function creates four env vars with the four digits of a node, from
# a stationid name. ( of the form: "{stn,ref,}XXXX" )
# Syntax:  set_node_digits <node> <var1> <var2> <var3> <var4>
# Example: set_node_digits stn1234 N1 N2 N3 N4
#          echo $N1 $N2 $N3 $N4

function set_node_digits {
  NODE=$1 NUM1=$2 NUM2=$3 NUM3=$4 NUM4=$5

  if [ "${#NODE}" = "7" ]; then
    NODE="${NODE#???}"
  fi

  if [ "${#NODE}" != "4" \
    -o -z "$NUM1" -o -z "$NUM2" -o -z "$NUM3" -o -z "$NUM4" ] ; then
   echo "Bad arguments to set_node_digits()"
   exit 1
  fi

  eval TEMP1=${NODE#?} TEMP2=${NODE#??}
  eval NUM1=${NODE%???} NUM2=${TEMP1%??} NUM3=${TEMP2%?} NUM4=${NODE#???}
}

# Logging
function log {
  MESSAGE=$@
  if [ -n "$LOGFILE" ]; then
    echo "`date '+%b %d %Y %T %z'` $MESSAGE" >> $LOGFILE
  fi
}

### End Functions
#########################################################################
