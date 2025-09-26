# OPA Policy: Pod Security Standards
# Enforces Big Bang Pod Security Standards and DoD container requirements
#
# References:
# - Kubernetes Pod Security Standards
# - DoD Container Security Requirements Guide
# - Big Bang security baseline policies
# - NSA Kubernetes Hardening Guide

package podsecurity

import rego.v1

# DENY: Privileged containers
# DoD Container Security Requirements prohibit privileged containers
# as they have unrestricted access to host resources
deny contains msg if {
	input.kind in ["Deployment", "StatefulSet", "DaemonSet", "Job"]
	container := input.spec.template.spec.containers[_]
	container.securityContext.privileged == true
	msg := sprintf("Container '%s' cannot run privileged. This violates DoD security requirements", [container.name])
}

# DENY: Privileged escalation
# Big Bang security baseline prevents privilege escalation attacks
deny contains msg if {
	input.kind in ["Deployment", "StatefulSet", "DaemonSet", "Job"]
	container := input.spec.template.spec.containers[_]
	container.securityContext.allowPrivilegeEscalation == true
	msg := sprintf("Container '%s' must set allowPrivilegeEscalation: false to prevent privilege escalation", [container.name])
}

# DENY: Root user execution
# DoD Container Security Requirements mandate non-root execution
# following principle of least privilege
deny contains msg if {
	input.kind in ["Deployment", "StatefulSet", "DaemonSet", "Job"]
	pod_security := input.spec.template.spec.securityContext
	pod_security.runAsUser == 0
	msg := "Pod cannot run as root user (UID 0). Set runAsUser to non-zero value in securityContext"
}

deny contains msg if {
	input.kind in ["Deployment", "StatefulSet", "DaemonSet", "Job"]
	container := input.spec.template.spec.containers[_]
	container.securityContext.runAsUser == 0
	msg := sprintf("Container '%s' cannot run as root user (UID 0)", [container.name])
}

# DENY: Missing runAsNonRoot enforcement
# Big Bang security policy requires explicit non-root enforcement
deny contains msg if {
	input.kind in ["Deployment", "StatefulSet", "DaemonSet", "Job"]
	pod_security := input.spec.template.spec.securityContext
	pod_security.runAsNonRoot != true
	msg := "Pod must set runAsNonRoot: true in securityContext for DoD compliance"
}

# DENY: Dangerous capabilities
# DoD Container Security Requirements restrict Linux capabilities
# to prevent container escape and privilege escalation
dangerous_capabilities := {
	"SYS_ADMIN",    # Full system administration
	"SYS_PTRACE",   # Process tracing (debugging)
	"SYS_MODULE",   # Kernel module loading
	"DAC_OVERRIDE", # File permission override
	"SETUID",       # Change user ID
	"SETGID",       # Change group ID
	"SYS_CHROOT",   # Change root directory
	"SYS_TIME",     # System time modification
}

deny contains msg if {
	input.kind in ["Deployment", "StatefulSet", "DaemonSet", "Job"]
	container := input.spec.template.spec.containers[_]
	capability := container.securityContext.capabilities.add[_]
	capability in dangerous_capabilities
	msg := sprintf("Container '%s' cannot add dangerous capability '%s'. Use principle of least privilege", [container.name, capability])
}

# DENY: Host namespace usage
# Using host namespaces bypasses container isolation
# and violates DoD security requirements
deny contains msg if {
	input.kind in ["Deployment", "StatefulSet", "DaemonSet", "Job"]
	input.spec.template.spec.hostPID == true
	msg := "Pod cannot use host PID namespace. This breaks container isolation"
}

deny contains msg if {
	input.kind in ["Deployment", "StatefulSet", "DaemonSet", "Job"]
	input.spec.template.spec.hostIPC == true
	msg := "Pod cannot use host IPC namespace. This breaks container isolation"
}

deny contains msg if {
	input.kind in ["Deployment", "StatefulSet", "DaemonSet", "Job"]
	input.spec.template.spec.hostNetwork == true
	msg := "Pod cannot use host network namespace. This bypasses network security controls"
}

