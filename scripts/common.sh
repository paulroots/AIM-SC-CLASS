#!/usr/bin/env bash
# Shared helpers. Sourced by the other scripts; not meant to be run directly.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Load .env if present. Variables already set in the shell win.
if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  . ./.env
  set +a
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

require_private_key() {
  if [ -z "${PRIVATE_KEY:-}" ]; then
    echo "PRIVATE_KEY is not set. Copy .env.example to .env and fill it in." >&2
    exit 1
  fi
}

ok()   { printf '  \033[32m[ok]\033[0m   %s\n' "$*"; }
warn() { printf '  \033[33m[warn]\033[0m %s\n' "$*"; }
fail() { printf '  \033[31m[fail]\033[0m %s\n' "$*"; }
