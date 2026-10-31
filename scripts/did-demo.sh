#!/usr/bin/env bash
# Decentralized identity demo: a university issues a credential, a verifier checks it without
# calling the university, then the university rotates a key and revokes the credential.
#   NETWORK=local|prismo  STEP=setup|resolve|issue|verify|tamper|rotate|retire|revoke|reset  [ARG=...]  scripts/did-demo.sh
#   or: make did STEP=issue NETWORK=prismo
# Run the steps in that order. State lives in did-demo/<chainId>/ (gitignored).
#
# Credentials are JWTs whose signature is an Ethereum personal_sign (EIP-191) over header.payload,
# so cast can sign and check them with no extra libraries. Production systems use ES256K or EdDSA
# through did-jwt-vc; the header, the claims and the resolve-then-verify flow are the same.

# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

NETWORK="${NETWORK:-local}"
STEP="${STEP:-${1:-}}"
ARG="${ARG:-${2:-}}"
resolve_network "$NETWORK"

STATE="did-demo/$CHAIN_ID"
VERI_KEY="$(cast format-bytes32-string veriKey)"
CHAIN_HEX="$(printf '0x%x' "$CHAIN_ID")"
GAS=(--legacy --gas-price 1gwei)

HOLDER_NAME="${HOLDER_NAME:-Juan Dela Cruz}"
DEGREE="${DEGREE:-Bachelor of Science in Computer Science}"
FAKE_DEGREE="Doctor of Philosophy in Computer Science"

say()  { printf '\n\033[1m%s\033[0m\n' "$*"; }
note() { printf '  %s\n' "$*"; }

deployed() { # deployed <Contract> <field> prints the field from web/deployments.json, or nothing
  node -e '
    const fs = require("fs");
    if (!fs.existsSync("web/deployments.json")) process.exit(0);
    const c = (JSON.parse(fs.readFileSync("web/deployments.json", "utf8"))[process.argv[1]] || { contracts: {} }).contracts[process.argv[2]];
    if (c && c[process.argv[3]] != null) process.stdout.write(String(c[process.argv[3]]));
  ' "$CHAIN_ID" "$1" "$2"
}

need_contracts() {
  REG="$(deployed DIDRegistry address)"
  STATUS="$(deployed StatusList address)"
  REG_BLOCK="$(deployed DIDRegistry block)"
  [ -n "$REG" ] && [ -n "$STATUS" ] || { echo "No DID contracts on $NETWORK_NAME yet. Run: make did STEP=setup NETWORK=$NETWORK" >&2; exit 1; }
}

ISSUER_KEY="$(signer_key "$NETWORK")"
ISSUER="$(cast wallet address --private-key "$ISSUER_KEY")"
did_of() { printf 'did:ethr:%s:%s' "$CHAIN_HEX" "$1"; }

explorer_tx() { [ -n "$EXPLORER" ] && note "$EXPLORER/tx/$1"; return 0; }

send() { # send <signature> <args...> sends from the issuer to $REG_OR_STATUS; prints "txhash block"
  local out
  out="$(cast send "${GAS[@]}" --rpc-url "$RPC_URL" --private-key "$ISSUER_KEY" --json "$REG_OR_STATUS" "$@")"
  node -e 'const r = JSON.parse(process.argv[1]); if (r.status !== "0x1" && r.status !== 1) { console.error("Transaction failed"); process.exit(1); } process.stdout.write(r.transactionHash + " " + parseInt(r.blockNumber));' "$out"
}

