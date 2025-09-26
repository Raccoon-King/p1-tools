#!/bin/bash
# P1 Dev Guard - Verification Logic
# Called by entrypoint.sh to perform actual compliance checks

# Helm Chart Validation
verify_helm_chart() {
    if [[ "${SKIP_HELM}" == "true" || -z "${CHART_PATH}" ]]; then
        update_result "helm_validation" "SKIP" "Helm chart validation skipped"
        return 0
    fi

    if [[ ! -f "${CHART_PATH}/Chart.yaml" ]]; then
        update_result "helm_validation" "FAIL" "Chart.yaml not found at ${CHART_PATH}"
        return 1
    fi

    blue "📊 Validating Helm chart: ${CHART_PATH}"

    # Helm lint
    if helm lint "${CHART_PATH}" >/dev/null 2>&1; then
        update_result "helm_lint" "PASS" "Chart linting successful"
    else
        local lint_output=$(helm lint "${CHART_PATH}" 2>&1)
        update_result "helm_lint" "FAIL" "Chart linting failed" "${lint_output}"
        return 1
    fi

    # Helm template validation
    local template_dir="${OUTPUT_DIR}/templates"
    mkdir -p "${template_dir}"

    if helm template test "${CHART_PATH}" --output-dir "${template_dir}" >/dev/null 2>&1; then
        update_result "helm_template" "PASS" "Template rendering successful"
    else
        local template_output=$(helm template test "${CHART_PATH}" 2>&1)
        update_result "helm_template" "FAIL" "Template rendering failed" "${template_output}"
        return 1
    fi

    # Values schema validation if present
    if [[ -f "${CHART_PATH}/values.schema.json" ]]; then
        if helm template test "${CHART_PATH}" --validate >/dev/null 2>&1; then
            update_result "values_schema" "PASS" "Values schema validation successful"
        else
            local schema_output=$(helm template test "${CHART_PATH}" --validate 2>&1)
            update_result "values_schema" "FAIL" "Values schema validation failed" "${schema_output}"
            return 1
        fi
    else
        update_result "values_schema" "SKIP" "No values.schema.json found"
    fi

    return 0
}

