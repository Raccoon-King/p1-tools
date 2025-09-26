{{/*
Expand the name of the chart.
*/}}
{{- define "sample-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "sample-app.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "sample-app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels - Big Bang compliant
*/}}
{{- define "sample-app.labels" -}}
helm.sh/chart: {{ include "sample-app.chart" . }}
{{ include "sample-app.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: {{ .Chart.Name }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "sample-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "sample-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "sample-app.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "sample-app.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Container image with digest or tag
*/}}
{{- define "sample-app.image" -}}
{{- if .Values.image.digest }}
{{- printf "%s@%s" .Values.image.repository .Values.image.digest }}
{{- else }}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag }}
{{- end }}
{{- end }}

{{/*
Common annotations for Big Bang integration
*/}}
{{- define "sample-app.annotations" -}}
bigbang.dev/version: {{ .Chart.AppVersion | quote }}
config.kubernetes.io/depends-on: kustomize.config.k8s.io/v1beta1/Kustomization/flux-system/sample-app
{{- end }}

{{/*
Pod security context
*/}}
{{- define "sample-app.podSecurityContext" -}}
runAsNonRoot: {{ .Values.securityContext.pod.runAsNonRoot }}
runAsUser: {{ .Values.securityContext.pod.runAsUser }}
{{- if .Values.securityContext.pod.runAsGroup }}
runAsGroup: {{ .Values.securityContext.pod.runAsGroup }}
{{- end }}
{{- if .Values.securityContext.pod.fsGroup }}
fsGroup: {{ .Values.securityContext.pod.fsGroup }}
{{- end }}
seccompProfile:
  type: {{ .Values.securityContext.pod.seccompProfile.type }}
{{- end }}

{{/*
Container security context
*/}}
{{- define "sample-app.containerSecurityContext" -}}
allowPrivilegeEscalation: {{ .Values.securityContext.container.allowPrivilegeEscalation }}
readOnlyRootFilesystem: {{ .Values.securityContext.container.readOnlyRootFilesystem }}
runAsNonRoot: {{ .Values.securityContext.container.runAsNonRoot }}
{{- if .Values.securityContext.container.runAsUser }}
runAsUser: {{ .Values.securityContext.container.runAsUser }}
{{- end }}
{{- if .Values.securityContext.container.runAsGroup }}
runAsGroup: {{ .Values.securityContext.container.runAsGroup }}
{{- end }}
capabilities:
  drop:
    {{- range .Values.securityContext.container.capabilities.drop }}
    - {{ . }}
    {{- end }}
  {{- if .Values.securityContext.container.capabilities.add }}
  add:
    {{- range .Values.securityContext.container.capabilities.add }}
    - {{ . }}
    {{- end }}
  {{- end }}
{{- end }}

{{/*
Environment variables
*/}}
{{- define "sample-app.env" -}}
{{- range .Values.env }}
- name: {{ .name }}
  {{- if .value }}
  value: {{ .value | quote }}
  {{- else if .valueFrom }}
  valueFrom:
    {{- toYaml .valueFrom | nindent 4 }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Volume mounts for read-only root filesystem
*/}}
{{- define "sample-app.volumeMounts" -}}
{{- range .Values.volumeMounts }}
- name: {{ .name }}
  mountPath: {{ .mountPath }}
  {{- if .subPath }}
  subPath: {{ .subPath }}
  {{- end }}
  {{- if .readOnly }}
  readOnly: {{ .readOnly }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Volumes for read-only root filesystem
*/}}
{{- define "sample-app.volumes" -}}
{{- range .Values.volumes }}
- name: {{ .name }}
  {{- if .emptyDir }}
  emptyDir: {}
  {{- else if .configMap }}
  configMap:
    name: {{ .configMap.name }}
    {{- if .configMap.defaultMode }}
    defaultMode: {{ .configMap.defaultMode }}
    {{- end }}
  {{- else if .secret }}
  secret:
    secretName: {{ .secret.secretName }}
    {{- if .secret.defaultMode }}
    defaultMode: {{ .secret.defaultMode }}
    {{- end }}
  {{- else if .persistentVolumeClaim }}
  persistentVolumeClaim:
    claimName: {{ .persistentVolumeClaim.claimName }}
  {{- end }}
{{- end }}
{{- end }}