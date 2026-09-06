# AWS Secrets Manager & KMS Integration Guide

## Overview

This guide integrates **AWS Secrets Manager** and **AWS KMS** for secure credential storage in your Azure DevOps CI/CD security pipeline.

### What's Included
- **AWS Secrets Manager**: Centralized secret storage (API keys, tokens)
- **AWS KMS**: Encryption keys for sensitive data protection
- **IAM**: Fine-grained access control policies
- **Azure DevOps**: Automated secret retrieval in pipeline

---

## ⚡ Quick Start (Automated Setup)

### 1. Run Setup Script

```bash
chmod +x setup-secrets.sh
./setup-secrets.sh
```

The script automatically:
- ✓ Creates KMS encryption key
- ✓ Stores SonarQube token in Secrets Manager
- ✓ Stores Dependency-Track API key
- ✓ Stores SonarQube URL
- ✓ Stores Dependency-Track URL
- ✓ Creates IAM user with restricted permissions
- ✓ Generates access keys

### 2. Add to Azure DevOps Variable Group

**Pipelines → Library → Variable groups → +New**

Create variable group: `SecurityAuditVariables`

| Variable | Value | Secret |
|----------|-------|--------|
| AWS_ACCESS_KEY_ID | AKIA... | No |
| AWS_SECRET_ACCESS_KEY | wJal... | ✓ Yes |
| AWS_DEFAULT_REGION | us-east-1 | No |
| SonarQubeUrl | https://... | No |
| DependencyTrackUrl | https://... | No |

### 3. Link Variable Group to Pipeline

In your `azure-pipelines.yml`:

```yaml
variables:
  - group: SecurityAuditVariables
```

---

## 🔧 Manual Setup (If Script Doesn't Work)

### Step 1: Create KMS Key

```bash
# Create KMS key
KMS_KEY=$(aws kms create-key \
  --description "KMS key for CI/CD security" \
  --region us-east-1 \
  --query 'KeyMetadata.KeyId' \
  --output text)

echo $KMS_KEY  # Save this ID

# Create alias for easy reference
aws kms create-alias \
  --alias-name alias/cicd-security-pipeline \
  --target-key-id $KMS_KEY
```

### Step 2: Store Secrets

**SonarQube Token**
```bash
aws secretsmanager create-secret \
  --name security-audit-sonarqube-token \
  --secret-string "squ_1234567890abcdefghij..." \
  --kms-key-id $KMS_KEY
```

**Dependency-Track API Key**
```bash
aws secretsmanager create-secret \
  --name security-audit-dependencytrack-api-key \
  --secret-string "odc_1234567890abcdefghij..." \
  --kms-key-id $KMS_KEY
```

**SonarQube URL**
```bash
aws secretsmanager create-secret \
  --name security-audit-sonarqube-url \
  --secret-string "https://sonarqube.example.com" \
  --kms-key-id $KMS_KEY
```

**Dependency-Track URL**
```bash
aws secretsmanager create-secret \
  --name security-audit-dependencytrack-url \
  --secret-string "https://dependencytrack.example.com" \
  --kms-key-id $KMS_KEY
```

### Step 3: Create IAM User

```bash
# Create user
aws iam create-user --user-name azuredevops-cicd-audit

# Create access key
aws iam create-access-key \
  --user-name azuredevops-cicd-audit

# Save: AccessKeyId and SecretAccessKey
```

### Step 4: Attach IAM Policy

```bash
cat > /tmp/policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": "arn:aws:secretsmanager:*:*:secret:security-audit-*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "kms:Decrypt",
        "kms:DescribeKey"
      ],
      "Resource": "*"
    }
  ]
}
EOF

aws iam put-user-policy \
  --user-name azuredevops-cicd-audit \
  --policy-name CI-CD-SecurityAuditPolicy \
  --policy-document file:///tmp/policy.json
```

---

## 🔄 Pipeline Secret Flow

```
Azure DevOps Pipeline Starts
        ↓
Retrieves AWS credentials from Variable Group
        ↓
Calls AWS Secrets Manager API
        ↓
KMS automatically decrypts secrets
        ↓
Secrets injected into pipeline environment
        ↓
SonarQube, Dependency-Track, and other tools use secrets
        ↓
Secrets never stored in logs or artifacts
```

