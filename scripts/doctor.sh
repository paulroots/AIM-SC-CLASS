#!/usr/bin/env bash
# Checks that this machine can build, test, and deploy. Run it first: `make doctor`.

# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

status=0
echo "Smart Contracts Lab: environment check"
echo

echo "Tools"
for tool in forge cast anvil node git; do
  if command -v "$tool" >/dev/null 2>&1; then
    ok "$tool $("$tool" --version 2>/dev/null | head -1 | sed 's/^[a-z]* *//')"
  else
    fail "$tool not found"; status=1
  fi
done
if command -v node >/dev/null 2>&1; then
  major="$(node -p 'process.versions.node.split(".")[0]')"
  if [ "$major" -lt 18 ]; then fail "node 18 or newer is required (found $major)"; status=1; fi
fi

echo
echo "Project"
if [ -d lib/forge-std/src ]; then ok "forge-std installed"; else fail "forge-std missing. Run: make install"; status=1; fi
if [ -f .env ]; then ok ".env present"; else warn ".env missing. Copy .env.example to .env (fine for local-only work until you deploy)"; fi
if [ -n "${PRIVATE_KEY:-}" ]; then
  if addr="$(cast wallet address --private-key "$PRIVATE_KEY" 2>/dev/null)"; then
    ok "PRIVATE_KEY resolves to $addr"
  else
    fail "PRIVATE_KEY is set but invalid"; status=1
  fi
else
  warn "PRIVATE_KEY not set"
fi

echo
echo "Networks"
check_rpc() {
  local name="$1" url="$2" expected="$3"
  local got
  got="$(cast chain-id --rpc-url "$url" 2>/dev/null || true)"
  if [ -z "$got" ]; then
    if [ "$name" = "local" ]; then warn "$name ($url) not reachable. Start it with: make anvil"; else fail "$name ($url) not reachable"; status=1; fi
    return
  fi
  if [ "$got" = "$expected" ]; then ok "$name chain id $got"; else fail "$name returned chain id $got, expected $expected"; status=1; fi
  if [ -n "${PRIVATE_KEY:-}" ] && [ -n "${addr:-}" ]; then
    local bal
    bal="$(cast balance --rpc-url "$url" --ether "$addr" 2>/dev/null || echo "?")"
    if [ "$bal" = "0" ] || [ "$bal" = "0.000000000000000000" ]; then warn "$name balance of $addr is 0. Ask the instructor for gas."; else ok "$name balance $bal"; fi
  fi
}
check_rpc local "$LOCAL_RPC_URL" "$LOCAL_CHAIN_ID"
check_rpc prismo "$PRISMO_RPC_URL" "$PRISMO_CHAIN_ID"

echo
if [ "$status" -eq 0 ]; then echo "All required checks passed."; else echo "Fix the [fail] items above, then run make doctor again."; fi
exit "$status"