# OPA Policy Validation
verify_policies() {
    if [[ "${SKIP_POLICIES}" == "true" ]]; then
        update_result "opa_policies" "SKIP" "OPA policy validation skipped"
        return 0
    fi

    blue "🛡️  Running OPA policy validation"

    # Find manifests to test
    local manifest_files=()

    # From Helm template output
    if [[ -d "${OUTPUT_DIR}/templates" ]]; then
        while IFS= read -r -d '' file; do
            manifest_files+=("$file")
        done < <(find "${OUTPUT_DIR}/templates" -name "*.yaml" -print0)
    fi

    # From manifests directory
    if [[ -n "${MANIFESTS_PATH}" && -d "${MANIFESTS_PATH}" ]]; then
        while IFS= read -r -d '' file; do
            manifest_files+=("$file")
        done < <(find "${MANIFESTS_PATH}" -name "*.yaml" -o -name "*.yml" -print0)
    fi

    if [[ ${#manifest_files[@]} -eq 0 ]]; then
        update_result "opa_policies" "SKIP" "No manifest files found for policy validation"
        return 0
    fi

    # Create config data for policies
    local config_file="${OUTPUT_DIR}/policy-config.json"
    cat > "${config_file}" << EOF
{
  "config": {
    "ironbank_mirror": "${IRONBANK_MIRROR}"
  }
}
EOF

    # Run conftest
    local policy_output=$(conftest test "${manifest_files[@]}" --policy /policies --data "${config_file}" 2>&1)
    local policy_exit_code=$?

    if [[ ${policy_exit_code} -eq 0 ]]; then
        update_result "opa_policies" "PASS" "All OPA policies passed"
    else
        update_result "opa_policies" "FAIL" "OPA policy violations found" "${policy_output}"
        return 1
    fi

    return 0
}

# Dockerfile Security Scanning
verify_dockerfile() {
    if [[ "${SKIP_DOCKER}" == "true" || -z "${DOCKERFILE_PATH}" ]]; then
        update_result "dockerfile_scan" "SKIP" "Dockerfile scanning skipped"
        return 0
    fi

    if [[ ! -f "${DOCKERFILE_PATH}" ]]; then
        update_result "dockerfile_scan" "SKIP" "No Dockerfile found"
        return 0
    fi

    blue "🐳 Scanning Dockerfile: ${DOCKERFILE_PATH}"

    # Hadolint scan
    local hadolint_output=$(hadolint --ignore "${HADOLINT_IGNORE}" "${DOCKERFILE_PATH}" 2>&1)
    local hadolint_exit_code=$?

    if [[ ${hadolint_exit_code} -eq 0 ]]; then
        update_result "dockerfile_hadolint" "PASS" "Dockerfile security scan passed"
    else
        update_result "dockerfile_hadolint" "FAIL" "Dockerfile security issues found" "${hadolint_output}"
        return 1
    fi

    return 0
}

# Vulnerability Scanning
verify_vulnerabilities() {
    if [[ "${SKIP_SCAN}" == "true" ]]; then
        update_result "vulnerability_scan" "SKIP" "Vulnerability scanning skipped"
        return 0
    fi

    blue "🔒 Running vulnerability scan"

    # Trivy filesystem scan
    local trivy_output=$(trivy fs --severity "${TRIVY_SEVERITY}" --exit-code 1 "${SCAN_PATH}" 2>&1)
    local trivy_exit_code=$?

    if [[ ${trivy_exit_code} -eq 0 ]]; then
        update_result "vulnerability_scan" "PASS" "No ${TRIVY_SEVERITY} vulnerabilities found"
    else
        update_result "vulnerability_scan" "FAIL" "${TRIVY_SEVERITY} vulnerabilities detected" "${trivy_output}"
        return 1
    fi

    return 0
}

# SBOM Generation
generate_sbom() {
    if [[ "${SKIP_SBOM}" == "true" ]]; then
        update_result "sbom_generation" "SKIP" "SBOM generation skipped"
        return 0
    fi

    blue "📄 Generating Software Bill of Materials"

    local commit_sha=$(cd "${SCAN_PATH}" && git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    local sbom_file="${OUTPUT_DIR}/sbom/sbom-${commit_sha}.spdx.json"

    if syft dir:"${SCAN_PATH}" -o spdx-json > "${sbom_file}" 2>/dev/null; then
        update_result "sbom_generation" "PASS" "SBOM generated successfully" "File: ${sbom_file}"
    else
        local sbom_output=$(syft dir:"${SCAN_PATH}" -o spdx-json 2>&1)
        update_result "sbom_generation" "FAIL" "SBOM generation failed" "${sbom_output}"
        return 1
    fi

    return 0
}

# Cryptographic Attestation
generate_attestation() {
    blue "🔐 Generating cryptographic attestation"

    local commit_sha=$(cd "${SCAN_PATH}" && git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    local attestation_file="${OUTPUT_DIR}/attestations/attestation-${commit_sha}.intoto.jsonl"

    if [[ -f "${KEYS_DIR}/cosign.key" ]]; then
        # Sign with cosign if key is available
        if COSIGN_PASSWORD="" cosign attest --predicate "${RESULTS_FILE}" --key "${KEYS_DIR}/cosign.key" --output-file "${attestation_file}" --type custom >/dev/null 2>&1; then
            update_result "attestation" "PASS" "Cryptographic attestation generated" "File: ${attestation_file}"
        else
            local cosign_output=$(COSIGN_PASSWORD="" cosign attest --predicate "${RESULTS_FILE}" --key "${KEYS_DIR}/cosign.key" --output-file "${attestation_file}" --type custom 2>&1)
            update_result "attestation" "FAIL" "Cryptographic attestation failed" "${cosign_output}"
            return 1
        fi
    else
        # Generate unsigned attestation
        cp "${RESULTS_FILE}" "${attestation_file}"
        update_result "attestation" "SKIP" "No signing key available - generated unsigned attestation" "File: ${attestation_file}"
    fi

    return 0
}

# AI Analysis
run_ai_analysis() {
    if [[ "${SKIP_AI:-false}" == "true" ]]; then
        update_result "ai_analysis" "SKIP" "AI analysis skipped"
        return 0
    fi

    blue "🤖 Running AI-powered compliance analysis..."

    local analysis_file="${OUTPUT_DIR}/reports/ai-analysis-$(date -u +%Y%m%d_%H%M%S).json"

    if python3 /usr/local/bin/bedrock_analyzer.py "${RESULTS_FILE}" --output "${analysis_file}" 2>/dev/null; then
        # Merge AI analysis into results file
        if command -v jq >/dev/null 2>&1 && [[ -f "${analysis_file}" ]]; then
            jq -s '.[0] * .[1]' "${RESULTS_FILE}" "${analysis_file}" > "${RESULTS_FILE}.tmp" && mv "${RESULTS_FILE}.tmp" "${RESULTS_FILE}"
            update_result "ai_analysis" "PASS" "AI analysis completed successfully"
        else
            update_result "ai_analysis" "SKIP" "AI analysis completed but could not merge results"
        fi
    else
        # AI analysis failed, but that's okay - the system should still work
        update_result "ai_analysis" "SKIP" "AI analysis unavailable (check AWS credentials or network)"
    fi

    return 0
}

# Output final results
output_results() {
    if [[ "${OUTPUT_FORMAT}" == "json" ]]; then
        cat "${RESULTS_FILE}"
    else
        blue "📊 Verification Results Summary"
        echo "================================"

        if command -v jq >/dev/null 2>&1 && [[ -f "${RESULTS_FILE}" ]]; then
            local total=$(jq -r '.summary.total' "${RESULTS_FILE}")
            local passed=$(jq -r '.summary.passed' "${RESULTS_FILE}")
            local failed=$(jq -r '.summary.failed' "${RESULTS_FILE}")
            local skipped=$(jq -r '.summary.skipped' "${RESULTS_FILE}")

            echo "Total checks: ${total}"
            green "Passed: ${passed}"
            red "Failed: ${failed}"
            yellow "Skipped: ${skipped}"

            # Display AI analysis if available
            local ai_enabled=$(jq -r '.ai_analysis.enabled // false' "${RESULTS_FILE}")
            if [[ "${ai_enabled}" == "true" ]]; then
                echo ""
                blue "🤖 AI Analysis Summary"
                echo "======================"

                local ai_mode=$(jq -r '.ai_analysis.mode // "unknown"' "${RESULTS_FILE}")
                local ai_priority=$(jq -r '.ai_analysis.priority // "unknown"' "${RESULTS_FILE}")
                local ai_summary=$(jq -r '.ai_analysis.summary // "No summary available"' "${RESULTS_FILE}")

                echo "Mode: ${ai_mode}"
                echo "Priority: ${ai_priority}"
                echo "Summary: ${ai_summary}"

                # Show remediation steps if available and there are failures
                if [[ ${failed} -gt 0 ]]; then
                    echo ""
                    blue "🔧 Remediation Recommendations:"
                    jq -r '.ai_analysis.remediation_steps[]? | "  • \(.check): \(.fix)"' "${RESULTS_FILE}" 2>/dev/null || true

                    local effort=$(jq -r '.ai_analysis.estimated_effort // "unknown"' "${RESULTS_FILE}")
                    echo ""
                    echo "Estimated effort: ${effort}"
                fi
            fi

            echo ""
            echo "Results saved to: ${RESULTS_FILE}"

            if [[ -d "${OUTPUT_DIR}/sbom" ]]; then
                echo "SBOM files: ${OUTPUT_DIR}/sbom/"
            fi
            if [[ -d "${OUTPUT_DIR}/attestations" ]]; then
                echo "Attestations: ${OUTPUT_DIR}/attestations/"
            fi

            echo ""
            if [[ ${failed} -eq 0 ]]; then
                green "🎉 All compliance checks passed!"
            else
                red "❌ ${failed} compliance issues found"
                if [[ "${ai_enabled}" == "true" ]]; then
                    echo "See AI recommendations above for remediation guidance."
                else
                    echo "Review the detailed output above for remediation steps."
                fi
            fi
        else
            yellow "Results processing completed (jq not available for detailed summary)"
        fi
    fi
}

# Main verification function
verify() {
    local overall_result=0

    # Run all verification steps
    verify_helm_chart || overall_result=1
    verify_policies || overall_result=1
    verify_dockerfile || overall_result=1
    verify_vulnerabilities || overall_result=1
    generate_sbom || overall_result=1

    # Run AI analysis after all checks are complete
    run_ai_analysis || true  # Don't fail overall verification if AI analysis fails

    generate_attestation || overall_result=1

    # Output results
    output_results

    return ${overall_result}
}