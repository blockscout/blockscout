{{/*
Get the environment suffix. Eg. prod, dev, sandbox
*/}}
{{- define "quai-blockscout.envSuffix" -}}
{{- (split "-" .Values.quaiBlockscout.env)._1 -}}
{{- end }}

{{/*
Get the environment URL prefix where prod is ""
*/}}
{{- define "quai-blockscout.envPrefix" -}}
{{- $suffix := include "quai-blockscout.envSuffix" . -}}
{{- if eq $suffix "prod" }}{{- else }}
{{- $suffix -}}.{{- end }}
{{- end }}

{{/*
Expand the name of the chart.
*/}}
{{- define "quai-blockscout.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}-{{- include "quai-blockscout.envSuffix" . -}}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "quai-blockscout.fullname" -}}
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
{{- define "quai-blockscout.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "quai-blockscout.labels" -}}
helm.sh/chart: {{ include "quai-blockscout.chart" . }}
{{ include "quai-blockscout.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "quai-blockscout.selectorLabels" -}}
app.kubernetes.io/name: {{ include "quai-blockscout.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "quai-blockscout.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "quai-blockscout.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
