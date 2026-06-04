{{- define "vault.fullname" -}}
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

{{- define "vault.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "vault.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "vault.namespace" -}}
{{- default .Release.Namespace .Values.global.namespace -}}
{{- end -}}

{{- define "vault.csiEnabled" -}}
{{- $_ := set . "csiEnabled" (or
  (eq (.Values.csi.enabled | toString) "true")
  (and (eq (.Values.csi.enabled | toString) "-") (eq (.Values.global.enabled | toString) "true"))) -}}
{{- end -}}

{{- define "vault.injectorEnabled" -}}
{{- $_ := set . "injectorEnabled" (or
  (eq (.Values.injector.enabled | toString) "true")
  (and (eq (.Values.injector.enabled | toString) "-") (eq (.Values.global.enabled | toString) "true"))) -}}
{{- end -}}

{{- define "vault.serverEnabled" -}}
{{- $_ := set . "serverEnabled" (or
  (eq (.Values.server.enabled | toString) "true")
  (and (eq (.Values.server.enabled | toString) "-") (eq (.Values.global.enabled | toString) "true"))) -}}
{{- end -}}

{{- define "vault.serverServiceAccountEnabled" -}}
{{- $_ := set . "serverServiceAccountEnabled"
  (and
    (eq (.Values.server.serviceAccount.create | toString) "true" )
    (or
      (eq (.Values.server.enabled | toString) "true")
      (eq (.Values.global.enabled | toString) "true"))) -}}
{{- end -}}

{{- define "vault.serverServiceAccountSecretCreationEnabled" -}}
{{- $_ := set . "serverServiceAccountSecretCreationEnabled"
  (and
    (eq (.Values.server.serviceAccount.create | toString) "true")
    (eq (.Values.server.serviceAccount.createSecret | toString) "true")) -}}
{{- end -}}

{{- define "vault.serverAuthDelegator" -}}
{{- $_ := set . "serverAuthDelegator"
  (and
    (eq (.Values.server.authDelegator.enabled | toString) "true" )
    (or (eq (.Values.server.serviceAccount.create | toString) "true")
        (not (eq .Values.server.serviceAccount.name "")))
    (or
      (eq (.Values.server.enabled | toString) "true")
      (eq (.Values.global.enabled | toString) "true"))) -}}
{{- end -}}

{{- define "vault.serverServiceEnabled" -}}
{{- template "vault.serverEnabled" . -}}
{{- $_ := set . "serverServiceEnabled" (and .serverEnabled (eq (.Values.server.service.enabled | toString) "true")) -}}
{{- end -}}

{{- define "vault.uiEnabled" -}}
{{- $_ := set . "uiEnabled" (or
  (eq (.Values.ui.enabled | toString) "true")
  (and (eq (.Values.ui.enabled | toString) "-") (eq (.Values.global.enabled | toString) "true"))) -}}
{{- end -}}

{{- define "vault.pdb.maxUnavailable" -}}
{{- if eq (int .Values.server.ha.replicas) 1 -}}
{{ 0 }}
{{- else if .Values.server.ha.disruptionBudget.maxUnavailable -}}
{{ .Values.server.ha.disruptionBudget.maxUnavailable -}}
{{- else if and (eq (.Values.server.ha.raft.enabled | toString) "true") (eq (.Values.server.ha.raft.redundancyZones.enabled | toString) "true") -}}
{{ 1 }}
{{- else -}}
{{- div (sub (div (mul (int .Values.server.ha.replicas) 10) 2) 1) 10 -}}
{{- end -}}
{{- end -}}

{{- define "vault.mode" -}}
  {{- template "vault.serverEnabled" . -}}
  {{- if or (.Values.injector.externalVaultAddr) (.Values.global.externalVaultAddr) -}}
    {{- $_ := set . "mode" "external" -}}
  {{- else if not .serverEnabled -}}
    {{- $_ := set . "mode" "external" -}}
  {{- else if eq (.Values.server.dev.enabled | toString) "true" -}}
    {{- $_ := set . "mode" "dev" -}}
  {{- else if eq (.Values.server.ha.enabled | toString) "true" -}}
    {{- $_ := set . "mode" "ha" -}}
  {{- else if or (eq (.Values.server.standalone.enabled | toString) "true") (eq (.Values.server.standalone.enabled | toString) "-") -}}
    {{- $_ := set . "mode" "standalone" -}}
  {{- else -}}
    {{- $_ := set . "mode" "" -}}
  {{- end -}}
{{- end -}}

{{- define "vault.replicas" -}}
  {{ if eq .mode "standalone" }}
    {{- default 1 -}}
  {{ else if eq .mode "ha" }}
    {{- if or (kindIs "int64" .Values.server.ha.replicas) (kindIs "float64" .Values.server.ha.replicas) -}}
      {{- .Values.server.ha.replicas -}}
    {{ else }}
      {{- 3 -}}
    {{- end -}}
  {{ else }}
    {{- default 1 -}}
  {{ end }}
{{- end -}}

