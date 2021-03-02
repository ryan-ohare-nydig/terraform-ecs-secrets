#!/bin/bash

rm ~/.aws/cli/process-creds-cache/*.json

aws --profile $1 ec2 describe-vpcs >/dev/null

export AWS_ACCESS_KEY=`cat ~/.aws/cli/process-creds-cache/*.json | jq -r .Credentials.AccessKeyId`
export AWS_SECRET_KEY=`cat ~/.aws/cli/process-creds-cache/*.json | jq -r .Credentials.SecretAccessKey`
export AWS_SESSION_TOKEN=`cat ~/.aws/cli/process-creds-cache/*.json | jq -r .Credentials.SessionToken`