---

## ✅ Verify Setup

### Check Secrets Manager

```bash
# List all secrets
aws secretsmanager list-secrets \
  --filters Key=name,Values=security-audit \
  --region us-east-1
```

### Test Secret Retrieval

```bash
# Retrieve SonarQube token
aws secretsmanager get-secret-value \
  --secret-id security-audit-sonarqube-token \
  --query SecretString \
  --output text
```

### Check KMS Key

```bash
# Describe KMS key
aws kms describe-key \
  --key-id alias/cicd-security-pipeline \
  --region us-east-1
```

### Verify IAM User Permissions

```bash
# Check user policy
aws iam get-user-policy \
  --user-name azuredevops-cicd-audit \
  --policy-name CI-CD-SecurityAuditPolicy
```

---

## 🔐 Security Best Practices

✓ **Never commit credentials** - All stored in AWS Secrets Manager  
✓ **KMS encryption** - Secrets encrypted at rest and in transit  
✓ **Least privilege IAM** - User only access needed secrets  
✓ **Audit logging** - CloudTrail tracks all secret access  
✓ **Secret rotation** - Update secrets every 90 days  
✓ **Pipeline sanitization** - No secrets in logs/artifacts  
✓ **Access control** - Restrict IAM user to pipeline only  

---

## 🐛 Troubleshooting

### Error: "AccessDenied: User not authorized"

```bash
# Check IAM policy
aws iam get-user-policy \
  --user-name azuredevops-cicd-audit \
  --policy-name CI-CD-SecurityAuditPolicy

# Verify policy is attached
aws iam list-user-policies --user-name azuredevops-cicd-audit
```

### Error: "KMS DecryptionFailed"

```bash
# Verify KMS key permissions
aws kms describe-key \
  --key-id alias/cicd-security-pipeline \
  --region us-east-1

# Check key policy
aws kms get-key-policy \
  --key-id alias/cicd-security-pipeline \
  --policy-name default
```

### Error: "Secret not found"

```bash
# List all secrets
aws secretsmanager list-secrets --region us-east-1 | jq '.SecretList[].Name'

# Verify secret name matches pipeline expectations
# Should be: security-audit-*
```

---

## 💰 Cost Estimation

| Service | Cost |
|---------|------|
| KMS (1 key) | $1.00/month |
| Secrets Manager (4 secrets) | $1.60/month |
| API calls (1000/month) | $0.05/month |
| **Total** | **~$2.65/month** |

---

## 🧹 Cleanup

To remove all resources:

```bash
# Delete secrets (7-day recovery window)
aws secretsmanager delete-secret \
  --secret-id security-audit-sonarqube-token \
  --force-delete-without-recovery

aws secretsmanager delete-secret \
  --secret-id security-audit-dependencytrack-api-key \
  --force-delete-without-recovery

# Delete IAM user policy
aws iam delete-user-policy \
  --user-name azuredevops-cicd-audit \
  --policy-name CI-CD-SecurityAuditPolicy

# Delete access key
aws iam delete-access-key \
  --user-name azuredevops-cicd-audit \
  --access-key-id AKIA...

# Delete IAM user
aws iam delete-user --user-name azuredevops-cicd-audit

# Schedule KMS key deletion (7-30 day window)
aws kms schedule-key-deletion \
  --key-id alias/cicd-security-pipeline \
  --pending-window-in-days 7
```

---

## 📚 References

- [AWS Secrets Manager Documentation](https://docs.aws.amazon.com/secretsmanager/)
- [AWS KMS Documentation](https://docs.aws.amazon.com/kms/)
- [Azure DevOps Variable Groups](https://docs.microsoft.com/en-us/azure/devops/pipelines/library/variable-groups)
- [IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [SonarQube Authentication](https://docs.sonarqube.org/latest/instance-administration/authentication/)
- [Dependency-Track API Documentation](https://docs.dependencytrack.org/)

---

## 📧 Support

For issues or questions:
1. Check AWS CloudTrail logs for access issues
2. Review Secrets Manager audit trail
3. Verify IAM policy syntax
4. Test AWS CLI access manually
