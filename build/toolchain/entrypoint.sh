#!/bin/bash
set -euo pipefail

# P1 Dev Guard - Containerized Big Bang Verification Tool
# Standalone container entrypoint for any project structure

VERSION="2025.09.01"
WORKSPACE="/workspace"
OUTPUT_DIR="${WORKSPACE}/.p1-artifacts"
KEYS_DIR="${KEYS_DIR:-/keys}"

# Default configuration - can be overridden by environment variables
export IRONBANK_MIRROR="${IRONBANK_MIRROR:-registry.internal/ironbank}"
export TRIVY_SEVERITY="${TRIVY_SEVERITY:-HIGH,CRITICAL}"
export HADOLINT_IGNORE="${HADOLINT_IGNORE:-DL3008,DL3009}"

# Color output functions
red() { echo -e "\033[31m$*\033[0m"; }
green() { echo -e "\033[32m$*\033[0m"; }
yellow() { echo -e "\033[33m$*\033[0m"; }
blue() { echo -e "\033[34m$*\033[0m"; }
bold() { echo -e "\033[1m$*\033[0m"; }

# Usage information
usage() {
    cat << EOF
P1 Dev Guard - Big Bang Compliance Verification Tool v${VERSION}

USAGE:
    p1-verify [OPTIONS] [PATH]

OPTIONS:
    -h, --help              Show this help message
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
    --ai-model MODEL        AI model to use: claude-3-sonnet|claude-3-haiku|titan (default: claude-3-haiku)
    --ai-region REGION      AWS region for Bedrock (default: us-east-1)
    --format FORMAT         Output format: json|text (default: text)
    --ci                    CI mode: JSON output, proper exit codes
    --config FILE           Load configuration from file

EXAMPLES:
    # Verify current directory (auto-detect project structure)
    docker run --rm -v \$(pwd):/workspace p1guard

    # Verify specific Helm chart
    docker run --rm -v \$(pwd):/workspace p1guard --chart ./helm/myapp

    # CI/CD mode with JSON output
    docker run --rm -v \$(pwd):/workspace p1guard --ci --format json

    # With AI analysis and AWS credentials
    docker run --rm -v \$(pwd):/workspace -e AWS_PROFILE=default p1guard

    # Skip AI analysis (faster for basic compliance checks)
    docker run --rm -v \$(pwd):/workspace p1guard --skip-ai

    # Use specific AI model
    docker run --rm -v \$(pwd):/workspace p1guard --ai-model claude-3-sonnet

ENVIRONMENT VARIABLES:
    IRONBANK_MIRROR         Iron Bank registry URL (default: registry.internal/ironbank)
    TRIVY_SEVERITY          Vulnerability severity levels (default: HIGH,CRITICAL)
    HADOLINT_IGNORE         Hadolint rules to ignore (default: DL3008,DL3009)
    KEYS_DIR                Directory containing signing keys (default: /keys)
    AWS_PROFILE             AWS profile for Bedrock access
    AWS_ACCESS_KEY_ID       AWS access key (for Bedrock)
    AWS_SECRET_ACCESS_KEY   AWS secret key (for Bedrock)
    AWS_REGION              AWS region (for Bedrock)

EXIT CODES:
    0    All checks passed
    1    Policy violations or security issues found
    2    Tool execution error
    3    Invalid arguments or missing files
EOF
}

