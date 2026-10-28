# Smart Contracts Lab

A teaching kit for writing, testing, and deploying Solidity contracts, first on a local chain and then on the Prismo Glassnet L2 testnet. Each dApp is one contract, one test file, one deploy script, and one web page you can open in a browser with MetaMask.

## 1. Install

You need three things.

| Tool | Why | Install |
| --- | --- | --- |
| Foundry (`forge`, `cast`, `anvil`) | Compiles, tests, deploys, runs the local chain | macOS: `brew install foundry`. Linux or WSL2: `curl -L https://foundry.paradigm.xyz \| bash` then `foundryup` |
| Node.js 18 or newer | Serves the dApp pages and reads JSON | https://nodejs.org |
| MetaMask | Signs transactions from the browser | https://metamask.io (browser extension) |

Windows: install WSL2 (Ubuntu) and work inside it. Foundry does not run natively on Windows.

Then, inside this folder:

```sh
make install     # fetches the forge-std library
cp .env.example .env
make doctor      # tells you what is missing
```

`make` on its own lists every command.

## 2. Local chain

Open a terminal and leave it running:

```sh
make anvil
```

Anvil prints ten funded accounts with their private keys. Account #0 is already in `.env.example`. Import that private key into MetaMask (Account menu, Import account) and add the Anvil network (the Overview page has an "Add to wallet" button, or add it by hand: RPC `http://127.0.0.1:8545`, chain id `31337`).

## 3. Build, test, deploy

```sh
make test                                   # runs test/Counter.t.sol
make deploy NETWORK=local CONTRACT=Counter  # deploys and writes web/deployments.json
```

## 4. Open the dApp

```sh
make dapp
```

Open http://localhost:3000 and click Counter in the rail. Connect MetaMask, press Increment, approve the transaction, and watch the number, the proof card, and the event log update.

Read `web/counter/index.html` next. It is plain HTML and ethers v6, no framework, and every call it makes to the chain is visible in the file.

If you restart Anvil, deploy again and reset MetaMask's activity (Settings, Advanced, Clear activity tab data) so its nonce count matches the fresh chain.

## 5. Deploy to Prismo Glassnet

Prismo Glassnet is a public zkRollup testnet (Polygon CDK). Facts you will need:

| | |
| --- | --- |
| RPC | `https://rpc.glassnet.prismo.network/` |
| Chain id | `101001000` |
| Explorer | https://explorer.glassnet.prismo.network |
| Gas token | USDC (test units, no value) |

Steps:

1. Create a fresh account in MetaMask for class. Never reuse a wallet that holds real funds.
2. Give your instructor the account's address. They will send you test gas. Check with `make doctor`.
3. Export that account's private key from MetaMask and put it in `.env` as `PRIVATE_KEY`.
4. Deploy and verify:

```sh
make deploy NETWORK=prismo CONTRACT=Counter
make verify CONTRACT=Counter
```

The deploy prints an explorer link. Verification uploads your source so the explorer can show it and decode your transactions. On the Counter page, switch the Deployment selector to Prismo Glassnet; the page offers to add the network to MetaMask.

Prismo accepts legacy (type 0) transactions only. The scripts already pass `--legacy`; MetaMask handles it on its own.

## 6. Make your own dApp

```sh
make new-dapp NAME=Voting
```

This creates `src/Voting.sol`, `script/Voting.s.sol`, `test/Voting.t.sol`, and `web/voting/index.html`, and adds Voting to the rail. The web page is generated from the ABI, so it works as soon as the contract compiles: every view function shows as a value, every write function as a form, every event in the timeline. Replace it with a hand-built page like `web/counter/index.html` once the contract design settles.

Keep the deploy script's constructor arguments in sync with your contract, and if you verify on Prismo, pass the same arguments: `CONSTRUCTOR_ARGS=$(cast abi-encode 'constructor(string)' "hello") make verify CONTRACT=Voting`.

## Useful commands

```sh
forge test --match-test test_increment -vvvv        # one test, full trace
forge test --gas-report                             # gas per function
cast call <address> "number()(uint256)" --rpc-url http://127.0.0.1:8545
cast send <address> "increment()" --rpc-url http://127.0.0.1:8545 --private-key $PRIVATE_KEY
cast balance <address> --ether --rpc-url https://rpc.glassnet.prismo.network/
```

## Layout

```
src/        contracts            script/     deploy scripts         test/       tests
web/        dApp pages           web/shared/ wallet, shell, Lumen CSS
scripts/    the make targets     templates/  what make new-dapp copies
```

Never commit `.env`. It is gitignored, keep it that way.
