// The networks this lab deploys to. Keyed by decimal chain id.
// `addParams` is the payload MetaMask expects from wallet_addEthereumChain.
window.LAB_CHAINS = {
  31337: {
    name: "Anvil (local)",
    rpc: "http://127.0.0.1:8545",
    explorer: "",
    currency: "ETH",
    addParams: {
      chainId: "0x7a69",
      chainName: "Anvil (local)",
      rpcUrls: ["http://127.0.0.1:8545"],
      nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
    },
  },
  101001000: {
    name: "Prismo Glassnet",
    rpc: "https://rpc.glassnet.prismo.network/",
    explorer: "https://explorer.glassnet.prismo.network",
    currency: "USDC",
    addParams: {
      chainId: "0x6052728",
      chainName: "Prismo Glassnet",
      rpcUrls: ["https://rpc.glassnet.prismo.network/"],
      nativeCurrency: { name: "USDC", symbol: "USDC", decimals: 18 },
      blockExplorerUrls: ["https://explorer.glassnet.prismo.network"],
    },
  },
};
