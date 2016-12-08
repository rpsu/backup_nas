#!/bin/bash
# 
# File:   backup_script
# Author: Perttu Ehn, Itusi Oy
# License: GPL2
#
# Created on Jul 22, 2011, 3:54:37 PM
# for Synology NAS (BusyBox), updated for QNAP (Busybox)
#
# REQUIREMENTS:
# -- configuration in	./backup_script.conf
# -- functions in	./backup_script.functions
# -- server configurations in conf.d/<server-fqdn>.conf
#
# usage: 
# ./backup_script [full-list|<server-fqdn>]
# if "full-list" specified, searching files *.conf in ./conf.d/
# if <server-fqdn> sepcified, assuming to conf file exist in ./conf.d/<server-fqdn>.conf

/sbin/log_tool -t 0 -a "[$(basename $0)] running..."

if [ -z "$1" ]; then
	echo "Usage: $(basename "$0") [full-list|<server>]"
	echo "..where <server-fqdn> matches filename in conf.d/<server-fqdn>.conf"
	echo "Nothing is done this time!"
	exit 1
fi 

# load configurations and functions
	
FILENAMEBODY=$(basename ${0} .sh)
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



#make sure there's not other instance of this script running...
CNT=0
while [ -f "$LOCKFILE" ] && [ "$CNT" -lt "120" ]
do
	CNT=$((${CNT}+1))
	echo "$(date) / $(hostname) / $(basename $0)"
	echo -e "Lockfile keeps me from continuing, still trying...round ${CNT}/120"
	echo -e "Waiting for 60 secs to try again.\n"
	sleep 60
done

if [ -f "$LOCKFILE" ]; then
	echo "Could not execute $0, since there's a lockfile. Maybe it is a dead process?"
	echo -e "\nExiting. \n\nIMPORTANT: Backup failed!\n\n"
	exit 1
fi
# create lockfile 
$TOUCH $LOCKFILE
if [ ! -e "$LOCKFILE" ]; then 
	echo "Could not create lockfile!"
fi 

# strip trailing slashes away, if present
LOCAL_STORAGE="${LOCAL_STORAGE%/}"
CONF_DIR="${CONF_DIR%/}"
if [ ! -z "$1" ]; then
	SERVER="$1"
fi

check_logfile
echo -e "\n\n============================================" >> $LOGFILE
echo -e "============================================" >> $LOGFILE
echo -e "============================================\n" >> $LOGFILE
echo -e "$(date) LOKI [$UNIQ]: $0 -- STARTED HERE\n"  >> $LOGFILE


# get configuration either for specified server of grab all configuration files
if [ "$SERVER" == "full-list" ]; then
	echo "Requested full list of servers, so using all conf files in ${CONF_DIR}" >> $LOGFILE
	for FILE in ${CONF_DIR}/*${CONF_EXT}
	do
		FILE=$(basename $FILE)
		# cut out unnecessary sfuff (ending) out of filename
		SRV=${FILE%$CONF_EXT}
		# push newest item into array, :-0 -syntax pushes 0 if count would be null
		CNT=${#SRV_LIST[@]:-0}
		SRV_LIST[${CNT}]=${SRV}
		echo "$(date) LOKI [$UNIQ]: Added ${SRV} to list of servers as \$SRV_LIST[${CNT}]" >> $LOGFILE
	done
	echo -e "\n" >> $LOGFILE
else 
	echo "$(date) LOKI [$UNIQ]: Using specified server ${SERVER}" >> $LOGFILE
	SRV_CONF=${CONF_DIR}/${SERVER}${CONF_EXT} 
	if [ -f $SRV_CONF ]; then
		SRV_LIST=(${SERVER})
	else 
		echo "$(date) LOKI [$UNIQ]: NO configuration file for $SERVER found." >> $LOGFILE
		echo "$(date) LOKI [$UNIQ]: Tried this: ${SRV_CONF}" >> $LOGFILE
		ERRORS=$((${ERRORS} + 1)) 
	fi
fi
echo -e "\nFinal list of servers is: '${SRV_LIST[@]}' (${#SRV_LIST[*]} elements)" >> $LOGFILE

# make sure we've got at least one configuration
if [ "${#SRV_LIST[@]}" -gt "0" ]; then
	for SRC_SERVER in "${SRV_LIST[@]}"
	do
		echo -e "\n=================================\n=================================\n\nStarting rsyncing with server ${SRC_SERVER}" >> $LOGFILE
		# read conf within rsync_server -function
		# and loop throug possible multiple directories _there_
		RotateAndRsync
	done
else 
	echo "No servers to backup. Nothing to do." >> $LOGFILE
	if [ -z "$1" ]; then
		echo -e "It seems like there's no configuration files in $CONF_DIR\n" >> $LOGFILE
		ERRORS=$(($ERRORS + 1))
	fi
fi


if [ "$ERRORS" -ne "0" ]; then
        echo -e "$(date) LOKI [$UNIQ]: ** FINISHED WITH ERRORS ** , error count ${ERRORS} in  ${LOGFILE}\n" >> $LOGFILE
	echo -e "\n$(date) LOKI [$UNIQ]: Encountered some errors @$(hostname) using $(basename $0) (counted ${ERRORS}), check your log!\n"
	logmailer "errors" 2>> $LOGFILE
	if [  "$?" -ne "0" ]; then
		echo -e "$(date)\nScript $(basename ${0}) logmailer did not finish clean. Check log in $LOGFILE for errors."
	fi
	EXITCODE=1
else 
	logmailer "ok" 2>> $LOGFILE
        echo -e "\n$(date) LOKI [$UNIQ]: FINISHED, no errors.\n" >> $LOGFILE
	EXITCODE=0
fi
 
#remove lockfile
$RM $LOCKFILE
RM_RESULT=$?
if [ "$RM_RESULT" = "0" ] ; then
        echo -e "\n$(date) LOKI [$UNIQ]: Lockfile removed!\n" >> $LOGFILE
else 
        echo -e "\n$(date) LOKI [$UNIQ]: ** ERROR ** Lockfile could not be removed!\n" >> $LOGFILE
        echo -e "\n$(date) LOKI [$UNIQ]: ** ERROR ** Tried this: $RM $LOCKFILE\n" >> $LOGFILE
        echo -e "\n$(date) LOKI [$UNIQ]: ** ERROR ** RM resulted: '$RM_RESULT'\n" >> $LOGFILE
fi

/sbin/log_tool -t 0 -a "[$(basename $0)] done!"

exit $EXITCODE
