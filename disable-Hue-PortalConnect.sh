#!/usr/bin/env bash
#
# disable-Hue-PortalScript.sh
# Disables the cloud "portal services" on a Philips Hue Bridge using its local API.
#
# Usage:
#   ./disable-Hue-PortalScript.sh [BRIDGE_IP]
#   HUE_KEY=<existing-api-key> ./disable-Hue-PortalScript.sh [BRIDGE_IP]   # skip the button step
#
# To undo later, send {"portalservices": true} to the same endpoint.

set -uo pipefail

BRIDGE_IP="${1:-192.168.10.11}"
HOST_TAG="$(hostname -s 2>/dev/null || echo host)"
DEVICETYPE="hue_portal_off#${HOST_TAG:0:19}"   # Hue limit: app<=20, device<=19 chars
API="http://${BRIDGE_IP}/api"

confirm() {
    local reply
    read -r -p "$1 [y/N]: " reply
    [[ "$reply" =~ ^[Yy]$ ]]
}

die() { echo "ERROR: $*" >&2; exit 1; }

command -v curl >/dev/null 2>&1 || die "curl is required but not installed."

# --- 1. Make sure the bridge is reachable --------------------------------------
echo "Checking for a Hue Bridge at ${BRIDGE_IP}..."
info=$(curl -s -m 5 "${API}/config") || die "Could not reach ${BRIDGE_IP}."
grep -q '"bridgeid"' <<<"$info" || die "${BRIDGE_IP} does not look like a Hue Bridge. Response: $info"
name=$(sed -n 's/.*"name":"\([^"]*\)".*/\1/p' <<<"$info")
echo "Found: ${name:-Hue Bridge} (${BRIDGE_IP})"
echo

# --- 2. Get an API key (unless one was supplied) ------------------------------
KEY="${HUE_KEY:-}"
if [[ -z "$KEY" ]]; then
    cat <<EOF
To authorize this script, you must press the PHYSICAL LINK BUTTON
(the large round button on top) of the Hue Bridge.

  1. Walk over to the bridge and press the button.
  2. Within 30 seconds, come back and answer 'y' below.

EOF
    confirm "Have you pressed the link button on the Hue Bridge?" || die "Aborted by user."

    while true; do
        resp=$(curl -s -m 5 -X POST "${API}" -d "{\"devicetype\":\"${DEVICETYPE}\"}") \
            || die "Request to the bridge failed."
        KEY=$(sed -n 's/.*"username":"\([^"]*\)".*/\1/p' <<<"$resp")
        [[ -n "$KEY" ]] && break

        if grep -q '"type":101' <<<"$resp"; then
            echo
            echo "The bridge reports the link button was NOT pressed (or the 30s window expired)."
            confirm "Press the button again, then answer 'y' to retry" || die "Aborted by user."
        else
            die "Unexpected response from bridge: $resp"
        fi
    done
    echo
    echo "Success! API key retrieved: ${KEY}"
    echo "(Save it: next time run 'HUE_KEY=${KEY} $0' to skip the button step.)"
fi
echo

# --- 3. Show current state ----------------------------------------------------
cfg=$(curl -s -m 5 "${API}/${KEY}/config") || die "Could not read bridge config."
grep -q '"unauthorized user"' <<<"$cfg" && die "API key was rejected by the bridge."
current=$(grep -o '"portalservices":[a-z]*' <<<"$cfg" | cut -d: -f2)
echo "Current portalservices setting: ${current:-unknown}"

if [[ "$current" == "false" ]]; then
    echo "Portal services are already disabled. Nothing to do."
    exit 0
fi
echo

# --- 4. Confirm and send the PUT ----------------------------------------------
cat <<EOF
About to send the following request to the bridge:

  PUT ${API}/${KEY}/config
  {"portalservices": false}

This disables Hue cloud connectivity: remote (away-from-home) control and
cloud-based voice assistants will stop working. Local control is unaffected.

EOF
confirm "Continue and disable portal services?" || die "Aborted by user. No changes made."

resp=$(curl -s -m 5 -X PUT "${API}/${KEY}/config" -d '{"portalservices":false}') \
    || die "PUT request failed."
grep -q '"success"' <<<"$resp" || die "Bridge did not accept the change. Response: $resp"
echo "Bridge response: $resp"

# --- 5. Verify -----------------------------------------------------------------
sleep 3
after=$(curl -s -m 5 "${API}/${KEY}/config" | grep -o '"portalservices":[a-z]*' | cut -d: -f2)
if [[ "$after" == "false" ]]; then
    echo "Verified: portalservices is now DISABLED."
else
    die "Verification failed. portalservices reads as '${after:-unknown}'."
fi
