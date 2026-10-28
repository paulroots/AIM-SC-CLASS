// Wallet and chain helpers shared by every dApp page. Requires ethers v6 and chains.js.
// Everything here is plain ethers; read it to see what the page is doing under the hood.

window.Lab = (() => {
  const CHAINS = window.LAB_CHAINS;

  // deployments.json is written by scripts/deploy.sh. It is served from the web root.
  async function loadDeployments() {
    const res = await fetch("/deployments.json", { cache: "no-store" });
    if (!res.ok) return {};
    return res.json();
  }

  function hasWallet() {
    return typeof window.ethereum !== "undefined";
  }

  // A provider that can sign: MetaMask (or any injected wallet).
  function browserProvider() {
    return hasWallet() ? new ethers.BrowserProvider(window.ethereum) : null;
  }

  // A read-only provider straight to the chain's RPC. Works without a wallet.
  function readProvider(chainId) {
    const chain = CHAINS[chainId];
    if (!chain) throw new Error(`Unknown chain ${chainId}`);
    return new ethers.JsonRpcProvider(chain.rpc, Number(chainId), { staticNetwork: true });
  }

  async function connect() {
    if (!hasWallet()) throw new Error("No wallet found. Install MetaMask and reload.");
    const accounts = await window.ethereum.request({ method: "eth_requestAccounts" });
    return accounts[0];
  }

  async function currentAccount() {
    if (!hasWallet()) return null;
    const accounts = await window.ethereum.request({ method: "eth_accounts" });
    return accounts[0] || null;
  }

  async function currentChainId() {
    if (!hasWallet()) return null;
    const hex = await window.ethereum.request({ method: "eth_chainId" });
    return parseInt(hex, 16);
  }

  // Ask the wallet to switch; if it has never seen the chain, add it first.
  async function switchChain(chainId) {
    const chain = CHAINS[chainId];
    try {
      await window.ethereum.request({
        method: "wallet_switchEthereumChain",
        params: [{ chainId: chain.addParams.chainId }],
      });
    } catch (err) {
      if (err.code === 4902 || /unrecognized|not added/i.test(err.message || "")) {
        await window.ethereum.request({ method: "wallet_addEthereumChain", params: [chain.addParams] });
      } else {
        throw err;
      }
    }
  }

  function onWalletChange(handler) {
    if (!hasWallet()) return;
    window.ethereum.on("accountsChanged", () => handler("accounts"));
    window.ethereum.on("chainChanged", () => handler("chain"));
  }

  // Formatting helpers. Machine text stays exact; only display is shortened.
  const short = (addr) => (addr ? `${addr.slice(0, 6)}…${addr.slice(-4)}` : "");
  const utc = (d = new Date()) => d.toISOString().replace("T", " ").slice(0, 19) + " UTC";
  const explorerLink = (chainId, kind, value) => {
    const base = CHAINS[chainId] && CHAINS[chainId].explorer;
    return base ? `${base}/${kind}/${value}` : "";
  };

  // Turn an ethers error into a sentence a student can act on.
  function explain(err) {
    if (!err) return "Unknown error";
    if (err.code === "ACTION_REJECTED" || err.code === 4001) return "You rejected the transaction in the wallet.";
    if (err.code === "INSUFFICIENT_FUNDS") return "Not enough gas token in this account.";
    if (err.reason) return err.reason;
    if (err.shortMessage) return err.shortMessage;
    return err.message || String(err);
  }

  async function copy(text, button) {
    try {
      await navigator.clipboard.writeText(text);
      if (button) {
        const was = button.textContent;
        button.textContent = "Copied";
        setTimeout(() => (button.textContent = was), 1200);
      }
    } catch {
      /* clipboard blocked; nothing to do */
    }
  }

  return {
    CHAINS, loadDeployments, hasWallet, browserProvider, readProvider, connect, currentAccount,
    currentChainId, switchChain, onWalletChange, short, utc, explorerLink, explain, copy,
  };
})();
