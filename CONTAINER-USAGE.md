# P1 Dev Guard - Container Usage Guide

P1 Dev Guard is now available as a standalone container that can verify any project without requiring files to be dropped into your project directory.

## Quick Start

### Basic Usage

```bash
# Verify current directory (auto-detects project structure)
docker run --rm -v $(pwd):/workspace registry.internal/p1/p1-dev-guard:2025.09.01

# With signing keys for attestation
docker run --rm \
  -v $(pwd):/workspace \
  -v ~/.p1devguard/keys:/keys:ro \
  registry.internal/p1/p1-dev-guard:2025.09.01
```

### Using the CLI Wrapper (Recommended)

1. **Install the CLI wrapper:**
   ```bash
   curl -fsSL https://raw.githubusercontent.com/your-org/p1-tools/main/p1-verify -o p1-verify
   chmod +x p1-verify
   sudo mv p1-verify /usr/local/bin/
   ```

2. **Use the wrapper:**
   ```bash
   # Simple verification
   p1-verify

   # With AI-powered analysis (requires AWS credentials)
   export AWS_PROFILE=default
   p1-verify --ai-model claude-3-haiku

   # With custom options
   p1-verify --chart ./helm/myapp --ci
   ```

## Container Features

### Auto-Detection
The container automatically detects:
- Helm charts (searches for `Chart.yaml`)
- Dockerfiles (any file named `Dockerfile`)
- Kubernetes manifests (YAML files with `apiVersion`)

### Verification Capabilities
- **Helm Chart Validation**: Linting, templating, values schema validation
- **OPA Policy Enforcement**: Big Bang compliance policies
- **Container Security**: Dockerfile best practices with Hadolint
- **Vulnerability Scanning**: High/Critical CVE detection with Trivy
- **Supply Chain**: SBOM generation and cryptographic attestation
- **🤖 AI-Powered Analysis**: Intelligent compliance insights with Amazon Bedrock (optional)

### Output Formats
- **Text Mode**: Human-readable console output (default)
- **JSON Mode**: Machine-parseable results for CI/CD
- **CI Mode**: Optimized for continuous integration pipelines

## Command Line Options

```
USAGE:
    p1-verify [OPTIONS] [PATH]

OPTIONS:
    -h, --help              Show help message
    -v, --version           Show version information
    -o, --output DIR        Output directory for artifacts (default: .p1-artifacts)
    --chart PATH            Specific Helm chart path to verify
    --dockerfile PATH       Specific Dockerfile to scan
    --manifests PATH        Directory containing Kubernetes manifests
    --skip-helm             Skip Helm chart validation
    --skip-docker           Skip Dockerfile scanning
    --skip-policies         Skip OPA policy validation
    --skip-scan             Skip vulnerability scanning
    --skip-sbom             Skip SBOM generation
    --skip-ai               Skip AI-powered analysis
    --ai-model MODEL        AI model: claude-3-sonnet|claude-3-haiku|titan (default: claude-3-haiku)
    --ai-region REGION      AWS region for Bedrock (default: us-east-1)
    --format FORMAT         Output format: json|text (default: text)
    --ci                    CI mode: JSON output, proper exit codes
    --config FILE           Load configuration from file

ENVIRONMENT VARIABLES:
    IRONBANK_MIRROR         Iron Bank registry URL
    TRIVY_SEVERITY          Vulnerability severity levels
    HADOLINT_IGNORE         Hadolint rules to ignore
    KEYS_DIR                Directory containing signing keys
    AWS_PROFILE             AWS profile for Bedrock access (optional)
    AWS_ACCESS_KEY_ID       AWS access key for Bedrock (optional)
    AWS_SECRET_ACCESS_KEY   AWS secret key for Bedrock (optional)
    AWS_REGION              AWS region for Bedrock (optional)
```

## Project Structure Examples

### Helm Chart Project
```
my-app/
├── helm/
│   └── my-app/
│       ├── Chart.yaml
│       ├── values.yaml
│       ├── values.schema.json
│       └── templates/
└── build/
    └── Dockerfile
```

**Command:**
```bash
docker run --rm -v $(pwd):/workspace p1guard
# Auto-detects: chart at helm/my-app, Dockerfile at build/Dockerfile
```

### Kubernetes Manifests Only
```
k8s-app/
├── manifests/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── ingress.yaml
└── Dockerfile
```

**Command:**
```bash
docker run --rm -v $(pwd):/workspace p1guard --manifests manifests
```

### Multi-Chart Repository
```
charts-repo/
├── chart1/
│   ├── Chart.yaml
│   └── templates/
├── chart2/
│   ├── Chart.yaml
│   └── templates/
└── common/
    └── Dockerfile
```

**Commands:**
```bash
# Verify specific chart
docker run --rm -v $(pwd):/workspace p1guard --chart chart1

# Verify all charts (run multiple times)
for chart in chart1 chart2; do
    docker run --rm -v $(pwd):/workspace p1guard --chart $chart
done
```

## CI/CD Integration

### GitLab CI

```yaml
# .gitlab-ci.yml
stages:
  - compliance

p1-compliance:
  stage: compliance
  image: docker:latest
  services:
    - docker:dind
  before_script:
    - docker info
  script:
    - >
      docker run --rm
      -v ${CI_PROJECT_DIR}:/workspace
      registry.internal/p1/p1-dev-guard:2025.09.01
      --ci --format json --output /workspace/.p1-artifacts
  artifacts:
    when: always
    paths:
      - .p1-artifacts/
    reports:
      junit: .p1-artifacts/reports/*.xml  # If XML output is added
  allow_failure: false
```

