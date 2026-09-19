"use strict";

// The options page. Everything the extension reads is editable here, and what
// it writes is storage.local -- the same place home-manager seeds. That is the
// honest tension of a declarative config with a UI: an edit made here survives
// until the next activation and no longer, which is what the banner says and
// what "Copy as Nix" is for.

const DAY_LABELS = ["S", "M", "T", "W", "T", "F", "S"];
const DAY_ORDER = [1, 2, 3, 4, 5, 6, 0];

const el = (tag, props = {}, children = []) => {
  const node = Object.assign(document.createElement(tag), props);
  for (const child of children) {
    node.append(child);
  }
  return node;
};

let containers = [];
let state = { intervalMinutes: 5, rules: [] };

function minutesToTime(value) {
  return /^\d{1,2}:\d{2}$/.test(String(value || "")) ? String(value) : "09:00";
}

// ---- pattern list <-> textarea -------------------------------------------

const patternsToText = (urls) => (Array.isArray(urls) ? urls : []).join("\n");
const textToPatterns = (text) =>
  text
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line.length > 0);

// ---- rendering ------------------------------------------------------------

function renderDays(selected, onChange) {
  const box = el("div", { className: "days" });
  for (const day of DAY_ORDER) {
    const input = el("input", { type: "checkbox", checked: selected.includes(day) });
    input.addEventListener("change", () => {
      const next = new Set(selected);
      input.checked ? next.add(day) : next.delete(day);
      onChange([...next].sort());
    });
    box.append(el("label", {}, [document.createTextNode(DAY_LABELS[day]), input]));
  }
  return box;
}

function renderWindow(win, rule, redraw) {
  const mode = win.suspend === false ? "never" : typeof win.idleMinutes === "number" ? "custom" : "standing";

  const action = el("select");
  for (const [value, label] of [
    ["never", "never suspend"],
    ["custom", "suspend after"],
    ["standing", "use the standing time"],
  ]) {
    action.append(el("option", { value, textContent: label, selected: mode === value }));
  }

  const minutes = el("input", {
    type: "number",
    min: "0",
    step: "1",
    value: typeof win.idleMinutes === "number" ? win.idleMinutes : 30,
    hidden: mode !== "custom",
  });

  const apply = () => {
    delete win.suspend;
    delete win.idleMinutes;
    if (action.value === "never") {
      win.suspend = false;
    } else if (action.value === "custom") {
      win.idleMinutes = Number(minutes.value) || 0;
    }
    minutes.hidden = action.value !== "custom";
  };
  action.addEventListener("change", apply);
  minutes.addEventListener("input", apply);

  const from = el("input", { type: "time", value: minutesToTime(win.from) });
  const to = el("input", { type: "time", value: minutesToTime(win.to) });
  from.addEventListener("input", () => (win.from = from.value));
  to.addEventListener("input", () => (win.to = to.value));

  const remove = el("button", { className: "link", textContent: "remove" });
  remove.addEventListener("click", () => {
    rule.windows.splice(rule.windows.indexOf(win), 1);
    redraw();
  });

  return el("div", { className: "window" }, [
    el("div", { className: "row" }, [
      renderDays(Array.isArray(win.days) ? win.days : [], (days) => (win.days = days)),
      from,
      el("span", { className: "status", textContent: "to" }),
      to,
      action,
      minutes,
      el("span", { className: "spacer" }),
      remove,
    ]),
  ]);
}

