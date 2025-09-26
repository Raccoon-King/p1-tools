# P1 Dev Guard - AI-Enhanced Compliance Analysis

P1 Dev Guard includes comprehensive AI-powered analysis using Amazon Bedrock with fully configurable models, providers, and analysis settings. The system provides intelligent insights and remediation suggestions while maintaining perfect functionality without AI.

## Key Features

### 🤖 Intelligent Analysis
- **Multiple LLM Models**: Support for Claude 3 (Haiku, Sonnet, Opus), GPT-4, and Amazon Titan
- **Configurable Providers**: Amazon Bedrock, OpenAI, Azure OpenAI, and extensible architecture
- **Rule-Based Fallback**: Works perfectly without AWS - provides smart analysis even when AI is unavailable
- **Priority Assessment**: Automatically categorizes issues by risk level (critical/high/medium/low)
- **Root Cause Analysis**: Identifies underlying patterns causing multiple compliance failures
- **Cost Optimization**: Intelligent model selection with cost estimation and tracking

### 🔧 Smart Remediation
- **Actionable Fixes**: Specific, step-by-step remediation instructions tailored to your environment
- **Code Examples**: Provides working YAML snippets, Helm values, and OPA policies
- **Effort Estimation**: Estimates time required to fix all issues with complexity assessment
- **Prevention Guidance**: Suggests practices to avoid future violations with architectural recommendations

### ⚙️ Comprehensive Configuration
- **Multi-Model Support**: Easy switching between Claude, GPT, and Titan models
- **Custom Parameters**: Configure temperature, max tokens, timeout, and retry behavior
- **Organization Defaults**: Set company-specific preferences and model availability
- **Environment Profiles**: Different configurations for dev, staging, and production
- **Cost Controls**: Budget limits, model selection based on cost, and usage tracking

### 🔄 Graceful Degradation
- **Zero Dependencies**: Functions fully without AWS credentials or internet access
- **Automatic Fallback**: Seamlessly switches to rule-based analysis when AI is unavailable
- **Consistent Experience**: Same interface whether using AI or rule-based analysis
- **IAM Role Support**: Native support for EC2, ECS, EKS, and cross-account roles

## Usage Examples

### Basic Usage (AI Enabled)

```bash
# With AWS credentials configured
docker run --rm \
  -v $(pwd):/workspace \
  -e AWS_PROFILE=default \
  registry.internal/p1/p1-dev-guard:2025.09.01
```

### Specific AI Model

```bash
# Use Claude 3 Sonnet for more detailed analysis
docker run --rm \
  -v $(pwd):/workspace \
  -e AWS_ACCESS_KEY_ID=your-key \
  -e AWS_SECRET_ACCESS_KEY=your-secret \
  -e AWS_REGION=us-east-1 \
  p1guard --ai-model claude-3-sonnet
```

### Skip AI Analysis (Faster)

```bash
# Basic compliance checks only
docker run --rm \
  -v $(pwd):/workspace \
  p1guard --skip-ai
```

### Air-Gapped Environment

```bash
# Works without AWS - uses rule-based analysis
docker run --rm \
  -v $(pwd):/workspace \
  p1guard
# Automatically falls back to intelligent rule-based analysis
```

## AI Analysis Output

### With Bedrock Available

```
🤖 AI Analysis Summary
======================
Mode: bedrock
Priority: high
Summary: Found 3 compliance issues: 1 security, 2 image violations requiring immediate attention

🔧 Remediation Recommendations:
  • dockerfile_hadolint: Replace 'FROM nginx:latest' with specific version like 'FROM registry.internal/ironbank/nginx:1.25.3@sha256:...'
  • opa_policies: Set runAsUser to non-zero value (e.g., 65534) and runAsNonRoot: true in securityContext
  • helm_template: Add resource requests and limits: resources.requests.cpu/memory, resources.limits.cpu/memory

Estimated effort: 30-45 minutes (moderate complexity fixes)
```

### Without Bedrock (Fallback)

```
🤖 AI Analysis Summary
======================
Mode: rule-based
Priority: high
Summary: Found 3 compliance issues: 1 security, 2 image

🔧 Remediation Recommendations:
  • dockerfile_hadolint: Replace ':latest' tag with specific version or digest (e.g., ':1.2.3' or '@sha256:...')
  • opa_policies: Set 'runAsUser' to a non-zero value (e.g., 65534) and 'runAsNonRoot: true'
  • helm_template: Add resource requests: resources.requests.cpu and resources.requests.memory

Estimated effort: 30-60 minutes (multiple simple fixes)
```