{{- define "vault.volumes" -}}
  {{- if and (ne .mode "dev") (or (.Values.server.standalone.config) (.Values.server.ha.config) (.Values.server.ha.raft.config)) }}
        - name: config
          configMap:
            name: {{ template "vault.fullname" . }}-config
  {{ end }}
  {{- range .Values.server.extraVolumes }}
        - name: userconfig-{{ .name }}
          {{ .type }}:
          {{- if (eq .type "configMap") }}
            name: {{ .name }}
          {{- else if (eq .type "secret") }}
            secretName: {{ .name }}
          {{- end }}
            defaultMode: {{ .defaultMode | default 420 }}
  {{- end }}
  {{- if .Values.server.volumes }}
    {{- toYaml .Values.server.volumes | nindent 8}}
  {{- end }}
  {{- if (and .Values.server.enterpriseLicense.secretName .Values.server.enterpriseLicense.secretKey) }}
        - name: vault-license
          secret:
            secretName: {{ .Values.server.enterpriseLicense.secretName }}
            defaultMode: 0440
  {{- end }}
{{- end -}}

{{- define "vault.args" -}}
  {{ if or (eq .mode "standalone") (eq .mode "ha") }}
          - |
            cp /vault/config/extraconfig-from-values.hcl /tmp/storageconfig.hcl;
            [ -n "${HOST_IP}" ] && sed -Ei "s|HOST_IP|${HOST_IP?}|g" /tmp/storageconfig.hcl;
            [ -n "${POD_IP}" ] && sed -Ei "s|POD_IP|${POD_IP?}|g" /tmp/storageconfig.hcl;
            [ -n "${HOSTNAME}" ] && sed -Ei "s|HOSTNAME|${HOSTNAME?}|g" /tmp/storageconfig.hcl;
            [ -n "${API_ADDR}" ] && sed -Ei "s|API_ADDR|${API_ADDR?}|g" /tmp/storageconfig.hcl;
            [ -n "${TRANSIT_ADDR}" ] && sed -Ei "s|TRANSIT_ADDR|${TRANSIT_ADDR?}|g" /tmp/storageconfig.hcl;
            [ -n "${RAFT_ADDR}" ] && sed -Ei "s|RAFT_ADDR|${RAFT_ADDR?}|g" /tmp/storageconfig.hcl;
{{- if and (eq (.Values.server.ha.raft.enabled | toString) "true") (eq (.Values.server.ha.raft.redundancyZones.enabled | toString) "true") }}
            if [ -n "${VAULT_REDUNDANCY_ZONE}" ]; then
              sed -Ei 's|(\"?autopilot_redundancy_zone\"?[[:space:]]*[=:][[:space:]]*)\"VAULT_REDUNDANCY_ZONE\"|\1\"'"${VAULT_REDUNDANCY_ZONE}"'\"|g' /tmp/storageconfig.hcl;
            else
              echo "ERROR: Missing zone label on pod. Enabling redundancy zones in vault-helm requires the PodTopologyLabels admission controller (enabled by default in Kubernetes 1.35+) and nodes labeled with topology.kubernetes.io/zone. Verify node labels: kubectl get nodes -L topology.kubernetes.io/zone; verify pod labels: kubectl get pod \${HOSTNAME} -o jsonpath='{.metadata.labels}'" >&2;
              exit 1;
            fi;
{{- else if eq (.Values.server.ha.raft.enabled | toString) "true" }}
            if grep -vE '^[[:space:]]*(#|//)' /tmp/storageconfig.hcl | grep -qE '\"?autopilot_redundancy_zone\"?[[:space:]]*[=:][[:space:]]*\"VAULT_REDUNDANCY_ZONE\"'; then
              echo "ERROR: autopilot_redundancy_zone placeholder found but server.ha.raft.redundancyZones.enabled=false. Enable the feature or remove the placeholder." >&2;
              exit 1;
            fi;
{{- end }}
            /usr/local/bin/docker-entrypoint.sh vault server -config=/tmp/storageconfig.hcl {{ .Values.server.extraArgs }}
   {{ else if eq .mode "dev" }}
          - |
            /usr/local/bin/docker-entrypoint.sh vault server -dev {{ .Values.server.extraArgs }}
  {{ end }}
{{- end -}}

{{- define "vault.envs" -}}
  {{ if eq .mode "dev" }}
            - name: VAULT_DEV_ROOT_TOKEN_ID
              value: {{ .Values.server.dev.devRootToken }}
            - name: VAULT_DEV_LISTEN_ADDRESS
              value: "[::]:8200"
  {{ end }}
{{- end -}}

