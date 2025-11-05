*************************kubeslice-controller*********************************

{{/*
Expand the name of the chart.
*/}}
{{- define "kubeslice-controller.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "kubeslice-controller.fullname" -}}
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
{{- define "kubeslice-controller.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "kubeslice-controller.labels" -}}
helm.sh/chart: {{ include "kubeslice-controller.chart" . }}
{{ include "kubeslice-controller.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "kubeslice-controller.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kubeslice-controller.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "kubeslice-controller.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "kubeslice-controller.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

*************************PROMETHUES*********************************

{{/*
Expand the name of the chart.
*/}}
{{- define "prometheus.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Set a fixed name "prometheus-service" for the Prometheus fullname.
This ensures both the service and configmap are named "prometheus-service".
*/}}
{{- define "prometheus.fullname" -}}
prometheus-service
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "prometheus.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "prometheus.labels" -}}
helm.sh/chart: {{ include "prometheus.chart" . }}
{{ include "prometheus.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "prometheus.selectorLabels" -}}
app.kubernetes.io/name: {{ include "prometheus.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "prometheus.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "prometheus.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Global image helpers - Production-level image reference patterns
*/}}

{{/*
Generate full image reference with global registry
Usage: {{ include "kubeslice.image" (dict "image" .Values.component.image "tag" .Values.component.tag "registry" .Values.global.imageRegistry) }}
*/}}
{{- define "kubeslice.image" -}}
{{- $registry := .registry -}}
{{- if $registry -}}
{{ $registry }}/{{ .image }}:{{ .tag }}
{{- else -}}
{{ .image }}:{{ .tag }}
{{- end -}}
{{- end }}

{{/*
Generate image pull secrets reference
Usage: {{ include "kubeslice.imagePullSecrets" . }}
*/}}
{{- define "kubeslice.imagePullSecrets" -}}
{{- if .Values.global.imagePullSecrets.name }}
imagePullSecrets:
  - name: {{ .Values.global.imagePullSecrets.name }}
{{- end }}
{{- end }}

{{/*
Generate image pull secrets name
Usage: {{ include "kubeslice.imagePullSecretsName" . }}
*/}}
{{- define "kubeslice.imagePullSecretsName" -}}
{{- .Values.global.imagePullSecrets.name | default "kubeslice-image-pull-secret" -}}
{{- end }}