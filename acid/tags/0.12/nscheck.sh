#! /bin/bash                                                                     
TOPDOMAIN=allstarlink.org                                                       
WGET=`which wget`

for i in nodes1 nodes2 nodes3 nodes4
do                                                               
	$WGET  -q -O /tmp/$i.out http://$i.$TOPDOMAIN/cgi-bin/nodes.pl
	if [ $? -ne 0 ]
	then
		rm -f /tmp/$i.out
		echo "$i.$TOPDOMAIN is down"
	else
		echo "$i.$TOPDOMAIN is up"
		sites=$((sites+1))
		if [ -z "$nodelist" ]
		then
			nodelist=$i 
		else
			nodelist="$nodelist $i"
		fi

	fi
done

if ! [ -z $1 ]
then
	files=$(echo "/tmp/nodes?.out")
	for file in $files
	do
		node=$(echo $file | cut -d '/' -f3 | cut -d '.' -f1)
		echo "***** $node *****"
		grep $1 < $file
	done
else
	files=$(echo "/tmp/nodes?.out")
	for file in $files
	do
		node=$(echo $file | cut -d '/' -f3 | cut -d '.' -f1)
		echo "***** $node  *****"
		head -n 3 $file
	done
fi

rm /tmp/nodes*.out
