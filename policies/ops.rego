# OPA Policy: Operational Readiness
# Enforces Big Bang operational standards for production readiness
#
# References:
# - Big Bang package integration requirements
# - Kubernetes production best practices
# - DoD Container Security Requirements Guide

package ops

import rego.v1

# DENY: Missing resource requests
# Big Bang requires resource requests for proper scheduling and QoS
# This prevents resource starvation and enables cluster autoscaling
deny contains msg if {
	input.kind in ["Deployment", "StatefulSet", "DaemonSet"]
	container := input.spec.template.spec.containers[_]
	not container.resources.requests.cpu
	msg := sprintf("Container '%s' must specify CPU resource request", [container.name])
}

deny contains msg if {
	input.kind in ["Deployment", "StatefulSet", "DaemonSet"]
	container := input.spec.template.spec.containers[_]
	not container.resources.requests.memory
	msg := sprintf("Container '%s' must specify memory resource request", [container.name])
}

# DENY: Missing resource limits
# DoD Container Security Requirements mandate resource limits
# to prevent resource exhaustion attacks and ensure fair resource sharing
deny contains msg if {
	input.kind in ["Deployment", "StatefulSet", "DaemonSet"]
	container := input.spec.template.spec.containers[_]
	not container.resources.limits.cpu
	msg := sprintf("Container '%s' must specify CPU resource limit", [container.name])
}

deny contains msg if {
	input.kind in ["Deployment", "StatefulSet", "DaemonSet"]
	container := input.spec.template.spec.containers[_]
	not container.resources.limits.memory
	msg := sprintf("Container '%s' must specify memory resource limit", [container.name])
}

# DENY: Missing liveness probe
# Big Bang operational standards require liveness probes
# for automatic recovery from unhealthy states
deny contains msg if {
	input.kind in ["Deployment", "StatefulSet", "DaemonSet"]
	container := input.spec.template.spec.containers[_]
	not container.livenessProbe
	msg := sprintf("Container '%s' must define livenessProbe for health monitoring", [container.name])
}

# DENY: Missing readiness probe
# Big Bang requires readiness probes to ensure traffic
# is only routed to healthy pods
deny contains msg if {
	input.kind in ["Deployment", "StatefulSet", "DaemonSet"]
	container := input.spec.template.spec.containers[_]
	not container.readinessProbe
	msg := sprintf("Container '%s' must define readinessProbe for traffic management", [container.name])
}

# DENY: Excessive CPU limits
# Prevent resource hogging that could impact other workloads
# in shared Big Bang clusters
deny contains msg if {
	input.kind in ["Deployment", "StatefulSet", "DaemonSet"]
	container := input.spec.template.spec.containers[_]
	cpu_limit := container.resources.limits.cpu
	contains(cpu_limit, "m")
	cpu_millicores := to_number(trim_suffix(cpu_limit, "m"))
	cpu_millicores > 4000
	msg := sprintf("Container '%s' CPU limit '%s' exceeds 4000m. Use horizontal scaling instead", [container.name, cpu_limit])
}

deny contains msg if {
	input.kind in ["Deployment", "StatefulSet", "DaemonSet"]
	container := input.spec.template.spec.containers[_]
	cpu_limit := container.resources.limits.cpu
	not contains(cpu_limit, "m")
	cpu_cores := to_number(cpu_limit)
	cpu_cores > 4
	msg := sprintf("Container '%s' CPU limit '%s' exceeds 4 cores. Use horizontal scaling instead", [container.name, cpu_limit])
}

# DENY: Excessive memory limits
# Prevent memory exhaustion in Big Bang shared infrastructure
deny contains msg if {
	input.kind in ["Deployment", "StatefulSet", "DaemonSet"]
	container := input.spec.template.spec.containers[_]
	mem_limit := container.resources.limits.memory
	contains(mem_limit, "Gi")
	mem_gib := to_number(trim_suffix(mem_limit, "Gi"))
	mem_gib > 8
	msg := sprintf("Container '%s' memory limit '%s' exceeds 8Gi. Use horizontal scaling instead", [container.name, mem_limit])
}

# DENY: Missing security context
# DoD Container Security Requirements mandate explicit security contexts
deny contains msg if {
	input.kind in ["Deployment", "StatefulSet", "DaemonSet"]
	not input.spec.template.spec.securityContext
	msg := "Pod must define securityContext for security compliance"
}

# DENY: Writable root filesystem
# Big Bang security standards require read-only root filesystem
# to prevent runtime tampering
deny contains msg if {
	input.kind in ["Deployment", "StatefulSet", "DaemonSet"]
	container := input.spec.template.spec.containers[_]
	container.securityContext.readOnlyRootFilesystem != true
	msg := sprintf("Container '%s' must set readOnlyRootFilesystem: true for security", [container.name])
}

# DENY: Missing pod disruption budget for multi-replica deployments
# Big Bang operational requirements for high availability workloads
deny contains msg if {
	input.kind == "Deployment"
	input.spec.replicas > 1
	deployment_name := input.metadata.name
	not data.podDisruptionBudgets[deployment_name]
	msg := sprintf("Deployment '%s' with %d replicas should have a PodDisruptionBudget", [deployment_name, input.spec.replicas])
}

# WARN: Single replica deployment
# Big Bang recommends multiple replicas for production workloads
warn contains msg if {
	input.kind == "Deployment"
	input.spec.replicas == 1
	msg := sprintf("Deployment '%s' has only 1 replica. Consider increasing for high availability", [input.metadata.name])
}

# WARN: High probe timeout values
# Excessive probe timeouts can delay failure detection
warn contains msg if {
	input.kind in ["Deployment", "StatefulSet", "DaemonSet"]
	container := input.spec.template.spec.containers[_]
	container.livenessProbe.timeoutSeconds > 10
	msg := sprintf("Container '%s' liveness probe timeout %ds is high. Consider reducing for faster failure detection", [container.name, container.livenessProbe.timeoutSeconds])
}