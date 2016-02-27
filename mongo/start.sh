#!/bin/bash
: "${OPTIONS:=}" # Mongo opptions


echosmall(){
	echo "-------MONGO-SETUP--"$1
}


if [ -n "$WAITFOR" ]; then
	
	WAITFOR_PORT=${WAITFOR_PORT:=27017}
	SLEEP=${SLEEP:=1}


for i in $(echo $WAITFOR | sed "s/,/ /g")
do

echosmall "Waiting on ${i}..."
	
timeout 30 bash <<EOT
while ! timeout 1 bash -c "echo > /dev/tcp/${i}/${WAITFOR_PORT}"; do sleep 1; done
EOT
RESULT=$?
	if [ $RESULT -ne 0 ]; then
	  echosmall "waitfor: timeout out after 30 seconds waiting for ${i}:27017"
	  exit 2
	fi
	
	echosmall "Success! Done waiting for ${i}"
	
done



fi



case "$MODE" in
      (init-set)
        echosmall "Adding Mongo replica set information on ${TARGET}..."
        /usr/bin/mongo ${TARGET}:27017 /setupReplicaSet${SET}.js
        echosmall "Replica Set setup complete for ${TARGET}..."
        ;;
      (init-cluster)
        sleep 15 # Wait for mongo to start
		/usr/bin/mongo ${TARGET}:27017 /addShard.js
		sleep 15 # Wait for sharding to be enabled
		/usr/bin/mongo ${TARGET}:27017 /addDBs.js
		sleep 15 # Wait for db to be created
		/usr/bin/mongo ${TARGET}:27017/admin /enabelSharding.js
		sleep 15 # Wait sharding to be enabled
		/usr/bin/mongo ${TARGET}:27017 /addIndexes.js
		;;
      (*)
        # Start mongo and log
		/usr/bin/mongo$OPTIONS
		;;
    esac



