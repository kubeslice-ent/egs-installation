{{/*
Return the image registry to use
Priority: Parent global config > Spire-server-specific config > default
*/}}
{{- define "spire-server.imageRegistry" -}}
    {{- if and .Values.global .Values.global.imageRegistry -}}
        {{- printf "%s" .Values.global.imageRegistry -}}
    {{- else -}}
        {{- printf "harbor.saas1.smart-scaler.io/avesha/aveshasystems" -}}
    {{- end -}}
{{- end -}}