# --- resolve ------------------------------------------------------------------------------
# Builds the DID document the way a did:ethr resolver does: the controller from identityOwner(),
# plus every unexpired veriKey delegate found in the registry's events.
resolve_doc() { # resolve_doc <address> writes the document to $STATE/doc-<address>.json
  local id="$1" owner owners delegates now
  owner="$(cast call --rpc-url "$RPC_URL" "$REG" "identityOwner(address)(address)" "$id")"
  owners="$(cast logs --json --rpc-url "$RPC_URL" --from-block "${REG_BLOCK:-0}" --to-block latest --address "$REG" \
    "DIDOwnerChanged(address indexed identity, address owner, uint256 previousChange)" "$id")"
  delegates="$(cast logs --json --rpc-url "$RPC_URL" --from-block "${REG_BLOCK:-0}" --to-block latest --address "$REG" \
    "DIDDelegateChanged(address indexed identity, bytes32 delegateType, address delegate, uint256 validTo, uint256 previousChange)" "$id")"
  now="$(cast block latest -f timestamp --rpc-url "$RPC_URL")"
  node - "$id" "$owner" "$owners" "$delegates" "$now" "$CHAIN_ID" "$CHAIN_HEX" "$STATE/doc-$id.json" <<'EOF'
const fs = require("fs");
const [id, owner, ownersJson, delegatesJson, now, chainId, chainHex, out] = process.argv.slice(2);
const words = (data) => data.slice(2).match(/.{64}/g);
const addr = (w) => "0x" + w.slice(24);
const did = `did:ethr:${chainHex}:${id}`;
const vm = (frag, a) => ({ id: `${did}#${frag}`, type: "EcdsaSecp256k1RecoveryMethod2020", controller: did, blockchainAccountId: `eip155:${chainId}:${a}` });

const history = [];
for (const l of JSON.parse(ownersJson || "[]")) {
  const w = words(l.data);
  history.push({ block: parseInt(l.blockNumber), log: parseInt(l.logIndex), what: `controller changed to ${addr(w[0])}`, previous: parseInt(w[1], 16) });
}
const delegates = new Map(); // first-seen order gives each key a stable #delegate-N id
for (const l of JSON.parse(delegatesJson || "[]")) {
  const w = words(l.data);
  const type = Buffer.from(w[0], "hex").toString().replace(/\0+$/, "");
  const a = addr(w[1]), validTo = parseInt(w[2], 16);
  if (type !== "veriKey") continue;
  if (!delegates.has(a)) delegates.set(a, { n: delegates.size + 1 });
  delegates.get(a).validTo = validTo;
  const live = validTo > Number(now);
  history.push({ block: parseInt(l.blockNumber), log: parseInt(l.logIndex), what: `${live ? "added" : "revoked"} signing key ${a}${live ? ` until ${new Date(validTo * 1000).toISOString().slice(0, 10)}` : ""}`, previous: parseInt(w[3], 16) });
}
history.sort((a, b) => a.block - b.block || a.log - b.log);

const methods = [vm("controller", owner)];
for (const [a, d] of delegates) if (d.validTo > Number(now)) methods.push(vm(`delegate-${d.n}`, a));
const doc = {
  "@context": ["https://www.w3.org/ns/did/v1", "https://w3id.org/security/suites/secp256k1recovery-2020/v2"],
  id: did,
  verificationMethod: methods,
  authentication: [methods[0].id],
  assertionMethod: methods.map((m) => m.id),
};
fs.writeFileSync(out, JSON.stringify({ doc, history, delegates: Object.fromEntries([...delegates].map(([a, d]) => [a.toLowerCase(), d.n])) }, null, 2));
EOF
}

print_doc() { # print_doc <address>
  node - "$STATE/doc-$1.json" <<'EOF'
const { doc, history } = JSON.parse(require("fs").readFileSync(process.argv[2], "utf8"));
console.log(JSON.stringify(doc, null, 2).split("\n").map((l) => "  " + l).join("\n"));
console.log("\n\x1b[1mRegistry history\x1b[0m");
if (!history.length) console.log("  none. The DID document above is the default every address gets for free.");
for (const h of history) console.log(`  block ${h.block}  ${h.what}  (previous change: ${h.previous || "none"})`);
EOF
}

# --- credentials --------------------------------------------------------------------------
b64url() { node -e 'process.stdout.write(Buffer.from(process.argv[1]).toString("base64url"))' "$1"; }

issue_jwt() { # issue_jwt <signing key> <kid fragment> <out file>
  local key="$1" frag="$2" out="$3" holder header payload sig
  holder="$(cat "$STATE/holder.address")"
  header="$(b64url "{\"alg\":\"EIP191\",\"typ\":\"JWT\",\"kid\":\"$(did_of "$ISSUER")#$frag\"}")"
  payload="$(node - "$(did_of "$ISSUER")" "$(did_of "$holder")" "$HOLDER_NAME" "$DEGREE" "$STATUS" <<'EOF'
const [iss, sub, name, degree, statusList] = process.argv.slice(2);
const index = require("crypto").randomInt(0, 65536);
const now = Math.floor(Date.now() / 1000);
const vc = {
  iss, sub, nbf: now, jti: "urn:uuid:" + require("crypto").randomUUID(),
  vc: {
    "@context": ["https://www.w3.org/ns/credentials/v2"],
    type: ["VerifiableCredential", "UniversityDegreeCredential"],
    credentialSubject: { id: sub, name, degree },
    credentialStatus: { type: "StatusList (on chain, teaching)", statusListContract: statusList, statusListIndex: index },
  },
};
process.stdout.write(Buffer.from(JSON.stringify(vc)).toString("base64url"));
EOF
)"
  sig="$(cast wallet sign --private-key "$key" "$header.$payload")"
  printf '%s.%s.%s\n' "$header" "$payload" "$(node -e 'process.stdout.write(Buffer.from(process.argv[1].slice(2), "hex").toString("base64url"))' "$sig")" > "$out"
}