### GitHub Actions

```yaml
# .github/workflows/compliance.yml
name: Big Bang Compliance
on: [push, pull_request]

jobs:
  compliance:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run P1 Dev Guard
        run: |
          docker run --rm \
            -v ${{ github.workspace }}:/workspace \
            registry.internal/p1/p1-dev-guard:2025.09.01 \
            --ci --format json

      - name: Upload Artifacts
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: compliance-reports
          path: .p1-artifacts/
```

### Jenkins Pipeline

```groovy
// Jenkinsfile
pipeline {
    agent any

    stages {
        stage('Big Bang Compliance') {
            steps {
                script {
                    docker.image('registry.internal/p1/p1-dev-guard:2025.09.01').inside('-v ${WORKSPACE}:/workspace') {
                        sh 'p1-verify --ci --format json'
                    }
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: '.p1-artifacts/**/*', allowEmptyArchive: true
                }
            }
        }
    }
}
```

### Azure DevOps

```yaml
# azure-pipelines.yml
trigger:
- main

pool:
  vmImage: 'ubuntu-latest'

steps:
- task: Docker@2
  displayName: 'Run P1 Dev Guard'
  inputs:
    command: 'run'
    arguments: >
      --rm
      -v $(System.DefaultWorkingDirectory):/workspace
      registry.internal/p1/p1-dev-guard:2025.09.01
      --ci --format json

- task: PublishBuildArtifacts@1
  displayName: 'Publish Compliance Artifacts'
  condition: always()
  inputs:
    pathToPublish: '.p1-artifacts'
    artifactName: 'compliance-reports'
```

## Advanced Usage

### Custom Configuration

Create a configuration file:
```bash
# p1guard.conf
IRONBANK_MIRROR=registry.myorg.mil/ironbank
TRIVY_SEVERITY=MEDIUM,HIGH,CRITICAL
HADOLINT_IGNORE=DL3008,DL3009,SC2086
```

Use with container:
```bash
docker run --rm \
  -v $(pwd):/workspace \
  -v $(pwd)/p1guard.conf:/etc/p1guard/config \
  p1guard --config /etc/p1guard/config
```

### Signing Keys Setup

1. **Generate cosign key pair:**
   ```bash
   mkdir -p ~/.p1devguard/keys
   cosign generate-key-pair
   mv cosign.key cosign.pub ~/.p1devguard/keys/
   ```

2. **Use with container:**
   ```bash
   docker run --rm \
     -v $(pwd):/workspace \
     -v ~/.p1devguard/keys:/keys:ro \
     p1guard
   ```

### Air-Gapped Environments

1. **Save container image:**
   ```bash
   docker save registry.internal/p1/p1-dev-guard:2025.09.01 > p1guard.tar
   ```

2. **Load on air-gapped system:**
   ```bash
   docker load < p1guard.tar
   ```

3. **Use local registry:**
   ```bash
   docker tag p1guard:2025.09.01 localhost:5000/p1guard:2025.09.01
   docker push localhost:5000/p1guard:2025.09.01
   ```

## Troubleshooting

### Common Issues

**"No such file or directory" when mounting volumes:**
- Ensure paths are absolute: `-v $(pwd):/workspace`
- On Windows, use: `-v ${PWD}:/workspace`

**"Permission denied" errors:**
- Add user mapping: `--user $(id -u):$(id -g)`
- Or fix permissions: `chmod -R 755 .p1-artifacts`

**Container fails to pull:**
- Check registry access: `docker login registry.internal`
- Use local build: `docker build -t p1guard build/toolchain/`

**Policy violations not detected:**
- Ensure manifests contain `apiVersion` fields
- Check that Iron Bank mirror URL matches your environment
- Verify OPA policies are loading: `--skip-policies` to test

### Debug Mode

Enable verbose output:
```bash
docker run --rm \
  -v $(pwd):/workspace \
  -e DEBUG=1 \
  p1guard --format json
```

### Exit Codes

- **0**: All checks passed
- **1**: Policy violations or security issues found
- **2**: Tool execution error
- **3**: Invalid arguments or missing files

## Migration from File-Based Approach

If you're currently using the file-based P1 Dev Guard:

1. **Remove project files** (optional):
   ```bash
   rm -rf make/ .git-hooks/ policies/ .devcontainer/
   rm makefile README.md
   ```

2. **Use container instead**:
   ```bash
   # Instead of: make verify
   docker run --rm -v $(pwd):/workspace p1guard

   # Instead of: make verify --chart helm/myapp
   docker run --rm -v $(pwd):/workspace p1guard --chart helm/myapp
   ```

3. **Update CI/CD pipelines** to use container image instead of local tools.

The containerized version provides the same functionality without polluting your project with configuration files.

## AI-Enhanced Analysis

P1 Dev Guard includes optional AI-powered analysis using Amazon Bedrock:

- **🤖 Intelligent Insights**: Uses LLMs to analyze compliance failures and provide context-aware recommendations
- **🔧 Smart Remediation**: Generates specific, actionable fix instructions with code examples
- **📊 Priority Assessment**: Automatically categorizes issues by risk level and complexity
- **💡 Prevention Guidance**: Suggests best practices to avoid future violations

**Works with or without AI**: The system functions perfectly without AWS credentials, falling back to intelligent rule-based analysis.

**See [AI-FEATURES.md](AI-FEATURES.md) for complete AI capabilities documentation.**