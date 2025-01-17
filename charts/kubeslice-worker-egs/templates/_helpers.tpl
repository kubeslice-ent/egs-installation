{{/*
Expand the name of the chart.
*/}}
{{- define "kubeslice-operator.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "kubeslice-operator.fullname" -}}
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
{{- define "kubeslice-operator.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "kubeslice-operator.labels" -}}
helm.sh/chart: {{ include "kubeslice-operator.chart" . }}
{{ include "kubeslice-operator.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "kubeslice-operator.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kubeslice-operator.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "kubeslice-operator.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "kubeslice-operator.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

# {{/*
# check kserve crds are present or not, extend to check deployment & version
# */}}
# {{- define "kubeslice-worker-egs.check_kserve_crds" }}
# {{- $crds := lookup "apiextensions.k8s.io/v1" "CustomResourceDefinition" "" "" -}}
# {{- range $crds.items -}}
#   {{- if and (hasKey .metadata.labels "app.kubernetes.io/name") (regexMatch ".*serving.kserve.io.*" .spec.group) -}}
#     true
#   {{- end -}}
# {{- end -}}
# {{- end }}
