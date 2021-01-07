#!/bin/bash
## auto connect to PIA, obtain port, update port in Transmission

## can be run with a crontab job to ensure connection is up and running, recommend frequent test

#basic config options
TRANSUSER=user
TRANSPASS=password
TRANSHOST=localip


#!/bin/bash
## check if PIA is connected, if not, reconnect

# test if pia-daemon is running, sleep for 1 second until it is
until pgrep "pia-daemon" >/dev/null 2>&1
do
	sleep 1
done

CONNECTSTATUS=$(/usr/local/bin/piactl get connectionstate)

if [ $CONNECTSTATUS == "Connected" ]; then
	echo 'Already connected'
else
	/usr/local/bin/piactl connect
	echo 'Reconnecting'
fi

sleep 5 # wait a little bit to make sure connection is fully set, mostly to allow time to obtain a Port

# get port foward value from PIA
PIAPORT=$(/usr/local/bin/piactl get portforward)

# test if port has been assigned, sleep for 1 second and get it again until it has been
# this might be a bit "abusive" but I'm pretty sure you're just asking the client for the data so it shouldn't be a big deal
until [[ $PIAPORT == ?(-)+([0-9]) ]]
do
	echo 'no port assigned'
	sleep 1
	PIAPORT=$(/usr/local/bin/piactl get portforward)
done

# check if transmission sees it's port as open already
PORTOPEN=`/usr/bin/transmission-remote $TRANSHOST -n $TRANSUSER:$TRANSPASS --port-test | cut -f2 -d":" | sed 's/ //g'`

# if port isn't open, provide new port forward value into transmission
if [ $PORTOPEN != "Yes" ];then
	echo "Updating Transmission port to $PIAPORT"
	/usr/bin/transmission-remote $TRANSHOST -n $TRANSUSER:$TRANSPASS --port $PIAPORT
else
	echo 'Transmission port is open!'
fi