# Parse command line arguments
parse_args() {
    CHART_PATH=""
    DOCKERFILE_PATH=""
    MANIFESTS_PATH=""
    SCAN_PATH="${WORKSPACE}"
    SKIP_HELM=false
    SKIP_DOCKER=false
    SKIP_POLICIES=false
    SKIP_SCAN=false
    SKIP_SBOM=false
    SKIP_AI=false
    AI_MODEL="claude-3-haiku"
    AI_REGION="us-east-1"
    OUTPUT_FORMAT="text"
    CI_MODE=false
    CONFIG_FILE=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -v|--version)
                echo "P1 Dev Guard v${VERSION}"
                exit 0
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            --chart)
                CHART_PATH="$2"
                shift 2
                ;;
            --dockerfile)
                DOCKERFILE_PATH="$2"
                shift 2
                ;;
            --manifests)
                MANIFESTS_PATH="$2"
                shift 2
                ;;
            --skip-helm)
                SKIP_HELM=true
                shift
                ;;
            --skip-docker)
                SKIP_DOCKER=true
                shift
                ;;
            --skip-policies)
                SKIP_POLICIES=true
                shift
                ;;
            --skip-scan)
                SKIP_SCAN=true
                shift
                ;;
            --skip-sbom)
                SKIP_SBOM=true
                shift
                ;;
            --skip-ai)
                SKIP_AI=true
                shift
                ;;
            --ai-model)
                AI_MODEL="$2"
                shift 2
                ;;
            --ai-region)
                AI_REGION="$2"
                shift 2
                ;;
            --format)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            --ci)
                CI_MODE=true
                OUTPUT_FORMAT="json"
                shift
                ;;
            --config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -*)
                red "Unknown option: $1"
                usage
                exit 3
                ;;
            *)
                SCAN_PATH="$1"
                shift
                ;;
        esac
    done

    # Convert relative paths to absolute
    if [[ -n "${CHART_PATH}" && "${CHART_PATH:0:1}" != "/" ]]; then
        CHART_PATH="${WORKSPACE}/${CHART_PATH}"
    fi
    if [[ -n "${DOCKERFILE_PATH}" && "${DOCKERFILE_PATH:0:1}" != "/" ]]; then
        DOCKERFILE_PATH="${WORKSPACE}/${DOCKERFILE_PATH}"
    fi
    if [[ -n "${MANIFESTS_PATH}" && "${MANIFESTS_PATH:0:1}" != "/" ]]; then
        MANIFESTS_PATH="${WORKSPACE}/${MANIFESTS_PATH}"
    fi
    if [[ "${SCAN_PATH:0:1}" != "/" ]]; then
        SCAN_PATH="${WORKSPACE}/${SCAN_PATH}"
    fi
    if [[ "${OUTPUT_DIR:0:1}" != "/" ]]; then
        OUTPUT_DIR="${WORKSPACE}/${OUTPUT_DIR}"
    fi

    # Export AI configuration
    export SKIP_AI AI_MODEL AI_REGION
}

