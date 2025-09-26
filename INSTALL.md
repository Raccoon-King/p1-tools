# P1 Dev Guard - Quick Installation Guide

## Choose Your Setup Method

### 🐳 Container Mode (Recommended)
**Best for:** Clean projects, multiple repositories, CI/CD integration

```bash
# 1. Get the container (choose one method)
# Option A: Pull from registry
docker pull registry.internal/p1/p1-dev-guard:2025.09.01

# Option B: Build locally
docker build -t p1guard build/toolchain/

# Option C: Load from file (air-gapped)
docker load < p1guard.tar

# 2. Create CLI wrapper (optional but recommended)
cat > p1-verify << 'EOF'
#!/bin/bash
docker run --rm \
  -v $(pwd):/workspace \
  -v ~/.docker:/root/.docker:ro \
  -e IRONBANK_MIRROR="${IRONBANK_MIRROR:-registry.internal/ironbank}" \
  registry.internal/p1/p1-dev-guard:2025.09.01 "$@"
EOF
chmod +x p1-verify && sudo mv p1-verify /usr/local/bin/

# 3. Configure your environment
export IRONBANK_MIRROR=registry.yourcompany.com/approved-images

# 4. Test it works
p1-verify --help
p1-verify  # Runs in current directory
```

### 📁 Project Mode (Full Development Environment)
**Best for:** Active development, team consistency, git integration

```bash
# 1. Add P1 Dev Guard to your project
# Option A: Copy the entire toolkit
cp -r /path/to/p1-tools/* ./

# Option B: Git subtree (if using git)
git subtree add --prefix=.p1-tools https://github.com/your-org/p1-tools.git main --squash

# 2. Bootstrap development environment
make bootstrap

# 3. Configure organization settings
cp make/.env.example make/.env
# Edit make/.env with your values:
# IRONBANK_MIRROR=registry.yourcompany.com/hardened
# ORG_NAMESPACE=yourcompany-apps

# 4. Test it works
make verify
```

## VS Code Integration

### Quick Setup
```bash
# 1. Open the workspace
code p1-devguard.code-workspace

# 2. Install recommended extensions when prompted

# 3. Ready! Use these keyboard shortcuts:
# Ctrl+Alt+P V - Full P1 verification
# Ctrl+Alt+P A - AI analysis (container required)
# Ctrl+Alt+P Q - Quick AI scan
# Ctrl+Alt+P S - Security scan
# Ctrl+Alt+P T - Test AWS connection
```

### Manual Extension Install
```bash
# Install required VS Code extensions
code --install-extension ms-python.python
code --install-extension ms-azuretools.vscode-docker
code --install-extension ms-kubernetes-tools.vscode-kubernetes-tools
code --install-extension redhat.vscode-yaml
code --install-extension tim-koike.helm-intellisense
```

## Registry Configuration

### With Iron Bank Mirror
```bash
export IRONBANK_MIRROR=registry.yourcompany.com/ironbank
```

### Without Iron Bank (Use Your Registry)
```bash
# Point to your approved/hardened images
export IRONBANK_MIRROR=registry.yourcompany.com/platform-approved

# Or document compliance gaps without failing
export IRONBANK_MIRROR=registry.yourcompany.com/current-images
export COMPLIANCE_MODE=documentation  # vs enforcement
```

### Air-Gapped Environment
```bash
# Disable external dependencies
export SKIP_AI=true
export AI_ENABLED=false
export IRONBANK_MIRROR=localhost:5000/approved-images

# Use local registry
docker tag p1guard:latest localhost:5000/p1guard:latest
docker push localhost:5000/p1guard:latest
```

## AWS/AI Configuration (Optional)

### Quick AWS Setup
```bash
# Option A: Use AWS profile
export AWS_PROFILE=your-profile

# Option B: Direct credentials
export AWS_ACCESS_KEY_ID=your-key
export AWS_SECRET_ACCESS_KEY=your-secret
export AWS_REGION=us-east-1

# Test AWS connection
bash build/toolchain/test-iam-roles.sh
```

### AI Model Configuration
```bash
# Use fastest/cheapest model (default)
export AI_MODEL=claude-3-haiku

# Use more detailed analysis
export AI_MODEL=claude-3-sonnet

# Create persistent config
python3 build/toolchain/ai_config.py sample
# Edit ~/.p1devguard/ai-config.yaml as needed
```

## Verification

### Test Container Mode
```bash
# Basic test
p1-verify --help

# Full test in a project directory
cd /path/to/your/project
p1-verify

# With AI (if configured)
p1-verify --ai-model claude-3-haiku
```

### Test Project Mode
```bash
# Basic test
make help

# Full test
make verify

# Individual components
make lint        # Linting only
make scan        # Security scan only
make policies    # OPA policy check only
```

### Test VS Code Integration
```bash
# Open VS Code in project
code .

# Try keyboard shortcuts:
# Ctrl+Alt+P V should run P1 verification
# Check VS Code terminal for output
```

## Troubleshooting

### Docker Issues
```bash
# Check Docker is running
docker version

# Check image exists
docker images | grep p1guard

# Check registry access
docker login registry.yourcompany.com
```

### Permission Issues
```bash
# Fix file permissions
chmod +x p1-verify

# Fix Docker socket (Linux)
sudo usermod -aG docker $USER
# Logout and login again
```

### Registry/Network Issues
```bash
# Test registry access
docker pull registry.yourcompany.com/test-image

# Skip external dependencies
export SKIP_AI=true
export SKIP_SBOM=true  # If SBOM upload fails
```

### VS Code Issues
```bash
# Reset VS Code workspace
rm -rf .vscode/
# Reopen: code p1-devguard.code-workspace

# Check Python path
which python3
# Update .vscode/settings.json if needed
```

## What's Next?

After installation:

1. **Run your first scan**: `p1-verify` or `make verify`
2. **Review the output**: Check `.p1-artifacts/` directory
3. **Fix compliance issues**: Follow the generated recommendations
4. **Set up CI/CD**: Use container mode in your pipelines
5. **Configure team settings**: Share configuration files with your team

## Quick Reference

| Command | Container Mode | Project Mode |
|---------|---------------|--------------|
| Full verification | `p1-verify` | `make verify` |
| Quick scan | `p1-verify --skip-sbom` | `make lint` |
| Security only | `p1-verify --skip-helm --skip-policies` | `make scan` |
| With AI | `p1-verify --ai-model claude-3-haiku` | `AI_ENABLED=true make verify` |
| Help | `p1-verify --help` | `make help` |

The system auto-detects your project structure (Helm charts, Dockerfiles, Kubernetes manifests) and provides compliance analysis tailored to your setup.