# OPA Policy: Container Image Security
# Enforces Big Bang container image standards and Iron Bank requirements
#
# References:
# - DoD Container Security Requirements Guide
# - Iron Bank container hardening standards
# - Big Bang package integration guidelines

package images

import rego.v1

# DENY: Images not from approved Iron Bank mirror
# Big Bang requires all container images to come from Iron Bank registry
# to ensure they meet DoD security standards and vulnerability scanning
deny contains msg if {
	input.kind in ["Deployment", "StatefulSet", "DaemonSet", "Job", "CronJob"]
	container := input.spec.template.spec.containers[_]
	not startswith(container.image, data.config.ironbank_mirror)
	msg := sprintf("Container image '%s' must use Iron Bank mirror: %s", [container.image, data.config.ironbank_mirror])
}

deny contains msg if {
	input.kind in ["Deployment", "StatefulSet", "DaemonSet", "Job", "CronJob"]
	container := input.spec.template.spec.initContainers[_]
	not startswith(container.image, data.config.ironbank_mirror)
	msg := sprintf("Init container image '%s' must use Iron Bank mirror: %s", [container.image, data.config.ironbank_mirror])
}

# DENY: Latest tag usage
# Using 'latest' tag breaks immutability and makes deployments non-deterministic
# Big Bang requires digest-pinned or semantic version tags for audit trail
deny contains msg if {
	input.kind in ["Deployment", "StatefulSet", "DaemonSet", "Job", "CronJob"]
	container := input.spec.template.spec.containers[_]
	endswith(container.image, ":latest")
	msg := sprintf("Container '%s' uses ':latest' tag. Use specific version or digest", [container.name])
}

deny contains msg if {
	input.kind in ["Deployment", "StatefulSet", "DaemonSet", "Job", "CronJob"]
	container := input.spec.template.spec.initContainers[_]
	endswith(container.image, ":latest")
	msg := sprintf("Init container '%s' uses ':latest' tag. Use specific version or digest", [container.name])
}

# DENY: Missing image digest
# Big Bang strongly recommends digest pinning for immutable deployments
# This ensures exact same container content across environments
deny contains msg if {
	input.kind in ["Deployment", "StatefulSet", "DaemonSet", "Job", "CronJob"]
	container := input.spec.template.spec.containers[_]
	not contains(container.image, "@sha256:")
	not regex.match(`:[0-9]+\.[0-9]+\.[0-9]+`, container.image)
	msg := sprintf("Container '%s' should use digest (@sha256:) or semantic version for immutability", [container.name])
}

# DENY: Privileged containers
# DoD Container Security Requirements prohibit privileged containers
# as they have full access to host resources
deny contains msg if {
	input.kind in ["Deployment", "StatefulSet", "DaemonSet", "Job", "CronJob"]
	container := input.spec.template.spec.containers[_]
	container.securityContext.privileged == true
	msg := sprintf("Container '%s' cannot run privileged. Use specific capabilities instead", [container.name])
}

# DENY: Root user execution
# Big Bang security standards require non-root container execution
# to follow principle of least privilege
deny contains msg if {
	input.kind in ["Deployment", "StatefulSet", "DaemonSet", "Job", "CronJob"]
	pod_spec := input.spec.template.spec
	pod_spec.securityContext.runAsUser == 0
	msg := "Pod cannot run as root user (UID 0). Set runAsUser to non-zero value"
}

deny contains msg if {
	input.kind in ["Deployment", "StatefulSet", "DaemonSet", "Job", "CronJob"]
	container := input.spec.template.spec.containers[_]
	container.securityContext.runAsUser == 0
	msg := sprintf("Container '%s' cannot run as root user (UID 0)", [container.name])
}

# DENY: Missing image pull policy
# Big Bang requires explicit pull policy to ensure image freshness
# and prevent stale cached images in production
deny contains msg if {
	input.kind in ["Deployment", "StatefulSet", "DaemonSet", "Job", "CronJob"]
	container := input.spec.template.spec.containers[_]
	not container.imagePullPolicy
	msg := sprintf("Container '%s' must specify imagePullPolicy (Always, IfNotPresent, or Never)", [container.name])
}

# WARN: Always pull policy with digest
# When using digest, IfNotPresent is more efficient than Always
warn contains msg if {
	input.kind in ["Deployment", "StatefulSet", "DaemonSet", "Job", "CronJob"]
	container := input.spec.template.spec.containers[_]
	contains(container.image, "@sha256:")
	container.imagePullPolicy == "Always"
	msg := sprintf("Container '%s' uses digest with Always pull policy. Consider IfNotPresent for efficiency", [container.name])
}