#!/bin/bash

BILLSTORE_KEY="BILLSTORE_KEY_VALUE"
SLACK_KEY="SLACK_KEY_VALUE"

echo "Getting bootstrap data"
mkdir -p /var/run/redis
curl -s https://s3.amazonaws.com/billchecker.nparry.com/redis-dump.rdb > /var/run/redis/dump.rdb
chown -R core:core /var/run/redis
chmod a+rw /var/run/redis/dump.rdb

echo "Starting Redis"
cat > /etc/systemd/system/billchecker-storage.service <<END_OF_UNIT
[Unit]
Description=Billchecker Redis storage

[Service]
User=core
ExecStart=/usr/bin/docker run --name=billchecker-storage --volume=/var/run/redis:/data redis
END_OF_UNIT
systemctl start billchecker-storage.service

echo "Waiting for Redis to start"
until docker run --link=billchecker-storage:billchecker-storage redis redis-cli -h billchecker-storage ping | grep PONG; do sleep 10; done

echo "Starting BillStreamer"
cat > /etc/systemd/system/billstreamer.service <<END_OF_UNIT
[Unit]
Description=Billstreamer bot responding to bill inquiries

[Service]
User=core
ExecStart=/usr/bin/docker run --name=billstreamer --link=billchecker-storage:billchecker-storage --env BILLSTORE_KEY=$BILLSTORE_KEY --env SLACK_API_TOKEN=$SLACK_KEY --env REDIS_URL='redis://billchecker-storage:6379' nparry/billchecker /usr/local/bin/process-bill-stream
END_OF_UNIT
systemctl start billstreamer.service

echo "Creating Billchecker jobs"
START_OFFSET="0"
for ACCOUNT_ID in $(docker run --link=billchecker-storage:billchecker-storage redis redis-cli -h billchecker-storage keys \* | sort); do
  START_OFFSET=$(($START_OFFSET+5))
  cat > /etc/systemd/system/billchecker-check-$ACCOUNT_ID.service <<END_OF_UNIT
[Unit]
Description=Billchecker for account $ACCOUNT_ID

[Service]
Type=oneshot
User=core
ExecStart=/usr/bin/docker run --rm --name=billchecker-check-$ACCOUNT_ID --link=billchecker-storage:billchecker-storage --env=BILLSTORE_KEY=$BILLSTORE_KEY --env=SLACK_API_TOKEN=$SLACK_KEY --env=REDIS_URL=redis://billchecker-storage:6379 nparry/billchecker /usr/local/bin/get-bill-balance $ACCOUNT_ID
END_OF_UNIT

  cat > /etc/systemd/system/billchecker-check-$ACCOUNT_ID.timer <<END_OF_UNIT
[Unit]
Description=Run billchecker for account $ACCOUNT_ID on a schedule

[Timer]
OnCalendar=0/4:$START_OFFSET
END_OF_UNIT
  systemctl start billchecker-check-$ACCOUNT_ID.timer
done

