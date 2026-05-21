#!/bin/bash
# usage:
#   ./deploy.sh          # update existing stack (default)
#   ./deploy.sh --fresh  # tear down and redeploy from scratch

STACK=mcropsey-lab
REGION=us-east-2
TEMPLATE=~/mcropsey-aws-crapi-lab.yaml
MY_IP=$(curl -s https://checkip.amazonaws.com)/32

if [[ "${1:-}" == "--fresh" ]]; then
  echo "==> Deleting existing stack..."
  aws cloudformation delete-stack --stack-name $STACK --region $REGION
  aws cloudformation wait stack-delete-complete --stack-name $STACK --region $REGION
  echo "==> Stack deleted."
fi

echo "==> Deploying stack..."
aws cloudformation deploy \
  --template-file $TEMPLATE \
  --stack-name $STACK \
  --region $REGION \
  --parameter-overrides AllowedSSHCIDR=$MY_IP

echo "==> Done. Outputs:"
aws cloudformation describe-stacks \
  --stack-name $STACK \
  --region $REGION \
  --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
  --output table
