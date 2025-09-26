#!/bin/bash
set -euo pipefail

# P1 Dev Guard - IAM Role Testing Script
# Tests various AWS credential sources for Bedrock access

# Colors
red() { echo -e "\033[31m$*\033[0m"; }
green() { echo -e "\033[32m$*\033[0m"; }
yellow() { echo -e "\033[33m$*\033[0m"; }
blue() { echo -e "\033[34m$*\033[0m"; }
bold() { echo -e "\033[1m$*\033[0m"; }

bold "🔐 P1 Dev Guard - AWS Credentials & IAM Role Test"
echo "=================================================="

# Test 1: Check for AWS CLI
echo ""
blue "1. Checking AWS CLI availability..."
if command -v aws >/dev/null 2>&1; then
    green "✅ AWS CLI found: $(aws --version)"
else
    yellow "⚠️  AWS CLI not found (optional)"
fi

# Test 2: Check current identity
echo ""
blue "2. Checking AWS credentials and identity..."
if aws sts get-caller-identity 2>/dev/null; then
    green "✅ AWS credentials are working"

    # Get detailed information
    ACCOUNT=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
    ARN=$(aws sts get-caller-identity --query Arn --output text 2>/dev/null)
    USER_ID=$(aws sts get-caller-identity --query UserId --output text 2>/dev/null)

    echo "Account: ${ACCOUNT}"
    echo "ARN: ${ARN}"
    echo "User ID: ${USER_ID}"

    # Detect credential source
    if echo "${ARN}" | grep -q "assumed-role"; then
        if echo "${ARN}" | grep -qi "ec2"; then
            green "🎯 Detected: EC2 Instance Role"
        elif echo "${ARN}" | grep -qi "eks"; then
            green "🎯 Detected: EKS Service Account (IRSA)"
        elif echo "${ARN}" | grep -qi "ecs"; then
            green "🎯 Detected: ECS Task Role"
        else
            ROLE_NAME=$(echo "${ARN}" | cut -d'/' -f2)
            green "🎯 Detected: IAM Role - ${ROLE_NAME}"
        fi
    elif echo "${ARN}" | grep -q "user"; then
        green "🎯 Detected: IAM User"
    else
        yellow "🤔 Detected: Unknown credential type"
    fi
else
    red "❌ AWS credentials not found or not working"
    echo ""
    echo "Available credential sources:"
    echo "1. EC2 Instance Role (automatic)"
    echo "2. EKS Service Account (IRSA)"
    echo "3. ECS Task Role"
    echo "4. Environment variables (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)"
    echo "5. AWS Profile (~/.aws/credentials)"
    echo "6. IAM roles for cross-account access"
    exit 1
fi

# Test 3: Check Bedrock permissions
echo ""
blue "3. Testing Bedrock access permissions..."

REGION="${AWS_REGION:-us-east-1}"
echo "Using region: ${REGION}"

# Test bedrock:ListFoundationModels (read-only, good for testing)
if aws bedrock list-foundation-models --region "${REGION}" >/dev/null 2>&1; then
    green "✅ Bedrock read access confirmed"

    # Check specific models
    MODELS=$(aws bedrock list-foundation-models --region "${REGION}" --query 'modelSummaries[?contains(modelId, `anthropic`) || contains(modelId, `titan`)].modelId' --output table)
    echo ""
    echo "Available models:"
    echo "${MODELS}"

else
    red "❌ Bedrock access denied"
    echo ""
    echo "Required IAM permissions:"
    echo "  - bedrock:ListFoundationModels"
    echo "  - bedrock:InvokeModel"
    echo ""
    echo "Example IAM policy:"
    cat << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "bedrock:ListFoundationModels",
        "bedrock:InvokeModel"
      ],
      "Resource": [
        "*",
        "arn:aws:bedrock:*::foundation-model/*"
      ]
    }
  ]
}
EOF
    exit 1
fi

# Test 4: Test actual Bedrock invocation
echo ""
blue "4. Testing Bedrock model invocation..."

# Try Claude 3 Haiku (cheapest option)
MODEL_ID="anthropic.claude-3-haiku-20240307-v1:0"

