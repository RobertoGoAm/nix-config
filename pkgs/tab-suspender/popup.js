"use strict";

// What is asleep right now, grouped by the jar it belongs to. Every discarded
// tab is listed, not only the ones a rule put to sleep: Gecko discards tabs of
// its own accord under memory pressure, and for the question the popup answers
// -- what is not currently loaded -- the distinction does not matter.

const el = (tag, props = {}, children = []) => {
  const node = Object.assign(document.createElement(tag), props);
  for (const child of children) {
    node.append(child);
  }
  return node;
};

function hostOf(url) {
  try {
    return new URL(url).hostname.replace(/^www\./, "");
  } catch (e) {
    return url || "";
  }
}

async function containerNames() {
  const names = new Map([[0, "No container"]]);
  try {
    for (const identity of await browser.contextualIdentities.query({})) {
      const m = /^firefox-container-(\d+)$/.exec(identity.cookieStoreId);
      if (m) {
        names.set(Number(m[1]), identity.name);
      }
    }
  } catch (e) {
    // Without the container list the grouping falls back to numbers.
  }
  return names;
}

function containerOf(tab) {
  const m = /^firefox-container-(\d+)$/.exec(tab.cookieStoreId || "");
  return m ? Number(m[1]) : 0;
}

async function render() {
  const [tabs, names] = await Promise.all([
    browser.tabs.query({ discarded: true }),
    containerNames(),
  ]);

  document.getElementById("count").textContent =
    tabs.length === 0 ? "Nothing suspended" : `${tabs.length} suspended`;
  document.getElementById("sub").textContent =
    tabs.length === 0 ? "" : "click one to wake it";

  const list = document.getElementById("list");
  list.textContent = "";

  if (tabs.length === 0) {
    list.append(el("p", { className: "empty", textContent: "Every tab is loaded." }));
    return;
  }

  const groups = new Map();
  for (const tab of tabs) {
    const id = containerOf(tab);
    if (!groups.has(id)) {
      groups.set(id, []);
    }
    groups.get(id).push(tab);
  }

  for (const [id, group] of [...groups.entries()].sort((a, b) => a[0] - b[0])) {
    const section = el("section", { className: "group" });
    section.append(el("h2", { textContent: names.get(id) || `Container ${id}` }));
    for (const tab of group) {
      const button = el("button", { className: "tab", title: tab.url || "" }, [
        el("span", { className: "title", textContent: tab.title || hostOf(tab.url) }),
        el("span", { className: "host", textContent: hostOf(tab.url) }),
      ]);
      // Activating a discarded tab is what loads it again; raising its window
      // too, so the click lands somewhere visible when the tab is elsewhere.
      button.addEventListener("click", async () => {
        await browser.tabs.update(tab.id, { active: true });
        await browser.windows.update(tab.windowId, { focused: true });
        window.close();
      });
      section.append(button);
    }
    list.append(section);
  }
}

document.getElementById("sweep").addEventListener("click", async () => {
  await browser.runtime.sendMessage({ type: "sweep-now" });
  await render();
});
document.getElementById("options").addEventListener("click", () => {
  browser.runtime.openOptionsPage();
  window.close();
});

render();
