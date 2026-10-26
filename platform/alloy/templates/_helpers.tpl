{{- define "alloy.selectorLabels" -}}
app.kubernetes.io/name: alloy
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "alloy.labels" -}}
{{ include "alloy.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{- end -}}
