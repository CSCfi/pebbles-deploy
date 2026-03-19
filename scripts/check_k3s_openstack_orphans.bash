#!/bin/bash

set -euo pipefail

: "${ENV_NAME:?ENV_NAME is not set. Run the script inside the pebbles-deployer container.}"
: "${OS_AUTH_URL:?OpenStack credentials not sourced. Source your openrc (or clouds.yaml env) first.}"

# Colors only when stdout is a TTY
if [[ -t 1 ]]; then
    RED=$'\033[0;31m'
    GREEN=$'\033[0;32m'
    YELLOW=$'\033[0;33m'
    NC=$'\033[0m'
else
    RED='' ; GREEN='' ; YELLOW='' ; NC=''
fi

# Minimum VM age before we consider it an orphan
MIN_VM_AGE_SECONDS=1800
now_epoch=$(date +%s)
cutoff_epoch=$((now_epoch - MIN_VM_AGE_SECONDS))

# Fail-safe: unparseable timestamps are treated as old (surfaced, not hidden).
is_old_enough() {
    local ts="$1"
    local ts_epoch
    if ! ts_epoch=$(date -d "$ts" +%s 2>/dev/null); then
        return 0
    fi
    [[ "$ts_epoch" -lt "$cutoff_epoch" ]]
}

echo "🔍 Comparing OpenStack servers (filtered by '$ENV_NAME') vs Kubernetes nodes..."
echo ""

# Temporary files with a trap to clean up
os_raw=$(mktemp)
os_names=$(mktemp)
oc_names=$(mktemp)
os_names_unsorted=$(mktemp)
trap 'rm -f "$os_raw" "$os_names_unsorted" "$os_names" "$oc_names"' EXIT

# --- OpenStack ---
echo "📦 Fetching OpenStack servers..."
if ! openstack server list --long --name "$ENV_NAME" -c Name -c "Created At" -f value > "$os_raw"
then
    echo -e "${RED}❌ Failed to list OpenStack servers. Check your OS_* credentials.${NC}" >&2
    exit 1
fi

# Loop runs in current shell — piping into sort would subshell it and lose os_created updates.
declare -A os_created
while read -r name created; do
    [[ -z "$name" ]] && continue
    if [[ "$name" == "$ENV_NAME-jump" || "$name" == "$ENV_NAME-bastion" || "$name" == "$ENV_NAME-nfs" ]]; then
        continue
    fi
    os_created["$name"]="$created"
    printf '%s\t%s\n' "$created" "$name" >> "$os_names_unsorted"
done < "$os_raw"

# Sort by "Created At" descending (newest first). ISO 8601 timestamps sort lexicographically.
sort -r "$os_names_unsorted" | cut -f2 > "$os_names"

if [[ ! -s "$os_names" ]]; then
    echo -e "${YELLOW}⚠️  No OpenStack servers found matching '$ENV_NAME'.${NC}"
fi

# --- Kubernetes ---
echo "🖥️ Fetching Kubernetes nodes..."
if ! oc get nodes -o wide 2>/dev/null | awk 'NR>1 {print $1}' | sed 's/\..*$//' | sort -u > "$oc_names"
then
    echo -e "${RED}❌ Failed to get Kubernetes nodes. Is 'oc' logged in and connected?${NC}" >&2
    exit 1
fi

if [[ ! -s "$oc_names" ]]; then
    echo -e "${RED}❌ No Kubernetes nodes returned. Is 'oc' logged in and connected?${NC}" >&2
    exit 1
fi

echo ""