{{- define "vault.mounts" -}}
  {{ if eq (.Values.server.auditStorage.enabled | toString) "true" }}
            - name: audit
              mountPath: {{ .Values.server.auditStorage.mountPath }}
  {{ end }}
  {{ if or (eq .mode "standalone") (and (eq .mode "ha") (eq (.Values.server.ha.raft.enabled | toString) "true"))  }}
    {{ if eq (.Values.server.dataStorage.enabled | toString) "true" }}
            - name: data
              mountPath: {{ .Values.server.dataStorage.mountPath }}
    {{ end }}
  {{ end }}
  {{ if and (ne .mode "dev") (or (.Values.server.standalone.config)  (.Values.server.ha.config)) }}
            - name: config
              mountPath: /vault/config
  {{ end }}
  {{- range .Values.server.extraVolumes }}
            - name: userconfig-{{ .name }}
              readOnly: true
              mountPath: {{ .path | default "/vault/userconfig" }}/{{ .name }}
  {{- end }}
  {{- if .Values.server.volumeMounts }}
    {{- toYaml .Values.server.volumeMounts | nindent 12}}
  {{- end }}
  {{- if (and .Values.server.enterpriseLicense.secretName .Values.server.enterpriseLicense.secretKey) }}
            - name: vault-license
              mountPath: /vault/license
              readOnly: true
  {{- end }}
{{- end -}}

{{- define "vault.volumeclaims" -}}
  {{- if and (ne .mode "dev") (or .Values.server.dataStorage.enabled .Values.server.auditStorage.enabled) }}
  volumeClaimTemplates:
      {{- if and (eq (.Values.server.dataStorage.enabled | toString) "true") (or (eq .mode "standalone") (eq (.Values.server.ha.raft.enabled | toString ) "true" )) }}
    - apiVersion: v1
      kind: PersistentVolumeClaim
      metadata:
        name: data
        {{- include "vault.dataVolumeClaim.annotations" . | nindent 6 }}
        {{- include "vault.dataVolumeClaim.labels" . | nindent 6 }}
      spec:
        accessModes:
          - {{ .Values.server.dataStorage.accessMode | default "ReadWriteOnce" }}
        resources:
          requests:
            storage: {{ .Values.server.dataStorage.size }}
          {{- if .Values.server.dataStorage.storageClass }}
        storageClassName: {{ .Values.server.dataStorage.storageClass }}
          {{- end }}
      {{ end }}
      {{- if eq (.Values.server.auditStorage.enabled | toString) "true" }}
    - apiVersion: v1
      kind: PersistentVolumeClaim
      metadata:
        name: audit
        {{- include "vault.auditVolumeClaim.annotations" . | nindent 6 }}
        {{- include "vault.auditVolumeClaim.labels" . | nindent 6 }}
      spec:
        accessModes:
          - {{ .Values.server.auditStorage.accessMode | default "ReadWriteOnce" }}
        resources:
          requests:
            storage: {{ .Values.server.auditStorage.size }}
          {{- if .Values.server.auditStorage.storageClass }}
        storageClassName: {{ .Values.server.auditStorage.storageClass }}
          {{- end }}
      {{ end }}
  {{ end }}
{{- end -}}

{{- define "vault.affinity" -}}
  {{- if and (ne .mode "dev") .Values.server.affinity }}
      affinity:
        {{ $tp := typeOf .Values.server.affinity }}
        {{- if eq $tp "string" }}
          {{- tpl .Values.server.affinity . | nindent 8 | trim }}
        {{- else }}
          {{- toYaml .Values.server.affinity | nindent 8 }}
        {{- end }}
  {{ end }}
{{- end -}}

{{- define "injector.affinity" -}}
  {{- if .Values.injector.affinity }}
      affinity:
        {{ $tp := typeOf .Values.injector.affinity }}
        {{- if eq $tp "string" }}
          {{- tpl .Values.injector.affinity . | nindent 8 | trim }}
        {{- else }}
          {{- toYaml .Values.injector.affinity | nindent 8 }}
        {{- end }}
  {{ end }}
{{- end -}}

{{- define "vault.topologySpreadConstraints" -}}
  {{- if and (ne .mode "dev") .Values.server.topologySpreadConstraints }}
      topologySpreadConstraints:
        {{ $tp := typeOf .Values.server.topologySpreadConstraints }}
        {{- if eq $tp "string" }}
          {{- tpl .Values.server.topologySpreadConstraints . | nindent 8 | trim }}
        {{- else }}
          {{- toYaml .Values.server.topologySpreadConstraints | nindent 8 }}
        {{- end }}
  {{ end }}
{{- end -}}

{{- define "injector.topologySpreadConstraints" -}}
  {{- if .Values.injector.topologySpreadConstraints }}
      topologySpreadConstraints:
        {{ $tp := typeOf .Values.injector.topologySpreadConstraints }}
        {{- if eq $tp "string" }}
          {{- tpl .Values.injector.topologySpreadConstraints . | nindent 8 | trim }}
        {{- else }}
          {{- toYaml .Values.injector.topologySpreadConstraints | nindent 8 }}
        {{- end }}
  {{ end }}
{{- end -}}