show_jwt() { # show_jwt <file>
  node - "$1" <<'EOF'
const [h, p, s] = require("fs").readFileSync(process.argv[2], "utf8").trim().split(".");
const dec = (x) => JSON.parse(Buffer.from(x, "base64url").toString());
const indent = (o) => JSON.stringify(o, null, 2).split("\n").map((l) => "  " + l).join("\n");
console.log("\x1b[1mHeader\x1b[0m\n" + indent(dec(h)));
console.log("\x1b[1mClaims\x1b[0m\n" + indent(dec(p)));
console.log("\x1b[1mSignature\x1b[0m\n  " + s.slice(0, 24) + "…  (" + Buffer.from(s, "base64url").length + " bytes)");
EOF
}

jwt_field() { # jwt_field <file> <header|claims|sig|input> [path]
  node - "$@" <<'EOF'
const [file, part, path] = process.argv.slice(2);
const [h, p, s] = require("fs").readFileSync(file, "utf8").trim().split(".");
const dec = (x) => JSON.parse(Buffer.from(x, "base64url").toString());
if (part === "input") process.stdout.write(`${h}.${p}`);
else if (part === "sig") process.stdout.write("0x" + Buffer.from(s, "base64url").toString("hex"));
else process.stdout.write(String(path.split(".").reduce((o, k) => o[k], dec(part === "header" ? h : p))));
EOF
}

verify_jwt() { # verify_jwt <file>; exit status 0 when valid
  local file="$1" kid iss issuer_addr signer index ok_all=1
  kid="$(jwt_field "$file" header kid)"
  iss="$(jwt_field "$file" claims iss)"
  issuer_addr="${iss##*:}"
  say "Verifying $(basename "$file")"
  note "Issuer  $iss"
  note "Key id  #${kid##*#}"
  note "Holder  $(jwt_field "$file" claims vc.credentialSubject.name), $(jwt_field "$file" claims vc.credentialSubject.degree)"
  echo
  # 1. Resolve the issuer's DID from the chain. The university is never contacted.
  resolve_doc "$issuer_addr"
  signer="$(node -e '
    const { doc } = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
    const m = doc.verificationMethod.find((v) => v.id === process.argv[2]);
    if (m) process.stdout.write(m.blockchainAccountId.split(":").pop());
  ' "$STATE/doc-$issuer_addr.json" "$kid")"
  if [ -z "$signer" ]; then fail "key ${kid##*#} is not in the issuer's DID document (revoked or never added)"; ok_all=0
  else ok "issuer DID resolved from the registry; key ${kid##*#} is $signer"; fi
  # 2. Check the signature against that key, offline.
  if [ -z "$signer" ]; then note "signature not checked: no trusted key to check it against"
  elif cast wallet verify --address "$signer" "$(jwt_field "$file" input)" "$(jwt_field "$file" sig)" >/dev/null 2>&1; then
    ok "signature matches: the claims are exactly what the issuer signed"
  else fail "signature does not match the claims"; ok_all=0; fi
  # 3. Check the revocation bit.
  index="$(jwt_field "$file" claims vc.credentialStatus.statusListIndex)"
  if [ "$(cast call --rpc-url "$RPC_URL" "$STATUS" "isRevoked(address,uint256)(bool)" "$issuer_addr" "$index")" = "true" ]; then
    fail "status list bit $index is set: the issuer revoked this credential"; ok_all=0
  else ok "status list bit $index is clear: not revoked"; fi
  note "university contacted: no"
  echo
  if [ "$ok_all" = 1 ]; then printf '  \033[32mVALID\033[0m\n'; else printf '  \033[31mREJECTED\033[0m\n'; return 1; fi
}

new_holder() { # a fresh student identity; only the address is needed, the student never transacts
  mkdir -p "$STATE"
  cast wallet new --json | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>process.stdout.write(JSON.parse(s).data[0].address))' > "$STATE/holder.address"
}