# Create a minimal test payload
TEST_PAYLOAD=$(cat << 'EOF'
{
    "messages": [
        {
            "role": "user",
            "content": "Hello, respond with just 'AI test successful'"
        }
    ],
    "max_tokens": 20,
    "anthropic_version": "bedrock-2023-05-31"
}
EOF
)

if aws bedrock-runtime invoke-model \
    --region "${REGION}" \
    --model-id "${MODEL_ID}" \
    --body "${TEST_PAYLOAD}" \
    --cli-binary-format raw-in-base64-out \
    /tmp/bedrock-test-response.json >/dev/null 2>&1; then

    green "✅ Bedrock model invocation successful"

    # Extract response
    if command -v jq >/dev/null 2>&1; then
        RESPONSE=$(jq -r '.content[0].text' /tmp/bedrock-test-response.json 2>/dev/null || echo "Response parsing failed")
        echo "AI Response: ${RESPONSE}"
    fi

    rm -f /tmp/bedrock-test-response.json
else
    red "❌ Bedrock model invocation failed"
    echo ""
    echo "This could be due to:"
    echo "  1. Model not enabled in Bedrock console"
    echo "  2. Insufficient permissions"
    echo "  3. Region not supported"
    echo ""
    echo "Enable models at: https://console.aws.amazon.com/bedrock/home?region=${REGION}#/modelaccess"
    exit 1
fi

# Test 5: Test P1 Dev Guard Python integration
echo ""
blue "5. Testing P1 Dev Guard Python integration..."

if python3 -c "
import boto3
import json
import sys

try:
    # Test the same way P1 Dev Guard does
    session = boto3.Session()
    client = session.client('bedrock-runtime', region_name='${REGION}')

    # Minimal test
    body = json.dumps({
        'messages': [{'role': 'user', 'content': 'test'}],
        'max_tokens': 10,
        'anthropic_version': 'bedrock-2023-05-31'
    })

    response = client.invoke_model(
        modelId='${MODEL_ID}',
        body=body,
        contentType='application/json'
    )

    print('✅ P1 Dev Guard Python integration test passed')
except Exception as e:
    print(f'❌ Python integration test failed: {e}')
    sys.exit(1)
"; then
    green "✅ P1 Dev Guard Python integration working"
else
    red "❌ P1 Dev Guard Python integration failed"
    exit 1
fi

# Test 6: Container environment simulation
echo ""
blue "6. Testing container environment compatibility..."

# Check if running in container-like environment
if [ -f /.dockerenv ]; then
    green "🐳 Running inside container"
elif grep -q docker /proc/1/cgroup 2>/dev/null; then
    green "🐳 Running inside container"
else
    yellow "💻 Running on host (not container)"
fi

# Check metadata service access (for EC2 role testing)
if curl -s --connect-timeout 2 http://169.254.169.254/latest/meta-data/iam/security-credentials/ >/dev/null 2>&1; then
    green "✅ EC2 metadata service accessible"
    ROLE_NAME=$(curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/)
    if [[ -n "${ROLE_NAME}" ]]; then
        echo "Instance role: ${ROLE_NAME}"
    fi
else
    yellow "⚠️  EC2 metadata service not accessible (normal if not on EC2)"
fi

# Summary
echo ""
bold "🎉 Credential Test Summary"
echo "========================="
green "✅ AWS credentials working"
green "✅ Bedrock permissions confirmed"
green "✅ Model invocation successful"
green "✅ P1 Dev Guard integration ready"

echo ""
bold "💡 Usage Examples:"
echo ""
echo "# For EC2 with IAM role (your use case):"
echo "docker run --rm -v \$(pwd):/workspace p1guard"
echo ""
echo "# For EKS with IRSA:"
echo "kubectl run p1guard --image=p1guard --serviceaccount=p1-service-account"
echo ""
echo "# For ECS with task role:"
echo "# Configure task definition with appropriate IAM role"
echo ""

if [[ "${ARN}" =~ "assumed-role" ]]; then
    green "🎯 Your current setup (IAM role) is optimal for containerized workloads!"
fi