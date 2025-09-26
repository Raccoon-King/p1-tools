# Test Samples for P1 Dev Guard

This directory contains test samples to validate OPA policies and demonstrate Big Bang compliance requirements.

## Passing Sample

The `passing-sample/` directory contains Kubernetes manifests that fully comply with Big Bang and DoD security requirements:

- **deployment.yaml**: Compliant deployment with Iron Bank images, security contexts, resource limits, and health probes
- **service.yaml**: Properly configured service with named ports for Istio compatibility
- **networkpolicy.yaml**: Zero-trust network policy with explicit allow rules
- **serviceaccount.yaml**: Dedicated service account with Istio integration
- **ingress.yaml**: TLS-enabled ingress with proper annotations

### Key Compliance Features

- ✅ Iron Bank container images with digest pinning
- ✅ Non-root execution (UID 65534)
- ✅ Read-only root filesystem with volume mounts for temp directories
- ✅ Dropped all capabilities
- ✅ Resource requests and limits specified
- ✅ Liveness and readiness probes configured
- ✅ NetworkPolicy for zero-trust networking
- ✅ TLS encryption for external traffic
- ✅ Proper Big Bang labels and annotations

## Failing Sample

The `failing-sample/` directory contains manifests that violate Big Bang security policies:

- **deployment.yaml**: Multiple violations including latest tags, missing security contexts, no resource limits
- **service.yaml**: Missing port names and protocol specifications
- **ingress.yaml**: No TLS configuration violating encryption requirements
- **privileged-deployment.yaml**: Extreme violations including privileged containers and host access

### Common Violations Demonstrated

- ❌ Using `:latest` tag instead of specific versions/digests
- ❌ Non-Iron Bank container images
- ❌ Missing or inadequate security contexts
- ❌ No resource limits (allows resource exhaustion)
- ❌ Missing health probes
- ❌ Privileged containers and dangerous capabilities
- ❌ Host network/PID usage
- ❌ No NetworkPolicy (allows unrestricted traffic)
- ❌ HTTP-only ingress (no encryption)
- ❌ Missing proper Big Bang labels

## Testing the Policies

Run the test suite to validate policies:

```bash
# Test policies against passing samples (should pass)
make test-policies

# Test individual samples with conftest
conftest test test/passing-sample/ --policy policies/

# Test failing samples (should fail with clear error messages)
conftest test test/failing-sample/ --policy policies/
```

## Expected Output

### Passing Sample Results
```
PASS - test/passing-sample/deployment.yaml
PASS - test/passing-sample/service.yaml
PASS - test/passing-sample/networkpolicy.yaml
PASS - test/passing-sample/serviceaccount.yaml
PASS - test/passing-sample/ingress.yaml
```

### Failing Sample Results
```
FAIL - test/failing-sample/deployment.yaml
  Container image 'nginx:latest' must use Iron Bank mirror
  Container 'app' uses ':latest' tag. Use specific version or digest
  Container 'app' must specify CPU resource request
  Container 'app' must define livenessProbe for health monitoring
  Pod must define securityContext for security compliance

FAIL - test/failing-sample/service.yaml
  Service 'non-compliant-app' port 80 must have a name for service mesh compatibility

FAIL - test/failing-sample/ingress.yaml
  Ingress 'non-compliant-app' must define TLS configuration for encrypted traffic
```

## Adding New Tests

When adding new test cases:

1. Create manifests in appropriate subdirectory
2. Add clear comments explaining compliance/violation points
3. Test with `conftest test` to verify policy behavior
4. Update this README with new test scenarios

## Integration with CI/CD

These test samples can be used in CI/CD pipelines to validate policy changes:

```bash
# In your CI pipeline
make test-policies
```

This ensures policy changes don't break existing compliance checks and new violations are properly detected.