{{- define "vault.tolerations" -}}
  {{- if and (ne .mode "dev") .Values.server.tolerations }}
      tolerations:
      {{- $tp := typeOf .Values.server.tolerations }}
      {{- if eq $tp "string" }}
        {{ tpl .Values.server.tolerations . | nindent 8 | trim }}
      {{- else }}
        {{- toYaml .Values.server.tolerations | nindent 8 }}
      {{- end }}
  {{- end }}
{{- end -}}

{{- define "injector.tolerations" -}}
  {{- if .Values.injector.tolerations }}
      tolerations:
      {{- $tp := typeOf .Values.injector.tolerations }}
      {{- if eq $tp "string" }}
        {{ tpl .Values.injector.tolerations . | nindent 8 | trim }}
      {{- else }}
        {{- toYaml .Values.injector.tolerations | nindent 8 }}
      {{- end }}
  {{- end }}
{{- end -}}

{{- define "vault.nodeselector" -}}
  {{- if and (ne .mode "dev") .Values.server.nodeSelector }}
      nodeSelector:
      {{- $tp := typeOf .Values.server.nodeSelector }}
      {{- if eq $tp "string" }}
        {{ tpl .Values.server.nodeSelector . | nindent 8 | trim }}
      {{- else }}
        {{- toYaml .Values.server.nodeSelector | nindent 8 }}
      {{- end }}
  {{- end }}
{{- end -}}

{{- define "injector.nodeselector" -}}
  {{- if .Values.injector.nodeSelector }}
      nodeSelector:
      {{- $tp := typeOf .Values.injector.nodeSelector }}
      {{- if eq $tp "string" }}
        {{ tpl .Values.injector.nodeSelector . | nindent 8 | trim }}
      {{- else }}
        {{- toYaml .Values.injector.nodeSelector | nindent 8 }}
      {{- end }}
  {{- end }}
{{- end -}}

{{- define "injector.strategy" -}}
  {{- if .Values.injector.strategy }}
  strategy:
  {{- $tp := typeOf .Values.injector.strategy }}
  {{- if eq $tp "string" }}
    {{ tpl .Values.injector.strategy . | nindent 4 | trim }}
  {{- else }}
    {{- toYaml .Values.injector.strategy | nindent 4 }}
  {{- end }}
  {{- end }}
{{- end -}}

{{- define "vault.annotations" }}
      annotations:
  {{- if .Values.server.includeConfigAnnotation }}
        vault.hashicorp.com/config-checksum: {{ include "vault.config" . | sha256sum }}
  {{- end }}
  {{- if .Values.server.annotations }}
        {{- $tp := typeOf .Values.server.annotations }}
        {{- if eq $tp "string" }}
          {{- tpl .Values.server.annotations . | nindent 8 }}
        {{- else }}
          {{- toYaml .Values.server.annotations | nindent 8 }}
        {{- end }}
  {{- end }}
{{- end -}}

{{- define "injector.annotations" -}}
  {{- if .Values.injector.annotations }}
      annotations:
        {{- $tp := typeOf .Values.injector.annotations }}
        {{- if eq $tp "string" }}
          {{- tpl .Values.injector.annotations . | nindent 8 }}
        {{- else }}
          {{- toYaml .Values.injector.annotations | nindent 8 }}
        {{- end }}
  {{- end }}
{{- end -}}

{{- define "injector.service.annotations" -}}
  {{- if .Values.injector.service.annotations }}
  annotations:
    {{- $tp := typeOf .Values.injector.service.annotations }}
    {{- if eq $tp "string" }}
      {{- tpl .Values.injector.service.annotations . | nindent 4 }}
    {{- else }}
      {{- toYaml .Values.injector.service.annotations | nindent 4 }}
    {{- end }}
  {{- end }}
{{- end -}}

{{- define "injector.securityContext.pod" -}}
  {{- if .Values.injector.securityContext.pod }}
      securityContext:
        {{- $tp := typeOf .Values.injector.securityContext.pod }}
        {{- if eq $tp "string" }}
          {{- tpl .Values.injector.securityContext.pod . | nindent 8 }}
        {{- else }}
          {{- toYaml .Values.injector.securityContext.pod | nindent 8 }}
        {{- end }}
  {{- else if not .Values.global.openshift }}
      securityContext:
        runAsNonRoot: true
        runAsGroup: {{ .Values.injector.gid | default 1000 }}
        runAsUser: {{ .Values.injector.uid | default 100 }}
        fsGroup: {{ .Values.injector.gid | default 1000 }}
  {{- end }}
{{- end -}}

