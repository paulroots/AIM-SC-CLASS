#!/usr/bin/env bash
# Creates a new dApp from the templates: contract, deploy script, test, and web page.
#   NAME=Voting scripts/new-dapp.sh
# NAME must be a valid Solidity identifier in PascalCase.

# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

NAME="${NAME:-}"
[[ "$NAME" =~ ^[A-Z][A-Za-z0-9]*$ ]] || { echo "NAME must be PascalCase, for example NAME=Voting" >&2; exit 1; }
lower="$(echo "$NAME" | tr '[:upper:]' '[:lower:]')"

for target in "src/$NAME.sol" "script/$NAME.s.sol" "test/$NAME.t.sol" "web/$lower/index.html"; do
  [ -e "$target" ] && { echo "$target already exists. Pick another name or remove it first." >&2; exit 1; }
done

render() {
  sed -e "s/__NAME__/$NAME/g" -e "s/__name__/$lower/g" "$1" > "$2"
}

mkdir -p "web/$lower"
render templates/Name.sol        "src/$NAME.sol"
render templates/Name.s.sol      "script/$NAME.s.sol"
render templates/Name.t.sol      "test/$NAME.t.sol"
render templates/web-index.html  "web/$lower/index.html"

# Register the page in the shared dApp list so the nav rail and landing page pick it up.
node - "$NAME" "$lower" <<'EOF'
const fs = require("fs");
const [name, lower] = process.argv.slice(2);
const file = "web/shared/dapps.json";
const list = JSON.parse(fs.readFileSync(file, "utf8"));
if (!list.some(d => d.contract === name)) {
  list.push({ contract: name, path: lower, title: name.replace(/([a-z])([A-Z])/g, "$1 $2") });
  fs.writeFileSync(file, JSON.stringify(list, null, 2) + "\n");
}
EOF

echo "Created:"
echo "  src/$NAME.sol"
echo "  script/$NAME.s.sol"
echo "  test/$NAME.t.sol"
echo "  web/$lower/index.html"
echo
echo "Next: edit the contract, then"
echo "  forge test --match-contract ${NAME}Test -vv"
echo "  make deploy NETWORK=local CONTRACT=$NAME"
