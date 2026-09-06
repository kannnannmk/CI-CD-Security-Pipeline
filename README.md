# CI/CD Security Pipeline

Complete Azure DevOps CI/CD security pipeline with automated scanning, security gates, and AWS credential management.

## Features

✅ **Secret Scanning** (GitLeaks)  
✅ **SAST Analysis** (SonarQube)  
✅ **Dependency Scanning** (OWASP Dependency-Check)  
✅ **SBOM Generation** (CycloneDX)  
✅ **Dependency Tracking** (Dependency-Track)  
✅ **IaC Scanning** (Checkov - Terraform & CloudFormation)  
✅ **Security Gates** (Automated approval/rejection)  
✅ **AWS Secrets Manager** (Secure credential storage)  
✅ **AWS KMS** (Encryption at rest)  

---

## Quick Start

### 1. Setup AWS Secrets & KMS (2 minutes)

```bash
chmod +x setup-secrets.sh
./setup-secrets.sh
```

### 2. Create Azure DevOps Variable Group

**Pipelines → Library → Variable groups → +New**

Create: `SecurityAuditVariables`

Add these variables (mark secrets with 🔒):
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY` 🔒
- `AWS_DEFAULT_REGION` = `us-east-1`
- `SonarQubeUrl`
- `DependencyTrackUrl`

### 3. Add Pipeline to Your Repo

Copy `azure-pipelines-kms-secrets.yml` to your repository root as `azure-pipelines.yml`

### 4. Link Variable Group

Add to pipeline YAML:
```yaml
variables:
  - group: SecurityAuditVariables
```

### 5. Create Service Connection (Optional)

If using SonarQube task:
- **Project Settings → Service connections → SonarQube**
- Name: `SonarQubeConnection`
- Add URL and token

---

## Pipeline Stages

### Stage 1: 🔐 Retrieve Secrets
- Fetches SonarQube token from AWS Secrets Manager
- Fetches Dependency-Track API key
- Decrypts with KMS
- Injects into pipeline environment

### Stage 2: 🔑 Decrypt KMS Secrets
- Decrypts additional encrypted secrets
- Validates key access

### Stage 3: 🔒 Secret Scanning (GitLeaks)
- Scans repository for hardcoded secrets
- Detects API keys, tokens, credentials
- **Security Gate**: Fails if secrets found

### Stage 4: 🔍 SAST Analysis (SonarQube)
- Code quality analysis
- Security vulnerability detection
- Supports: Java, JavaScript, Python, C#, etc.
- **Security Gate**: Quality gate must pass

### Stage 5: 📦 Dependency Analysis & SBOM
- Generates CycloneDX SBOM
- Runs OWASP Dependency-Check
- Uploads to Dependency-Track
- **Security Gate**: No critical vulnerabilities allowed

### Stage 6: 🏗️ IaC Scanning (Checkov)
- Scans Terraform files
- Scans CloudFormation templates
- Validates security compliance
- **Security Gate**: Max 10 compliance failures

### Stage 7: ✅ Security Audit Complete
- Final approval gate
- Generates summary report
- All gates must pass

---

## Security Gates Summary

| Gate | Condition | Action |
|------|-----------|--------|
| 🔐 GitLeaks | Secrets found > 0 | ❌ FAIL |
| 🔍 SonarQube | Quality Gate ≠ OK | ❌ FAIL |
| 📦 Dependencies | CRITICAL > 0 | ❌ FAIL |
| 🏗️ IaC | Failed checks > 10 | ❌ FAIL |

---

## File Structure

```
.
├── azure-pipelines-kms-secrets.yml    # Main pipeline YAML
├── setup-secrets.sh                    # Automated setup script
├── AWS-SECRETS-KMS-SETUP.md           # Complete setup guide
└── README.md                           # This file
```

---

## Usage Examples

### Run Locally

```bash
# Setup AWS secrets
./setup-secrets.sh