# --- steps --------------------------------------------------------------------------------
case "$STEP" in
  setup)
    say "Deploying the DID registry and the status list to $NETWORK_NAME"
    NETWORK="$NETWORK" CONTRACT=DIDRegistry bash scripts/deploy.sh
    REG="$(deployed DIDRegistry address)"
    DID_REGISTRY="$REG" NETWORK="$NETWORK" CONTRACT=StatusList bash scripts/deploy.sh
    new_holder
    say "Cast"
    note "University (issuer)  $(did_of "$ISSUER")"
    note "Student (holder)     $(did_of "$(cat "$STATE/holder.address")")"
    note "Employer (verifier)  needs no DID, only read access to the chain"
    ;;

  resolve)
    need_contracts; mkdir -p "$STATE"
    target="${ARG:-$ISSUER}"; target="${target##*:}"
    say "Resolving $(did_of "$target")"
    resolve_doc "$target"; print_doc "$target"
    ;;

  issue)
    need_contracts; [ -f "$STATE/holder.address" ] || new_holder
    issue_jwt "$ISSUER_KEY" controller "$STATE/credential.jwt"
    say "The university signed a credential for the student"
    show_jwt "$STATE/credential.jwt"
    echo; note "Saved to $STATE/credential.jwt. It lives with the student, not on the chain: no transaction was sent."
    ;;

  verify)
    need_contracts
    verify_jwt "${ARG:-$STATE/credential.jwt}" || true
    ;;

  tamper)
    need_contracts
    node - "$STATE/credential.jwt" "$STATE/tampered.jwt" "$DEGREE" "$FAKE_DEGREE" <<'EOF'
const fs = require("fs");
const [src, out, from, to] = process.argv.slice(2);
const [h, p, s] = fs.readFileSync(src, "utf8").trim().split(".");
const claims = JSON.parse(Buffer.from(p, "base64url").toString());
claims.vc.credentialSubject.degree = claims.vc.credentialSubject.degree.replace(from, to);
fs.writeFileSync(out, [h, Buffer.from(JSON.stringify(claims)).toString("base64url"), s].join(".") + "\n");
EOF
    say "The student edits one claim and keeps the original signature"
    note "\"$DEGREE\"  →  \"$FAKE_DEGREE\""
    verify_jwt "$STATE/tampered.jwt" || true
    ;;

  rotate)
    need_contracts
    cast wallet new --json | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const k=JSON.parse(s).data[0];process.stdout.write(k.address+" "+k.private_key)})' > "$STATE/signing.key"
    read -r NEW_ADDR NEW_KEY < "$STATE/signing.key" || true
    say "The university adds a new signing key to its DID (valid 30 days)"
    REG_OR_STATUS="$REG"
    OUT="$(send "addDelegate(address,bytes32,address,uint256)" "$ISSUER" "$VERI_KEY" "$NEW_ADDR" 2592000)"; read -r TX BLOCK <<< "$OUT"
    ok "addDelegate in block $BLOCK"; note "tx $TX"; explorer_tx "$TX"
    resolve_doc "$ISSUER"
    N="$(node -e 'process.stdout.write(String(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).delegates[process.argv[2].toLowerCase()]))' "$STATE/doc-$ISSUER.json" "$NEW_ADDR")"
    issue_jwt "$NEW_KEY" "delegate-$N" "$STATE/credential-2.jwt"
    say "New credentials are signed with the new key"
    note "Saved $STATE/credential-2.jwt (key #delegate-$N)"
    print_doc "$ISSUER"
    verify_jwt "$STATE/credential-2.jwt" || true
    ;;

  retire)
    need_contracts
    [ -f "$STATE/signing.key" ] || { echo "Run STEP=rotate first." >&2; exit 1; }
    read -r NEW_ADDR NEW_KEY < "$STATE/signing.key" || true
    say "The university retires the signing key it added (say it was stolen)"
    REG_OR_STATUS="$REG"
    OUT="$(send "revokeDelegate(address,bytes32,address)" "$ISSUER" "$VERI_KEY" "$NEW_ADDR")"; read -r TX BLOCK <<< "$OUT"
    ok "revokeDelegate in block $BLOCK"; note "tx $TX"; explorer_tx "$TX"
    verify_jwt "$STATE/credential-2.jwt" || true
    ;;

  revoke)
    need_contracts
    file="${ARG:-$STATE/credential.jwt}"
    index="$(jwt_field "$file" claims vc.credentialStatus.statusListIndex)"
    say "The university revokes $(basename "$file") (status list bit $index)"
    REG_OR_STATUS="$STATUS"
    OUT="$(send "setRevoked(address,uint256,bool)" "$ISSUER" "$index" true)"; read -r TX BLOCK <<< "$OUT"
    ok "setRevoked in block $BLOCK"; note "tx $TX"; explorer_tx "$TX"
    verify_jwt "$file" || true
    ;;

  reset)
    rm -rf "$STATE"
    echo "Removed $STATE. The contracts stay deployed: STEP=issue starts again with a new student, STEP=setup deploys fresh contracts."
    ;;

  *)
    echo "Usage: make did STEP=<step> [NETWORK=local|prismo]"
    echo "Steps, in order: setup, resolve, issue, verify, tamper, rotate, retire, revoke. Also: reset."
    exit 1 ;;
esac