function renderRule(rule, index, redraw) {
  const body = el("fieldset");
  body.append(el("legend", { textContent: `Rule ${index + 1}` }));

  // containers
  const containerRow = el("div", { className: "row" });
  const ids = Array.isArray(rule.containerIds) ? rule.containerIds : [];
  for (const container of containers) {
    const input = el("input", { type: "checkbox", checked: ids.includes(container.id) });
    input.addEventListener("change", () => {
      const next = new Set(rule.containerIds || []);
      input.checked ? next.add(container.id) : next.delete(container.id);
      rule.containerIds = [...next].sort((a, b) => a - b);
    });
    containerRow.append(el("label", { className: "inline" }, [input, document.createTextNode(container.name)]));
  }
  containerRow.append(
    el("span", { className: "status", textContent: ids.length === 0 ? "none ticked = every container" : "" })
  );
  body.append(el("div", { className: "row" }, [el("h2", { textContent: "Containers" })]), containerRow);

  // url patterns
  const patterns = el("textarea", { value: patternsToText(rule.urls), spellcheck: false });
  patterns.addEventListener("input", () => (rule.urls = textToPatterns(patterns.value)));
  body.append(
    el("div", { className: "row" }, [el("h2", { textContent: "Sites" })]),
    patterns,
    el("p", { className: "hint" }, [
      document.createTextNode("One per line, empty for every site. "),
      el("code", { textContent: "atlassian.net" }),
      document.createTextNode(" host and subdomains · "),
      el("code", { textContent: "host:*.atlassian.net" }),
      document.createTextNode(" · "),
      el("code", { textContent: "url:https://x.com/a/*" }),
      document.createTextNode(" · "),
      el("code", { textContent: "exact:" }),
      document.createTextNode(" · "),
      el("code", { textContent: "prefix:" }),
      document.createTextNode(" · "),
      el("code", { textContent: "suffix:" }),
      document.createTextNode(" · "),
      el("code", { textContent: "contains:" }),
      document.createTextNode(" · "),
      el("code", { textContent: "regex:" }),
      document.createTextNode(" · "),
      el("code", { textContent: "*" }),
      document.createTextNode(" everything"),
    ])
  );

  // standing time + protections
  const standing = el("input", {
    type: "number",
    min: "0",
    step: "1",
    value: typeof rule.idleMinutes === "number" ? rule.idleMinutes : "",
    placeholder: "never",
  });
  standing.addEventListener("input", () => {
    if (standing.value === "") {
      delete rule.idleMinutes;
    } else {
      rule.idleMinutes = Number(standing.value) || 0;
    }
  });

  const protections = el("div", { className: "row" });
  rule.protect = rule.protect || {};
  for (const [key, label] of [
    ["pinned", "pinned tabs"],
    ["audio", "playing audio or video"],
    ["sharing", "camera, microphone or screen share"],
  ]) {
    const input = el("input", { type: "checkbox", checked: rule.protect[key] !== false });
    input.addEventListener("change", () => (rule.protect[key] = input.checked));
    protections.append(el("label", { className: "inline" }, [input, document.createTextNode(label)]));
  }

  body.append(
    el("div", { className: "row" }, [el("h2", { textContent: "Timing" })]),
    el("div", { className: "row" }, [
      el("label", { className: "field" }, [document.createTextNode("Standing idle minutes"), standing]),
      el("span", { className: "status", textContent: "blank = never suspend unless a window below says otherwise" }),
    ]),
    el("div", { className: "row" }, [el("h2", { textContent: "Never discard while" })]),
    protections
  );

  // windows
  rule.windows = Array.isArray(rule.windows) ? rule.windows : [];
  body.append(el("div", { className: "row" }, [el("h2", { textContent: "Hours that override the standing time" })]));
  for (const win of rule.windows) {
    body.append(renderWindow(win, rule, redraw));
  }
  const addWindow = el("button", { textContent: "Add hours" });
  addWindow.addEventListener("click", () => {
    rule.windows.push({ days: [1, 2, 3, 4, 5], from: "09:00", to: "18:00", suspend: false });
    redraw();
  });

  const removeRule = el("button", { className: "link", textContent: "Delete this rule" });
  removeRule.addEventListener("click", () => {
    state.rules.splice(index, 1);
    redraw();
  });
  const duplicate = el("button", { className: "link", textContent: "Duplicate" });
  duplicate.addEventListener("click", () => {
    state.rules.splice(index + 1, 0, JSON.parse(JSON.stringify(rule)));
    redraw();
  });

  body.append(
    el("p", { className: "hint", textContent: "The first window matching the moment decides; where none matches, the standing time applies." }),
    el("div", { className: "row" }, [addWindow, el("span", { className: "spacer" }), duplicate, removeRule])
  );
  return body;
}

function redraw() {
  const host = document.getElementById("rules");
  host.textContent = "";
  state.rules.forEach((rule, index) => host.append(renderRule(rule, index, redraw)));
}

