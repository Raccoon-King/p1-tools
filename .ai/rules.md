# AI Assistant Rules for P1 Dev Guard Development

## Overview
These rules guide AI assistants (Continue, Cline, etc.) when working on P1 Dev Guard projects to ensure compliance with Big Bang and Platform One standards.

## Container and Image Rules

### ALWAYS
- Use Iron Bank registry images: `registry.internal/ironbank/*`
- Pin images with SHA256 digests for production: `@sha256:...`
- Run containers as non-root user (UID > 0)
- Set `readOnlyRootFilesystem: true`
- Drop all capabilities and add only required ones: `capabilities: {drop: [ALL]}`
- Set `allowPrivilegeEscalation: false`
- Include resource requests and limits for CPU and memory

### NEVER
- Use `:latest` tags in any environment
- Run privileged containers (`privileged: true`)
- Use host networking (`hostNetwork: true`)
- Mount hostPath volumes except for specific justified cases
- Run as root user (UID 0)

## Dockerfile Rules

### ALWAYS
- Start with Iron Bank base images
- Create and use non-root user
- Use multi-stage builds to minimize attack surface
- Pin package versions for reproducibility
- Set proper file permissions (non-executable by default)
- Include health checks when appropriate
- Document each layer's purpose in comments

### Example Pattern
```dockerfile
FROM registry.internal/ironbank/redhat/ubi/ubi9:9.4
RUN useradd -r -u 1001 -g 0 appuser
USER 1001
HEALTHCHECK --interval=30s CMD curl -f http://localhost:8080/health || exit 1
```

## Kubernetes Manifest Rules

### ALWAYS Include
- Resource requests and limits
- Liveness and readiness probes
- Security context with non-root settings
- NetworkPolicy for zero-trust networking
- ServiceAccount (not default)
- Proper labels following Big Bang conventions

### Required Labels
```yaml
labels:
  app.kubernetes.io/name: {{ app-name }}
  app.kubernetes.io/instance: {{ release-name }}
  app.kubernetes.io/version: {{ version }}
  app.kubernetes.io/managed-by: Helm
  app.kubernetes.io/part-of: {{ chart-name }}
```

## Helm Chart Rules

### ALWAYS
- Create `values.schema.json` for all charts
- Use semantic versioning
- Include Big Bang metadata in Chart.yaml
- Parameterize all configurable values
- Provide sensible defaults that pass policies
- Include helper templates for common patterns

### Values Schema Enforcement
- Validate Iron Bank image repositories
- Require resource specifications
- Enforce security context requirements
- Validate probe configurations

## Network Security Rules

### ALWAYS
- Create NetworkPolicy for each workload
- Use default-deny approach with explicit allow rules
- Require TLS for all external-facing services
- Use named ports in Services for Istio compatibility
- Include proper ingress annotations for cert-manager

### NetworkPolicy Template
```yaml
spec:
  policyTypes: [Ingress, Egress]
  ingress: [/* explicit allow rules */]
  egress: [/* DNS and required external services */]
```

## OPA Policy Development

### When Writing Policies
- Provide clear, actionable error messages
- Reference the specific Big Bang requirement being enforced
- Include both deny rules (violations) and warn rules (recommendations)
- Group related policies logically (images, ops, network, security)
- Test policies with both passing and failing examples

### Message Format
```
"Container 'app' cannot run privileged. This violates DoD security requirements"
"Deployment 'app' must specify CPU resource request for proper scheduling"
```

## Testing and Validation

### ALWAYS Test
- Helm chart linting and template rendering
- OPA policy validation with conftest
- Security scanning with Trivy
- Dockerfile linting with Hadolint
- YAML syntax validation

### Test Data Requirements
- Provide both passing and failing examples
- Cover edge cases and common mistakes
- Include realistic resource values
- Test with actual Iron Bank images

## Documentation Rules

### Code Comments
- Explain WHY security restrictions exist
- Reference specific compliance requirements
- Provide examples of correct implementation
- Link to relevant Big Bang documentation

### README Updates
- Keep troubleshooting section current
- Map each check to Big Bang requirements
- Provide clear quickstart instructions
- Include common failure scenarios and fixes

## Makefile and Automation

### Build Targets
- `verify`: Run all compliance checks
- `lint`: Basic syntax and style checks
- `bootstrap`: Setup development environment
- `chart`: Package and validate Helm charts
- `scan`: Security vulnerability scanning
- `sbom`: Generate software bill of materials

### Error Handling
- Fail fast on policy violations
- Provide actionable error messages
- Log all verification steps
- Generate compliance artifacts (SBOM, attestations)

## Air-gapped Environment Considerations

### ALWAYS
- Use internal mirrors and registries
- Gracefully handle network unavailability
- Cache dependencies locally
- Provide offline fallback options

### NEVER
- Assume internet connectivity
- Hard-code external URLs
- Download packages at runtime
- Skip verification due to network issues

## Git and Version Control

### Hooks Behavior
- Pre-commit: Fast checks only (YAML, basic validation)
- Pre-push: Full compliance verification
- Block commits that fail security policies
- Generate and verify cryptographic attestations

### Commit Messages
- Reference policy violations being fixed
- Include compliance checkpoint information
- Link to relevant Big Bang requirements

## AI Assistant Behavior

### When Making Changes
1. Always read existing files first to understand patterns
2. Update `values.schema.json` when adding new values
3. Ensure changes maintain Big Bang compliance
4. Test changes with `make verify` before suggesting
5. Provide clear explanations of security implications

### Default Assumptions
- Prefer Helm over raw Kubernetes manifests
- Assume air-gapped environment unless told otherwise
- Default to most restrictive security settings
- Follow principle of least privilege
- Generate comprehensive examples and tests

These rules ensure consistent, secure, and compliant code generation that meets Big Bang and Platform One standards.