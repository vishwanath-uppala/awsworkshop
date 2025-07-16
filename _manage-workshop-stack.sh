#!/bin/bash -x
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

main() {
    STACK_OPERATION=$1
    GIT_REPO=$2
    GIT_BRANCH=$3

    if [[ "$STACK_OPERATION" == "create" || "$STACK_OPERATION" == "update" ]]; then
        # Enable AWS IAM Identity Center Script

        echo "=== Enabling AWS IAM Identity Center ==="

        # Check if AWS CLI is configured
        if ! aws sts get-caller-identity &>/dev/null; then
            echo "Error: AWS CLI is not configured or you don't have proper permissions"
            echo "Please run 'aws configure' first"
            exit 1
        fi

        echo "✓ AWS CLI is configured"

        # Check if Identity Center is already enabled
        if aws sso-admin list-instances --query 'Instances[0].InstanceArn' --output text 2>/dev/null | grep -q "arn:aws:sso"; then
            echo "✓ IAM Identity Center is already enabled"
            INSTANCE_ARN=$(aws sso-admin list-instances --query 'Instances[0].InstanceArn' --output text)
            IDENTITY_STORE_ID=$(aws sso-admin list-instances --query 'Instances[0].IdentityStoreId' --output text)
            echo "Instance ARN: $INSTANCE_ARN"
            echo "Identity Store ID: $IDENTITY_STORE_ID"
        else
            echo "IAM Identity Center is not enabled. Attempting to enable it..."

            # Method 1: Try using Organizations API
            if aws organizations describe-organization &>/dev/null; then
                echo "AWS Organizations detected. Attempting to enable Identity Center..."
                
                if aws sso-admin create-instance --name "Default" 2>/dev/null; then
                    echo "✓ IAM Identity Center enabled successfully via Organizations"
                    sleep 10  # Wait for service to initialize
                else
                    echo "Failed to enable via Organizations API, trying alternative method..."
                fi
            fi

            # Wait for Identity Center to become available
            echo "Waiting for Identity Center to initialize..."
            for i in {1..12}; do
                if aws sso-admin list-instances --query 'Instances[0].InstanceArn' --output text 2>/dev/null | grep -q "arn:aws:sso"; then
                    echo "✓ IAM Identity Center is now enabled"
                    INSTANCE_ARN=$(aws sso-admin list-instances --query 'Instances[0].InstanceArn' --output text)
                    IDENTITY_STORE_ID=$(aws sso-admin list-instances --query 'Instances[0].IdentityStoreId' --output text)
                    echo "Instance ARN: $INSTANCE_ARN"
                    echo "Identity Store ID: $IDENTITY_STORE_ID"
                    break
                fi
                echo "Waiting... (attempt $i/12)"
                sleep 10
            done
            
            # Check if enablement failed
            if ! aws sso-admin list-instances --query 'Instances[0].InstanceArn' --output text 2>/dev/null | grep -q "arn:aws:sso"; then
                echo "❌ Automatic enablement failed."
                exit 1
            fi
        fi
        
    elif [ "$STACK_OPERATION" == "delete" ]; then
        echo "Done cdk destroy!"
    else
        echo "Invalid stack operation!"
        exit 1
    fi
}

STACK_OPERATION=$(echo "$1" | tr '[:upper:]' '[:lower:]')
GIT_REPO=$2
GIT_BRANCH=$3
main "$STACK_OPERATION" "$GIT_REPO" "$GIT_BRANCH"