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

mkdir -p /var/lib/billchecker
curl -s https://s3.amazonaws.com/billchecker.nparry.com/twitter_settings.base64.des3 > /var/lib/billchecker/twitter_settings.base64.des3

BILLSTORE_KEY="BILLSTORE_KEY_VALUE"
TWITTER_SETTINGS=$(cat /var/lib/billchecker/twitter_settings.base64.des3 | openssl des3 -d -k $BILLSTORE_KEY)

echo "Starting Redis"
docker run \
  --detach \
  --name=billchecker-storage \
  --publish=6379:6379 \
  --volume=/var/run/redis:/data \
  redis

echo "Waiting for Redis to start"
until redis-cli ping | grep PONG; do sleep 10; done

echo "Starting BillStreamer"
docker run \
  --detach \
  --name=billstreamer \
  --link=billchecker-storage:billchecker-storage \
  --env BILLSTORE_KEY="$BILLSTORE_KEY" \
  --env TWITTER_SETTINGS="$TWITTER_SETTINGS" \
  --env REDIS_URL="redis://billchecker-storage:6379" \
  nparry/billchecker /usr/local/bin/process-bill-stream

echo "Creating Billchecker jobs"
START_OFFSET="0"
for ACCOUNT_ID in $(redis-cli keys \* | sort); do
  START_OFFSET=$(($START_OFFSET+5))
  CRON_SPEC="$START_OFFSET */4 * * *"
  CRON_CMD="docker run \
    --rm \
    --name=billchecker-$ACCOUNT_ID \
    --link=billchecker-storage:billchecker-storage \
    --env=BILLSTORE_KEY=\"$BILLSTORE_KEY\" \
    --env=TWITTER_SETTINGS=\"$TWITTER_SETTINGS\" \
    --env=REDIS_URL=\"redis://billchecker-storage:6379\" \
    nparry/billchecker /usr/local/bin/get-bill-balance $ACCOUNT_ID"

  crontab -l | { cat; echo "$CRON_SPEC $CRON_CMD"; } | crontab -
done
