// Generic console for any contract, driven by its ABI. Used by pages created with
// `make new-dapp`. It renders view functions as a detail list, write functions as forms,
// and every event as a timeline. Hand-written pages (like counter/) do not need this.

window.AbiUI = (() => {
  const $ = (id) => document.getElementById(id);

  async function boot({ contract: NAME, active }) {
    await Shell.mount({ active });
    const deployments = await Lab.loadDeployments();
    const available = Object.keys(deployments).filter((id) => deployments[id].contracts[NAME]);

    let chainId = null, reader = null, contract = null, account = null, walletChain = null;

    function notice(kind, title, body, action) {
      const el = $("notice");
      if (!kind) { el.className = "hidden"; el.innerHTML = ""; return; }
      el.className = `alert alert-${kind}`;
      el.innerHTML = `<span class="alert-mark" aria-hidden="true">${kind === "danger" ? "&#215;" : "!"}</span>
        <div class="alert-content"><div class="alert-title">${title}</div><div class="alert-body">${body}</div>
        ${action ? `<div class="cluster" style="margin-top: var(--sp-2)"><button class="btn btn-sm" id="notice-action">${action.label}</button></div>` : ""}</div>`;
      if (action) $("notice-action").addEventListener("click", action.run);
    }

    if (!available.length) {
      notice("warning", `${NAME} is not deployed yet`, `Run <code>make deploy NETWORK=local CONTRACT=${NAME}</code> (with Anvil running), then reload.`);
      Shell.classify({ network: "No deployment", subject: NAME });
      return;
    }

    const select = $("network");
    select.innerHTML = available.map((id) => `<option value="${id}">${deployments[id].name} (${id})</option>`).join("");
    select.addEventListener("change", () => useChain(Number(select.value)));

    const fns = (abi, pred) => abi.filter((f) => f.type === "function" && pred(f));
    const isView = (f) => f.stateMutability === "view" || f.stateMutability === "pure";

    async function useChain(id) {
      if (contract) contract.removeAllListeners();
      chainId = id; select.value = String(id);
      const dep = deployments[id].contracts[NAME];
      reader = Lab.readProvider(id);
      contract = new ethers.Contract(dep.address, dep.abi, reader);

      // Facts
      const link = Lab.explorerLink(id, "address", dep.address);
      $("facts").innerHTML = `
        <dt>Address</dt><dd><span class="hash"><span class="hash-text">${dep.address}</span><button class="hash-copy" aria-label="Copy address">Copy</button></span></dd>
        <dt>Network</dt><dd class="mono">${Lab.CHAINS[id].name} (${id})</dd>
        <dt>Deployed</dt><dd class="mono">${dep.deployedAt ? dep.deployedAt.replace("T", " ").slice(0, 19) + " UTC" : "unknown"}${dep.block ? `, block ${dep.block}` : ""}</dd>
        <dt>Explorer</dt><dd>${link ? `<a href="${link}" target="_blank" rel="noopener">${link.replace("https://", "")}</a>` : '<span class="text-muted">none on Anvil</span>'}</dd>`;
      $("facts").querySelector(".hash-copy").onclick = (e) => Lab.copy(dep.address, e.target);

      // Reads: zero-input views as a detail list, views with inputs as small query forms.
      const views = fns(dep.abi, isView);
      $("reads").innerHTML = `<dl class="detail-list" id="read-list">${views.filter((f) => !f.inputs.length).map((f) =>
        `<dt>${f.name}</dt><dd class="mono" data-read="${f.name}">…</dd>`).join("")}</dl>
        ${views.filter((f) => f.inputs.length).map((f) => form(f, "Query", "btn-ghost btn-sm")).join("")}`;
      for (const f of views.filter((f) => f.inputs.length)) bindForm(f, true);

      // Writes: the first write gets the primary button, the rest are ghost.
      const writes = fns(dep.abi, (f) => !isView(f));
      $("writes").innerHTML = writes.length
        ? `<div class="stack">${writes.map((f, i) => form(f, f.name, i === 0 ? "btn-primary" : "btn-ghost")).join("")}</div>`
        : '<p class="body-sm text-muted">This contract has no write functions.</p>';
      for (const f of writes) bindForm(f, false);

      try { await refreshReads(); notice(null); }
      catch (err) { notice("danger", "Cannot reach the chain", `${Lab.explain(err)}. Is Anvil running?`); return; }

      await loadEvents(dep.abi, dep.block || 0);
      for (const ev of dep.abi.filter((e) => e.type === "event")) {
        contract.on(ev.name, (...args) => { const e = args[args.length - 1]; addEvent(ev, e.log, args.slice(0, -1), Lab.utc(), true); refreshReads(); });
      }
      syncWalletState();
    }

    function form(f, label, btnClass) {
      const sig = `${f.name}(${f.inputs.map((i) => i.type).join(",")})`;
      return `<form class="field" data-fn="${sig}">
        <label>${f.name}${f.stateMutability === "payable" ? ' <span class="badge badge-info">payable</span>' : ""}</label>
        <div class="cluster">
          ${f.inputs.map((i, n) => `<input class="input mono" name="${n}" placeholder="${i.name || "arg" + n}: ${i.type}" required style="max-width: 14rem">`).join("")}
          ${f.stateMutability === "payable" ? '<input class="input mono" name="value" placeholder="value (ether)" style="max-width: 9rem">' : ""}
          <button class="btn ${btnClass}" type="submit"${isView(f) ? "" : " disabled"}>${label}</button>
        </div>
        <span class="hint mono" data-out></span>
      </form>`;
    }

    function parseArg(type, raw) {
      if (type.endsWith("[]")) return JSON.parse(raw);
      if (type === "bool") return raw === "true";
      if (/^u?int/.test(type)) return BigInt(raw);
      return raw;
    }

    function bindForm(f, isRead) {
      const sig = `${f.name}(${f.inputs.map((i) => i.type).join(",")})`;
      const el = document.querySelector(`form[data-fn="${sig}"]`);
      el.addEventListener("submit", async (e) => {
        e.preventDefault();
        const out = el.querySelector("[data-out]");
        try {
          const args = f.inputs.map((i, n) => parseArg(i.type, el.elements[n].value));
          if (isRead) {
            const r = await contract[sig](...args);
            out.textContent = String(r);
          } else {
            const signer = await Lab.browserProvider().getSigner();
            const overrides = f.stateMutability === "payable" && el.elements.value.value ? { value: ethers.parseEther(el.elements.value.value) } : {};
            out.textContent = "awaiting signature";
            const tx = await contract.connect(signer)[sig](...args, overrides);
            out.textContent = `pending ${Lab.short(tx.hash)}`;
            const receipt = await tx.wait();
            const link = Lab.explorerLink(chainId, "tx", tx.hash);
            out.innerHTML = `${receipt.status === 1 ? "VERIFIED" : "FAILED"} in block ${receipt.blockNumber}, gas ${receipt.gasUsed} · ${link ? `<a href="${link}" target="_blank" rel="noopener">${tx.hash}</a>` : tx.hash}`;
            refreshReads();
          }
        } catch (err) { out.textContent = Lab.explain(err); }
      });
    }

    async function refreshReads() {
      const block = await reader.getBlockNumber();
      Shell.classify({ network: Lab.CHAINS[chainId].name, subject: `${NAME} ${Lab.short(contract.target)}`, chainId, block });
      for (const dd of document.querySelectorAll("[data-read]")) {
        try { dd.textContent = String(await contract[dd.dataset.read]()); } catch (err) { dd.textContent = Lab.explain(err); }
      }
    }
    setInterval(() => { if (contract) refreshReads().catch(() => {}); }, 4000);

    const seen = new Set();
    function addEvent(ev, log, args, when, live) {
      const key = `${log.transactionHash}:${log.index ?? log.logIndex}`;
      if (seen.has(key)) return; seen.add(key);
      const li = document.createElement("li");
      li.className = "timeline-item";
      const txLink = Lab.explorerLink(chainId, "tx", log.transactionHash);
      li.innerHTML = `<span class="timeline-node ${live ? "is-success" : "is-info"}" aria-hidden="true"></span>
        <div class="timeline-time">${when} · block ${log.blockNumber}</div>
        <div class="timeline-title">${ev.name}</div>
        <div class="timeline-body"><span class="mono">${ev.inputs.map((i, n) => `${i.name}=${String(args[n])}`).join(", ")}</span><br>tx <span class="mono">${txLink ? `<a href="${txLink}" target="_blank" rel="noopener">${log.transactionHash}</a>` : log.transactionHash}</span></div>`;
      $("timeline").prepend(li);
      $("ev-count").textContent = `${seen.size} events`;
      const empty = $("timeline-empty");
      if (empty) empty.remove();
    }
    async function loadEvents(abi, fromBlock) {
      $("timeline").innerHTML = ""; seen.clear();
      for (const ev of abi.filter((e) => e.type === "event")) {
        try {
          const logs = await contract.queryFilter(contract.filters[ev.name](), fromBlock, "latest");
          for (const log of logs) {
            const blk = await log.getBlock();
            addEvent(ev, log, Array.from(log.args), Lab.utc(new Date(blk.timestamp * 1000)), false);
          }
        } catch (err) { console.warn("event query failed", ev.name, err); }
      }
      if (!seen.size) {
        $("timeline").insertAdjacentHTML("afterend", `<div class="empty" id="timeline-empty">
          <span class="empty-mark">NO EVENTS</span>
          <h2 class="empty-title">No events yet</h2>
          <p class="empty-body">Call a write function. Every event the contract emits lands here.</p></div>`);
      }
    }

    const connectBtn = $("connect");
    connectBtn.addEventListener("click", async () => { try { await Lab.connect(); } catch (err) { notice("danger", "Wallet", Lab.explain(err)); } syncWalletState(); });
    Lab.onWalletChange(syncWalletState);
    async function syncWalletState() {
      account = await Lab.currentAccount();
      walletChain = await Lab.currentChainId();
      connectBtn.textContent = account ? Lab.short(account) : (Lab.hasWallet() ? "Connect wallet" : "No wallet detected");
      const ready = account && walletChain === chainId;
      for (const b of document.querySelectorAll('#writes button[type="submit"]')) b.disabled = !ready;
      $("op-state").textContent = ready ? `signing as ${Lab.short(account)}` : "read only";
      if (account && walletChain !== chainId) {
        notice("warning", "Wallet is on the wrong network", `Your wallet is on chain ${walletChain}. This deployment lives on ${Lab.CHAINS[chainId].name} (chain ${chainId}).`,
          { label: `Switch to ${Lab.CHAINS[chainId].name}`, run: () => Lab.switchChain(chainId).catch((e) => notice("danger", "Switch failed", Lab.explain(e))) });
      } else if (account) notice(null);
    }

    const wc = await Lab.currentChainId();
    await useChain(wc && available.includes(String(wc)) ? wc : Number(available[0]));
  }

  return { boot };
})();
