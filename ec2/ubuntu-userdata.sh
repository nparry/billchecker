#!/bin/bash

echo "Setting up package repos"
apt-key adv --keyserver hkp://keyserver.ubuntu.com --recv-keys 36A1D7869245C8950F966E92D8576A8BA88D21E9

DISTRO=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
CODENAME=$(lsb_release -cs)

echo "deb https://get.docker.com/ubuntu docker main" > /etc/apt/sources.list.d/docker.list

# Newness, please
apt-get -y update
apt-get -y upgrade

echo "Installing packages"
apt-get -y install \
  lxc-docker \
  redis-tools

# Configure system for docker usage
adduser ubuntu docker

echo "Getting bootstrap data"
mkdir -p /var/run/redis
curl -s https://s3.amazonaws.com/billchecker.nparry.com/redis-dump.rdb > /var/run/redis/dump.rdb
chown -R ubuntu:ubuntu /var/run/redis
chmod a+rw /var/run/redis/dump.rdb

BILLSTORE_KEY="BILLSTORE_KEY_VALUE"
SLACK_KEY="SLACK_KEY_VALUE"

echo "Starting Redis"
su -l ubuntu -c 'docker run \
  --detach \
  --name=billchecker-storage \
  --publish=6379:6379 \
  --volume=/var/run/redis:/data \
  redis'

echo "Waiting for Redis to start"
until redis-cli ping | grep PONG; do sleep 10; done

echo "Starting BillStreamer"
su -l ubuntu -c "docker run \
  --detach \
  --name=billstreamer \
  --link=billchecker-storage:billchecker-storage \
  --env BILLSTORE_KEY=$BILLSTORE_KEY \
  --env SLACK_API_TOKEN=$SLACK_KEY \
  --env REDIS_URL='redis://billchecker-storage:6379' \
  nparry/billchecker /usr/local/bin/process-bill-stream"

echo "Creating Billchecker jobs"
su -l ubuntu -c 'crontab -l' | { cat; echo "0 * * * * docker pull nparry/billchecker"; } | su -l ubuntu -c 'crontab -'

START_OFFSET="0"
for ACCOUNT_ID in $(redis-cli keys \* | sort); do
  START_OFFSET=$(($START_OFFSET+5))
  CRON_SPEC="$START_OFFSET */4 * * *"
  CRON_CMD="docker run \
    --rm \
    --name=billchecker-$ACCOUNT_ID \
    --link=billchecker-storage:billchecker-storage \
    --env=BILLSTORE_KEY=\"$BILLSTORE_KEY\" \
    --env=SLACK_API_TOKEN=\"$SLACK_KEY\" \
    --env=REDIS_URL=\"redis://billchecker-storage:6379\" \
    nparry/billchecker /usr/local/bin/get-bill-balance $ACCOUNT_ID \
    >/var/log/billchecker-$ACCOUNT_ID 2>&1"

  su -l ubuntu -c 'crontab -l' | { cat; echo "$CRON_SPEC $CRON_CMD"; } | su -l ubuntu -c 'crontab -'
done
