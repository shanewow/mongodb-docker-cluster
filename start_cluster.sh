#!/bin/bash

# Docker interface ip
#DNS="172.17.0.2"
MACHINE="mongo-test"
LOCALPATH="/home/docker"


eval $(docker-machine env ${MACHINE})

# Clean up
containers=( skydns skydock mongos1r1 mongos1r2 mongos2r1 mongos2r2 mongos3r1 mongos3r2 configservers1 configservers2 configservers3 mongos1 )
for c in ${containers[@]}; do
	docker kill ${c} 	> /dev/null 2>&1
	docker rm ${c} 		> /dev/null 2>&1
done

# Uncomment to build mongo image yourself otherwise it will download from docker index.
#docker build -t jacksoncage/mongo ${LOCALPATH}/mongo > /dev/null 2>&1

# Setup skydns/skydock
CID=$(docker run -d -p 53:53/udp --name skydns crosbymichael/skydns -nameserver 8.8.8.8:53 -domain docker)
DNS=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' ${CID})

echo "Skydns ip address: "$DNS 

docker run -d -v /var/run/docker.sock:/docker.sock --name skydock crosbymichael/skydock -ttl 30 -environment dev -s /docker.sock -domain docker -name skydns

for (( i = 1; i < 4; i++ )); do
	# Setup local db storage if not exist
	if [ ! -d "${LOCALPATH}/mongodata/${i}-1" ]; then
		docker-machine ssh ${MACHINE} sudo mkdir -p ${LOCALPATH}/mongodata/${i}-1
		docker-machine ssh ${MACHINE} sudo mkdir -p ${LOCALPATH}/mongodata/${i}-2
		docker-machine ssh ${MACHINE} sudo mkdir -p ${LOCALPATH}/mongodata/${i}-cfg
	fi
    
	echo "Create mongd servers"
	REP1=$(docker run --dns ${DNS} --name mongos${i}r1 -P -i -d -v ${LOCALPATH}/mongodata/${i}-1:/data/db -e OPTIONS="d --replSet set${i} --dbpath /data/db --notablescan --noprealloc --smallfiles" jacksoncage/mongo)
    
	REP2=$(docker run --dns ${DNS} --name mongos${i}r2 -P -i -d -v ${LOCALPATH}/mongodata/${i}-2:/data/db -e OPTIONS="d --replSet set${i} --dbpath /data/db --notablescan --noprealloc --smallfiles" jacksoncage/mongo)
    
	sleep 20 # Wait for mongo to start
    
	echo "Setup replica set"
    REP1_IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' ${REP1})
    #REP1_PORT=$(docker port mongos${i}r1 27017|cut -d ":" -f2)
    
	docker run --dns ${DNS} -P -i -t -e OPTIONS=" ${REP1_IP}:27017 /initiate.js" jacksoncage/mongo
	sleep 30 # Waiting for set to be initiated
	docker run --dns ${DNS} -P -i -t -e OPTIONS=" ${REP1_IP}:27017 /setupReplicaSet${i}.js" jacksoncage/mongo
	echo "Create configserver"
	docker run --dns ${DNS} --name configservers${i} -P -i -d -v ${LOCALPATH}/mongodata/${i}-cfg:/data/db -e OPTIONS="d --configsvr --dbpath /data/db --notablescan --noprealloc --smallfiles --port 27017" jacksoncage/mongo
done

echo "Setup and configure mongo router"
MONGOS1=$(docker run --dns ${DNS} --name mongos1 -P -i -d -e OPTIONS="s --configdb configservers1.mongo.dev.docker:27017,configservers2.mongo.dev.docker:27017,configservers3.mongo.dev.docker:27017 --port 27017" jacksoncage/mongo)

MONGOS1_IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' ${MONGOS1})

echo "MONGOS1 IP:" ${MONGOS1_IP}

sleep 15 # Wait for mongo to start
docker run --dns ${DNS} -P -i -t -e OPTIONS=" ${MONGOS1_IP}:27017 /addShard.js" jacksoncage/mongo
sleep 15 # Wait for sharding to be enabled
docker run --dns ${DNS} -P -i -t -e OPTIONS=" ${MONGOS1_IP}:27017 /addDBs.js" jacksoncage/mongo
sleep 15 # Wait for db to be created
docker run --dns ${DNS} -P -i -t -e OPTIONS=" ${MONGOS1_IP}:27017/admin /enabelSharding.js" jacksoncage/mongo
sleep 15 # Wait sharding to be enabled
docker run --dns ${DNS} -P -i -t -e OPTIONS=" ${MONGOS1_IP}:27017 /addIndexes.js" jacksoncage/mongo

echo "#####################################"
echo "MongoDB Cluster is now ready to use"
echo "Connect to cluster by:"
echo "$ mongo --port 27017"