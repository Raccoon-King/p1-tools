# OPA Policy: Network Security
# Enforces Big Bang network security and segmentation requirements
#
# References:
# - Big Bang Istio service mesh integration patterns
# - DoD Container Security Requirements Guide
# - Kubernetes Network Policy best practices
# - Zero Trust Architecture principles

package network

import rego.v1

# DENY: Missing NetworkPolicy for workloads
# Big Bang requires explicit network policies for zero trust networking
# Default deny-all with explicit allow rules follows DoD security principles
deny contains msg if {
	input.kind in ["Deployment", "StatefulSet", "DaemonSet"]
	app_name := input.metadata.labels.app
	namespace := input.metadata.namespace
	not data.networkPolicies[namespace][app_name]
	msg := sprintf("Workload '%s' in namespace '%s' must have a corresponding NetworkPolicy for network segmentation", [app_name, namespace])
}

# DENY: Service without explicit port definition
# Big Bang service mesh integration requires well-defined service ports
# for proper traffic management and security policy enforcement
deny contains msg if {
	input.kind == "Service"
	port := input.spec.ports[_]
	not port.name
	msg := sprintf("Service '%s' port %d must have a name for service mesh compatibility", [input.metadata.name, port.port])
}

deny contains msg if {
	input.kind == "Service"
	port := input.spec.ports[_]
	not port.protocol
	msg := sprintf("Service '%s' port %s must specify protocol (TCP/UDP)", [input.metadata.name, port.name])
}

# DENY: Ingress without TLS
# Big Bang security standards mandate encrypted traffic
# All external-facing services must use TLS encryption
deny contains msg if {
	input.kind == "Ingress"
	not input.spec.tls
	msg := sprintf("Ingress '%s' must define TLS configuration for encrypted traffic", [input.metadata.name])
}

deny contains msg if {
	input.kind == "Ingress"
	count(input.spec.tls) == 0
	msg := sprintf("Ingress '%s' must have at least one TLS configuration", [input.metadata.name])
}

# DENY: Ingress with HTTP-only routes
# All Ingress routes must be HTTPS to meet DoD encryption requirements
deny contains msg if {
	input.kind == "Ingress"
	rule := input.spec.rules[_]
	http_path := rule.http.paths[_]
	tls_hosts := {host | host := input.spec.tls[_].hosts[_]}
	not rule.host in tls_hosts
	msg := sprintf("Ingress '%s' has HTTP rule for host '%s' without TLS configuration", [input.metadata.name, rule.host])
}

# DENY: Overly permissive NetworkPolicy
# NetworkPolicy should not allow all traffic (empty selectors)
# This violates zero trust principles required by Big Bang
deny contains msg if {
	input.kind == "NetworkPolicy"
	ingress_rule := input.spec.ingress[_]
	not ingress_rule.from
	msg := sprintf("NetworkPolicy '%s' has ingress rule allowing all sources. Specify explicit 'from' selectors", [input.metadata.name])
}

deny contains msg if {
	input.kind == "NetworkPolicy"
	egress_rule := input.spec.egress[_]
	not egress_rule.to
	msg := sprintf("NetworkPolicy '%s' has egress rule allowing all destinations. Specify explicit 'to' selectors", [input.metadata.name])
}

# DENY: NetworkPolicy allowing all pods in namespace
# Overly broad namespace selectors violate micro-segmentation principles
deny contains msg if {
	input.kind == "NetworkPolicy"
	ingress_rule := input.spec.ingress[_]
	from_rule := ingress_rule.from[_]
	from_rule.namespaceSelector
	count(from_rule.namespaceSelector.matchLabels) == 0
	count(from_rule.namespaceSelector.matchExpressions) == 0
	msg := sprintf("NetworkPolicy '%s' allows traffic from all namespaces. Use specific namespace labels", [input.metadata.name])
}

# DENY: Service account without explicit definition
# Big Bang requires explicit service accounts for workload identity
# and integration with Istio service mesh RBAC
deny contains msg if {
	input.kind in ["Deployment", "StatefulSet", "DaemonSet", "Job"]
	not input.spec.template.spec.serviceAccountName
	msg := sprintf("Workload '%s' must specify serviceAccountName for identity management", [input.metadata.name])
}

deny contains msg if {
	input.kind in ["Deployment", "StatefulSet", "DaemonSet", "Job"]
	input.spec.template.spec.serviceAccountName == "default"
	msg := sprintf("Workload '%s' should not use 'default' service account. Create dedicated service account", [input.metadata.name])
}

# DENY: Host network usage
# Using host network bypasses network policies and service mesh
# This is prohibited in Big Bang multi-tenant environments
deny contains msg if {
	input.kind in ["Deployment", "StatefulSet", "DaemonSet", "Job"]
	input.spec.template.spec.hostNetwork == true
	msg := sprintf("Workload '%s' cannot use hostNetwork. It bypasses network security controls", [input.metadata.name])
}

# DENY: Host port usage
# Host ports create conflicts in shared environments
# and bypass service mesh traffic management
deny contains msg if {
	input.kind in ["Deployment", "StatefulSet", "DaemonSet"]
	container := input.spec.template.spec.containers[_]
	port := container.ports[_]
	port.hostPort
	msg := sprintf("Container '%s' cannot use hostPort. Use Service for port exposure", [container.name])
}

# WARN: Service without app selector
# Services should use consistent labeling for observability
# and proper integration with service mesh
warn contains msg if {
	input.kind == "Service"
	not input.spec.selector.app
	msg := sprintf("Service '%s' should include 'app' label selector for consistency", [input.metadata.name])
}

# WARN: Missing Istio sidecar injection annotation
# Big Bang uses Istio service mesh for traffic management
# Workloads should explicitly opt-in or opt-out of sidecar injection
warn contains msg if {
	input.kind in ["Deployment", "StatefulSet", "DaemonSet"]
	not input.spec.template.metadata.annotations["sidecar.istio.io/inject"]
	msg := sprintf("Workload '%s' should specify sidecar.istio.io/inject annotation for Istio integration", [input.metadata.name])
}

# WARN: NetworkPolicy without egress rules
# Default deny egress may break legitimate external dependencies
# Consider explicit egress rules for required external services
warn contains msg if {
	input.kind == "NetworkPolicy"
	input.spec.policyTypes[_] == "Egress"
	count(input.spec.egress) == 0
	msg := sprintf("NetworkPolicy '%s' blocks all egress traffic. Consider allowing required external services", [input.metadata.name])
}