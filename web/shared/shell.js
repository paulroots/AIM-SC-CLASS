// Renders the console shell shared by every page: the dark nav rail on the left and the
// classification bar across the top of the main column. Pages call Shell.mount() once.
// Markup and classes come from the Lumen design system (web/shared/lumen).

window.Shell = (() => {
  const ICONS = {
    overview: '<svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.4" aria-hidden="true"><rect x="2" y="2" width="5" height="5"/><rect x="9" y="2" width="5" height="5"/><rect x="2" y="9" width="5" height="5"/><rect x="9" y="9" width="5" height="5"/></svg>',
    contract: '<svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.4" aria-hidden="true"><rect x="2.5" y="2" width="11" height="12"/><line x1="5" y1="5.5" x2="11" y2="5.5"/><line x1="5" y1="8" x2="11" y2="8"/><line x1="5" y1="10.5" x2="9" y2="10.5"/></svg>',
  };

  async function loadDapps() {
    const res = await fetch("/shared/dapps.json", { cache: "no-store" });
    return res.ok ? res.json() : [];
  }

  // active: "overview" or a dApp path such as "counter".
  async function mount({ active }) {
    const dapps = await loadDapps();
    const rail = document.getElementById("rail");
    const items = [{ path: "", title: "Overview", icon: ICONS.overview, key: "overview" }]
      .concat(dapps.map((d) => ({ path: d.path + "/", title: d.title, icon: ICONS.contract, key: d.path })));

    rail.innerHTML = `
      <div class="rail-head">
        <img class="rail-logo" src="/shared/lumen/lumen-full-white.png" alt="Lumen">
        <span class="eyebrow">Smart Contracts Lab</span>
      </div>
      <nav class="nav-rail" aria-label="Primary">
        ${items.map((i) => `
          <a class="nav-item${i.key === active ? " is-active" : ""}" href="/${i.path}"${i.key === active ? ' aria-current="page"' : ""}>
            ${i.icon}<span>${i.title}</span>
          </a>`).join("")}
      </nav>
      <div class="rail-foot">
        <span class="mono">Lumen DS ${await version()}</span>
      </div>`;
    return dapps;
  }

  async function version() {
    try {
      const res = await fetch("/shared/lumen/VERSION", { cache: "no-store" });
      return res.ok ? (await res.text()).trim() : "";
    } catch {
      return "";
    }
  }

  // Updates the classification bar. Call whenever the network, block, or subject changes.
  function classify({ network, subject, chainId, block }) {
    const bar = document.getElementById("cbar");
    if (!bar) return;
    bar.querySelector(".cb-mark").textContent = network || "No network";
    bar.querySelector(".cb-subject").textContent = subject || "";
    const meta = [];
    if (chainId) meta.push(`chain ${chainId}`);
    if (block != null) meta.push(`block ${block}`);
    meta.push(`synced ${Lab.utc().slice(11)}`);
    bar.querySelector(".cb-meta").textContent = meta.join(" · ");
  }

  return { mount, classify };
})();