## Configuration

### AWS Setup

1. **Configure AWS Credentials** (multiple options):

   ```bash
   # Option 1: AWS Profile
   export AWS_PROFILE=your-profile

   # Option 2: Direct credentials
   export AWS_ACCESS_KEY_ID=your-key
   export AWS_SECRET_ACCESS_KEY=your-secret
   export AWS_REGION=us-east-1

   # Option 3: IAM Role (in EC2/ECS)
   # Credentials automatically available
   ```

2. **Required IAM Permissions**:

   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": [
           "bedrock:InvokeModel"
         ],
         "Resource": [
           "arn:aws:bedrock:*::foundation-model/anthropic.claude-3-haiku-20240307-v1:0",
           "arn:aws:bedrock:*::foundation-model/anthropic.claude-3-sonnet-20240229-v1:0",
           "arn:aws:bedrock:*::foundation-model/amazon.titan-text-express-v1"
         ]
       }
     ]
   }
   ```

3. **Enable Bedrock Models** in your AWS region:
   - Go to Amazon Bedrock console
   - Navigate to Model access
   - Enable Claude 3 Haiku, Claude 3 Sonnet, and/or Titan models

### CLI Options

```bash
--skip-ai              # Disable AI analysis entirely
--ai-model MODEL       # claude-3-sonnet|claude-3-haiku|titan (default: claude-3-haiku)
--ai-region REGION     # AWS region (default: us-east-1)
```

### Environment Variables

```bash
AWS_PROFILE           # AWS profile name
AWS_ACCESS_KEY_ID     # AWS access key
AWS_SECRET_ACCESS_KEY # AWS secret key
AWS_REGION           # AWS region for Bedrock
```

## Available AI Models

### Claude 3 Haiku (Default)
- **Best for**: Fast, cost-effective analysis
- **Strengths**: Quick responses, good for basic remediation
- **Use case**: CI/CD pipelines, frequent scans

### Claude 3 Sonnet
- **Best for**: Detailed analysis and complex scenarios
- **Strengths**: Comprehensive insights, better context understanding
- **Use case**: Complex compliance issues, detailed remediation planning

### Amazon Titan Text Express
- **Best for**: AWS-native option
- **Strengths**: Good performance, integrated with AWS ecosystem
- **Use case**: When you prefer AWS-native models

## Integration Examples

### GitLab CI with AI

```yaml
p1-compliance-ai:
  stage: compliance
  image: docker:latest
  services:
    - docker:dind
  before_script:
    - echo $AWS_ACCESS_KEY_ID # Verify credentials available
  script:
    - >
      docker run --rm
      -v ${CI_PROJECT_DIR}:/workspace
      -e AWS_ACCESS_KEY_ID
      -e AWS_SECRET_ACCESS_KEY
      -e AWS_REGION=us-east-1
      registry.internal/p1/p1-dev-guard:2025.09.01
      --ci --ai-model claude-3-haiku
  artifacts:
    when: always
    paths:
      - .p1-artifacts/
    reports:
      junit: .p1-artifacts/reports/*.xml
```

### GitHub Actions with AI

```yaml
- name: P1 Compliance with AI
  env:
    AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
    AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    AWS_REGION: us-east-1
  run: |
    docker run --rm \
      -v ${{ github.workspace }}:/workspace \
      -e AWS_ACCESS_KEY_ID \
      -e AWS_SECRET_ACCESS_KEY \
      -e AWS_REGION \
      registry.internal/p1/p1-dev-guard:2025.09.01 \
      --ci --ai-model claude-3-sonnet
```

### Kubernetes Job with AI

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: p1-compliance-ai
spec:
  template:
    spec:
      serviceAccountName: p1-compliance  # With IRSA for Bedrock access
      containers:
      - name: p1guard
        image: registry.internal/p1/p1-dev-guard:2025.09.01
        args: ["--ci", "--ai-model", "claude-3-haiku"]
        env:
        - name: AWS_REGION
          value: "us-east-1"
        volumeMounts:
        - name: source-code
          mountPath: /workspace
      volumes:
      - name: source-code
        persistentVolumeClaim:
          claimName: source-code-pvc
      restartPolicy: Never
```

## Cost Considerations

### Model Costs (Approximate)
- **Claude 3 Haiku**: ~$0.00025 per 1K input tokens, ~$0.00125 per 1K output tokens
- **Claude 3 Sonnet**: ~$0.003 per 1K input tokens, ~$0.015 per 1K output tokens
- **Titan Text Express**: ~$0.0008 per 1K input tokens, ~$0.0016 per 1K output tokens

### Typical Analysis Costs
- **Simple project** (few violations): $0.01-0.05 per scan
- **Complex project** (many violations): $0.10-0.25 per scan
- **Large monorepo**: $0.25-0.50 per scan

### Cost Optimization Tips
1. Use `--skip-ai` for basic compliance checks
2. Use Claude 3 Haiku for frequent CI/CD scans
3. Reserve Claude 3 Sonnet for complex issues or detailed analysis
4. Use rule-based fallback in development environments

## Troubleshooting

### "AI analysis unavailable"
- **Check AWS credentials**: `aws sts get-caller-identity`
- **Verify region**: Ensure Bedrock is available in your region
- **Check model access**: Enable models in Bedrock console
- **Network connectivity**: Ensure outbound HTTPS access to AWS

### "Bedrock not initialized"
- **IAM permissions**: Verify `bedrock:InvokeModel` permission
- **Model access**: Enable specific models in AWS console
- **Region mismatch**: Use `--ai-region` to specify correct region

### Poor AI recommendations
- **Try different model**: Use `--ai-model claude-3-sonnet` for better analysis
- **Check input quality**: Ensure manifests are valid YAML
- **Provide context**: Use descriptive names and labels in manifests

### High costs
- **Use Haiku model**: Fastest and most cost-effective
- **Skip AI in dev**: Use `--skip-ai` for development scans
- **Batch analysis**: Analyze multiple issues together rather than one-by-one

## Advanced Configuration

### AI Configuration File

Create `~/.p1devguard/ai-config.yaml` for persistent AI settings:

```yaml
# P1 Dev Guard AI Configuration
default_model: claude-3-haiku

models:
  claude-3-haiku:
    name: Claude 3 Haiku
    provider: bedrock
    model_id: anthropic.claude-3-haiku-20240307-v1:0
    max_tokens: 4000
    temperature: 0.1
    region: us-east-1
    cost_per_1k_input: 0.00025
    cost_per_1k_output: 0.00125
    capabilities: [analysis, remediation, code_generation]
    enabled: true

  claude-3-sonnet:
    name: Claude 3 Sonnet
    provider: bedrock
    model_id: anthropic.claude-3-sonnet-20240229-v1:0
    max_tokens: 4000
    temperature: 0.1
    cost_per_1k_input: 0.003
    cost_per_1k_output: 0.015
    capabilities: [analysis, remediation, code_generation, detailed_explanation]
    enabled: true

  gpt-4:
    name: GPT-4
    provider: openai
    model_id: gpt-4
    max_tokens: 4000
    temperature: 0.1
    api_key: ${OPENAI_API_KEY}
    cost_per_1k_input: 0.03
    cost_per_1k_output: 0.06
    capabilities: [analysis, remediation, code_generation]
    enabled: false  # Enable when API key available

analysis:
  enabled: true
  fallback_enabled: true
  max_retries: 3
  timeout_seconds: 30
  analysis_depth: standard  # basic, standard, detailed
  include_code_examples: true
  include_prevention_tips: true
  priority_threshold: medium
  max_issues_per_request: 10

custom_prompts:
  security_focus: |
    You are a cybersecurity expert specializing in Kubernetes and container security.
    Focus heavily on security implications and provide detailed security remediation.
```

### Comprehensive Configuration

P1 Dev Guard supports full configuration management with `~/.p1devguard/config.yaml`:

```yaml
# Complete P1 Dev Guard Configuration
version: "2025.09.01"
enabled: true

# AI Configuration (embedded)
ai:
  default_model: claude-3-haiku
  models:
    claude-3-haiku:
      name: Claude 3 Haiku
      provider: bedrock
      model_id: anthropic.claude-3-haiku-20240307-v1:0
      max_tokens: 4000
      temperature: 0.1
      enabled: true
  analysis:
    enabled: true
    analysis_depth: standard
    include_code_examples: true

# Vulnerability Scanning Configuration
scanning:
  enabled: true
  severity_levels: [HIGH, CRITICAL]
  timeout_seconds: 300
  ignore_unfixed: false
  cache_enabled: true

# OPA Policy Configuration
policies:
  enabled: true
  policy_dirs: [/policies, ./policies]
  strict_mode: false
  ignore_namespaces: [kube-system, kube-public]

# Helm Configuration
helm:
  enabled: true
  lint_strict: false
  template_validation: true
  schema_validation: true
  dependency_update: true

# Container Registry Settings
registry:
  ironbank_mirror: "${IRONBANK_MIRROR}"
  insecure_registries: []
  image_pull_timeout: 300

# Output Configuration
output:
  format: text  # text, json, xml
  artifacts_dir: .p1-artifacts
  detailed_reports: true
  include_suggestions: true
  cost_reporting: true
  ci_mode: false

# External Integrations
integrations:
  vscode_enabled: true
  gitlab_integration: false
  github_integration: false
  slack_webhook: null

# Environment-Specific Overrides
environment_overrides:
  development:
    scanning:
      severity_levels: [MEDIUM, HIGH, CRITICAL]
    ai:
      analysis:
        analysis_depth: basic
  production:
    scanning:
      severity_levels: [HIGH, CRITICAL]
    ai:
      analysis:
        analysis_depth: detailed
    policies:
      strict_mode: true

# Organization Defaults
organization_defaults:
  registry_mirror: registry.myorg.mil/ironbank
  default_namespace: myorg-apps
  security_contact: security@myorg.mil
```

### VS Code Integration

The AI features integrate seamlessly with VS Code through:

**Settings** (`.vscode/settings.json`):
```json
{
  "p1devguard.enabled": true,
  "p1devguard.autoAnalysis": true,
  "p1devguard.aiModel": "claude-3-haiku",
  "p1devguard.awsRegion": "us-east-1",
  "p1devguard.analysisDepth": "standard",
  "p1devguard.showCostEstimates": true
}
```

**Tasks** for AI-powered analysis:
- `Ctrl+Alt+P V`: Full P1 verification
- `Ctrl+Alt+P A`: AI analysis with Bedrock
- `Ctrl+Alt+P Q`: Quick AI scan
- `Ctrl+Alt+P C`: Cost estimation
- `Ctrl+Alt+P T`: Test AWS/Bedrock connection

**IntelliSense Integration**:
```python
# Real-time AI suggestions using vscode_integration.py
python3 build/toolchain/vscode_integration.py suggestions \
  --file values.yaml --line 42 --content "$(cat values.yaml)"
```

### Configuration Management CLI

Manage configurations using the comprehensive config manager:

```bash
# Show current configuration
python3 build/toolchain/config_manager.py show

# Show environment-specific config
python3 build/toolchain/config_manager.py show --env production

# Validate configuration
python3 build/toolchain/config_manager.py validate

# Export for container use
python3 build/toolchain/config_manager.py export

# Create sample configuration
python3 build/toolchain/config_manager.py sample
```

### Model Management

```bash
# List available AI models
python3 build/toolchain/ai_config.py list

# Show specific model configuration
python3 build/toolchain/ai_config.py show --model claude-3-sonnet

# Estimate costs for analysis
python3 build/toolchain/ai_config.py cost --model claude-3-haiku \
  --input-tokens 2000 --output-tokens 1000

# Create sample AI configuration
python3 build/toolchain/ai_config.py sample
```

### IAM Role Support

P1 Dev Guard automatically detects and uses various AWS credential sources:

- **EC2 Instance Roles**: Automatic detection via metadata service
- **EKS Service Account (IRSA)**: Web identity token authentication
- **ECS Task Roles**: Container-native role assumption
- **Cross-Account Roles**: Support for role chaining and assumption
- **Environment Variables**: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY
- **AWS Profiles**: ~/.aws/credentials and config files

Test credential setup:
```bash
# Test AWS credentials and Bedrock access
bash build/toolchain/test-iam-roles.sh
```

## Privacy and Security

### Data Handling
- **No data retention**: Analysis requests are not stored by Bedrock
- **Encrypted in transit**: All communications use HTTPS/TLS
- **No model training**: Your data is not used to train models
- **Audit logs**: CloudTrail logs all Bedrock API calls

### Sensitive Data Protection
- **Manifest scanning only**: Only analyzes Kubernetes manifests and compliance results
- **No secrets analysis**: Does not scan for or expose application secrets
- **Configurable analysis**: Can skip specific checks or files

### Compliance
- **SOC 2 Type II**: Bedrock is SOC 2 compliant
- **HIPAA eligible**: Available for HIPAA workloads
- **FedRAMP**: Available in FedRAMP regions
- **Air-gap compatible**: Falls back to local analysis when needed

The AI-enhanced P1 Dev Guard provides intelligent compliance analysis while maintaining full functionality without AI dependencies, ensuring it works in any environment from air-gapped systems to cloud-native pipelines.