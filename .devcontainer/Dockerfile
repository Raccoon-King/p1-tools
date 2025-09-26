# P1 Dev Guard Development Container
# Based on official devcontainer base image with Big Bang tools pre-installed

FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    gnupg \
    lsb-release \
    ca-certificates \
    software-properties-common \
    build-essential \
    git \
    jq \
    unzip \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Install internal CA certificates for air-gapped environment
# Copy your organization's CA certificates to .devcontainer/certs/
COPY certs/*.crt /usr/local/share/ca-certificates/ 2>/dev/null || true
RUN update-ca-certificates

# Install Docker CLI (for docker-outside-of-docker)
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y docker-ce-cli \
    && rm -rf /var/lib/apt/lists/*

# Tool versions
ENV HELM_VERSION=3.14.0
ENV CONFTEST_VERSION=0.49.1
ENV HADOLINT_VERSION=2.12.0
ENV TRIVY_VERSION=0.50.1
ENV SYFT_VERSION=0.105.0
ENV COSIGN_VERSION=2.2.3
ENV FLUX_VERSION=2.2.3
ENV K3D_VERSION=5.6.3

# Install Helm
RUN curl -fsSL https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz | \
    tar -xzC /tmp && \
    mv /tmp/linux-amd64/helm /usr/local/bin/helm && \
    chmod +x /usr/local/bin/helm

# Install kubectl (latest stable)
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install conftest
RUN curl -fsSL https://github.com/open-policy-agent/conftest/releases/download/v${CONFTEST_VERSION}/conftest_${CONFTEST_VERSION}_linux_amd64.tar.gz | \
    tar -xzC /tmp && \
    mv /tmp/conftest /usr/local/bin/conftest && \
    chmod +x /usr/local/bin/conftest

# Install hadolint
RUN curl -fsSL https://github.com/hadolint/hadolint/releases/download/v${HADOLINT_VERSION}/hadolint-Linux-x86_64 \
    -o /usr/local/bin/hadolint && \
    chmod +x /usr/local/bin/hadolint

# Install trivy
RUN curl -fsSL https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz | \
    tar -xzC /tmp && \
    mv /tmp/trivy /usr/local/bin/trivy && \
    chmod +x /usr/local/bin/trivy

# Install syft
RUN curl -fsSL https://github.com/anchore/syft/releases/download/v${SYFT_VERSION}/syft_${SYFT_VERSION}_linux_amd64.tar.gz | \
    tar -xzC /tmp && \
    mv /tmp/syft /usr/local/bin/syft && \
    chmod +x /usr/local/bin/syft

# Install cosign
RUN curl -fsSL https://github.com/sigstore/cosign/releases/download/v${COSIGN_VERSION}/cosign-linux-amd64 \
    -o /usr/local/bin/cosign && \
    chmod +x /usr/local/bin/cosign

# Install Flux CLI
RUN curl -fsSL https://github.com/fluxcd/flux2/releases/download/v${FLUX_VERSION}/flux_${FLUX_VERSION}_linux_amd64.tar.gz | \
    tar -xzC /tmp && \
    mv /tmp/flux /usr/local/bin/flux && \
    chmod +x /usr/local/bin/flux

# Install k3d for local Kubernetes development
RUN curl -fsSL https://github.com/k3d-io/k3d/releases/download/v${K3D_VERSION}/k3d-linux-amd64 \
    -o /usr/local/bin/k3d && \
    chmod +x /usr/local/bin/k3d

# Install yamllint
RUN pip3 install yamllint==1.35.1

# Install AWS CLI v2
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf aws awscliv2.zip

# Install additional development tools
RUN pip3 install \
    pre-commit \
    black \
    flake8 \
    pytest

# Setup development user
USER vscode
WORKDIR /workspace

# Install Helm plugins
RUN helm plugin install https://github.com/chartmuseum/helm-push || true
RUN helm plugin install https://github.com/helm/helm-2to3 || true

# Create directories for keys and config
RUN mkdir -p ~/.p1devguard/keys ~/.kube ~/.aws

# Set git configuration for development
RUN git config --global init.defaultBranch main \
    && git config --global pull.rebase false \
    && git config --global core.editor "code --wait" \
    && git config --global core.autocrlf input

# Create bash aliases for common tasks
RUN echo 'alias ll="ls -la"' >> ~/.bashrc \
    && echo 'alias k="kubectl"' >> ~/.bashrc \
    && echo 'alias p1verify="make verify"' >> ~/.bashrc \
    && echo 'alias p1lint="make lint"' >> ~/.bashrc \
    && echo 'export PATH=$PATH:/usr/local/bin' >> ~/.bashrc

# Set default shell to bash
SHELL ["/bin/bash", "-c"]

# Expose common development ports
EXPOSE 8080 3000 9090

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD helm version --client && kubectl version --client=true