// ---- nix export -----------------------------------------------------------

const nixString = (value) => JSON.stringify(String(value));
const nixList = (items, indent) =>
  items.length === 0 ? "[ ]" : "[\n" + items.map((i) => `${indent}  ${i}`).join("\n") + `\n${indent}]`;

function toNix() {
  const lines = [];
  lines.push("rules = [");
  for (const rule of state.rules) {
    lines.push("  {");
    if ((rule.containerIds || []).length > 0) {
      lines.push(`    containerIds = ${nixList(rule.containerIds.map(String), "    ")};`);
    }
    if ((rule.urls || []).length > 0) {
      lines.push(`    urls = ${nixList(rule.urls.map(nixString), "    ")};`);
    }
    if (typeof rule.idleMinutes === "number") {
      lines.push(`    idleMinutes = ${rule.idleMinutes};`);
    }
    for (const [key, value] of Object.entries(rule.protect || {})) {
      if (value === false) {
        lines.push(`    protect.${key} = false;`);
      }
    }
    if ((rule.windows || []).length > 0) {
      lines.push("    windows = [");
      for (const win of rule.windows) {
        const bits = [`days = [ ${(win.days || []).join(" ")} ]`, `from = ${nixString(win.from)}`, `to = ${nixString(win.to)}`];
        if (win.suspend === false) {
          bits.push("suspend = false");
        } else if (typeof win.idleMinutes === "number") {
          bits.push(`idleMinutes = ${win.idleMinutes}`);
        }
        lines.push(`      { ${bits.join("; ")}; }`);
      }
      lines.push("    ];");
    }
    lines.push("  }");
  }
  lines.push("];");
  return lines.join("\n");
}

// ---- load / save ----------------------------------------------------------

function say(message) {
  document.getElementById("status").textContent = message;
  setTimeout(() => {
    const status = document.getElementById("status");
    if (status.textContent === message) {
      status.textContent = "";
    }
  }, 4000);
}

async function load() {
  try {
    containers = (await browser.contextualIdentities.query({})).map((identity) => ({
      id: Number((/^firefox-container-(\d+)$/.exec(identity.cookieStoreId) || [])[1]),
      name: identity.name,
    }));
  } catch (e) {
    containers = [];
  }
  containers.unshift({ id: 0, name: "No container" });

  let managed = {};
  try {
    managed = (await browser.storage.managed.get(null)) || {};
  } catch (e) {
    managed = {};
  }
  const local = (await browser.storage.local.get(null)) || {};
  const source = Object.keys(managed).length > 0 ? "managed" : "local";

  const loaded = Object.assign({ intervalMinutes: 5, rules: [] }, local, managed);
  state = JSON.parse(JSON.stringify(loaded));
  document.getElementById("interval").value = state.intervalMinutes;

  const banner = document.getElementById("source");
  banner.textContent = "";
  if (source === "managed") {
    banner.append(
      document.createTextNode(
        "These settings come from an enterprise policy and the extension will keep reading that, not this page. Edit the policy instead."
      )
    );
  } else {
    banner.append(
      document.createTextNode("Settings are written by home-manager. Saving here works, and "),
      el("strong", { textContent: "the next activation overwrites it" }),
      document.createTextNode(" — use Copy as Nix to keep a change, and paste it into "),
      el("code", { textContent: "features/internet/zen.nix" }),
      document.createTextNode(".")
    );
  }
  redraw();
}

document.getElementById("interval").addEventListener("input", (event) => {
  state.intervalMinutes = Number(event.target.value) || 1;
});
document.getElementById("add-rule").addEventListener("click", () => {
  state.rules.push({ containerIds: [], urls: [], idleMinutes: 30, windows: [], protect: {} });
  redraw();
});
document.getElementById("save").addEventListener("click", async () => {
  await browser.storage.local.set(JSON.parse(JSON.stringify(state)));
  say("Saved. The next sweep uses it.");
});
document.getElementById("revert").addEventListener("click", async () => {
  await load();
  say("Reloaded from storage.");
});
document.getElementById("export").addEventListener("click", async () => {
  await navigator.clipboard.writeText(toNix());
  say("Nix snippet copied.");
});

load();
