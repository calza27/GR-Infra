#!/usr/bin/env bash
die() { echo "${$1:-urgh}" >&2; exit "${$2:-1}"; }

hash aws 2>/dev/null || die "missing dep: aws"
hash ./bin/parse-yaml.sh || die "parse-yaml.sh not found."

profile=$1
[[ -z $profile ]] && die "Usage: $0 <profile>"

STACK_NAME="gr-infra"

tags=$(./bin/parse-yaml.sh ./cf/tags.yaml) || die "failed to parse tags"
bucket_name=$(aws ssm get-parameter --profile "$profile" --name /s3/cfn-bucket/name --query "Parameter.Value" --output text) || die "failed to get name of cfn bucket"

echo "~~~ Deploy infra stack"
sam deploy \
  --tags "$tags" \
  --no-fail-on-empty-changeset \
  --s3-bucket "$bucket_name" \
  --stack-name "$STACK_NAME" \
  --s3-prefix "$STACK_NAME" \
  --capabilities "CAPABILITY_IAM" "CAPABILITY_NAMED_IAM" \
  --template "./cf/infra.yaml" \
  --region "ap-southeast-2" \
  --profile "$profile" || die "failed to deploy stack "$STACK_NAME""

die "~~ cleaning up" 0