#!/bin/bash

echo "Setting up package repos"
apt-key adv --keyserver hkp://keyserver.ubuntu.com --recv-keys 36A1D7869245C8950F966E92D8576A8BA88D21E9
apt-key adv --keyserver hkp://keyserver.ubuntu.com --recv-keys E56151BF

DISTRO=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
CODENAME=$(lsb_release -cs)

echo "deb https://get.docker.com/ubuntu docker main" > /etc/apt/sources.list.d/docker.list
echo "deb http://repos.mesosphere.io/${DISTRO} ${CODENAME} main" > /etc/apt/sources.list.d/mesosphere.list

# Newness, please
apt-get -y update
apt-get -y upgrade

echo "Installing Mesos packages"
apt-get -y install \
  lxc-docker \
  zookeeperd \
  mesos \
  marathon \
  chronos \
  redis-tools

# Configure system for Mesos usage
adduser ubuntu docker
echo 'docker,mesos' > /etc/mesos-slave/containerizers
echo '5mins' > /etc/mesos-slave/executor_registration_timeout

echo "Starting Mesos services"
service mesos-master restart
service mesos-slave restart
service marathon restart
service chronos restart

echo "Getting bootstrap data"
mkdir -p /var/run/redis
curl -s https://s3.amazonaws.com/billchecker.nparry.com/redis-dump.rdb > /var/run/redis/dump.rdb
chown -R ubuntu:ubuntu /var/run/redis
chmod a+rw /var/run/redis/dump.rdb

mkdir -p /var/lib/billchecker
curl -s https://s3.amazonaws.com/billchecker.nparry.com/twitter_settings.base64.des3 > /var/lib/billchecker/twitter_settings.base64.des3

# Run Redis via Marathon
# We should really use the bridged networking here, as we are abusing host networking
# ......but oh well
echo "Waiting for Marathon to start"
until curl -s http://localhost:8080/ping | grep pong; do sleep 10; done

echo "Starting Redis via Marathon"
curl -Ls -XPOST -HContent-Type:application/json --data @- http://localhost:8080/v2/apps <<JSON_END
{
  "id": "billchecker-storage",
  "cpus": 0.1,
  "mem": 32,
  "ports": [ 6379 ],
  "instances": 1,
  "container": {
    "type": "DOCKER",
    "docker": {
      "image": "redis"
    },
    "volumes": [
      {
        "containerPath": "/data",
        "hostPath": "/var/run/redis",
        "mode": "RW"
      }
    ]
  }
}
JSON_END

# Submit jobs to Chronos. Use the keys in Redis to auto-figure-out the jobs we need
echo "Waiting for Redis to start"
until redis-cli ping | grep PONG; do sleep 10; done

echo "Waiting for Chronos to start"
until curl -s http://localhost:4400/ping | grep pong; do sleep 10; done

echo "Submitting Billchecker jobs to Chronos"
BILLSTORE_KEY="BILLSTORE_KEY_VALUE"
TWITTER_SETTINGS=$(cat /var/lib/billchecker/twitter_settings.base64.des3 | openssl des3 -d -k $BILLSTORE_KEY)
START_OFFSET="0"
for ACCOUNT_ID in $(redis-cli keys \* | sort); do
  START_OFFSET=$(($START_OFFSET+5))
  START_TIME=$(date --iso-8601=seconds --date="now +$START_OFFSET minutes" | sed 's/+0000/Z/')
  curl -Ls -XPOST -HContent-Type:application/json --data @- http://localhost:4400/scheduler/iso8601 <<JSON_END
  {
    "name": "billchecker_$ACCOUNT_ID",
    "owner": "nparry@gmail.com",
    "schedule": "R/$START_TIME/PT4H",
    "cpus": "0.5",
    "mem": "128",
    "command": "docker run --rm --net=host -e REDIS_URL=\"redis://localhost:6379\" -e BILLSTORE_KEY=\"$BILLSTORE_KEY\" -e TWITTER_SETTINGS=\"$TWITTER_SETTINGS\" nparry/billchecker /usr/local/bin/get-bill-balance $ACCOUNT_ID"
  }
JSON_END
done
