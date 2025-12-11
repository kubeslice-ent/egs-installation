#IMAGE PULL SECRET ##
{{/*
Return the secret with imagePullSecrets credentials
Uses parent chart's global configuration
*/}}
{{- define "imagePullSecrets.secretName" -}}
    {{- if and .Values.global .Values.global.imagePullSecrets .Values.global.imagePullSecrets.secretName -}}
        {{- printf "%s" .Values.global.imagePullSecrets.secretName -}}
    {{- else -}}
        {{- printf "kubeslice-image-pull-secret" -}}
    {{- end -}}
{{- end -}}

{{/*
Return true if a secret object should be created for imagePullSecrets
Secret creation is managed by parent chart
*/}}
{{- define "imagePullSecrets.createSecret" -}}
    {{- false -}}
{{- end -}}

{{/*
Return the image registry to use
Priority: Parent global config > Netop-specific config > default
*/}}
{{- define "netop.imageRegistry" -}}
    {{- if and .Values.global .Values.global.imageRegistry -}}
        {{- printf "%s" .Values.global.imageRegistry -}}
    {{- else -}}
        {{- printf "harbor.saas1.smart-scaler.io/avesha/aveshasystems" -}}
    {{- end -}}
{{- end -}}