# DENY: Writable root filesystem
# Big Bang security standards require read-only root filesystem
# to prevent runtime tampering and meet immutability requirements
deny contains msg if {
	input.kind in ["Deployment", "StatefulSet", "DaemonSet", "Job"]
	container := input.spec.template.spec.containers[_]
	not container.securityContext.readOnlyRootFilesystem
	msg := sprintf("Container '%s' must set readOnlyRootFilesystem: true for security", [container.name])
}

deny contains msg if {
	input.kind in ["Deployment", "StatefulSet", "DaemonSet", "Job"]
	container := input.spec.template.spec.containers[_]
	container.securityContext.readOnlyRootFilesystem == false
	msg := sprintf("Container '%s' must not disable readOnlyRootFilesystem", [container.name])
}

# DENY: Host path volumes
# Host path volumes can expose sensitive host data
# and violate container isolation principles
deny contains msg if {
	input.kind in ["Deployment", "StatefulSet", "DaemonSet", "Job"]
	volume := input.spec.template.spec.volumes[_]
	volume.hostPath
	msg := sprintf("Pod cannot use hostPath volume '%s'. Use persistent volumes or configmaps instead", [volume.name])
}

# DENY: Unsafe sysctls
# Unsafe sysctls can compromise kernel security
# and are prohibited in Big Bang multi-tenant environments
unsafe_sysctls := {
	"kernel.",
	"vm.",
	"fs.",
	"net.",
}

deny contains msg if {
	input.kind in ["Deployment", "StatefulSet", "DaemonSet", "Job"]
	sysctl := input.spec.template.spec.securityContext.sysctls[_]
	prefix := unsafe_sysctls[_]
	startswith(sysctl.name, prefix)
	msg := sprintf("Pod cannot set unsafe sysctl '%s'. Only safe sysctls are allowed", [sysctl.name])
}

# DENY: Missing security context
# Big Bang requires explicit security context for all containers
# to ensure security policies are consistently applied
deny contains msg if {
	input.kind in ["Deployment", "StatefulSet", "DaemonSet", "Job"]
	container := input.spec.template.spec.containers[_]
	not container.securityContext
	msg := sprintf("Container '%s' must define securityContext for security compliance", [container.name])
}

# DENY: Default seccomp profile
# Big Bang requires explicit seccomp profiles for enhanced security
# Default profile may not meet DoD security requirements
deny contains msg if {
	input.kind in ["Deployment", "StatefulSet", "DaemonSet", "Job"]
	pod_security := input.spec.template.spec.securityContext
	not pod_security.seccompProfile
	msg := "Pod must specify seccompProfile for enhanced syscall filtering"
}

deny contains msg if {
	input.kind in ["Deployment", "StatefulSet", "DaemonSet", "Job"]
	pod_security := input.spec.template.spec.securityContext
	pod_security.seccompProfile.type == "Unconfined"
	msg := "Pod cannot use 'Unconfined' seccomp profile. Use 'RuntimeDefault' or custom profile"
}

# WARN: Missing capabilities drop
# Big Bang recommends dropping all capabilities by default
# and only adding required ones for principle of least privilege
warn contains msg if {
	input.kind in ["Deployment", "StatefulSet", "DaemonSet", "Job"]
	container := input.spec.template.spec.containers[_]
	not container.securityContext.capabilities
	msg := sprintf("Container '%s' should drop all capabilities and add only required ones", [container.name])
}

warn contains msg if {
	input.kind in ["Deployment", "StatefulSet", "DaemonSet", "Job"]
	container := input.spec.template.spec.containers[_]
	caps := container.securityContext.capabilities
	not caps.drop
	msg := sprintf("Container '%s' should drop unnecessary capabilities (recommend: drop ALL)", [container.name])
}

# WARN: High UID/GID values recommended
# Using high UID/GID values (>10000) reduces risk of conflicts
# with host system users in multi-tenant environments
warn contains msg if {
	input.kind in ["Deployment", "StatefulSet", "DaemonSet", "Job"]
	pod_security := input.spec.template.spec.securityContext
	pod_security.runAsUser < 10000
	pod_security.runAsUser != 0  # Already denied above
	msg := sprintf("Pod runAsUser %d is low. Consider using UID >10000 for better isolation", [pod_security.runAsUser])
}