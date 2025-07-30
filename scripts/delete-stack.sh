#!/bin/bash

# Usage: ./delete-stack.sh <number_of_users>
# Example: Deletes base infrastructure and participant resources for the specified number of users

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

# Specify AWS local CLI profile and region, in case you "~/.aws/config" does not explicitly specify region.
PROFILE=""
REGION="ap-northeast-1"
# Specify the team identifier
TEAM_ID="team01"

# Loop through the attendee names to delete participant resources
for ((i = 0; i < USER_COUNT; i++)); do
  USER_ID="${ATTENDEE_NAME[$i]}"
  STACK_NAME="codesec-lab-${USER_ID}"

  ##
  REPO_NAME="vuln-app-${USER_ID}"

  echo "Cleaning up images in ECR repository: ${REPO_NAME}"

  # 1. Delete images in ECR（ECR repo is NOT deleted）. You can't delete ECR repo unless it is empty.
  IMAGE_IDS=$(aws ecr list-images \
    --repository-name "${REPO_NAME}" \
    --profile "${PROFILE}" \
    --region "${REGION}" \
    --query 'imageIds' \
    --output json)

  if [[ "$IMAGE_IDS" != "[]" ]]; then
    aws ecr batch-delete-image \
      --repository-name "${REPO_NAME}" \
      --image-ids "$IMAGE_IDS" \
      --profile "${PROFILE}" \
      --region "${REGION}" \
      || echo "Failed to delete images from ${REPO_NAME}"
  else
    echo "No images found in ${REPO_NAME}, skipping image deletion."
  fi
  ##

  echo "Deleting participant CloudFormation stack: ${STACK_NAME}"

  aws cloudformation delete-stack \
    --stack-name "${STACK_NAME}" \
    --profile "${PROFILE}"

  echo "Waiting for stack ${STACK_NAME} to be deleted..."
  aws cloudformation wait stack-delete-complete \
    --stack-name "${STACK_NAME}" \
    --profile "${PROFILE}"

  echo "Stack ${STACK_NAME} has been deleted."
  echo "----------------------------------------"
done

# Delete base infrastructure last
BASE_STACK_NAME="base-vpc-${TEAM_ID}"
echo "Deleting base infrastructure stack: ${BASE_STACK_NAME}"

aws cloudformation delete-stack \
  --stack-name "${BASE_STACK_NAME}" \
  --profile "${PROFILE}"

echo "Waiting for base infrastructure stack to be deleted..."
aws cloudformation wait stack-delete-complete \
  --stack-name "${BASE_STACK_NAME}" \
  --profile "${PROFILE}"

echo "Base infrastructure stack ${BASE_STACK_NAME} has been deleted."
echo "All resources have been cleaned up successfully."
