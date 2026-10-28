# Instructor notes

Everything the students do not need to see. Keep this file out of the student zip if you prefer; `make zip` includes it by default.

## Before the first session

1. Run `make doctor` on the teaching machine with the owner key in `.env`. The owner wallet is `0xdC1d3B6FEadB5349efe46B067E105682a5FE9019` on Prismo Glassnet. It held about 1,631 gas units on 2026-10-28.
2. Deploy Counter to Prismo once from your own machine so the explorer link exists for the slides: `make deploy NETWORK=prismo CONTRACT=Counter` then `make verify CONTRACT=Counter`.
3. Package the kit: `make zip`. Hand out `aim-smart-contracts-kit.zip` or push the repo and share the URL.

## Funding students

Collect each student's Prismo address (a fresh MetaMask account), one per line, in `students.txt`:

```
0xabc...  Dela Cruz, J.
0xdef...  Reyes, M.
```

Then:

```sh
make fund-students            # sends STUDENT_FUND_AMOUNT (default 2) to each
AMOUNT=5 make fund-students   # or a different amount
```

The script skips anyone already holding at least the amount, so it is safe to re-run after adding names. At 1 gwei gas, 2 units covers thousands of Counter transactions. `students.txt` is gitignored.

## Classroom run-sheet (90 minutes)

| Minutes | What | Command |
| --- | --- | --- |
| 0 to 10 | Everyone runs the doctor; fix installs | `make doctor` |
| 10 to 25 | Read `src/Counter.sol` aloud: state, events, custom errors, immutables | |
| 25 to 40 | Tests: assertions, `vm.prank`, `vm.expectRevert`, `vm.expectEmit`, fuzzing | `make test`, then `forge test --match-test test_decrement_revertsAtZero -vvvv` |
| 40 to 55 | Local deploy and the dApp. Show `broadcast/` and `web/deployments.json` | `make anvil`, `make deploy NETWORK=local`, `make dapp` |
| 55 to 75 | Prismo deploy and verification. Walk the explorer: tx, logs, verified source | `make deploy NETWORK=prismo`, `make verify` |
| 75 to 90 | Scaffold a new dApp live, change the contract, redeploy | `make new-dapp NAME=Greeter` |

## How the pieces fit

- `scripts/deploy.sh` runs `forge script` with `--broadcast --legacy --with-gas-price 1gwei`, then reads `broadcast/<Contract>.s.sol/<chainId>/run-latest.json` and the ABI from `out/` into `web/deployments.json`. The pages read that one file.
- `web/shared/chains.js` is the only place network facts live on the web side; `scripts/common.sh` is the only place on the shell side.
- `web/shared/shell.js` draws the rail and classification bar. `web/shared/abi-ui.js` is the generic ABI console used by generated pages. `web/counter/index.html` is hand-written on purpose so students can read a complete dApp top to bottom.
- `templates/` holds what `make new-dapp` copies; `__NAME__` and `__name__` are the placeholders.

## Prismo Glassnet facts (verified 2026-10-28)

- cdk-erigon client built `no-typed-tx`: EIP-1559 transactions are rejected. Always `--legacy`. MetaMask detects this itself.
- Shanghai EVM (PUSH0 works). `foundry.toml` pins `evm_version = "shanghai"` and solc 0.8.28, matching the contracts already verified on the explorer.
- Gas price floor is 1 gwei. Gas token is USDC-denominated with 18 decimals.
- Blockscout explorer; `forge verify-contract --verifier blockscout --verifier-url https://explorer.glassnet.prismo.network/api` works without an API key.
- RPC allows cross-origin requests, so the pages read directly from it without a wallet.
- If Prismo ever enables typed transactions, dropping `--legacy` from `scripts/deploy.sh` and `scripts/fund-students.sh` is the only change.

## Design system

The pages use the Lumen design system (private repo `byc-product/lumen-design-system`, stage pilot). The compiled `tokens.css`, `byc.css`, the Lumen logos, and the `VERSION` file are vendored under `web/shared/lumen/` so students need no repo access. Refresh with `make sync-design` (needs `gh auth login`). Page-level layout lives in `web/shared/app.css` and uses semantic tokens only.

## Known rough edges

- Windows students must use WSL2. Budget time for it in session one.
- A restarted Anvil invalidates MetaMask's nonce cache. Students must clear activity data in MetaMask or transactions will hang.
- `make new-dapp` registers the page in `web/shared/dapps.json`. Deleting a generated dApp means removing its four files and that entry.
- `make verify` for a generated contract needs `CONSTRUCTOR_ARGS` to match the deploy script. Counter is handled automatically.
