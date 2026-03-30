#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <domain-name> <hosted-zone-id> [stack-name]"
  exit 1
fi

DOMAIN_NAME="$1"
HOSTED_ZONE_ID="$2"
STACK_NAME="${3:-dabbletube-site}"
AWS_REGION="${AWS_REGION:-us-east-1}"
CREATE_WWW_RECORD="${CREATE_WWW_RECORD:-true}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEMPLATE_PATH="${REPO_ROOT}/infra/site-stack.yaml"

get_stack_status() {
  aws cloudformation describe-stacks \
    --region "${AWS_REGION}" \
    --stack-name "${STACK_NAME}" \
    --query "Stacks[0].StackStatus" \
    --output text 2>/dev/null || true
}

wait_for_stack_if_busy() {
  local stack_status
  stack_status="$(get_stack_status)"

  case "${stack_status}" in
    CREATE_IN_PROGRESS)
      echo "Stack ${STACK_NAME} is still being created. Waiting for CREATE_COMPLETE..."
      aws cloudformation wait stack-create-complete \
        --region "${AWS_REGION}" \
        --stack-name "${STACK_NAME}"
      ;;
    UPDATE_IN_PROGRESS|UPDATE_COMPLETE_CLEANUP_IN_PROGRESS|UPDATE_ROLLBACK_IN_PROGRESS|UPDATE_ROLLBACK_COMPLETE_CLEANUP_IN_PROGRESS|REVIEW_IN_PROGRESS|IMPORT_IN_PROGRESS|IMPORT_ROLLBACK_IN_PROGRESS)
      echo "Stack ${STACK_NAME} is busy (${stack_status}). Waiting for the in-progress operation to finish..."
      aws cloudformation wait stack-update-complete \
        --region "${AWS_REGION}" \
        --stack-name "${STACK_NAME}"
      ;;
    *)
      ;;
  esac
}

wait_for_stack_if_busy

echo "Deploying infrastructure stack ${STACK_NAME} in ${AWS_REGION}..."
aws cloudformation deploy \
  --region "${AWS_REGION}" \
  --stack-name "${STACK_NAME}" \
  --template-file "${TEMPLATE_PATH}" \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    DomainName="${DOMAIN_NAME}" \
    HostedZoneId="${HOSTED_ZONE_ID}" \
    CreateWwwRecord="${CREATE_WWW_RECORD}"

echo "Reading stack outputs..."
BUCKET_NAME="$(aws cloudformation describe-stacks \
  --region "${AWS_REGION}" \
  --stack-name "${STACK_NAME}" \
  --query "Stacks[0].Outputs[?OutputKey=='BucketName'].OutputValue" \
  --output text)"

DISTRIBUTION_ID="$(aws cloudformation describe-stacks \
  --region "${AWS_REGION}" \
  --stack-name "${STACK_NAME}" \
  --query "Stacks[0].Outputs[?OutputKey=='DistributionId'].OutputValue" \
  --output text)"

DISTRIBUTION_DOMAIN="$(aws cloudformation describe-stacks \
  --region "${AWS_REGION}" \
  --stack-name "${STACK_NAME}" \
  --query "Stacks[0].Outputs[?OutputKey=='DistributionDomainName'].OutputValue" \
  --output text)"

echo "Uploading site files to s3://${BUCKET_NAME}..."
aws s3 sync "${REPO_ROOT}" "s3://${BUCKET_NAME}" \
  --delete \
  --exclude ".git/*" \
  --exclude ".gitignore" \
  --exclude "infra/*" \
  --exclude "scripts/*" \
  --exclude "README.md"

echo "Setting cache headers..."
aws s3 cp "${REPO_ROOT}/index.html" "s3://${BUCKET_NAME}/index.html" \
  --metadata-directive REPLACE \
  --cache-control "public,max-age=60,s-maxage=60" \
  --content-type "text/html"

aws s3 cp "${REPO_ROOT}/styles.css" "s3://${BUCKET_NAME}/styles.css" \
  --metadata-directive REPLACE \
  --cache-control "public,max-age=31536000,immutable" \
  --content-type "text/css"

echo "Creating CloudFront invalidation..."
aws cloudfront create-invalidation \
  --distribution-id "${DISTRIBUTION_ID}" \
  --paths "/*" >/dev/null

cat <<EOF
Deployment complete.

Domain: https://${DOMAIN_NAME}
CloudFront: https://${DISTRIBUTION_DOMAIN}
S3 bucket: ${BUCKET_NAME}
Distribution ID: ${DISTRIBUTION_ID}
EOF