# Run GitLeaks locally
gitleaks detect --source . --report-format json

# Run SonarQube locally
sonar-scanner \
  -Dsonar.projectKey=my-project \
  -Dsonar.sources=. \
  -Dsonar.host.url=https://sonarqube.com \
  -Dsonar.login=$SONAR_TOKEN

# Run Checkov on Terraform
checkov -d terraform/ --framework terraform
```

### Trigger Pipeline

1. Push to main/develop branch
2. Or create pull request
3. Azure DevOps automatically triggers pipeline
4. View results in pipeline run

---

## View Reports

### GitLeaks Report
- **Location**: Build Artifacts → `gitleaks-report`
- **File**: `gitleaks-report.json`

### SonarQube Results
- **Location**: Direct link in pipeline output
- **Dashboard**: https://your-sonarqube.com

### Dependency Report
- **Location**: Build Artifacts → `dependency-reports`
- **Files**: `sbom.json`, `dependency-check-report.json`
- **Dashboard**: https://your-dependencytrack.com

### IaC Scan Report
- **Location**: Build Artifacts → `iac-reports`
- **Files**: `checkov-terraform.json`, `checkov-cloudformation.json`

---

## Configuration

### SonarQube

Modify in pipeline YAML:
```yaml
extraProperties: |
  sonar.host.url=$(SonarQubeUrl)
  sonar.login=$(SONAR_TOKEN)
  sonar.exclusions=**/target/**,**/node_modules/**
  sonar.coverage.exclusions=**/test/**
```

### Dependency-Check

Modify CVSS threshold:
```bash
# Current: Warns on CRITICAL, fails on CRITICAL
# Adjust thresholds in:
dependency-check/bin/dependency-check.sh
```

### Checkov

Exclude specific checks:
```yaml
checkov -d terraform/ \
  --framework terraform \
  --skip-check CKV_AWS_1,CKV_AWS_2
```

---

## Prerequisites

- ✓ Azure DevOps organization and project
- ✓ AWS account with IAM permissions
- ✓ SonarQube instance running
- ✓ Dependency-Track instance (optional)
- ✓ Git repository

---

## Troubleshooting

### SonarQube Connection Failed
```bash
curl -u $SONAR_TOKEN: "$SONAR_URL/api/system/status"
```

### Secrets Not Retrieved
```bash
aws secretsmanager list-secrets --region us-east-1
aws secretsmanager get-secret-value --secret-id security-audit-sonarqube-token
```

### Pipeline Fails on Security Gate
- Check artifact reports
- Review stage logs
- Fix vulnerabilities
- Re-run pipeline

---

## Cost Estimation

| Service | Monthly Cost |
|---------|---------------|
| AWS KMS | $1.00 |
| Secrets Manager | $1.60 |
| SonarQube | $0-100+ |
| Dependency-Track | $0 (open-source) |
| **Total** | **$3-100+** |

---

## Best Practices

✅ Rotate secrets every 90 days  
✅ Use least-privilege IAM policies  
✅ Enable CloudTrail for audit logging  
✅ Review and approve policy violations  
✅ Integrate with SIEM/logging systems  
✅ Monitor pipeline execution trends  
✅ Keep scanning tools updated  
✅ Document exceptions and approvals  

---

## Support & Resources

- [AWS Secrets Manager Docs](https://docs.aws.amazon.com/secretsmanager/)
- [Azure DevOps Docs](https://docs.microsoft.com/en-us/azure/devops/)
- [SonarQube Documentation](https://docs.sonarqube.org/)
- [OWASP Dependency-Check](https://owasp.org/www-project-dependency-check/)
- [Checkov](https://www.checkov.io/)
- [CycloneDX](https://cyclonedx.org/)

---

## License

MIT License - Feel free to use and modify for your organization.

---

**Created**: 2024  
**Last Updated**: 2024  
**Status**: Production Ready
