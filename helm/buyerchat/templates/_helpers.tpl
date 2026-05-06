{{/*
Expand the name of the chart.
*/}}
{{- define "buyerchat.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited
to this (by the DNS naming spec).
*/}}
{{- define "buyerchat.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Chart name + version label value.
*/}}
{{- define "buyerchat.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels (recommended set per
https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/).
*/}}
{{- define "buyerchat.labels" -}}
helm.sh/chart: {{ include "buyerchat.chart" . }}
{{ include "buyerchat.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/component: web
app.kubernetes.io/part-of: devops-showcase
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Selector labels — must be stable across upgrades (Deployment selector
is immutable). Keep this set minimal: name + component only.
*/}}
{{- define "buyerchat.selectorLabels" -}}
app.kubernetes.io/name: {{ include "buyerchat.name" . }}
app.kubernetes.io/component: web
{{- end -}}
