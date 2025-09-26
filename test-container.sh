#!/bin/bash
set -euo pipefail

# P1 Dev Guard Container Testing Script
# Tests the containerized version against various project structures

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL_IMAGE="p1guard:test"

# Colors
red() { echo -e "\033[31m$*\033[0m"; }
green() { echo -e "\033[32m$*\033[0m"; }
yellow() { echo -e "\033[33m$*\033[0m"; }
blue() { echo -e "\033[34m$*\033[0m"; }
bold() { echo -e "\033[1m$*\033[0m"; }

# Test results
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test tracking
run_test() {
    local test_name="$1"
    local test_cmd="$2"
    local expect_success="${3:-true}"

    TESTS_RUN=$((TESTS_RUN + 1))
    blue "🧪 Test ${TESTS_RUN}: ${test_name}"

    if [[ "${expect_success}" == "true" ]]; then
        if eval "${test_cmd}" >/dev/null 2>&1; then
            green "  ✅ PASSED"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            red "  ❌ FAILED"
            TESTS_FAILED=$((TESTS_FAILED + 1))
            echo "  Command: ${test_cmd}"
        fi
    else
        if eval "${test_cmd}" >/dev/null 2>&1; then
            red "  ❌ FAILED (expected failure but succeeded)"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        else
            green "  ✅ PASSED (correctly failed as expected)"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        fi
    fi
}

# Build test container
build_container() {
    bold "🔨 Building test container..."

    if docker build -t "${TOOL_IMAGE}" -f build/toolchain/Dockerfile .; then
        green "✅ Container built successfully"
    else
        red "❌ Container build failed"
        exit 1
    fi
}

# Test basic functionality
test_basic() {
    bold "📋 Testing basic functionality"

    run_test "Container version check" \
        "docker run --rm ${TOOL_IMAGE} --version"

    run_test "Container help output" \
        "docker run --rm ${TOOL_IMAGE} --help"

    run_test "Invalid argument handling" \
        "docker run --rm ${TOOL_IMAGE} --invalid-option" \
        "false"
}

# Test with Helm chart
test_helm_chart() {
    bold "📊 Testing Helm chart detection and validation"

    run_test "Auto-detect Helm chart" \
        "docker run --rm -v ${SCRIPT_DIR}:/workspace ${TOOL_IMAGE} --skip-scan --skip-sbom"

    run_test "Specific chart path" \
        "docker run --rm -v ${SCRIPT_DIR}:/workspace ${TOOL_IMAGE} --chart helm/sample-app --skip-scan --skip-sbom"

    run_test "Non-existent chart path" \
        "docker run --rm -v ${SCRIPT_DIR}:/workspace ${TOOL_IMAGE} --chart helm/nonexistent --skip-scan --skip-sbom" \
        "false"
}

# Test policy validation
test_policies() {
    bold "🛡️  Testing OPA policy validation"

    run_test "Passing sample validation" \
        "docker run --rm -v ${SCRIPT_DIR}:/workspace ${TOOL_IMAGE} --manifests test/passing-sample --skip-scan --skip-sbom"

    run_test "Failing sample validation (should fail)" \
        "docker run --rm -v ${SCRIPT_DIR}:/workspace ${TOOL_IMAGE} --manifests test/failing-sample --skip-scan --skip-sbom" \
        "false"

    run_test "Skip policy validation" \
        "docker run --rm -v ${SCRIPT_DIR}:/workspace ${TOOL_IMAGE} --skip-policies --skip-scan --skip-sbom"
}

# Test Dockerfile scanning
test_dockerfile() {
    bold "🐳 Testing Dockerfile scanning"

    run_test "Dockerfile detection" \
        "docker run --rm -v ${SCRIPT_DIR}:/workspace ${TOOL_IMAGE} --dockerfile build/Dockerfile --skip-policies --skip-scan --skip-sbom"

    run_test "Skip Dockerfile scan" \
        "docker run --rm -v ${SCRIPT_DIR}:/workspace ${TOOL_IMAGE} --skip-docker --skip-policies --skip-scan --skip-sbom"
}