# --- Compare ---
# printf's %-Ns counts bytes, not display columns; Unicode status glyphs need manual padding.
status_col_width=24
pad_to() {
    local target="$1" label="$2"
    local display_len=${#label}
    [[ "$label" == ⏳* ]] && display_len=$((display_len + 1))
    local pad=$((target - display_len))
    (( pad < 0 )) && pad=0
    printf '%s%*s' "$label" "$pad" ""
}

printf "%-40s | %-${status_col_width}s | %s\n" "OpenStack Server" "Status" "Created At ⬇️"
printf '%s-+-%s-+-%s\n' \
    "----------------------------------------" \
    "$(printf '%*s' "$status_col_width" '' | tr ' ' '-')" \
    "-------------------------"

missing_vm_count=0
match_vm_count=0

while IFS= read -r name; do
    [[ -z "$name" ]] && continue

    created="${os_created[$name]:-}"

    if grep -Fxq -- "$name" "$oc_names"; then
        status_label="✓ Match"
        color="$GREEN"
        match_vm_count=$((match_vm_count + 1))
    elif is_old_enough "$created"; then
        status_label="✗ Missing in OC"
        color="$RED"
        missing_vm_count=$((missing_vm_count + 1))
    else
        status_label="⏳ Spawning (< $((MIN_VM_AGE_SECONDS / 60))m old)"
        color="$YELLOW"
    fi

    printf "%-40s | %s%s%s | %s\n" "$name" "$color" "$(pad_to "$status_col_width" "$status_label")" "$NC" "$created"
done < "$os_names"

# --- Unattached node volumes ---
echo ""
echo "💾 Checking for unattached OpenStack volumes matching '${ENV_NAME}-node'..."

vol_raw=$(mktemp)
trap 'rm -f "$os_raw" "$os_names_unsorted" "$os_names" "$oc_names" "$vol_raw"' EXIT

if ! openstack volume list --long -f json > "$vol_raw"
then
    echo -e "${RED}❌ Failed to list OpenStack volumes.${NC}" >&2
    exit 1
fi

# `openstack volume list --name` is exact match; filter client-side by prefix instead.
vol_total_count=$(jq --arg prefix "${ENV_NAME}-node" \
    '[.[] | select(.Name | startswith($prefix))] | length' "$vol_raw")
vol_unattached_count=0

if [[ "$vol_total_count" -eq 0 ]]; then
    echo -e "${YELLOW}⚠️  No volumes found matching '${ENV_NAME}-node'.${NC}"
else
    printf "%-40s | %-10s | %-12s | %s\n" "Volume Name" "Size (GB)" "Vol Status" "Created At"
    printf "%-40s-+-%-10s-+-%-12s-+-%s\n" \
        "----------------------------------------" \
        "----------" \
        "------------" \
        "-------------------------"

    # Print volumes, augmenting creation date per volume
    while IFS=$'\t' read -r vol_name vol_size vol_status; do
        [[ -z "$vol_name" ]] && continue
        if [[ "$vol_status" == "in-use" ]]; then
            color=$GREEN
        else
            color=$RED
            vol_unattached_count=$((vol_unattached_count + 1))
        fi

        # volume list --long omits created_at; fetch per-volume. Trim microseconds.
        if ! vol_created=$(openstack volume show "$vol_name" -c created_at -f value 2>/dev/null | sed 's/\..*$//'); then
            vol_created="<unknown>"
        fi
        printf "%-40s | %-10s | %s%-12s%s | %s\n" "$vol_name" "$vol_size" "$color" "$vol_status" "$NC" "$vol_created"
    done < <(jq -r --arg prefix "${ENV_NAME}-node" \
        '.[] | select(.Name | startswith($prefix)) | [.Name, (.Size|tostring), .Status] | @tsv' \
        "$vol_raw"
    )

    if [[ "$vol_unattached_count" -eq 0 ]]; then
        echo -e "${GREEN}✓ All ${vol_total_count} volume(s) are attached.${NC}"
    fi
fi

# --- Summary ---
os_count=$(wc -l < "$os_names" | tr -d ' ')

echo ""
echo "📊 Summary:"
echo "  OpenStack servers:  $os_count"
echo "  Matches:            $match_vm_count"
echo "  Missing in OC:      $missing_vm_count"
echo "  Volumes checked:    $vol_total_count"
echo "  Unattached volumes: $vol_unattached_count"
