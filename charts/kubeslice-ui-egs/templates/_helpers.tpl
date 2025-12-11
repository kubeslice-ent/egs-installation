*************************kubeslice-ui*********************************

{{/*
Expand the name of the chart.
*/}}
{{- define "kubeslice-ui.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "kubeslice-ui.fullname" -}}
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
{{- define "kubeslice-ui.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "kubeslice-ui.labels" -}}
helm.sh/chart: {{ include "kubeslice-ui.chart" . }}
{{ include "kubeslice-ui.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "kubeslice-ui.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kubeslice-ui.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "kubeslice-ui.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "kubeslice-ui.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

*************************KUBERNETES-DASHBOARD*********************************

{{/*
Expand the name of the chart.
*/}}
{{- define "kubernetes-dashboard.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "kubernetes-dashboard.fullname" -}}
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
{{- define "kubernetes-dashboard.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "kubernetes-dashboard.labels" -}}
helm.sh/chart: {{ include "kubernetes-dashboard.chart" . }}
{{ include "kubernetes-dashboard.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "kubernetes-dashboard.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kubernetes-dashboard.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "kubernetes-dashboard.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "kubernetes-dashboard.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

*************************GLOBAL HELPERS*********************************

{{/*
Global image registry helper
Returns the global image registry with fallback to empty string
*/}}
{{- define "global.imageRegistry" -}}
{{- if .Values.global.imageRegistry -}}
{{- .Values.global.imageRegistry -}}
{{- end -}}
{{- end -}}

{{/*
Global image pull policy helper
Returns the global image pull policy with fallback to IfNotPresent
*/}}
{{- define "global.imagePullPolicy" -}}
{{- .Values.global.imagePullPolicy | default "IfNotPresent" -}}
{{- end -}}

{{/*
Generate full image name with registry
Usage: {{ include "global.image" (dict "registry" .Values.global.imageRegistry "repository" "my-app" "tag" "v1.0.0" "context" .) }}
*/}}
{{- define "global.image" -}}
{{- $registry := .registry | default "" -}}
{{- $repository := .repository | required "Repository is required" -}}
{{- $tag := .tag | default "latest" -}}
{{- if $registry -}}
{{- printf "%s/%s:%s" $registry $repository $tag -}}
{{- else -}}
{{- printf "%s:%s" $repository $tag -}}
{{- end -}}
{{- end -}}

{{/*
Generate image pull secrets
Returns a list of image pull secrets based on global configuration
*/}}
{{- define "global.imagePullSecrets" -}}
{{- if .Values.global.imagePullSecrets.enabled -}}
{{- if .Values.global.imagePullSecrets.name -}}
- name: {{ .Values.global.imagePullSecrets.name }}
{{- end -}}
{{- range .Values.global.imagePullSecrets.additional -}}
- name: {{ .name }}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Check if image pull secrets should be rendered
Returns true if global image pull secrets are enabled and at least one secret is configured
*/}}
{{- define "global.hasImagePullSecrets" -}}
{{- if and .Values.global.imagePullSecrets.enabled (or .Values.global.imagePullSecrets.name .Values.global.imagePullSecrets.additional) -}}
true
{{- end -}}
{{- end -}}

{{/*
Generate image pull secrets with fallback to legacy configuration
This provides backward compatibility while encouraging migration to global config
*/}}
{{- define "global.imagePullSecretsWithFallback" -}}
{{- if include "global.hasImagePullSecrets" . -}}
{{- include "global.imagePullSecrets" . -}}
{{- else if .Values.imagePullSecretsName -}}
- name: {{ .Values.imagePullSecretsName }}
{{- end -}}
{{- end -}}

{{/*
Component-specific image helper
Generates full image name for a component with global registry fallback
Usage: {{ include "component.image" (dict "component" .Values.kubeslice.ui "global" .Values.global "context" .) }}
*/}}
{{- define "component.image" -}}
{{- $component := .component | required "Component configuration is required" -}}
{{- $global := .global | required "Global configuration is required" -}}
{{- $registry := $global.imageRegistry | default "" -}}
{{- $repository := $component.image | required "Component image is required" -}}
{{- $tag := $component.tag | default "latest" -}}
{{- if $registry -}}
{{- printf "%s/%s:%s" $registry $repository $tag -}}
{{- else -}}
{{- printf "%s:%s" $repository $tag -}}
{{- end -}}
{{- end -}}

{{/*
Component-specific image pull policy helper
Returns component-specific pull policy with fallback to global, then to IfNotPresent
*/}}
{{- define "component.imagePullPolicy" -}}
{{- $component := .component | required "Component configuration is required" -}}
{{- $global := .global | required "Global configuration is required" -}}
{{- $component.pullPolicy | default $global.imagePullPolicy | default "IfNotPresent" -}}
{{- end -}}