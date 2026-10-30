#!/usr/bin/env bash
# Shared helpers. Sourced by the other scripts; not meant to be run directly.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Load .env if present. Variables already set in the shell win.
if [ -f .env ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|\#*) continue ;; esac
    key="${line%%=*}"; val="${line#*=}"
    [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
    val="${val%\"}"; val="${val#\"}"
    if [ -z "${!key+x}" ]; then export "$key=$val"; fi
  done < .env
fi

LOCAL_RPC_URL="${LOCAL_RPC_URL:-http://127.0.0.1:8545}"
PRISMO_RPC_URL="${PRISMO_RPC_URL:-https://rpc.glassnet.prismo.network/}"
PRISMO_CHAIN_ID=101001000
PRISMO_EXPLORER="https://explorer.glassnet.prismo.network"
LOCAL_CHAIN_ID=31337

# resolve_network <local|prismo> sets RPC_URL, CHAIN_ID, EXPLORER, NETWORK_NAME.
resolve_network() {
  case "${1:-local}" in
    local)
      RPC_URL="$LOCAL_RPC_URL"; CHAIN_ID="$LOCAL_CHAIN_ID"; EXPLORER=""; NETWORK_NAME="Anvil (local)" ;;
    prismo)
      RPC_URL="$PRISMO_RPC_URL"; CHAIN_ID="$PRISMO_CHAIN_ID"; EXPLORER="$PRISMO_EXPLORER"; NETWORK_NAME="Prismo Glassnet" ;;
    *)
      echo "Unknown NETWORK '$1'. Use NETWORK=local or NETWORK=prismo." >&2; exit 1 ;;
  esac
}

PRISMO_FAUCET="https://faucet.glassnet.prismo.network/"

# Anvil account #0. Its key is printed by every Anvil install, so it is public:
# fine on the local chain, never acceptable on Prismo.
ANVIL_KEY0="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
LOCAL_PRIVATE_KEY="${LOCAL_PRIVATE_KEY:-$ANVIL_KEY0}"

# signer_key <local|prismo> prints the key that signs on that network.
#   local  -> LOCAL_PRIVATE_KEY (defaults to Anvil account #0, which Anvil funds)
#   prismo -> PRIVATE_KEY (your own wallet, funded from the faucet)
signer_key() {
  if [ "${1:-local}" = "local" ]; then
    printf '%s' "$LOCAL_PRIVATE_KEY"
    return
  fi
  if [ -z "${PRIVATE_KEY:-}" ]; then
    echo "PRIVATE_KEY is not set. Put your own wallet's key in .env (see README, section 5)." >&2
    exit 1
  fi
  if [ "$(echo "$PRIVATE_KEY" | tr '[:upper:]' '[:lower:]')" = "$ANVIL_KEY0" ]; then
    echo "PRIVATE_KEY is Anvil's public test key. Anyone can spend from it on Prismo." >&2
    echo "Create a fresh MetaMask account and put its key in .env instead." >&2
    exit 1
  fi
  printf '%s' "$PRIVATE_KEY"
}

require_private_key() {
  signer_key prismo >/dev/null
}

ok()   { printf '  \033[32m[ok]\033[0m   %s\n' "$*"; }
warn() { printf '  \033[33m[warn]\033[0m %s\n' "$*"; }
fail() { printf '  \033[31m[fail]\033[0m %s\n' "$*"; }
