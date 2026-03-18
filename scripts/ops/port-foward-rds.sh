#!/usr/bin/env bash
set -euo pipefail

AWS_PROFILE="${AWS_PROFILE:-default}"
AWS_REGION="${AWS_REGION:-ap-northeast-2}"
INSTANCE_NAME="${1:-ops-ec2}"
RDS_ENDPOINT="${2:-}"
REMOTE_PORT="${3:-3306}"
LOCAL_PORT="${4:-3306}"

if [[ -z "$RDS_ENDPOINT" ]]; then
  echo "Usage: $0 <instance-name> <rds-endpoint> [remote-port] [local-port]"
  exit 1
fi

INSTANCE_ID=$(
  aws ec2 describe-instances \
    --profile "$AWS_PROFILE" \
    --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=${INSTANCE_NAME}" "Name=instance-state-name,Values=running" \
    --query "Reservations[0].Instances[0].InstanceId" \
    --output text
)

if [[ -z "$INSTANCE_ID" || "$INSTANCE_ID" == "None" ]]; then
  echo "EC2 instance not found: ${INSTANCE_NAME}"
  exit 1
fi

echo "Starting port forwarding:"
echo "  local     : 127.0.0.1:${LOCAL_PORT}"
echo "  remote    : ${RDS_ENDPOINT}:${REMOTE_PORT}"
echo "  via ops EC2: ${INSTANCE_NAME} (${INSTANCE_ID})"

aws ssm start-session \
  --profile "$AWS_PROFILE" \
  --region "$AWS_REGION" \
  --target "$INSTANCE_ID" \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters "{\"host\":[\"${RDS_ENDPOINT}\"],\"portNumber\":[\"${REMOTE_PORT}\"],\"localPortNumber\":[\"${LOCAL_PORT}\"]}"