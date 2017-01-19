#!/opt/bin/bash
SRV_LIST=$(ls conf.d/*.conf)

for srv in $SRV_LIST; do 
    srv=$(basename $srv .conf)
    echo 
    echo 
    echo $srv
    ssh root@$srv
done
