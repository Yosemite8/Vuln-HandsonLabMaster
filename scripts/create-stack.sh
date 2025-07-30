#!/bin/bash

# Usage: ./create-stack.sh <number_of_users>
# Example: Creates base infrastructure and participant resources for the specified number of users

# Validate arguments
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <number_of_users>"
  exit 1
fi

USER_COUNT=$1

# Load attendee names from JSON
ATTENDEE_NAME=($(jq -r '.[]' attendees.json))

# Validate there are enough names
if [ "${#ATTENDEE_NAME[@]}" -lt "$USER_COUNT" ]; then
  echo "Error: Not enough attendee names in attendees.json (need $USER_COUNT)"
  exit 1
fi

# Define required variables
BASE_TEMPLATE_FILE="../CloudFormation/base-vpc.yml"
FARGATE_TEMPLATE_FILE="../CloudFormation/fargate-lab.yml"
# Choose your local AWS CLI Profile where this script actually runs (optional)
PROFILE=""
# Specify the team identifier
TEAM_ID="[Your team name]"
# Specify the CIDR range of source IP addresses that you need to allow for inbound access
CIDR="[Your IP, CIDR]"

# Create base infrastructure first
BASE_STACK_NAME="base-vpc-${TEAM_ID}"
echo "Creating base infrastructure stack: ${BASE_STACK_NAME}"

aws cloudformation create-stack \
  --stack-name "${BASE_STACK_NAME}" \
  --profile "${PROFILE}" \
  --template-body file://${BASE_TEMPLATE_FILE} \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameters \
      ParameterKey=TeamId,ParameterValue=${TEAM_ID}

echo "Waiting for base infrastructure stack to be created..."
aws cloudformation wait stack-create-complete \
  --stack-name "${BASE_STACK_NAME}" \
  --profile "${PROFILE}"

# Get VPC and Subnet IDs from base stack
VPC_ID=$(aws cloudformation describe-stacks \
  --stack-name "${BASE_STACK_NAME}" \
  --profile "${PROFILE}" \
  --query 'Stacks[0].Outputs[?OutputKey==`SharedVpcId`].OutputValue' \
  --output text)

SUBNET_ID=$(aws cloudformation describe-stacks \
  --stack-name "${BASE_STACK_NAME}" \
  --profile "${PROFILE}" \
  --query 'Stacks[0].Outputs[?OutputKey==`SharedSubnetId`].OutputValue' \
  --output text)

echo "Base infrastructure created successfully"
echo "VPC ID: ${VPC_ID}"
echo "Subnet ID: ${SUBNET_ID}"

# Get CI credentials from base stack
CI_ACCESS_KEY_ID=$(aws cloudformation describe-stacks \
  --stack-name "${BASE_STACK_NAME}" \
  --profile "${PROFILE}" \
  --query 'Stacks[0].Outputs[?OutputKey==`CIUserAccessKeyId`].OutputValue' \
  --output text)

CI_SECRET_ACCESS_KEY=$(aws cloudformation describe-stacks \
  --stack-name "${BASE_STACK_NAME}" \
  --profile "${PROFILE}" \
  --query 'Stacks[0].Outputs[?OutputKey==`CIUserSecretAccessKey`].OutputValue' \
  --output text)

echo "CI credentials generated successfully"
echo "Access Key ID: ${CI_ACCESS_KEY_ID}"
echo "Secret Access Key: ${CI_SECRET_ACCESS_KEY}"

# Loop over attendee names to create participant resources
for ((i = 0; i < USER_COUNT; i++)); do
  USER_ID="${ATTENDEE_NAME[$i]}"
  STACK_NAME="codesec-lab-${USER_ID}"

  echo "Creating participant CloudFormation stack: ${STACK_NAME}"

  aws cloudformation create-stack \
    --stack-name "${STACK_NAME}" \
    --profile "${PROFILE}" \
    --template-body file://${FARGATE_TEMPLATE_FILE} \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameters \
        ParameterKey=TeamId,ParameterValue=${TEAM_ID} \
        ParameterKey=UserId,ParameterValue=${USER_ID} \
        ParameterKey=VpcId,ParameterValue=${VPC_ID} \
        ParameterKey=VpcSubnet,ParameterValue=${SUBNET_ID} \
        ParameterKey=AllowedIngressCidr,ParameterValue=${CIDR}
done

echo "All stacks creation initiated. Check AWS Console for progress."
echo ""
echo "CI credentials for participants:"
echo "AWS_ACCESS_KEY_ID=${CI_ACCESS_KEY_ID}"
echo "AWS_SECRET_ACCESS_KEY=${CI_SECRET_ACCESS_KEY}"