{{- define "injector.securityContext.container" -}}
  {{- if .Values.injector.securityContext.container}}
          securityContext:
            {{- $tp := typeOf .Values.injector.securityContext.container }}
            {{- if eq $tp "string" }}
              {{- tpl .Values.injector.securityContext.container . | nindent 12 }}
            {{- else }}
              {{- toYaml .Values.injector.securityContext.container | nindent 12 }}
            {{- end }}
  {{- else if not .Values.global.openshift }}
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
                - ALL
  {{- end }}
{{- end -}}

{{- define "server.statefulSet.securityContext.pod" -}}
  {{- if .Values.server.statefulSet.securityContext.pod }}
      securityContext:
        {{- $tp := typeOf .Values.server.statefulSet.securityContext.pod }}
        {{- if eq $tp "string" }}
          {{- tpl .Values.server.statefulSet.securityContext.pod . | nindent 8 }}
        {{- else }}
          {{- toYaml .Values.server.statefulSet.securityContext.pod | nindent 8 }}
        {{- end }}
  {{- else if not .Values.global.openshift }}
      securityContext:
        runAsNonRoot: true
        runAsGroup: {{ .Values.server.gid | default 1000 }}
        runAsUser: {{ .Values.server.uid | default 100 }}
        fsGroup: {{ .Values.server.gid | default 1000 }}
  {{- end }}
{{- end -}}

{{- define "server.statefulSet.securityContext.container" -}}
  {{- if .Values.server.statefulSet.securityContext.container }}
          securityContext:
            {{- $tp := typeOf .Values.server.statefulSet.securityContext.container }}
            {{- if eq $tp "string" }}
              {{- tpl .Values.server.statefulSet.securityContext.container . | nindent 12 }}
            {{- else }}
              {{- toYaml .Values.server.statefulSet.securityContext.container | nindent 12 }}
            {{- end }}
  {{- else if not .Values.global.openshift }}
          securityContext:
            allowPrivilegeEscalation: false
  {{- end }}
{{- end -}}

{{- define "injector.serviceAccount.annotations" -}}
  {{- if and (ne .mode "dev") .Values.injector.serviceAccount.annotations }}
  annotations:
    {{- $tp := typeOf .Values.injector.serviceAccount.annotations }}
    {{- if eq $tp "string" }}
      {{- tpl .Values.injector.serviceAccount.annotations . | nindent 4 }}
    {{- else }}
      {{- toYaml .Values.injector.serviceAccount.annotations | nindent 4 }}
    {{- end }}
  {{- end }}
{{- end -}}

{{- define "injector.webhookAnnotations" -}}
  {{- if or (((.Values.injector.webhook)).annotations) (.Values.injector.webhookAnnotations)  }}
  annotations:
    {{- $tp := typeOf (or (((.Values.injector.webhook)).annotations) (.Values.injector.webhookAnnotations)) }}
    {{- if eq $tp "string" }}
      {{- tpl (((.Values.injector.webhook)).annotations | default .Values.injector.webhookAnnotations) . | nindent 4 }}
    {{- else }}
      {{- toYaml (((.Values.injector.webhook)).annotations | default .Values.injector.webhookAnnotations) | nindent 4 }}
    {{- end }}
  {{- end }}
{{- end -}}

{{- define "injector.objectSelector" -}}
  {{- $v := or (((.Values.injector.webhook)).objectSelector) (.Values.injector.objectSelector) -}}
  {{ if $v }}
    objectSelector:
    {{- $tp := typeOf $v -}}
    {{ if eq $tp "string" }}
      {{ tpl $v . | indent 6 | trim }}
    {{ else }}
      {{ toYaml $v | indent 6 | trim }}
    {{ end }}
  {{ end }}
{{ end }}

{{- define "vault.ui.annotations" -}}
  {{- if .Values.ui.annotations }}
  annotations:
    {{- $tp := typeOf .Values.ui.annotations }}
    {{- if eq $tp "string" }}
      {{- tpl .Values.ui.annotations . | nindent 4 }}
    {{- else }}
      {{- toYaml .Values.ui.annotations | nindent 4 }}
    {{- end }}
  {{- end }}
{{- end -}}

