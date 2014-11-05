#!/bin/bash

USER_DATA_FILE="$(dirname $0)/ubuntu-userdata.sh"
[ ! -f $USER_DATA_FILE ] &&  echo "Unable to find $USER_DATA_FILE" && exit 1

LAUNCH_SPEC=$(cat <<END
{
  "ImageId": "ami-98aa1cf0",
  "KeyName": "wintermute_aws",
  "SecurityGroups": ["mesos-spot-instances"],
  "UserData": "$(base64 $USER_DATA_FILE)",
  "InstanceType": "t1.micro"
}
END
)

aws ec2 request-spot-instances \
  --spot-price 0.01 \
  --instance-count 1 \
  --type persistent \
  --launch-specification "$(tr '\n' ' ' <<< $LAUNCH_SPEC)"

