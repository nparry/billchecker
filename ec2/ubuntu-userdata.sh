#!/bin/bash

# Add extra package repos
apt-key adv --keyserver hkp://keyserver.ubuntu.com --recv-keys 36A1D7869245C8950F966E92D8576A8BA88D21E9
apt-key adv --keyserver hkp://keyserver.ubuntu.com --recv-keys E56151BF

DISTRO=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
CODENAME=$(lsb_release -cs)

echo "deb https://get.docker.com/ubuntu docker main" > /etc/apt/sources.list.d/docker.list
echo "deb http://repos.mesosphere.io/${DISTRO} ${CODENAME} main" > /etc/apt/sources.list.d/mesosphere.list

# Newness, please
apt-get -y update
apt-get -y upgrade

# Install Mesos stuff
apt-get -y install \
  lxc-docker \
  zookeeperd \
  mesos \
  marathon \
  chronos

# Configure system for Mesos usage
adduser ubuntu docker
echo 'docker,mesos' > /etc/mesos-slave/containerizers
echo '5mins' > /etc/mesos-slave/executor_registration_timeout

# Get Mesos running
service mesos-master restart
service mesos-slave restart
service marathon restart
service chronos restart

# Get pre-configured Redis dump to bootstrap our Redis
mkdir -p /var/run/redis
curl -s https://s3.amazonaws.com/billchecker.nparry.com/redis-dump.rdb > /var/run/redis/dump.rdb
chown -R ubuntu:ubuntu /var/run/redis
chmod a+rw /var/run/redis/dump.rdb

# Run Redis via Marathon
# We should really use the bridged networking here, as we are abusing host networking
# ......but oh well
until curl -s http://localhost:8080/ping | grep pong; do sleep 10; done
curl -s -XPOST -HContent-Type:application/json --data @- http://localhost:8080/v2/apps <<JSON_END
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