{{- define "vault.serviceAccount.name" -}}
{{- if .Values.server.serviceAccount.create -}}
    {{ default (include "vault.fullname" .) .Values.server.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.server.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{- define "vault.serviceAccount.annotations" -}}
  {{- if and (ne .mode "dev") .Values.server.serviceAccount.annotations }}
  annotations:
    {{- $tp := typeOf .Values.server.serviceAccount.annotations }}
    {{- if eq $tp "string" }}
      {{- tpl .Values.server.serviceAccount.annotations . | nindent 4 }}
    {{- else }}
      {{- toYaml .Values.server.serviceAccount.annotations | nindent 4 }}
    {{- end }}
  {{- end }}
{{- end -}}

{{- define "vault.ingress.annotations" -}}
  {{- if .Values.server.ingress.annotations }}
  annotations:
    {{- $tp := typeOf .Values.server.ingress.annotations }}
    {{- if eq $tp "string" }}
      {{- tpl .Values.server.ingress.annotations . | nindent 4 }}
    {{- else }}
      {{- toYaml .Values.server.ingress.annotations | nindent 4 }}
    {{- end }}
  {{- end }}
{{- end -}}

{{- define "vault.service.annotations" -}}
  {{- if .Values.server.service.annotations }}
    {{- $tp := typeOf .Values.server.service.annotations }}
    {{- if eq $tp "string" }}
      {{- tpl .Values.server.service.annotations . | nindent 4 }}
    {{- else }}
      {{- toYaml .Values.server.service.annotations | nindent 4 }}
    {{- end }}
  {{- end }}
{{- end -}}

{{- define "vault.service.active.annotations" -}}
  {{- if .Values.server.service.active.annotations }}
    {{- $tp := typeOf .Values.server.service.active.annotations }}
    {{- if eq $tp "string" }}
      {{- tpl .Values.server.service.active.annotations . | nindent 4 }}
    {{- else }}
      {{- toYaml .Values.server.service.active.annotations | nindent 4 }}
    {{- end }}
  {{- end }}
{{- end -}}

{{- define "vault.service.standby.annotations" -}}
  {{- if .Values.server.service.standby.annotations }}
    {{- $tp := typeOf .Values.server.service.standby.annotations }}
    {{- if eq $tp "string" }}
      {{- tpl .Values.server.service.standby.annotations . | nindent 4 }}
    {{- else }}
      {{- toYaml .Values.server.service.standby.annotations | nindent 4 }}
    {{- end }}
  {{- end }}
{{- end -}}

{{- define "vault.statefulSet.annotations" -}}
  {{- if .Values.server.statefulSet.annotations }}
  annotations:
    {{- $tp := typeOf .Values.server.statefulSet.annotations }}
    {{- if eq $tp "string" }}
      {{- tpl .Values.server.statefulSet.annotations . | nindent 4 }}
    {{- else }}
      {{- toYaml .Values.server.statefulSet.annotations | nindent 4 }}
    {{- end }}
  {{- end }}
{{- end -}}

{{- define "vault.dataVolumeClaim.annotations" -}}
  {{- if and (ne .mode "dev") (.Values.server.dataStorage.enabled) (.Values.server.dataStorage.annotations) }}
  annotations:
    {{- $tp := typeOf .Values.server.dataStorage.annotations }}
    {{- if eq $tp "string" }}
      {{- tpl .Values.server.dataStorage.annotations . | nindent 4 }}
    {{- else }}
      {{- toYaml .Values.server.dataStorage.annotations | nindent 4 }}
    {{- end }}
  {{- end }}
{{- end -}}

{{- define "vault.dataVolumeClaim.labels" -}}
  {{- if and (ne .mode "dev") (.Values.server.dataStorage.enabled) (.Values.server.dataStorage.labels) }}
  labels:
    {{- $tp := typeOf .Values.server.dataStorage.labels }}
    {{- if eq $tp "string" }}
      {{- tpl .Values.server.dataStorage.labels . | nindent 4 }}
    {{- else }}
      {{- toYaml .Values.server.dataStorage.labels | nindent 4 }}
    {{- end }}
  {{- end }}
{{- end -}}

{{- define "vault.auditVolumeClaim.annotations" -}}
  {{- if and (ne .mode "dev") (.Values.server.auditStorage.enabled) (.Values.server.auditStorage.annotations) }}
  annotations:
    {{- $tp := typeOf .Values.server.auditStorage.annotations }}
    {{- if eq $tp "string" }}
      {{- tpl .Values.server.auditStorage.annotations . | nindent 4 }}
    {{- else }}
      {{- toYaml .Values.server.auditStorage.annotations | nindent 4 }}
    {{- end }}
  {{- end }}
{{- end -}}

{{- define "vault.auditVolumeClaim.labels" -}}
  {{- if and (ne .mode "dev") (.Values.server.auditStorage.enabled) (.Values.server.auditStorage.labels) }}
  labels:
    {{- $tp := typeOf .Values.server.auditStorage.labels }}
    {{- if eq $tp "string" }}
      {{- tpl .Values.server.auditStorage.labels . | nindent 4 }}
    {{- else }}
      {{- toYaml .Values.server.auditStorage.labels | nindent 4 }}
    {{- end }}
  {{- end }}
{{- end -}}

{{- define "vault.resources" -}}
  {{- if .Values.server.resources -}}
          resources:
{{ toYaml .Values.server.resources | indent 12}}
  {{ end }}
{{- end -}}

{{- define "injector.resources" -}}
  {{- if .Values.injector.resources -}}
          resources:
{{ toYaml .Values.injector.resources | indent 12}}
  {{ end }}
{{- end -}}

{{- define "csi.resources" -}}
  {{- if .Values.csi.resources -}}
          resources:
{{ toYaml .Values.csi.resources | indent 12}}
  {{ end }}
{{- end -}}

{{- define "csi.agent.resources" -}}
  {{- if .Values.csi.agent.resources -}}
          resources:
{{ toYaml .Values.csi.agent.resources | indent 12}}
  {{ end }}
{{- end -}}

{{- define "csi.daemonSet.annotations" -}}
  {{- if .Values.csi.daemonSet.annotations }}
  annotations:
    {{- $tp := typeOf .Values.csi.daemonSet.annotations }}
    {{- if eq $tp "string" }}
      {{- tpl .Values.csi.daemonSet.annotations . | nindent 4 }}
    {{- else }}
      {{- toYaml .Values.csi.daemonSet.annotations | nindent 4 }}
    {{- end }}
  {{- end }}
{{- end -}}

{{- define "csi.daemonSet.securityContext.pod" -}}
  {{- if .Values.csi.daemonSet.securityContext.pod }}
      securityContext:
    {{- $tp := typeOf .Values.csi.daemonSet.securityContext.pod }}
    {{- if eq $tp "string" }}
      {{- tpl .Values.csi.daemonSet.securityContext.pod . | nindent 8 }}
    {{- else }}
      {{- toYaml .Values.csi.daemonSet.securityContext.pod | nindent 8 }}
    {{- end }}
  {{- end }}
{{- end -}}

{{- define "csi.daemonSet.securityContext.container" -}}
  {{- if .Values.csi.daemonSet.securityContext.container }}
          securityContext:
    {{- $tp := typeOf .Values.csi.daemonSet.securityContext.container }}
    {{- if eq $tp "string" }}
      {{- tpl .Values.csi.daemonSet.securityContext.container . | nindent 12 }}
    {{- else }}
      {{- toYaml .Values.csi.daemonSet.securityContext.container | nindent 12 }}
    {{- end }}
  {{- else if .Values.global.openshift }}
          securityContext:
            privileged: true
  {{- end }}
{{- end -}}

{{- define "csi.agent.securityContext.container" -}}
  {{- if .Values.csi.agent.securityContext.container }}
          securityContext:
            {{- $tp := typeOf .Values.csi.agent.securityContext.container }}
            {{- if eq $tp "string" }}
              {{- tpl .Values.csi.agent.securityContext.container . | nindent 12 }}
            {{- else }}
              {{- toYaml .Values.csi.agent.securityContext.container | nindent 12 }}
            {{- end }}
  {{- end }}
{{- end -}}

{{- define "csi.pod.tolerations" -}}
  {{- if .Values.csi.pod.tolerations }}
      tolerations:
      {{- $tp := typeOf .Values.csi.pod.tolerations }}
      {{- if eq $tp "string" }}
        {{ tpl .Values.csi.pod.tolerations . | nindent 8 | trim }}
      {{- else }}
        {{- toYaml .Values.csi.pod.tolerations | nindent 8 }}
      {{- end }}
  {{- end }}
{{- end -}}

{{- define "csi.pod.nodeselector" -}}
  {{- if .Values.csi.pod.nodeSelector }}
      nodeSelector:
      {{- $tp := typeOf .Values.csi.pod.nodeSelector }}
      {{- if eq $tp "string" }}
        {{ tpl .Values.csi.pod.nodeSelector . | nindent 8 | trim }}
      {{- else }}
        {{- toYaml .Values.csi.pod.nodeSelector | nindent 8 }}
      {{- end }}
  {{- end }}
{{- end -}}

{{- define "csi.pod.affinity" -}}
  {{- if .Values.csi.pod.affinity }}
      affinity:
        {{ $tp := typeOf .Values.csi.pod.affinity }}
        {{- if eq $tp "string" }}
          {{- tpl .Values.csi.pod.affinity . | nindent 8 | trim }}
        {{- else }}
          {{- toYaml .Values.csi.pod.affinity | nindent 8 }}
        {{- end }}
  {{ end }}
{{- end -}}

{{- define "csi.pod.annotations" -}}
  {{- if .Values.csi.pod.annotations }}
      annotations:
      {{- $tp := typeOf .Values.csi.pod.annotations }}
      {{- if eq $tp "string" }}
        {{- tpl .Values.csi.pod.annotations . | nindent 8 }}
      {{- else }}
        {{- toYaml .Values.csi.pod.annotations | nindent 8 }}
      {{- end }}
  {{- end }}
{{- end -}}

{{- define "csi.serviceAccount.annotations" -}}
  {{- if .Values.csi.serviceAccount.annotations }}
  annotations:
    {{- $tp := typeOf .Values.csi.serviceAccount.annotations }}
    {{- if eq $tp "string" }}
      {{- tpl .Values.csi.serviceAccount.annotations . | nindent 4 }}
    {{- else }}
      {{- toYaml .Values.csi.serviceAccount.annotations | nindent 4 }}
    {{- end }}
  {{- end }}
{{- end -}}

{{- define "vault.extraEnvironmentVars" -}}
{{- if .extraEnvironmentVars -}}
{{- range $key, $value := .extraEnvironmentVars }}
- name: {{ printf "%s" $key | replace "." "_" | upper | quote }}
  value: {{ $value | quote }}
{{- end }}
{{- end -}}
{{- end -}}

{{- define "vault.extraSecretEnvironmentVars" -}}
{{- if .extraSecretEnvironmentVars -}}
{{- range .extraSecretEnvironmentVars }}
- name: {{ .envName }}
  valueFrom:
   secretKeyRef:
     name: {{ .secretName }}
     key: {{ .secretKey }}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "vault.scheme" -}}
{{- if .Values.global.tlsDisable -}}
{{ "http" }}
{{- else -}}
{{ "https" }}
{{- end -}}
{{- end -}}

