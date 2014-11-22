#!/bin/bash

USER_DATA_FILE="$(dirname $0)/ubuntu-userdata.sh"
[ ! -f $USER_DATA_FILE ] &&  echo "Unable to find $USER_DATA_FILE" && exit 1

BILLSTORE_KEY=$1
[ -z $BILLSTORE_KEY ] && echo "Please provide billstore key" && exit 1

AWS_REGION=${2:-"us-east-1"}

UBUNTU_OWNER="099720109477"
AMI_NAME="ubuntu/images/ebs-ssd/ubuntu-trusty-14.04-amd64-server-20140927"
AMI_ID=$(aws ec2 describe-images \
  --region $AWS_REGION \
  --owners $UBUNTU_OWNER \
  --filters "Name=name,Values=$AMI_NAME" \
  | grep '"ImageId":' | cut -d\" -f4)
[ -z "$AMI_ID" ] && echo "Unable to location Ubuntu AMI" && exit 1

USER_DATA=$(cat $USER_DATA_FILE | sed "s|BILLSTORE_KEY_VALUE|$BILLSTORE_KEY|" | base64)
LAUNCH_SPEC=$(cat <<END
{
  "ImageId": "$AMI_ID",
  "KeyName": "wintermute_aws",
  "SecurityGroups": ["mesos-spot-instances"],
  "UserData": "$USER_DATA",
  "InstanceType": "t1.micro"
}
END
)

aws ec2 request-spot-instances \
  --region $AWS_REGION \
  --spot-price 0.01 \
  --instance-count 1 \
  --type persistent \
  --launch-specification "$(tr '\n' ' ' <<< $LAUNCH_SPEC)"

