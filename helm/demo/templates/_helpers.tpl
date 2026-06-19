{{/*
Expand the name of the chart.
*/}}
{{- define "demo.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Fully qualified app name.
*/}}
{{- define "demo.fullname" -}}
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
{{- define "demo.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels.
*/}}
{{- define "demo.labels" -}}
helm.sh/chart: {{ include "demo.chart" . }}
{{ include "demo.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/part-of: stackup
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Selector labels — stable across upgrades.
*/}}
{{- define "demo.selectorLabels" -}}
app.kubernetes.io/name: {{ include "demo.name" . }}
app.kubernetes.io/component: web
{{- end -}}

{{/*
Shared container spec used by BOTH deployment.yaml and rollout.yaml, so the
two workload variants can never drift. Emits a single-item list (the `-`)
so callers nindent it directly under `containers:`.
*/}}
{{- define "demo.container" -}}
- name: demo
  image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
  imagePullPolicy: {{ .Values.image.pullPolicy }}
  ports:
    - name: http
      containerPort: 3000
      protocol: TCP
  env:
    - name: PORT
      value: "3000"
    - name: SERVICE_NAME
      value: {{ .Values.serviceName | quote }}
    - name: FAILURE_RATE
      value: {{ .Values.failureRate | quote }}
  securityContext:
    {{- toYaml .Values.containerSecurityContext | nindent 4 }}
  resources:
    {{- toYaml .Values.resources | nindent 4 }}
  startupProbe:
    httpGet:
      path: /healthz
      port: http
    failureThreshold: {{ .Values.probes.startup.failureThreshold }}
    periodSeconds: {{ .Values.probes.startup.periodSeconds }}
    timeoutSeconds: {{ .Values.probes.startup.timeoutSeconds }}
  livenessProbe:
    httpGet:
      path: /healthz
      port: http
    periodSeconds: {{ .Values.probes.liveness.periodSeconds }}
    timeoutSeconds: {{ .Values.probes.liveness.timeoutSeconds }}
    failureThreshold: {{ .Values.probes.liveness.failureThreshold }}
  readinessProbe:
    httpGet:
      path: /healthz
      port: http
    periodSeconds: {{ .Values.probes.readiness.periodSeconds }}
    timeoutSeconds: {{ .Values.probes.readiness.timeoutSeconds }}
    failureThreshold: {{ .Values.probes.readiness.failureThreshold }}
{{- end -}}