{{- define "imagePullSecrets" -}}
{{- with .Values.global.imagePullSecrets -}}
imagePullSecrets:
{{- range . -}}
{{- if typeIs "string" . }}
  - name: {{ . }}
{{- else if index . "name" }}
  - name: {{ .name }}
{{- end }}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "service.externalTrafficPolicy" -}}
{{- $type := "" -}}
{{- if .serviceType -}}
{{- $type = .serviceType -}}
{{- else if .type -}}
{{- $type = .type -}}
{{- end -}}
{{- if and .externalTrafficPolicy (or (eq $type "LoadBalancer") (eq $type "NodePort")) }}
  externalTrafficPolicy: {{ .externalTrafficPolicy }}
{{- else }}
{{- end }}
{{- end -}}

{{- define "service.loadBalancer" -}}
{{- if  eq (.serviceType | toString) "LoadBalancer" }}
{{- if .loadBalancerIP }}
  loadBalancerIP: {{ .loadBalancerIP }}
{{- end }}
{{- with .loadBalancerSourceRanges }}
  loadBalancerSourceRanges:
{{- range . }}
  - {{ . }}
{{- end }}
{{- end -}}
{{- end }}
{{- end -}}

{{- define "vault.config" -}}
{{- if or (eq .mode "ha") (eq .mode "standalone") }}
{{- $config := (index .Values.server .mode).config -}}
{{- if .Values.server.ha.raft.enabled -}}
{{- $config = .Values.server.ha.raft.config -}}
{{- end -}}
{{- $type := typeOf $config -}}
{{- if eq $type "string" -}}
{{- $json := tpl $config . | fromJson -}}
{{- if or (and (eq ($json | len) 1) (hasKey $json "Error")) (eq ($json | len) 0) -}}
{{- if not (regexMatch "(?m)^\\s*disable_mlock\\s*=\\s*(true|false)" $config) -}}
{{- $config = printf "%s\n%s" $config "disable_mlock = true" -}}
{{- end -}}
{{- else -}}
{{- if not (hasKey $json "disable_mlock") -}}
{{- $_ := set $json "disable_mlock" true -}}
{{- end -}}
{{- $config = $json | mustToJson -}}
{{- end -}}
{{- else }}
{{- fail "structured server config is not supported, value must be a string"}}
{{- end }}
{{- tpl $config . | nindent 4 | trim }}
{{- end -}}
{{- end -}}

