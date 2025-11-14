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

{{/*
Construct the full image name with registry, repository, and tag
Usage: {{ include "kubeslice.image" (dict "imageRoot" .Values.operator "global" .Values.global) }}
*/}}
{{- define "kubeslice.image" -}}
{{- $registry := .global.imageRegistry -}}
{{- $repository := .imageRoot.image -}}
{{- $tag := .imageRoot.tag -}}
{{- if .global.imageTagOverrides -}}
  {{- range $key, $value := .global.imageTagOverrides -}}
    {{- if eq $key $repository -}}
      {{- $tag = $value -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- printf "%s/%s:%s" $registry $repository $tag -}}
{{- end -}}

{{/*
Get the imagePullSecrets name
*/}}
{{- define "kubeslice.imagePullSecrets" -}}
{{- if .Values.global.imagePullSecrets.existingSecret -}}
  {{- .Values.global.imagePullSecrets.existingSecret -}}
{{- else -}}
  {{- .Values.global.imagePullSecrets.secretName -}}
{{- end -}}
{{- end -}}

{{/*
Determine if imagePullSecrets should be created
*/}}
{{- define "kubeslice.createImagePullSecret" -}}
{{- if and .Values.global.imagePullSecrets.create (not .Values.global.imagePullSecrets.existingSecret) -}}
  {{- if or .Values.global.imagePullSecrets.dockerconfigjson (and .Values.global.imagePullSecrets.username .Values.global.imagePullSecrets.password) -}}
    {{- true -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Image pull policy with fallback
*/}}
{{- define "kubeslice.imagePullPolicy" -}}
{{- .pullPolicy | default .global.imagePullPolicy | default "IfNotPresent" -}}
{{- end -}}

{{/*
Generate dockerconfigjson for imagePullSecrets
*/}}
{{- define "kubeslice.dockerconfigjson" -}}
{{- if .Values.global.imagePullSecrets.dockerconfigjson -}}
  {{- .Values.global.imagePullSecrets.dockerconfigjson -}}
{{- else -}}
  {{- printf "{\"auths\":{\"%s\":{\"username\":\"%s\",\"password\":\"%s\",\"email\":\"%s\",\"auth\":\"%s\"}}}" .Values.global.imagePullSecrets.registry .Values.global.imagePullSecrets.username .Values.global.imagePullSecrets.password .Values.global.imagePullSecrets.email (printf "%s:%s" .Values.global.imagePullSecrets.username .Values.global.imagePullSecrets.password | b64enc) | b64enc -}}
{{- end -}}
{{- end -}}

{{/*
Validate global image configuration
*/}}
{{- define "kubeslice.validateImageConfig" -}}
{{- if not .Values.global.imageRegistry -}}
  {{- fail "global.imageRegistry is required" -}}
{{- end -}}
{{- if and .Values.global.imagePullSecrets.create (not .Values.global.imagePullSecrets.existingSecret) -}}
  {{- if not (or .Values.global.imagePullSecrets.dockerconfigjson (and .Values.global.imagePullSecrets.username .Values.global.imagePullSecrets.password)) -}}
    {{- fail "global.imagePullSecrets requires either dockerconfigjson or username/password when create=true" -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Add image pull secret annotations for monitoring
*/}}
{{- define "kubeslice.imagePullAnnotations" -}}
prometheus.io/scrape-image-pulls: "true"
kubeslice.io/image-registry: {{ .Values.global.imageRegistry | quote }}
kubeslice.io/image-pull-secret: {{ include "kubeslice.imagePullSecrets" . | quote }}
{{- end -}}

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
