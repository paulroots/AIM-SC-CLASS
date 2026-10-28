#!/usr/bin/env bash
# Deploys one contract to one network and records the result for the dApp.
#   NETWORK=local|prismo  CONTRACT=Counter  scripts/deploy.sh
# After a successful run, web/deployments.json holds the address and ABI keyed by chain id.

# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

NETWORK="${NETWORK:-local}"
CONTRACT="${CONTRACT:-Counter}"
resolve_network "$NETWORK"
require_private_key

SCRIPT_FILE="script/${CONTRACT}.s.sol"
[ -f "$SCRIPT_FILE" ] || { echo "No deploy script at $SCRIPT_FILE" >&2; exit 1; }

echo "Deploying $CONTRACT to $NETWORK_NAME (chain $CHAIN_ID) via $RPC_URL"
echo

# --legacy: Prismo (cdk-erigon) rejects EIP-1559 typed transactions. Anvil accepts both,
# so one flag set serves every network. --with-gas-price pins 1 gwei, Prismo's floor.
forge script "$SCRIPT_FILE" \
  --rpc-url "$RPC_URL" \
  --broadcast \
  --legacy \
  --with-gas-price 1gwei \
  -vv

RUN_JSON="broadcast/${CONTRACT}.s.sol/${CHAIN_ID}/run-latest.json"
[ -f "$RUN_JSON" ] || { echo "Broadcast record not found at $RUN_JSON" >&2; exit 1; }

# Pull the address, tx hash, and ABI into web/deployments.json. Node does the JSON work
# so students do not need jq.
node - "$RUN_JSON" "out/${CONTRACT}.sol/${CONTRACT}.json" "$CONTRACT" "$CHAIN_ID" "$NETWORK_NAME" "$EXPLORER" <<'EOF'
const fs = require("fs");
const [runPath, artifactPath, name, chainId, networkName, explorer] = process.argv.slice(2);
const run = JSON.parse(fs.readFileSync(runPath, "utf8"));
const artifact = JSON.parse(fs.readFileSync(artifactPath, "utf8"));
const tx = run.transactions.find(t => t.transactionType === "CREATE" && t.contractName === name);
if (!tx) { console.error(`No CREATE transaction for ${name} in ${runPath}`); process.exit(1); }
const receipt = (run.receipts || []).find(r => r.transactionHash === tx.hash) || {};
const file = "web/deployments.json";
const all = fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, "utf8")) : {};
all[chainId] = all[chainId] || { name: networkName, explorer, contracts: {} };
all[chainId].name = networkName;
all[chainId].explorer = explorer;
all[chainId].contracts[name] = {
  address: tx.contractAddress,
  tx: tx.hash,
  block: receipt.blockNumber ? parseInt(receipt.blockNumber, 16) : null,
  // Foundry 1.8 writes the timestamp in milliseconds; older versions wrote seconds.
  deployedAt: new Date(run.timestamp > 1e12 ? run.timestamp : run.timestamp * 1000).toISOString(),
  abi: artifact.abi,
};
fs.writeFileSync(file, JSON.stringify(all, null, 2) + "\n");
console.log("");
console.log(`Recorded in ${file}`);
console.log(`  ${name} at ${tx.contractAddress}`);
console.log(`  tx ${tx.hash}`);
if (explorer) console.log(`  ${explorer}/address/${tx.contractAddress}`);
EOF
