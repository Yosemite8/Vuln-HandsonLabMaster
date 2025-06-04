#!/bin/bash

# Usage: ./create-stacks-pokemon.sh 60
# Example: Creates stacks using the first 60 attendee names

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
TEMPLATE_FILE="../CloudFormation/fargate-lab.yml"
# Choose your local AWS CLI Profile where this script actually runs (optional)
PROFILE=""
# Specify the VPC ID, that was created by base-vpc.yml
VPC_ID="vpc-00000000000000000"
# Specify the subnet ID, that was created by base-vpc.yml
SUBNET_ID="subnet-00000000000000000"
# Specify the CIDR, range of source IP addresses that you need to allow for inbound access
CIDR=""

# Loop over attendee names
for ((i = 0; i < USER_COUNT; i++)); do
  USER_ID="${ATTENDEE_NAME[$i]}"
  STACK_NAME="codesec-emealab-${USER_ID}"

  echo "Creating CloudFormation stack: ${STACK_NAME}"

  aws cloudformation create-stack \
    --stack-name "${STACK_NAME}" \
    --profile "${PROFILE}" \
    --template-body file://${TEMPLATE_FILE} \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameters \
        ParameterKey=UserId,ParameterValue=${USER_ID} \
        ParameterKey=VpcId,ParameterValue=${VPC_ID} \
        ParameterKey=VpcSubnet,ParameterValue=${SUBNET_ID} \
        ParameterKey=AllowedIngressCidr,ParameterValue=${CIDR}
done
