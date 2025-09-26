#!/bin/bash
set -euo pipefail

# P1 Dev Guard - Big Bang Verification Script
# Single entrypoint for all Platform One compliance checks

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/.env"

# Setup
COMMIT_SHA="${GITHUB_SHA:-$(git rev-parse --short HEAD)}"
TIMESTAMP=$(date -u +"%Y%m%d_%H%M%S")
ARTIFACTS_DIR="artifacts"
REPORTS_DIR="${ARTIFACTS_DIR}/reports"
SBOM_DIR="${ARTIFACTS_DIR}/sbom"
ATTESTATION_DIR="${ARTIFACTS_DIR}/attestations"

mkdir -p "${REPORTS_DIR}" "${SBOM_DIR}" "${ATTESTATION_DIR}"

echo "🔍 P1 Dev Guard - Big Bang Verification"
echo "Commit: ${COMMIT_SHA}"
echo "Chart: ${HELM_CHART_PATH}"
echo "Tool Image: ${TOOL_IMAGE}"

# Function to run checks in container
run_containerized() {
    local cmd="$1"
    echo "Running: ${cmd}"

    docker run --rm \
        -v "$(pwd):/workspace" \
        -v "${HOME}/.p1devguard/keys:/keys:ro" \
        -w /workspace \
        --env-file "${SCRIPT_DIR}/.env" \
        "${TOOL_IMAGE}" \
        bash -c "${cmd}"
}

# Initialize results tracking
RESULTS_FILE="${REPORTS_DIR}/${COMMIT_SHA}.json"
cat > "${RESULTS_FILE}" << EOF
{
  "commit": "${COMMIT_SHA}",
  "timestamp": "${TIMESTAMP}",
  "helm_chart": "${HELM_CHART_PATH}",
  "checks": {}
}
EOF

update_results() {
    local check="$1"
    local status="$2"
    local message="$3"

    jq --arg check "$check" --arg status "$status" --arg message "$message" \
        '.checks[$check] = {"status": $status, "message": $message}' \
        "${RESULTS_FILE}" > "${RESULTS_FILE}.tmp" && mv "${RESULTS_FILE}.tmp" "${RESULTS_FILE}"
}

# 1. Helm Chart Validation
echo "📊 Validating Helm Chart..."
if run_containerized "helm lint ${HELM_CHART_PATH}"; then
    update_results "helm_lint" "PASS" "Chart linting successful"
else
    update_results "helm_lint" "FAIL" "Chart linting failed"
    exit 1
fi

if run_containerized "helm template ${APP_NAME} ${HELM_CHART_PATH} --validate"; then
    update_results "helm_template" "PASS" "Template validation successful"
else
    update_results "helm_template" "FAIL" "Template validation failed"
    exit 1
fi

# 2. Values Schema Validation
echo "📋 Validating Values Schema..."
SCHEMA_FILE="${HELM_CHART_PATH}/values.schema.json"
if [[ -f "${SCHEMA_FILE}" ]]; then
    if run_containerized "helm template ${APP_NAME} ${HELM_CHART_PATH} --validate --values ${HELM_CHART_PATH}/values.yaml"; then
        update_results "values_schema" "PASS" "Values schema validation successful"
    else
        update_results "values_schema" "FAIL" "Values schema validation failed"
        exit 1
    fi
else
    update_results "values_schema" "FAIL" "values.schema.json not found"
    exit 1
fi

# 3. OPA Policy Validation
echo "🛡️  Running OPA Policy Checks..."
MANIFESTS_DIR="manifests_temp"
mkdir -p "${MANIFESTS_DIR}"
run_containerized "helm template ${APP_NAME} ${HELM_CHART_PATH} --output-dir ${MANIFESTS_DIR}"

if run_containerized "conftest test ${MANIFESTS_DIR}/**/*.yaml --policy ${CONFTEST_POLICY_PATH}"; then
    update_results "opa_policies" "PASS" "All OPA policies passed"
else
    update_results "opa_policies" "FAIL" "OPA policy violations found"
    exit 1
fi

rm -rf "${MANIFESTS_DIR}"

# 4. Dockerfile Security Scan
echo "🐳 Scanning Dockerfile with Hadolint..."
if [[ -f "build/Dockerfile" ]]; then
    if run_containerized "hadolint --ignore ${HADOLINT_IGNORE} build/Dockerfile"; then
        update_results "hadolint" "PASS" "Dockerfile security scan passed"
    else
        update_results "hadolint" "FAIL" "Dockerfile security issues found"
        exit 1
    fi
else
    update_results "hadolint" "SKIP" "No Dockerfile found"
fi

# 5. Vulnerability and Security Scan
echo "🔒 Running Trivy Security Scan..."
if run_containerized "trivy fs --severity ${TRIVY_SEVERITY} --exit-code 1 ."; then
    update_results "trivy_scan" "PASS" "No HIGH/CRITICAL vulnerabilities found"
else
    update_results "trivy_scan" "FAIL" "HIGH/CRITICAL vulnerabilities detected"
    exit 1
fi

# 6. Generate SBOM
echo "📄 Generating Software Bill of Materials..."
SBOM_FILE="${SBOM_DIR}/${COMMIT_SHA}.spdx.json"
if run_containerized "syft dir:/workspace -o spdx-json > ${SBOM_FILE}"; then
    update_results "sbom_generation" "PASS" "SBOM generated successfully"

    # Upload to S3 bucket if available (graceful failure for air-gapped)
    if command -v aws >/dev/null 2>&1; then
        if aws s3 cp "${SBOM_FILE}" "${SBOM_BUCKET}${COMMIT_SHA}.spdx.json" 2>/dev/null; then
            echo "✅ SBOM uploaded to S3"
        else
            echo "⚠️  SBOM upload to S3 failed (air-gapped mode - this is expected)"
        fi
    fi
else
    update_results "sbom_generation" "FAIL" "SBOM generation failed"
    exit 1
fi

# 7. Generate Cryptographic Attestation
echo "🔐 Generating Cryptographic Attestation..."
ATTESTATION_FILE="${ATTESTATION_DIR}/${COMMIT_SHA}.intoto.jsonl"

if [[ -f "/keys/cosign.key" ]]; then
    if run_containerized "cosign attest --predicate ${RESULTS_FILE} --key /keys/cosign.key --output-file ${ATTESTATION_FILE} --type custom"; then
        update_results "cosign_attestation" "PASS" "Cryptographic attestation generated"
    else
        update_results "cosign_attestation" "FAIL" "Cryptographic attestation failed"
        exit 1
    fi
else
    echo "⚠️  No cosign key found at /keys/cosign.key - generating unsigned attestation"
    cp "${RESULTS_FILE}" "${ATTESTATION_FILE}"
    update_results "cosign_attestation" "SKIP" "No signing key available"
fi

# Final Results
echo ""
echo "✅ All Big Bang compliance checks passed!"
echo "📊 Report: ${RESULTS_FILE}"
echo "📄 SBOM: ${SBOM_FILE}"
echo "🔐 Attestation: ${ATTESTATION_FILE}"
echo ""
echo "Commit ${COMMIT_SHA} is ready for Big Bang deployment."