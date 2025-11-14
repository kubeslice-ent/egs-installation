#IMAGE PULL SECRET ##
{{/*
Return the secret with imagePullSecrets credentials
Priority: Parent global config > Admission-webhook-specific config > default
*/}}
{{- define "imagePullSecrets.secretName" -}}
    {{- if and .Values.global .Values.global.imagePullSecrets .Values.global.imagePullSecrets.secretName -}}
        {{- printf "%s" .Values.global.imagePullSecrets.secretName -}}
    {{- else if .Values.global.nsmw_docker_existingImagePullSecret -}}
        {{- printf "%s" (tpl .Values.global.nsmw_docker_existingImagePullSecret $) -}}
    {{- else -}}
        {{- printf "kubeslice-image-pull-secret" -}}
    {{- end -}}
{{- end -}}

{{/*
Return true if a secret object should be created for imagePullSecrets
Priority: Don't create if parent manages secrets OR admission-webhook has existing secret
*/}}
{{- define "imagePullSecrets.createSecret" -}}
{{- if and .Values.global .Values.global.imagePullSecrets -}}
    {{- false -}}
{{- else if .Values.global.nsmw_docker_existingImagePullSecret -}}
    {{- false -}}
{{- else -}}
    {{- true -}}
{{- end -}}
{{- end -}}

{{/*
Return the image registry to use
Priority: Parent global config > Admission-webhook-specific config > default
*/}}
{{- define "admission-webhook.imageRegistry" -}}
    {{- if and .Values.global .Values.global.imageRegistry -}}
        {{- printf "%s" .Values.global.imageRegistry -}}
    {{- else -}}
        {{- printf "harbor.saas1.smart-scaler.io/avesha/aveshasystems" -}}
    {{- end -}}
{{- end -}}