{{- define "vault.validateRedundancyZones" -}}
{{- if eq (.Values.server.ha.raft.redundancyZones.enabled | toString) "true" -}}
  {{- if semverCompare "< 1.35-0" .Capabilities.KubeVersion.Version -}}
    {{- fail "server.ha.raft.redundancyZones.enabled=true requires Kubernetes >= 1.35 (PodTopologyLabelsAdmission)" -}}
  {{- end -}}
  {{- if ne (.Values.server.ha.enabled | toString) "true" -}}
    {{- fail "server.ha.raft.redundancyZones.enabled=true requires server.ha.enabled=true" -}}
  {{- end -}}
  {{- if ne (.Values.server.ha.raft.enabled | toString) "true" -}}
    {{- fail "server.ha.raft.redundancyZones.enabled=true requires server.ha.raft.enabled=true" -}}
  {{- end -}}
  {{- $config := .Values.server.ha.raft.config | default "" -}}
  {{- $hclMatch := regexMatch "(?m)^(?:[^#/\\n]|/[^/])*autopilot_redundancy_zone\\s*=\\s*\"VAULT_REDUNDANCY_ZONE\"" $config -}}
  {{- $jsonMatch := regexMatch "\"autopilot_redundancy_zone\"\\s*:\\s*\"VAULT_REDUNDANCY_ZONE\"" $config -}}
  {{- if not (or $hclMatch $jsonMatch) -}}
    {{- fail "server.ha.raft.redundancyZones.enabled=true requires 'autopilot_redundancy_zone = \"VAULT_REDUNDANCY_ZONE\"' in server.ha.raft.config (must not be commented out)" -}}
  {{- end -}}
{{- end -}}
{{- end -}}
