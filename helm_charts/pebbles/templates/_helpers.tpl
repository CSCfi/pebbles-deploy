{{/* Bouncer domains as a map of domain -> {tlsCert, tlsKey}, from bouncerDomains or the deprecated single-domain values, never both. */}}
{{- define "pebbles.bouncerDomains" -}}
{{- $legacy := or .Values.bouncerFromDomain .Values.bouncerTlsCert .Values.bouncerTlsKey -}}
{{- if and .Values.bouncerDomains $legacy -}}
{{- fail "bouncerDomains and the single-domain bouncerFromDomain/bouncerTlsCert/bouncerTlsKey cannot be combined; move the certificate to bouncerDomains" -}}
{{- end -}}
{{- $domains := .Values.bouncerDomains | default dict -}}
{{- if .Values.bouncerFromDomain -}}
{{- $domains = dict .Values.bouncerFromDomain (dict "tlsCert" .Values.bouncerTlsCert "tlsKey" .Values.bouncerTlsKey) -}}
{{- end -}}
{{- if not $domains -}}
{{- fail "bouncerEnabled needs bouncerDomains or bouncerFromDomain" -}}
{{- end -}}
{{- range $domain, $_ := $domains -}}
{{- if not (regexMatch "^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$" $domain) -}}
{{- fail (printf "bouncer domain %q is not a lowercase host name" $domain) -}}
{{- end -}}
{{- end -}}
{{/* toJson, not toYaml: toYaml drops the final newline of the last PEM value */}}
{{- toJson $domains -}}
{{- end -}}
