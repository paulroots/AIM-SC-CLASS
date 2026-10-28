#!/usr/bin/env bash
# Instructor only. Sends gas to every address in students.txt on Prismo Glassnet.
#   scripts/fund-students.sh            (uses STUDENT_FUND_AMOUNT from .env, default 2)
#   AMOUNT=5 scripts/fund-students.sh
# students.txt: one 0x address per line. Blank lines and lines starting with # are ignored.
# Addresses that already hold at least the amount are skipped.

# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

resolve_network prismo
require_private_key

LIST="${LIST:-students.txt}"
AMOUNT="${AMOUNT:-${STUDENT_FUND_AMOUNT:-2}}"
[ -f "$LIST" ] || { echo "No $LIST found. Copy students.txt.example and add one address per line." >&2; exit 1; }

FROM="$(cast wallet address --private-key "$PRIVATE_KEY")"
echo "Funding from $FROM on $NETWORK_NAME, $AMOUNT per student"
echo "Treasury balance: $(cast balance --rpc-url "$RPC_URL" --ether "$FROM")"
echo

sent=0; skipped=0; failed=0
while IFS= read -r line || [ -n "$line" ]; do
  addr="$(echo "$line" | awk '{print $1}')"
  case "$addr" in ""|\#*) continue ;; esac
  if ! [[ "$addr" =~ ^0x[0-9a-fA-F]{40}$ ]]; then
    fail "$addr is not an address"; failed=$((failed+1)); continue
  fi
  have="$(cast balance --rpc-url "$RPC_URL" --ether "$addr")"
  if node -e 'process.exit(parseFloat(process.argv[1]) >= parseFloat(process.argv[2]) ? 0 : 1)' "$have" "$AMOUNT"; then
    ok "$addr already has $have, skipped"; skipped=$((skipped+1)); continue
  fi
  if tx="$(cast send "$addr" --value "${AMOUNT}ether" --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --legacy --gas-price 1gwei --json 2>&1)"; then
    hash="$(echo "$tx" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{process.stdout.write(JSON.parse(s).transactionHash)}catch{process.stdout.write("?")}})')"
    ok "$addr funded, $EXPLORER/tx/$hash"; sent=$((sent+1))
  else
    fail "$addr: $tx"; failed=$((failed+1))
  fi
done < "$LIST"

echo
echo "Sent $sent, skipped $skipped, failed $failed."
[ "$failed" -eq 0 ]
