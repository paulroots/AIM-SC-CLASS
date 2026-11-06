# Lesson pages

Slides and explainers for Sessions 13 to 16. Every page is a single HTML file with nothing to install or build. Open it in your browser by double-clicking it, or run `open Lesson/<file>.html` on macOS.

## Session decks

| File | Session |
| --- | --- |
| `session-13-blockchain-101.html` | 13 · Blockchain 101: hashes, blocks, the mempool, and signing with a class-only wallet |
| `session-14-solidity-deploy-interact.html` | 14 · Deploy and Interact: from Solidity source to a mined deployment with its own address |
| `session-15-digital-identity.html` | 15 · Digital Identity on Blockchain: issuer, holder, verifier, DIDs, and what stays off chain |
| `session-16-gas-qa.html` | 16 · Gas and Q+A: gas metering, base fee and tip, and what a transaction costs |

Deck controls:

| Key | Action |
| --- | --- |
| `→` / `←` | Next / previous step |
| `N` | Speaker notes |
| `K` | Plain-language key terms for the scene on screen |

## Companion pages

| File | What it is |
| --- | --- |
| `student-lab.html` | What you will see in the 90-minute lab, block by block, and what to watch for |
| `descriptions.html` | Key Terms: every term from Sessions 13 to 16, with a definition and a plain-language explanation |
| `wallet-flow.html` | Animation: how MetaMask or Brave Wallet connects a page to a contract and the chain (connect, read, write) |
| `did-flow.html` | Animation for Session 15: issue, verify, tamper, rotate, and revoke a credential. Below it, the DIDRegistry and StatusList code with an explanation of each part; the code for the current step lights up. Pairs with `make did` |
| `kyc-card-flow.html` | Scenario 2 for Session 15: one bank does KYC once, another issues a credit card from that credential, and each payment is approved by checking the phone's signature against the customer's DID. Covers a stolen card number, a lost phone, and revoked KYC, with the code for each step |
| `erc8004-agent-flow.html` | Scenario 3: register an AI agent under ERC-8004 (identity, reputation, validation registries), then let another agent hire it and pay through an escrow contract that releases money only after an independent check. Covers an impostor, a failed job and a refund, and selling the agent, with the code for each step |
| `did-vs-database.html` | Why DIDs, and why on chain? Compares both scenarios with a normal database moment by moment, weighs issuer server vs shared database vs blockchain, and ends with when a database is the better choice and discussion questions |
| `instructor-guide.html` | The instructor's talking points in deck order. Useful for review after class |

## Try it yourself

The decks explain the ideas; the rest of this repo lets you run them. After a session, follow the [main README](../README.md): start a local chain with `make anvil`, deploy with `make deploy`, and open the dApps with `make dapp`. Session 15's credential demo runs step by step with `make did STEP=setup`, then `resolve`, `issue`, `verify`, `tamper`, `rotate`, `retire`, and `revoke`.
