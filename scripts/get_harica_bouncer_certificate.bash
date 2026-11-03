#!/usr/bin/env bash
set -euo pipefail

# === Usage and argument parsing ===
usage() {
  cat <<EOF
Usage: $0 --domain <domain_name> [--cert-extra-options "<options>"]

Obtains a certificate for the domain and stores it in
secrets-bouncer-domains.sops.yaml in the environment directory, as
bouncerDomains.<domain_name> for the Helm chart. An existing entry for the
domain is replaced; entries for other domains are kept. The file is updated
with a read-modify-write, so do not run the script for two domains at once.

Required arguments:
  --domain <domain_name>        Domain name for which to obtain the certificate.

Optional arguments:
  --cert-extra-options "<opts>" Optional additional flags to pass to certbot.
                                Example: "--force-renewal --preferred-challenges http"
  -h, --help                    Show this help message and exit.

Environment variables:
  CERTBOT_EXTRA_OPTIONS         Optional additional flags for certbot (alternative to --cert-extra-options)

Example usage:

  ./get_harica_bouncer_certificate.bash \\
      --domain example.com \\
      --cert-extra-options "--force-renewal --preferred-challenges http"

EOF
  exit 1
}

DOMAIN_NAME=""
CERTBOT_EXTRA_OPTIONS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --domain)
      DOMAIN_NAME="$2"
      shift 2
      ;;
    --cert-extra-options)
      CERTBOT_EXTRA_OPTIONS="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown argument: $1"
      usage
      ;;
  esac
done

if [[ -z "$DOMAIN_NAME" ]]; then
  echo "Error: --domain is required."
  usage
fi

if [[ ! "$DOMAIN_NAME" =~ ^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$ ]]; then
  echo "Error: --domain must be a lowercase host name."
  exit 1
fi


# === Static configuration ===
CONFIG_FILE="${ENV_BASE_DIR}/.env_secrets.sops.yaml"

CERTBOT_WORKDIR="/dev/shm/${DOMAIN_NAME}/certbot"
CERTBOT_CONF="${CERTBOT_WORKDIR}/certbot.conf"
CERT_DIR="/etc/letsencrypt/live/${DOMAIN_NAME}"
DOMAINS_SOPS_FILE="${ENV_BASE_DIR}/secrets-bouncer-domains.sops.yaml"
LEGACY_CERT_SOPS_FILE="${ENV_BASE_DIR}/secrets-bouncer-cert.sops.yaml"

# Convert extra options string into an array
read -r -a EXTRA_OPTS_ARRAY <<< "$CERTBOT_EXTRA_OPTIONS"


mkdir -p "$CERTBOT_WORKDIR" "$CERTBOT_WORKDIR/logs"

# === Decrypt config once into memory ===
if sops --decrypt "$CONFIG_FILE" >/dev/null 2>&1; then
  echo "Decrypting $CONFIG_FILE with SOPS..."
  DECRYPTED_CONTENT=$(sops --decrypt "$CONFIG_FILE")
else
  echo "Using plaintext config file $CONFIG_FILE"
  DECRYPTED_CONTENT=$(cat "$CONFIG_FILE")
fi

# Read multiple values into an array from SOPS-decrypted YAML
readarray -t conf_array < <(
  echo "$DECRYPTED_CONTENT" | yq -r '.vaulted_certbot_config.email,
                                     .vaulted_certbot_config.eab_kid,
                                     .vaulted_certbot_config.eab_hmac_key,
                                     .vaulted_certbot_config.server'
)

echo "Loaded certbot config for domain: $DOMAIN_NAME"

# === Create certbot config ===
cat > "$CERTBOT_CONF" <<EOF
email = "${conf_array[0]}"
eab-kid = "${conf_array[1]}"
eab-hmac-key = "${conf_array[2]}"
server = "${conf_array[3]}"

work-dir = $CERTBOT_WORKDIR/
logs-dir = $CERTBOT_WORKDIR/logs

agree-tos = true
authenticator = standalone
no-eff-email = true
EOF

# === Obtain certificate if it doesn't exist ===
if [ ! -f "${CERT_DIR}/privkey.pem" ]; then
  echo "Running certbot for $DOMAIN_NAME..."
  certbot certonly -n --standalone -c "$CERTBOT_CONF" \
    --domain "$DOMAIN_NAME" "${EXTRA_OPTS_ARRAY[@]}"
else
  echo "Certificate already exists for $DOMAIN_NAME, skipping certbot run."
fi

# === Store certificate + key as bouncerDomains.<domain> ===
FULLCHAIN_PATH="${CERT_DIR}/fullchain.pem"
PRIVKEY_PATH="${CERT_DIR}/privkey.pem"

if [[ ! -f "$FULLCHAIN_PATH" || ! -f "$PRIVKEY_PATH" ]]; then
  echo "Error: Certificate files not found for domain $DOMAIN_NAME"
  exit 1
fi

if [[ ! -f "$DOMAINS_SOPS_FILE" ]]; then
  {
    echo "# bouncer certificates, maintained with scripts/get_harica_bouncer_certificate.bash"
    echo 'bouncerDomains: {}'
  } | sops -e --input-type=yaml --output-type=yaml --output "$DOMAINS_SOPS_FILE" /dev/stdin
fi

# replaces the domain's entry in place, or adds it; other entries keep their ciphertext
ENTRY_JSON=$(jq -n --rawfile cert "$FULLCHAIN_PATH" --rawfile key "$PRIVKEY_PATH" \
  '{tlsCert: $cert, tlsKey: $key}')
sops set "$DOMAINS_SOPS_FILE" "[\"bouncerDomains\"][\"${DOMAIN_NAME}\"]" "$ENTRY_JSON"

echo "Certificate and key for $DOMAIN_NAME stored in $DOMAINS_SOPS_FILE"

if [[ -f "$LEGACY_CERT_SOPS_FILE" ]]; then
  echo "Note: $LEGACY_CERT_SOPS_FILE still holds the single-domain certificate, which the chart refuses alongside bouncerDomains; run this script for that domain too, then remove the file and bouncerFromDomain from the values."
fi
