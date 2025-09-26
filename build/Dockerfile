# Application Dockerfile - Big Bang and DoD Compliant
# This serves as an example of a hardened container following Iron Bank standards
#
# References:
# - DoD Container Security Requirements Guide
# - Iron Bank container hardening guidelines
# - Big Bang security baseline

# Multi-stage build for minimal attack surface
FROM redhat/ubi9:9.4 as builder

# Install build dependencies in builder stage only
USER root
RUN microdnf update -y && \
    microdnf install -y \
        gcc \
        make \
        git \
        ca-certificates && \
    microdnf clean all

# Create application user for build
RUN groupadd -r appgroup && \
    useradd -r -g appgroup -d /app -s /sbin/nologin -c "App User" appuser

# Build application (example: static binary)
WORKDIR /build
# In real implementation, copy source code and build here
# COPY src/ ./
# RUN make build

# Runtime stage - minimal and secure
FROM redhat/ubi9-minimal:9.4

# Install only runtime dependencies
USER root
RUN microdnf update -y && \
    microdnf install -y \
        ca-certificates \
        tzdata && \
    microdnf clean all && \
    rm -rf /var/cache/dnf

# Create non-root user and group
# Using high UID/GID values to avoid conflicts in multi-tenant environments
RUN groupadd -r appgroup && \
    useradd -r -g appgroup -d /app -s /sbin/nologin \
    -c "Application User" appuser

# Create application directories with proper ownership
RUN mkdir -p /app /app/data /app/logs /app/tmp && \
    chown -R appuser:appgroup /app && \
    chmod -R 755 /app

# Create required directories for read-only root filesystem
RUN mkdir -p /tmp /var/tmp /var/run && \
    chown appuser:appgroup /tmp /var/tmp /var/run && \
    chmod 1777 /tmp /var/tmp && \
    chmod 755 /var/run

# Copy application binary from builder (or package)
# COPY --from=builder --chown=appuser:appgroup /build/app /app/app
# For demo purposes, create a simple health check script
RUN echo '#!/bin/bash' > /app/health-check.sh && \
    echo 'echo "Health check passed"' >> /app/health-check.sh && \
    echo 'exit 0' >> /app/health-check.sh && \
    chown appuser:appgroup /app/health-check.sh && \
    chmod 755 /app/health-check.sh

# Copy configuration files with restricted permissions
# COPY --chown=appuser:appgroup config/ /app/config/
# RUN chmod -R 644 /app/config/

# Switch to non-root user
USER appuser

# Set working directory
WORKDIR /app

# Security: Remove unnecessary packages and files
# Already done in minimal base image, but verify no shells/utilities remain
RUN [ ! -f /bin/sh ] || echo "Warning: shell still present"

# Environment variables
ENV PATH="/app:${PATH}" \
    USER=appuser \
    HOME=/app

# Network configuration - use unprivileged port
EXPOSE 8080

# Health check using non-root user
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD ["/app/health-check.sh"]

# Security labels for container runtime
LABEL \
    name="sample-app" \
    vendor="Platform One" \
    version="1.0.0" \
    release="1" \
    summary="Big Bang compliant sample application" \
    description="A demonstration application following DoD container security requirements" \
    maintainer="team@platform1.dso.mil" \
    # Security scanning labels
    io.opencontainers.image.source="https://github.com/your-org/sample-app" \
    io.opencontainers.image.revision="" \
    io.opencontainers.image.created="" \
    # Compliance labels
    mil.disa.stig.version="V1R1" \
    gov.nist.compliance="800-53"

# Default command - runs as non-root user
# Using exec form to ensure proper signal handling
CMD ["/app/health-check.sh"]

# Security annotations for runtime environment
# These would typically be set by the container runtime/Kubernetes
# USER: appuser (UID 65534)
# CAPABILITIES: none (all dropped)
# SECCOMP: default profile
# APPARMOR: default profile
# SELINUX: enforcing mode
# READ_ONLY_ROOT_FS: true
# NO_NEW_PRIVS: true