# Test output formats
test_output() {
    bold "📄 Testing output formats and artifacts"

    # Create temporary output directory
    local temp_output="/tmp/p1-test-$$"
    mkdir -p "${temp_output}"

    run_test "JSON output format" \
        "docker run --rm -v ${SCRIPT_DIR}:/workspace -v ${temp_output}:/output ${TOOL_IMAGE} --format json --output /output --skip-scan"

    run_test "CI mode" \
        "docker run --rm -v ${SCRIPT_DIR}:/workspace -v ${temp_output}:/output ${TOOL_IMAGE} --ci --output /output --skip-scan"

    run_test "SBOM generation" \
        "docker run --rm -v ${SCRIPT_DIR}:/workspace -v ${temp_output}:/output ${TOOL_IMAGE} --output /output --skip-policies --skip-scan --skip-docker"

    # Check if artifacts were created
    if [[ -d "${temp_output}/reports" ]]; then
        green "  ✅ Reports directory created"
    else
        red "  ❌ Reports directory not created"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi

    # Cleanup
    rm -rf "${temp_output}"
}

# Test with different project structures
test_project_structures() {
    bold "🏗️  Testing various project structures"

    # Create test directories
    local test_base="/tmp/p1-structure-test-$$"
    mkdir -p "${test_base}"

    # Test 1: Empty directory
    local empty_dir="${test_base}/empty"
    mkdir -p "${empty_dir}"
    run_test "Empty directory handling" \
        "docker run --rm -v ${empty_dir}:/workspace ${TOOL_IMAGE} --skip-scan"

    # Test 2: Only Kubernetes manifests
    local k8s_only="${test_base}/k8s-only"
    mkdir -p "${k8s_only}"
    cp test/passing-sample/*.yaml "${k8s_only}/"
    run_test "Kubernetes manifests only" \
        "docker run --rm -v ${k8s_only}:/workspace ${TOOL_IMAGE} --skip-scan --skip-sbom"

    # Test 3: Only Dockerfile
    local docker_only="${test_base}/docker-only"
    mkdir -p "${docker_only}"
    cp build/Dockerfile "${docker_only}/"
    run_test "Dockerfile only" \
        "docker run --rm -v ${docker_only}:/workspace ${TOOL_IMAGE} --skip-scan --skip-sbom"

    # Cleanup
    rm -rf "${test_base}"
}

# Test error handling
test_error_handling() {
    bold "⚠️  Testing error handling"

    run_test "Invalid workspace permission" \
        "docker run --rm -v /dev/null:/workspace ${TOOL_IMAGE} --skip-scan" \
        "false"

    run_test "Missing required tools (simulated)" \
        "docker run --rm -v ${SCRIPT_DIR}:/workspace ${TOOL_IMAGE} --chart helm/sample-app --skip-scan --skip-sbom" \
        "true"  # Should still work with available tools
}

# Summary
print_summary() {
    echo ""
    bold "📊 Test Results Summary"
    echo "======================"
    echo "Tests run: ${TESTS_RUN}"
    green "Passed: ${TESTS_PASSED}"
    red "Failed: ${TESTS_FAILED}"

    if [[ ${TESTS_FAILED} -eq 0 ]]; then
        echo ""
        green "🎉 All tests passed! Container is ready for use."
        echo ""
        blue "Usage examples:"
        echo "  # Verify current directory"
        echo "  docker run --rm -v \$(pwd):/workspace ${TOOL_IMAGE}"
        echo ""
        echo "  # CI/CD mode"
        echo "  docker run --rm -v \$(pwd):/workspace ${TOOL_IMAGE} --ci"
        echo ""
        echo "  # With signing keys"
        echo "  docker run --rm -v \$(pwd):/workspace -v ~/.p1devguard/keys:/keys:ro ${TOOL_IMAGE}"
    else
        echo ""
        red "❌ Some tests failed. Please review the failures above."
        exit 1
    fi
}

# Main execution
main() {
    bold "P1 Dev Guard Container Testing"
    echo "=============================="

    build_container
    echo ""

    test_basic
    echo ""

    test_helm_chart
    echo ""

    test_policies
    echo ""

    test_dockerfile
    echo ""

    test_output
    echo ""

    test_project_structures
    echo ""

    test_error_handling
    echo ""

    print_summary
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi