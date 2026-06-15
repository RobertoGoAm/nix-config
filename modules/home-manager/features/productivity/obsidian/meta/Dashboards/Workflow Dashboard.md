---
title: Workflow Dashboard
status: active
tags: [dashboard, workflow]
cssclasses: [dashboard]
---
# Summary

```dataviewjs
const asMillis = (value) => {
  if (!value) return null;
  if (typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  if (typeof value === "string") {
    const parsed = dv.date(value);
    return parsed && typeof parsed.toMillis === "function" ? parsed.toMillis() : null;
  }
  const numeric = Number(value);
  return Number.isFinite(numeric) ? numeric : null;
};

const createdAt = (page) => page.created ?? page.file.cday ?? page.file.ctime ?? page.file.mday ?? page.file.mtime;
const ageInDays = (page) => {
  const createdMs = asMillis(createdAt(page));
  if (createdMs == null) return "";
  return `${Math.max(0, Math.floor((Date.now() - createdMs) / 86400000))}d`;
};

const inbox = dv.pages('"Inbox"')
  .where(p => p.file.folder === "Inbox")
  .where(p => !p.from_snipd)
  .where(p => String(p.status ?? "").toLowerCase() !== "complete");
const seedling = dv.pages('"Knowledge"').where(p => p.status === "seedling");
const growing = dv.pages('"Knowledge"').where(p => p.status === "growing");
const evergreen = dv.pages('"Knowledge"').where(p => p.status === "evergreen");

const tasks = dv.pages('"Work"').file.tasks.where(t => !t.completed);

// Summary callout
const callout = dv.el("div", "", { cls: "callout", attr: { "data-callout": "summary" } });
callout.createEl("div", { cls: "callout-title", text: "Pipeline at a Glance" });
const body = callout.createDiv({ cls: "callout-content" });
body.createEl("p").innerHTML = `<strong>${inbox.length}</strong> in Inbox · <strong>${seedling.length}</strong> seedling · <strong>${growing.length}</strong> growing · <strong>${evergreen.length}</strong> evergreen`;

// Two-column container
const container = dv.el("div", "", { cls: "dashboard-columns" });

// Left column — Pipeline
const left = container.createDiv({ cls: "dashboard-col" });
left.createEl("h3", { text: "Inbox — process next" });
if (inbox.length > 0) {
  const table = left.createEl("table", { cls: "dataview table-view-table" });
  const thead = table.createEl("thead");
  const hr = thead.createEl("tr");
  hr.createEl("th", { text: "Note" });
  hr.createEl("th", { text: "Type" });
  hr.createEl("th", { text: "Age" });
  const tbody = table.createEl("tbody");
  for (const p of inbox.sort(p => asMillis(createdAt(p)) ?? Number.MAX_SAFE_INTEGER, "asc").slice(0, 10)) {
    const row = tbody.createEl("tr");
    const td1 = row.createEl("td");
    const link = td1.createEl("a", { text: p.file.name, cls: "internal-link", attr: { href: p.file.path } });
    row.createEl("td", { text: p.type || "" });
    row.createEl("td", { text: ageInDays(p) });
  }
} else {
  left.createEl("p", { text: "Inbox empty", cls: "dashboard-empty" });
}

// Right column — Work tasks
const right = container.createDiv({ cls: "dashboard-col" });
right.createEl("h3", { text: "Work — Open Tasks" });
if (tasks.length > 0) {
  const ul = right.createEl("ul", { cls: "contains-task-list" });
  for (const t of tasks.slice(0, 15)) {
    const li = ul.createEl("li", { cls: "task-list-item" });
    const cb = li.createEl("input", { attr: { type: "checkbox", disabled: true } });
    li.appendText(" " + t.text);
  }
} else {
  right.createEl("p", { text: "No open tasks", cls: "dashboard-empty" });
}
```

---

## What Needs Attention

> [!caution] Stale Seedlings — untouched 14+ days
> ```dataview
> TABLE WITHOUT ID
>   file.link as "Note",
>   split(file.folder, "/")[1] as "Domain",
>   round((date(now) - file.mday).days) + "d" as "Idle"
> FROM "Knowledge"
> WHERE status = "seedling"
>   AND (date(now) - file.mday).days >= 14
> SORT file.mday ASC
> LIMIT 10
> ```

> [!tip] Growing — ready to promote?
> ```dataview
> TABLE WITHOUT ID
>   file.link as "Note",
>   split(file.folder, "/")[1] as "Domain",
>   file.mday as "Last Edited"
> FROM "Knowledge"
> WHERE status = "growing"
> SORT file.mday DESC
> LIMIT 10
> ```

---

## Knowledge

```dataviewjs
const pages = dv.pages('"Knowledge"').where(p => p.file.name !== "Maps of Content" && !p.file.folder.includes("Sources"));
const domains = pages.groupBy(p => p.file.folder.split("/")[1]);

dv.table(
  ["Domain", "Total", "Seedling", "Growing", "Evergreen"],
  domains.map(g => [
    g.key,
    g.rows.length,
    g.rows.where(r => r.status === "seedling").length,
    g.rows.where(r => r.status === "growing").length,
    g.rows.where(r => r.status === "evergreen").length
  ]).sort((a, b) => b[1] - a[1])
);
```

---

## Recent Activity
```dataview
TABLE WITHOUT ID
  file.link as "Note",
  file.folder as "Location",
  file.mday as "Modified"
FROM "Inbox" OR "Knowledge"
WHERE !contains(file.folder, "Sources")
  AND !contains(file.folder, "Inbox/Data")
  AND from_snipd != true
SORT file.mday DESC
LIMIT 8
```

---

[[Pipeline Guide]] · [[Incremental Writing Guide]] · [[Worked Examples]] · [[IW-Queue]]
