#!/usr/bin/env bash
# Verifies a deployed contract's source on the Prismo Glassnet explorer (Blockscout).
#   CONTRACT=Counter scripts/verify.sh
# Reads the address from web/deployments.json, so deploy first.

# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

CONTRACT="${CONTRACT:-Counter}"
NETWORK="${NETWORK:-prismo}"
resolve_network "$NETWORK"

if [ "$NETWORK" != "prismo" ]; then
  echo "Verification only applies to Prismo. Anvil has no explorer." >&2
  exit 1
fi

ADDRESS="${ADDRESS:-$(node -e '
  const d = require("./web/deployments.json");
  const c = d[process.argv[1]] && d[process.argv[1]].contracts[process.argv[2]];
  if (!c) process.exit(1);
  process.stdout.write(c.address);
' "$CHAIN_ID" "$CONTRACT" 2>/dev/null || true)}"

[ -n "$ADDRESS" ] || { echo "No $CONTRACT deployment recorded for chain $CHAIN_ID. Run: make deploy NETWORK=prismo CONTRACT=$CONTRACT" >&2; exit 1; }

# Constructor arguments must match what the deploy script used. Counter and StatusList are
# handled here; other contracts pass CONSTRUCTOR_ARGS.
ARGS="${CONSTRUCTOR_ARGS:-}"
if [ -z "$ARGS" ] && [ "$CONTRACT" = "Counter" ]; then
  ARGS="$(cast abi-encode 'constructor(uint256)' "${COUNTER_INITIAL:-0}")"
fi
# StatusList takes the DIDRegistry address it was deployed against.
if [ -z "$ARGS" ] && [ "$CONTRACT" = "StatusList" ]; then
  REGISTRY="$(node -e 'const d = require("./web/deployments.json"); process.stdout.write(d[process.argv[1]].contracts.DIDRegistry.address)' "$CHAIN_ID")"
  ARGS="$(cast abi-encode 'constructor(address)' "$REGISTRY")"
fi

echo "Verifying $CONTRACT at $ADDRESS on $NETWORK_NAME"
forge verify-contract "$ADDRESS" "src/${CONTRACT}.sol:${CONTRACT}" \
  --chain-id "$CHAIN_ID" \
  --verifier blockscout \
  --verifier-url "$EXPLORER/api" \
  ${ARGS:+--constructor-args "$ARGS"} \
  --watch

echo
echo "$EXPLORER/address/$ADDRESS?tab=contract"
