{{/*
KubeTally subchart helpers - inherits from parent chart
*/}}

{{/*
Generate full image reference with global registry for kubetally
Automatically inherits from parent chart's global values
Usage: {{ include "kubetally.image" (dict "image" .Values.kubetally.component.image "tag" .Values.kubetally.component.tag "context" .) }}
*/}}
{{- define "kubetally.image" -}}
{{- $registry := "" -}}
{{- if .context.Values.global -}}
{{- $registry = .context.Values.global.imageRegistry -}}
{{- end -}}
{{- if $registry -}}
{{ $registry }}/{{ .image }}:{{ .tag }}
{{- else -}}
{{ .image }}:{{ .tag }}
{{- end -}}
{{- end }}

{{/*
Generate image pull secrets reference for kubetally
Automatically inherits from parent chart's global values
Usage: {{ include "kubetally.imagePullSecrets" . }}
*/}}
{{- define "kubetally.imagePullSecrets" -}}
{{- $secretName := "" -}}
{{- if .Values.global -}}
{{- if .Values.global.imagePullSecrets -}}
{{- $secretName = .Values.global.imagePullSecrets.name -}}
{{- end -}}
{{- end -}}
{{- if not $secretName -}}
{{- $secretName = .Values.kubetally.imagePullSecretName | default "kubeslice-image-pull-secret" -}}
{{- end -}}
{{- if $secretName }}
imagePullSecrets:
  - name: {{ $secretName }}
{{- end }}
{{- end }}
