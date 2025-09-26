# P1 Dev Guard - Platform One Developer Toolkit

A developer toolkit that makes it easy and default for developers to meet Platform One / Big Bang standards and "pass the pipeline," even in air-gapped enclaves.

**Available in two modes:**
- **🐳 Container Mode** (Recommended): Zero project pollution, works with any project
- **📁 Project Mode**: Full development environment with git hooks and VS Code integration

## Quick Start

### Container Mode (Recommended)

```bash
# Verify any project without adding files to it
docker run --rm -v $(pwd):/workspace registry.internal/p1/p1-dev-guard:2025.09.01

# With signing keys for cryptographic attestation
docker run --rm \
  -v $(pwd):/workspace \
  -v ~/.p1devguard/keys:/keys:ro \
  registry.internal/p1/p1-dev-guard:2025.09.01

# CI/CD mode with JSON output
docker run --rm -v $(pwd):/workspace registry.internal/p1/p1-dev-guard:2025.09.01 --ci

# With AI-powered analysis (requires AWS credentials)
docker run --rm -v $(pwd):/workspace -e AWS_PROFILE=default registry.internal/p1/p1-dev-guard:2025.09.01
```

### 🤖 AI-Enhanced Analysis (Optional)

P1 Dev Guard includes **AI-powered compliance analysis** using Amazon Bedrock:
- **Intelligent remediation suggestions** with specific code examples
- **Priority assessment** and root cause analysis
- **Works with or without AWS** - gracefully falls back to rule-based analysis
- **Cost-effective** - typically $0.01-0.25 per scan

**See [AI-FEATURES.md](AI-FEATURES.md) for complete documentation.**

```bash
# Enable AI analysis with AWS credentials
export AWS_PROFILE=default
docker run --rm -v $(pwd):/workspace p1guard --ai-model claude-3-haiku
```

### Project Mode (Full Development Environment)

```bash
# Bootstrap the toolkit in your project
make bootstrap

# Verify your app meets P1/Big Bang standards
make verify

# Run in dev container for complete environment
code --folder-uri vscode-remote://dev-container+$(pwd | sed 's/\//+/g')/workspaces/p1-tools
```

## How This Maps to Big Bang

This toolkit enforces compliance with Platform One and Big Bang standards:

- **Helm Chart Standards**: Values schema validation, proper labeling, and resource definitions per [Big Bang Package Standards](https://repo1.dso.mil/big-bang/bigbang/-/blob/master/docs/developer/package-integration.md)
- **Container Hardening**: Iron Bank image requirements, non-root execution, minimal capabilities per [DoD Container Hardening Guide](https://cyber.mil/stigs/view/Container/)
- **Security Policies**: OPA/Conftest rules enforcing network policies, resource limits, and image security per Big Bang patterns
- **Supply Chain**: SBOM generation, container scanning, and cryptographic attestation using cosign
- **Flux Integration**: HelmRelease patterns for GitOps deployment matching [Big Bang Flux patterns](https://repo1.dso.mil/big-bang/bigbang/-/tree/master/chart/templates/flux)

## Architecture

The toolkit provides a "pipeline-in-a-box" that runs locally:

```
Developer Code → bb-verify.sh → Policies + Scans → Attestation → Git Hooks → Flux Deploy
```

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for detailed flow.

## What Gets Checked

- **Helm**: Chart linting, template validation, values schema enforcement
- **Images**: Iron Bank mirror usage, digest pinning, no `:latest` tags
- **Security**: Container scanning (Trivy), Dockerfile linting (Hadolint), secret detection
- **Operations**: Resource requests/limits, probes, NetworkPolicy requirements
- **Supply Chain**: SBOM generation, cryptographic attestation with cosign

## Troubleshooting

### "conftest policy violation: image not from Iron Bank mirror"
Update your image repository in `values.yaml` to use `${IRONBANK_MIRROR}/...` format.

### "trivy scan failed with HIGH/CRITICAL vulnerabilities"
Update base images or add exceptions in `build/Dockerfile` with justification.

### "values.schema.json validation failed"
Check that all required fields are present and match the expected format/enum values.

### Pre-push hook blocking commits
Run `make verify` to see all failing checks. Fix issues before pushing.

### SBOM upload fails in air-gapped environment
This is expected - SBOM will be generated locally in `artifacts/sbom/` for manual transfer.

## References

- [Big Bang Developer Documentation](https://repo1.dso.mil/big-bang/bigbang/-/blob/master/docs/developer/)
- [Big Bang Package Integration Guide](https://repo1.dso.mil/big-bang/bigbang/-/blob/master/docs/developer/package-integration.md)
- [Iron Bank Container Hardening](https://cyber.mil/stigs/view/Container/)
- [DoD Container Security Requirements Guide](https://dl.dod.cyber.mil/wp-content/uploads/stigs/zip/U_Container_Platform_SRG_V2R1.zip)
- [Helm Values Schema Documentation](https://helm.sh/docs/topics/charts/#schema-files)
- [Big Bang Flux Integration Patterns](https://repo1.dso.mil/big-bang/bigbang/-/tree/master/chart/templates/flux)

## Choosing Your Mode

### Container Mode 🐳 (Recommended)
**Best for:** CI/CD pipelines, multiple projects, clean project directories

- ✅ **Zero project pollution**: No files added to your project
- ✅ **Universal compatibility**: Works with any project structure
- ✅ **Easy distribution**: Single container image to manage
- ✅ **CI/CD ready**: Drop-in replacement for compliance tools
- ✅ **Consistent behavior**: Same tool everywhere

**Usage:** See [CONTAINER-USAGE.md](CONTAINER-USAGE.md) for complete guide

### Project Mode 📁 (Full Development)
**Best for:** Active development, team onboarding, integrated workflows

- ✅ **Full development environment**: VS Code integration, git hooks
- ✅ **Local Make targets**: Familiar workflow with `make verify`
- ✅ **Git integration**: Pre-commit and pre-push hooks
- ✅ **Team consistency**: Shared configuration and policies

**Setup:** Drop the entire toolkit into your project directory

## Configuration

### Container Mode
Configure via environment variables or volume-mounted config file:
```bash
export IRONBANK_MIRROR=registry.myorg.mil/ironbank
export TRIVY_SEVERITY=HIGH,CRITICAL
```

### Project Mode
Edit organization-specific variables in `make/.env` to match your environment.