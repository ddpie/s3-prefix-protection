#!/bin/bash

# S3 Object Protection System Deployment Script
# Usage: ./deploy.sh <stack-name> <bucket-name> <protected-prefixes> <region> [lifecycle-days]
# Example: ./deploy.sh my-protection-system my-bucket "important/,backup/,archive/" ap-southeast-1 60

set -e

# Check parameters
if [ $# -lt 4 ]; then
    echo "Usage: $0 <stack-name> <bucket-name> <protected-prefixes> <region> [lifecycle-days]"
    echo "Example: $0 my-protection-system my-bucket 'important/,backup/,archive/' ap-southeast-1 60"
    exit 1
fi

STACK_NAME=$1
BUCKET_NAME=$2
PROTECTED_PREFIXES=$3
REGION=$4
LIFECYCLE_DAYS=${5:-60}

echo "=== S3 Object Protection System Deployment ==="
echo "Stack Name: $STACK_NAME"
echo "S3 Bucket: $BUCKET_NAME"
echo "Protected Prefixes: $PROTECTED_PREFIXES"
echo "Region: $REGION"
echo "Reference Days: $LIFECYCLE_DAYS"
echo ""

# Check AWS CLI configuration
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "Error: AWS CLI not configured or invalid credentials"
    exit 1
fi

# Check S3 bucket existence
echo "Checking S3 bucket..."
if ! aws s3api head-bucket --bucket $BUCKET_NAME --region $REGION > /dev/null 2>&1; then
    echo "Error: S3 bucket '$BUCKET_NAME' does not exist or no access permission"
    echo "Tip: Please create the bucket first or check permissions"
    exit 1
fi
echo "Bucket found: $BUCKET_NAME"

# Check bucket versioning status
echo "Checking bucket versioning..."
VERSIONING_STATUS=$(aws s3api get-bucket-versioning --bucket $BUCKET_NAME --region $REGION --query 'Status' --output text 2>/dev/null || echo "None")

if [ "$VERSIONING_STATUS" != "Enabled" ]; then
    echo "Warning: Bucket versioning not enabled (current: $VERSIONING_STATUS)"
    echo "Object Lock requires versioning to be enabled"
    read -p "Enable versioning automatically? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Enabling versioning..."
        aws s3api put-bucket-versioning --bucket $BUCKET_NAME --versioning-configuration Status=Enabled --region $REGION
        echo "Versioning enabled"
    else
        echo "Error: Versioning must be enabled to use Object Lock"
        exit 1
    fi
else
    echo "Versioning is enabled"
fi

# Check Object Lock status
echo "Checking Object Lock status..."
OBJECT_LOCK_STATUS=$(aws s3api get-object-lock-configuration --bucket $BUCKET_NAME --region $REGION --query 'ObjectLockConfiguration.ObjectLockEnabled' --output text 2>/dev/null || echo "None")

if [ "$OBJECT_LOCK_STATUS" != "Enabled" ]; then
    echo "Warning: Object Lock not enabled (current: $OBJECT_LOCK_STATUS)"
    read -p "Enable Object Lock automatically? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Enabling Object Lock..."
        aws s3api put-object-lock-configuration --bucket $BUCKET_NAME --object-lock-configuration='{"ObjectLockEnabled": "Enabled"}' --region $REGION
        echo "Object Lock enabled"
    else
        echo "Error: Object Lock must be enabled to apply Legal Hold protection"
        exit 1
    fi
else
    echo "Object Lock is enabled"
fi

# Validate CloudFormation template
echo ""
echo "Validating CloudFormation template..."
aws cloudformation validate-template \
    --template-body file://cloudformation-template.yaml \
    --region $REGION

if [ $? -ne 0 ]; then
    echo "Error: CloudFormation template validation failed"
    exit 1
fi

echo "Template validation successful"

# Deploy CloudFormation stack
echo ""
echo "Deploying protection system..."
aws cloudformation deploy \
    --template-file cloudformation-template.yaml \
    --stack-name $STACK_NAME \
    --parameter-overrides \
        BucketName="$BUCKET_NAME" \
        ProtectedPrefixes="$PROTECTED_PREFIXES" \
        LifecycleDays=$LIFECYCLE_DAYS \
    --capabilities CAPABILITY_NAMED_IAM \
    --region $REGION

if [ $? -eq 0 ]; then
    echo ""
    echo "Deployment successful!"
    
    # Get stack outputs
    echo ""
    echo "Stack outputs:"
    aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --region $REGION \
        --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
        --output table
    
    echo ""
    echo "Testing suggestions:"
    echo "1. Upload test file to protected prefix:"
    echo "   echo 'Test file' > test.txt"
    echo "   aws s3 cp test.txt s3://$BUCKET_NAME/$(echo $PROTECTED_PREFIXES | cut -d',' -f1)test.txt --region $REGION"
    echo ""
    echo "2. Check Legal Hold status:"
    echo "   aws s3api get-object-legal-hold --bucket $BUCKET_NAME --key $(echo $PROTECTED_PREFIXES | cut -d',' -f1)test.txt --region $REGION"
    echo ""
    echo "3. View processing logs:"
    echo "   aws logs tail /aws/lambda/$BUCKET_NAME-object-processor --follow --region $REGION"
    echo ""
    echo "4. Monitor failed messages:"
    DLQ_URL=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION --query 'Stacks[0].Outputs[?OutputKey==`DeadLetterQueueUrl`].OutputValue' --output text)
    echo "   aws sqs receive-message --queue-url $DLQ_URL --region $REGION"
    
    echo ""
    echo "System features:"
    echo "- Automatic S3 bucket validation"
    echo "- Versioning and Object Lock setup"
    echo "- Automated S3 event notifications"
    echo "- Lambda retry mechanism with exponential backoff"
    echo "- CloudWatch monitoring and alerts"
    echo "- Comprehensive error handling"
    
else
    echo "Deployment failed"
    exit 1
fi
