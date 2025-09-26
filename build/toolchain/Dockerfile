# P1 Dev Guard Toolchain Container
# Contains all tools needed for Big Bang compliance verification

FROM registry.internal/ironbank/redhat/ubi/ubi9:9.4 as base

# Install base dependencies
RUN microdnf update -y && \
    microdnf install -y \
        curl \
        git \
        jq \
        unzip \
        tar \
        bash \
        ca-certificates && \
    microdnf clean all

# Tool versions (pin for reproducibility)
ENV HELM_VERSION=3.14.0
ENV CONFTEST_VERSION=0.49.1
ENV HADOLINT_VERSION=2.12.0
ENV TRIVY_VERSION=0.50.1
ENV SYFT_VERSION=0.105.0
ENV COSIGN_VERSION=2.2.3
ENV KUBECONFORM_VERSION=0.6.4
ENV YAMLLINT_VERSION=1.35.1

# Install Helm
RUN curl -fsSL https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz | \
    tar -xzC /tmp && \
    mv /tmp/linux-amd64/helm /usr/local/bin/helm && \
    chmod +x /usr/local/bin/helm

# Install Conftest (OPA policy testing)
RUN curl -fsSL https://github.com/open-policy-agent/conftest/releases/download/v${CONFTEST_VERSION}/conftest_${CONFTEST_VERSION}_linux_amd64.tar.gz | \
    tar -xzC /tmp && \
    mv /tmp/conftest /usr/local/bin/conftest && \
    chmod +x /usr/local/bin/conftest

# Install Hadolint (Dockerfile linting)
RUN curl -fsSL https://github.com/hadolint/hadolint/releases/download/v${HADOLINT_VERSION}/hadolint-Linux-x86_64 \
    -o /usr/local/bin/hadolint && \
    chmod +x /usr/local/bin/hadolint

# Install Trivy (vulnerability scanning)
RUN curl -fsSL https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz | \
    tar -xzC /tmp && \
    mv /tmp/trivy /usr/local/bin/trivy && \
    chmod +x /usr/local/bin/trivy

# Install Syft (SBOM generation)
RUN curl -fsSL https://github.com/anchore/syft/releases/download/v${SYFT_VERSION}/syft_${SYFT_VERSION}_linux_amd64.tar.gz | \
    tar -xzC /tmp && \
    mv /tmp/syft /usr/local/bin/syft && \
    chmod +x /usr/local/bin/syft

# Install Cosign (cryptographic signing)
RUN curl -fsSL https://github.com/sigstore/cosign/releases/download/v${COSIGN_VERSION}/cosign-linux-amd64 \
    -o /usr/local/bin/cosign && \
    chmod +x /usr/local/bin/cosign

# Install Kubeconform (Kubernetes manifest validation)
RUN curl -fsSL https://github.com/yannh/kubeconform/releases/download/v${KUBECONFORM_VERSION}/kubeconform-linux-amd64.tar.gz | \
    tar -xzC /tmp && \
    mv /tmp/kubeconform /usr/local/bin/kubeconform && \
    chmod +x /usr/local/bin/kubeconform

# Install Python and dependencies
RUN microdnf install -y python3 python3-pip && \
    pip3 install \
        yamllint==${YAMLLINT_VERSION} \
        boto3==1.34.44 \
        botocore==1.34.44 \
        requests==2.31.0 \
        jinja2==3.1.3

# Install chart-testing
RUN curl -fsSL https://github.com/helm/chart-testing/releases/download/v3.10.1/chart-testing_3.10.1_linux_amd64.tar.gz | \
    tar -xzC /tmp && \
    mv /tmp/ct /usr/local/bin/ct && \
    chmod +x /usr/local/bin/ct

# Copy OPA policies into the container
COPY policies/ /policies/

# Copy entrypoint and verification scripts
COPY build/toolchain/entrypoint.sh /usr/local/bin/p1-verify
COPY build/toolchain/verify.sh /usr/local/bin/verify.sh
COPY build/toolchain/bedrock_analyzer.py /usr/local/bin/bedrock_analyzer.py

# Make scripts executable
RUN chmod +x /usr/local/bin/p1-verify /usr/local/bin/verify.sh /usr/local/bin/bedrock_analyzer.py

# Create configuration directory and default config
RUN mkdir -p /etc/p1guard
RUN cat > /etc/p1guard/config << 'EOF'
# P1 Dev Guard Default Configuration
IRONBANK_MIRROR=registry.internal/ironbank
TRIVY_SEVERITY=HIGH,CRITICAL
HADOLINT_IGNORE=DL3008,DL3009
EOF

# Create non-root user for security
RUN groupadd -r p1guard && useradd -r -g p1guard -s /bin/bash p1guard

# Create directories that might be needed
RUN mkdir -p /keys /workspace && \
    chown p1guard:p1guard /keys /workspace

# Switch to non-root user
USER p1guard

# Set working directory
WORKDIR /workspace

# Verify installations
RUN helm version --client && \
    conftest --version && \
    hadolint --version && \
    trivy --version && \
    syft version && \
    cosign version && \
    kubeconform -v && \
    yamllint --version && \
    ct version

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD p1-verify --version || exit 1

# Default entrypoint
ENTRYPOINT ["/usr/local/bin/p1-verify"]
CMD ["--help"]