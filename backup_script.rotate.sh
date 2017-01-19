#!/bin/bash

# load configurations and functions

FILENAMEBODY=$(basename ${0} .rotate.sh)
DIR="$( cd "$( dirname "$0" )" && pwd )"

if [ ! -f "$DIR/$FILENAMEBODY.conf" ]; then
	echo "Could not load configuration! Exiting..."
	echo "Tried this: $DIR/$FILENAMEBODY.conf"
	exit 1
else
	if [ ! -f "$DIR/$FILENAMEBODY.functions" ]; then
		echo "Could not load required functions from a file! Exiting..."
		echo "Tried this: $DIR/$FILENAMEBODY.functions"
		exit 1
	fi
fi

# they exist, so read contents
. "$DIR/$FILENAMEBODY.conf"
. "$DIR/$FILENAMEBODY.functions"

ARCHIVE="$LOCAL_STORAGE"
LOGFILE="$FILENAMEBODY.log"
DATESTAMP=$(/opt/bin/date +%Y-%m-%d_%H-%M-%S)
$TAR -cf $ARCHIVE/$LOGFILE.$DATESTAMP.tar.gz $LOCAL_STORAGE/$LOGFILE 2> /dev/null && /bin/gzip $ARCHIVE/$LOGFILE.$DATESTAMP.tar.gz && echo > $LOCAL_STORAGE/$LOGFILE