# Auto-detect project structure
auto_detect() {
    blue "🔍 Auto-detecting project structure in ${SCAN_PATH}"

    # Find Helm charts
    if [[ -z "${CHART_PATH}" ]]; then
        local charts=($(find "${SCAN_PATH}" -name "Chart.yaml" -type f 2>/dev/null | head -5))
        if [[ ${#charts[@]} -gt 0 ]]; then
            CHART_PATH=$(dirname "${charts[0]}")
            green "📊 Found Helm chart: ${CHART_PATH}"
        fi
    fi

    # Find Dockerfiles
    if [[ -z "${DOCKERFILE_PATH}" ]]; then
        local dockerfiles=($(find "${SCAN_PATH}" -name "Dockerfile" -type f 2>/dev/null | head -1))
        if [[ ${#dockerfiles[@]} -gt 0 ]]; then
            DOCKERFILE_PATH="${dockerfiles[0]}"
            green "🐳 Found Dockerfile: ${DOCKERFILE_PATH}"
        fi
    fi

    # Find Kubernetes manifests
    if [[ -z "${MANIFESTS_PATH}" ]]; then
        local manifests=($(find "${SCAN_PATH}" -name "*.yaml" -o -name "*.yml" | xargs grep -l "apiVersion:" 2>/dev/null | head -1))
        if [[ ${#manifests[@]} -gt 0 ]]; then
            MANIFESTS_PATH=$(dirname "${manifests[0]}")
            green "☸️  Found Kubernetes manifests in: ${MANIFESTS_PATH}"
        fi
    fi

    # Summary of detection
    if [[ -n "${CHART_PATH}" || -n "${DOCKERFILE_PATH}" || -n "${MANIFESTS_PATH}" ]]; then
        green "✅ Project structure detected successfully"
    else
        yellow "⚠️  No recognizable project structure found"
        yellow "   Continuing with filesystem scan only"
    fi
}

# Initialize results tracking
init_results() {
    local commit_sha="${GITHUB_SHA:-$(cd "${SCAN_PATH}" && git rev-parse --short HEAD 2>/dev/null || echo "unknown")}"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    mkdir -p "${OUTPUT_DIR}"/{reports,sbom,attestations}

    RESULTS_FILE="${OUTPUT_DIR}/reports/results-${timestamp}.json"

    cat > "${RESULTS_FILE}" << EOF
{
  "version": "${VERSION}",
  "timestamp": "${timestamp}",
  "commit": "${commit_sha}",
  "scan_path": "${SCAN_PATH}",
  "chart_path": "${CHART_PATH:-null}",
  "dockerfile_path": "${DOCKERFILE_PATH:-null}",
  "manifests_path": "${MANIFESTS_PATH:-null}",
  "configuration": {
    "ironbank_mirror": "${IRONBANK_MIRROR}",
    "trivy_severity": "${TRIVY_SEVERITY}",
    "hadolint_ignore": "${HADOLINT_IGNORE}"
  },
  "checks": {},
  "summary": {
    "total": 0,
    "passed": 0,
    "failed": 0,
    "skipped": 0
  }
}
EOF
}

# Update results
update_result() {
    local check="$1"
    local status="$2"
    local message="$3"
    local details="${4:-}"

    if command -v jq >/dev/null 2>&1; then
        jq --arg check "$check" --arg status "$status" --arg message "$message" --arg details "$details" \
            '.checks[$check] = {
                "status": $status,
                "message": $message,
                "details": ($details | if . == "" then null else . end)
            } |
            .summary.total += 1 |
            if $status == "PASS" then .summary.passed += 1
            elif $status == "FAIL" then .summary.failed += 1
            else .summary.skipped += 1
            end' \
            "${RESULTS_FILE}" > "${RESULTS_FILE}.tmp" && mv "${RESULTS_FILE}.tmp" "${RESULTS_FILE}"
    fi

    # Output to console based on format
    if [[ "${OUTPUT_FORMAT}" == "text" ]]; then
        case $status in
            "PASS") green "  ✅ ${check}: ${message}" ;;
            "FAIL") red "  ❌ ${check}: ${message}" ;;
            "SKIP") yellow "  ⏭️  ${check}: ${message}" ;;
        esac
    fi
}

# Load configuration from file if specified
load_config() {
    if [[ -n "${CONFIG_FILE}" && -f "${CONFIG_FILE}" ]]; then
        blue "📋 Loading configuration from ${CONFIG_FILE}"
        source "${CONFIG_FILE}"
    fi
}

# Source verification logic
source /usr/local/bin/verify.sh

# Main entry point
main() {
    # Print banner unless in CI mode
    if [[ "${CI_MODE:-false}" != "true" ]]; then
        bold "P1 Dev Guard - Big Bang Compliance Verification v${VERSION}"
        echo "======================================================"
    fi

    parse_args "$@"
    load_config
    auto_detect
    init_results
    verify

    # Return appropriate exit code
    if command -v jq >/dev/null 2>&1 && [[ -f "${RESULTS_FILE}" ]]; then
        local failed=$(jq -r '.summary.failed' "${RESULTS_FILE}")
        if [[ "${failed}" -gt 0 ]]; then
            exit 1
        fi
    fi

    exit 0
}

# Handle the case where this script is sourced vs executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi