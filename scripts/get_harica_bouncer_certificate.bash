#!/usr/bin/env bash
set -euo pipefail

# === Usage and argument parsing ===
usage() {
  cat <<EOF
Usage: $0 --domain <domain_name> [--cert-extra-options "<options>"]

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


# === Static configuration ===
CONFIG_FILE="${ENV_BASE_DIR}/.env_secrets.sops.yaml"

CERTBOT_WORKDIR="/dev/shm/${DOMAIN_NAME}/certbot"
CERTBOT_CONF="${CERTBOT_WORKDIR}/certbot.conf"
CERT_DIR="/etc/letsencrypt/live/${DOMAIN_NAME}"
TARGET_CERT_SOPS_FILE="${ENV_BASE_DIR}/secrets-bouncer-cert.sops.yaml"

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

# === Read and encode certificate + key ===
FULLCHAIN_PATH="${CERT_DIR}/fullchain.pem"
PRIVKEY_PATH="${CERT_DIR}/privkey.pem"

if [[ ! -f "$FULLCHAIN_PATH" || ! -f "$PRIVKEY_PATH" ]]; then
  echo "Error: Certificate files not found for domain $DOMAIN_NAME"
  exit 1
fi

# Write updated file
{
  echo "# Ansible/SOPS updated certificate"
  echo "bouncerTlsCert: |"
  sed 's/^/  /' "$FULLCHAIN_PATH"
  echo "bouncerTlsKey: |"
  sed 's/^/  /' "$PRIVKEY_PATH"
} | sops -e --input-type=yaml --output-type=yaml --output $TARGET_CERT_SOPS_FILE /dev/stdin


echo "Certificate and key have been updated in $TARGET_CERT_SOPS_FILE"