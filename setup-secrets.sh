#!/bin/bash
# AWS Secrets Manager & KMS Setup for Azure DevOps CI/CD Security Pipeline
# Usage: chmod +x setup-secrets.sh && ./setup-secrets.sh

set -e

echo "========================================"
echo "AWS Secrets & KMS Setup for CI/CD Pipeline"
echo "========================================"

AWS_REGION="us-east-1"
KMS_ALIAS="alias/cicd-security-pipeline"
SECRET_PREFIX="security-audit"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Step 1: Create KMS Encryption Key${NC}"
KMS_KEY_ID=$(aws kms create-key \
  --description "KMS key for CI/CD security pipeline" \
  --region $AWS_REGION \
  --query 'KeyMetadata.KeyId' \
  --output text)
echo -e "${GREEN}✓ KMS Key created: $KMS_KEY_ID${NC}"

aws kms create-alias \
  --alias-name $KMS_ALIAS \
  --target-key-id $KMS_KEY_ID \
  --region $AWS_REGION 2>/dev/null || echo "Alias may already exist"

echo -e "${YELLOW}Step 2: Store Secrets in AWS Secrets Manager${NC}"

echo "Enter SonarQube API Token (from: https://your-sonarqube.com/account/security/)"
read -s SONAR_TOKEN

aws secretsmanager create-secret \
  --name "${SECRET_PREFIX}-sonarqube-token" \
  --secret-string "$SONAR_TOKEN" \
  --kms-key-id $KMS_KEY_ID \
  --region $AWS_REGION \
  --tags Key=Purpose,Value=CI-CD-Security || echo "Secret may already exist"

echo -e "${GREEN}✓ SonarQube token stored${NC}"

echo "Enter Dependency-Track API Key (from: https://your-dependencytrack.com/admin/apikeys)"
read -s DEPTRACK_KEY

aws secretsmanager create-secret \
  --name "${SECRET_PREFIX}-dependencytrack-api-key" \
  --secret-string "$DEPTRACK_KEY" \
  --kms-key-id $KMS_KEY_ID \
  --region $AWS_REGION \
  --tags Key=Purpose,Value=CI-CD-Security || echo "Secret may already exist"

echo -e "${GREEN}✓ Dependency-Track API key stored${NC}"

echo "Enter SonarQube URL (e.g., https://sonarqube.example.com)"
read SONAR_URL

aws secretsmanager create-secret \
  --name "${SECRET_PREFIX}-sonarqube-url" \
  --secret-string "$SONAR_URL" \
  --kms-key-id $KMS_KEY_ID \
  --region $AWS_REGION || echo "Secret may already exist"

echo -e "${GREEN}✓ SonarQube URL stored${NC}"

echo "Enter Dependency-Track URL (e.g., https://dependencytrack.example.com)"
read DEPTRACK_URL

aws secretsmanager create-secret \
  --name "${SECRET_PREFIX}-dependencytrack-url" \
  --secret-string "$DEPTRACK_URL" \
  --kms-key-id $KMS_KEY_ID \
  --region $AWS_REGION || echo "Secret may already exist"

echo -e "${GREEN}✓ Dependency-Track URL stored${NC}"

echo -e "${YELLOW}Step 3: Create IAM Policy${NC}"

cat > /tmp/secrets-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadSecretsManager",
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": "arn:aws:secretsmanager:*:*:secret:security-audit-*"
    },
    {
      "Sid": "DecryptWithKMS",
      "Effect": "Allow",
      "Action": [
        "kms:Decrypt",
        "kms:DescribeKey",
        "kms:GenerateDataKey"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "kms:ViaService": "secretsmanager.us-east-1.amazonaws.com"
        }
      }
    }
  ]
}
EOF

echo -e "${YELLOW}Step 4: Create IAM User/Role${NC}"
echo "Enter IAM User name (e.g., azuredevops-cicd-audit)"
read IAM_USER

aws iam create-user --user-name $IAM_USER --region $AWS_REGION 2>/dev/null || echo "User may already exist"

aws iam put-user-policy \
  --user-name $IAM_USER \
  --policy-name CI-CD-SecurityAuditPolicy \
  --policy-document file:///tmp/secrets-policy.json

echo -e "${GREEN}✓ IAM policy attached${NC}"

echo -e "${YELLOW}Step 5: Create Access Key${NC}"
echo "Creating access key for $IAM_USER..."

ACCESS_KEY=$(aws iam create-access-key \
  --user-name $IAM_USER \
  --query 'AccessKey.[AccessKeyId,SecretAccessKey]' \
  --output text 2>/dev/null || echo "Access key may already exist")

if [ ! -z "$ACCESS_KEY" ]; then
  echo -e "${GREEN}✓ Access key created${NC}"
fi

echo ""
echo -e "${YELLOW}=== SETUP COMPLETE - SAVE THIS INFO ===${NC}"
echo ""
echo "1. Add to Azure DevOps Variable Group (Pipelines > Library > Variable Groups):"
echo "   Variable Group Name: SecurityAuditVariables"
echo ""
echo "   AWS_ACCESS_KEY_ID: $(echo $ACCESS_KEY | awk '{print $1}')"
echo "   AWS_SECRET_ACCESS_KEY: $(echo $ACCESS_KEY | awk '{print $2}') [MARK AS SECRET]"
echo "   AWS_DEFAULT_REGION: us-east-1"
echo "   SonarQubeUrl: $SONAR_URL"
echo "   DependencyTrackUrl: $DEPTRACK_URL"
echo ""
echo "2. Secrets stored in AWS Secrets Manager:"
echo "   - ${SECRET_PREFIX}-sonarqube-token"
echo "   - ${SECRET_PREFIX}-dependencytrack-api-key"
echo "   - ${SECRET_PREFIX}-sonarqube-url"
echo "   - ${SECRET_PREFIX}-dependencytrack-url"
echo ""
echo "3. KMS Encryption Key:"
echo "   - Key ID: $KMS_KEY_ID"
echo "   - Alias: $KMS_ALIAS"
echo ""
echo "4. IAM User:"
echo "   - Username: $IAM_USER"
echo "   - Policy: CI-CD-SecurityAuditPolicy"
echo ""
echo -e "${GREEN}✓ All setup complete!${NC}"
echo "Note: Save AWS Access Keys securely. They cannot be viewed again."
