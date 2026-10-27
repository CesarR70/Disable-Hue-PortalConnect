# Disable Hue PortalConnect

Disable cloud "portal services" on a Philips Hue Bridge via its local API, preventing the bridge from reaching Philips' cloud infrastructure.

## What This Does

The Hue Bridge's `portalservices` setting controls its connection to Philips' cloud, which powers:

- **Remote control** — the ability to control lights from outside your home via the Hue app
- **Cloud voice assistants** — integrations like Amazon Alexa, Google Home, etc.
- **Internet reachability** — the bridge becomes accessible over the internet through Philips' cloud relay

Disabling `portalservices` does **not** affect local control. Lights, scenes, and automations that run on the bridge continue to work normally.

## Prerequisites

- A Philips Hue Bridge on your local network
- `curl` installed (standard on macOS & most Linux distos; install via your package manager if needed)
- The bridge's local IP address (Script default: `192.168.10.11`)

## Usage

```bash
# Basic usage — prompts you to press the bridge's link button
./disable-Hue-PortalConnect.sh [BRIDGE_IP]

# With a saved API key — skips the link-button step
HUE_KEY=<your-api-key> ./disable-Hue-PortalConnect.sh [BRIDGE_IP]
```

### First-Time Setup (Obtaining an API Key)

On the first run, the script will:

1. Verify the bridge is reachable at the given IP
2. Prompt you to press the **physical link button** (the round button on top of the bridge)
3. Wait up to 30 seconds for you to confirm the button was pressed
4. Register a new API key with the bridge and display it

Save the returned API key for future runs:

```bash
HUE_KEY=abc123def456 ./disable-Hue-PortalConnect.sh
```

### Re-enabling Portal Services

To undo this change, send `{"portalservices": true}` to the bridge's config endpoint:

```bash
HUE_KEY=<your-api-key> curl -X PUT http://<BRIDGE_IP>/api/<your-api-key>/config -d '{"portalservices":true}'
```

Or use the Hue app to re-enable cloud connectivity.

## How It Works

| Step | Description |
|------|-------------|
| 1 | Probes the bridge at `/api/config` to confirm it's a Hue Bridge |
| 2 | Registers an API key via the bridge's link button (or uses `HUE_KEY`) |
| 3 | Reads the current `portalservices` value and exits early if already `false` |
| 4 | Prompts for confirmation, then sends `PUT /api/<key>/config` with `{"portalservices": false}` |
| 5 | Re-reads the config to verify the change took effect |

## Security Notes

- The script uses only the local network API — no credentials or keys are transmitted over the internet
- The API key is displayed in plain text; store it securely and avoid committing it to version control
- Disabling portal services is reversible at any time using the re-enable command above
