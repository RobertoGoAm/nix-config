"use strict";

// Discards tabs belonging to given containers, either after they have been
// idle for a while or during a recurring window of the week.
//
// Matching is by container *id*, never by name: the ids are what nix assigns
// in the zen module (personal 1, work 2, client 3), they are stable across
// renames, and the names themselves cannot appear in a public repo.
//
// Configuration arrives from the browser, not from this file. storage.managed
// is the enterprise policy and wins where it exists; storage.local is what
// home-manager seeds on macOS, where this module's policies never reach the
// app bundle. Reading both in that order means one config shape works on
// either platform.

const DEFAULTS = {
  intervalMinutes: 5,
  rules: [],
};

// Where "last used" is remembered between sweeps.
//
// tabs.lastAccessed is not that: Gecko stamps it when a tab is *activated*, so
// a tab resumed at 19:00 and read until 19:45 still reports 19:00, and the
// first sweep after you switch away sees three quarters of an hour of idleness
// and discards work you touched a minute ago. What matters is when a tab
// stopped being used, which nothing reports, so it is recorded here: on every
// switch, for both the tab being left and the tab being entered, and on every
// sweep for whatever is in front at the time. The later of that and
// lastAccessed is the answer.
//
// storage.session and not storage.local: this is per-run state that should not
// survive a restart, and local is the file home-manager writes the settings
// into.

const SEEN_KEY = "lastSeen";

async function readSeen() {
  try {
    return (await browser.storage.session.get(SEEN_KEY))[SEEN_KEY] || {};
  } catch (e) {
    return {};
  }
}

async function writeSeen(seen) {
  try {
    await browser.storage.session.set({ [SEEN_KEY]: seen });
  } catch (e) {
    // Without session storage the extension still works, just from
    // lastAccessed alone.
  }
}

async function markSeen(tabIds, when) {
  const seen = await readSeen();
  for (const id of tabIds) {
    if (typeof id === "number") {
      seen[id] = when;
    }
  }
  await writeSeen(seen);
}

function lastSeenOf(tab, seen) {
  return Math.max(Number(tab.lastAccessed) || 0, Number(seen[tab.id]) || 0);
}

// A rule:
//   containerIds  [2, 3]        which jars it applies to; empty/absent = all
//   urls          ["a.com"]     which sites within them; empty/absent = all
//   idleMinutes   30            the standing time; absent = never suspend
//   windows       [ ... ]       hours that override that time; absent = none
//   protect       { pinned, audio, sharing }   all three default to true
//
// A window is { days, from, to } plus what it does to the time:
//
//   suspend: false     never, in these hours, however long it sits
//   idleMinutes: 120   a different time in these hours
//   neither            the rule's standing time, said explicitly
//
// The first window matching the moment decides; where none matches, the rule's
// own idleMinutes applies. So "never during the working day, five minutes
// outside it" is one workday window marked suspend false over a standing five,
// rather than an enumeration of the hours that are not the working day.
//
// A rule is the intersection of the two: the calendar in one jar can sleep
// while the same calendar signed in as someone else stays awake. That is also
// what lets the patterns be plain vendor hostnames -- "atlassian.net" is
// ambiguous on its own and exact once the container has already chosen whose
// Atlassian it is.
//
// days are JS weekdays, Sunday 0 .. Saturday 6. from/to are "HH:MM" on a
// 24-hour clock, and "24:00" is a legal end meaning midnight.

async function readConfig() {
  let managed = {};
  try {
    managed = (await browser.storage.managed.get(null)) || {};
  } catch (e) {
    // No policy for this extension: normal, and the local copy answers.
    managed = {};
  }
  const local = (await browser.storage.local.get(null)) || {};
  return Object.assign({}, DEFAULTS, local, managed);
}

function minutesOfDay(hhmm) {
  const m = /^(\d{1,2}):(\d{2})$/.exec(String(hhmm).trim());
  if (!m) {
    return null;
  }
  const mins = Number(m[1]) * 60 + Number(m[2]);
  return mins >= 0 && mins <= 24 * 60 ? mins : null;
}

// A window that ends at or before it starts is one that crosses midnight, and
// it belongs to the day it *opens* on -- "workdays 18:00 to 09:00" is awake at
// 23:00 on Friday and at 08:00 on Saturday, and asleep at 08:00 on Monday.
function inWindow(win, now) {
  const from = minutesOfDay(win.from);
  const to = minutesOfDay(win.to);
  if (from === null || to === null) {
    return false;
  }
  const days = Array.isArray(win.days) ? win.days : [0, 1, 2, 3, 4, 5, 6];
  const mins = now.getHours() * 60 + now.getMinutes();
  const today = now.getDay();

  if (to > from) {
    return days.includes(today) && mins >= from && mins < to;
  }
  if (days.includes(today) && mins >= from) {
    return true;
  }
  return days.includes((today + 6) % 7) && mins < to;
}

function standingIdleMs(rule) {
  const minutes = Number(rule.idleMinutes);
  return Number.isFinite(minutes) && minutes >= 0 ? minutes * 60000 : null;
}

// How long this rule wants a tab left alone *right now*, or null for "not at
// this hour". Computed once per sweep rather than once per tab: it depends on
// the clock, not on the tab.
function idleMsNow(rule, now) {
  const windows = Array.isArray(rule.windows) ? rule.windows : [];
  for (const win of windows) {
    if (!inWindow(win, now)) {
      continue;
    }
    if (win.suspend === false) {
      return null;
    }
    const minutes = Number(win.idleMinutes);
    if (Number.isFinite(minutes) && minutes >= 0) {
      return minutes * 60000;
    }
    break;
  }
  return standingIdleMs(rule);
}

// "firefox-container-2" -> 2; the default jar and private windows -> 0.
function containerOf(tab) {
  const m = /^firefox-container-(\d+)$/.exec(tab.cookieStoreId || "");
  return m ? Number(m[1]) : 0;
}

function ruleCoversContainer(rule, tab) {
  const ids = rule.containerIds;
  if (!Array.isArray(ids) || ids.length === 0) {
    return true;
  }
  return ids.includes(containerOf(tab));
}

// How a pattern is read. A bare string is a hostname and matches that host and
// anything under it, which is the common case and the one worth having short.
// A prefix chooses something else:
//
//   atlassian.net                       host, with its subdomains
//   host:*.atlassian.net                glob against the hostname alone
//   url:https://mail.google.com/*/u/1/* glob against the whole URL
//   exact:https://example.com/page      that URL and nothing else
//   prefix:https://example.com/app      URLs starting with it
//   suffix:/settings                    URLs ending with it
//   contains:/jira/                     the text anywhere in the URL
//   regex:^https://[a-z]+\.example\.com  a JS regular expression
//
// A string carrying "://" and no prefix is read as url: rather than as a
// hostname, since no hostname contains a scheme.
//
// Globs are literal text with * for any run of characters and ? for one, so a
// pattern never has to be escaped the way a regex does. "*" alone therefore
// means every URL, and "url:*.pdf" every URL ending in .pdf.

const PREFIXES = ["host", "url", "exact", "prefix", "suffix", "contains", "regex"];

function parsePattern(pattern) {
  const text = String(pattern);
  const colon = text.indexOf(":");
  if (colon > 0) {
    const kind = text.slice(0, colon);
    if (PREFIXES.includes(kind)) {
      return { kind, value: text.slice(colon + 1) };
    }
  }
  if (text === "*") {
    // Every URL. Spelled without a prefix because it is the one pattern people
    // reach for without thinking, and as a hostname it would match nothing.
    return { kind: "url", value: "*" };
  }
  return text.includes("://") ? { kind: "url", value: text } : { kind: "hostname", value: text };
}

function globToRegExp(glob) {
  const escaped = String(glob).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  return new RegExp("^" + escaped.replace(/\\\*/g, ".*").replace(/\\\?/g, ".") + "$");
}

// The hostname form: the host itself, or anything under it at a dot boundary.
// Never a bare substring -- notatlassian.net and atlassian.net.evil.com are
// different sites, and a rule for atlassian.net must not reach them. A path
// may follow the host when the host alone is too coarse.
function hostnameMatches(value, parsed) {
  const slash = value.indexOf("/");
  const wantHost = (slash === -1 ? value : value.slice(0, slash)).toLowerCase().replace(/^\*\./, "");
  const wantPath = slash === -1 ? "" : value.slice(slash).toLowerCase();

  const host = parsed.hostname.toLowerCase();
  if (host !== wantHost && !host.endsWith("." + wantHost)) {
    return false;
  }
  if (wantPath === "" || wantPath === "/") {
    return true;
  }
  return parsed.pathname.toLowerCase().startsWith(wantPath);
}

function urlMatches(pattern, url) {
  let parsed;
  try {
    parsed = new URL(url);
  } catch (e) {
    return false;
  }

  const { kind, value } = parsePattern(pattern);
  const full = parsed.href;

  switch (kind) {
    case "hostname":
      return hostnameMatches(value, parsed);
    case "host":
      try {
        return globToRegExp(value.toLowerCase()).test(parsed.hostname.toLowerCase());
      } catch (e) {
        return false;
      }
    case "url":
      try {
        return globToRegExp(value).test(full);
      } catch (e) {
        return false;
      }
    case "exact":
      return full === value;
    case "prefix":
      return full.startsWith(value);
    case "suffix":
      return full.endsWith(value);
    case "contains":
      return full.includes(value);
    case "regex":
      try {
        return new RegExp(value).test(full);
      } catch (e) {
        // A pattern that does not compile matches nothing rather than
        // everything: a typo should not suspend the browser.
        return false;
      }
    default:
      return false;
  }
}

function ruleCoversUrl(rule, tab) {
  const urls = rule.urls;
  if (!Array.isArray(urls) || urls.length === 0) {
    return true;
  }
  return urls.some((pattern) => urlMatches(pattern, tab.url || ""));
}

function ruleCovers(rule, tab) {
  return ruleCoversContainer(rule, tab) && ruleCoversUrl(rule, tab);
}

// A tab holding the camera, the microphone or a screen share is in a call, and
// a call is the one thing that is in use precisely while nobody touches the
// tab. Audio is not the test: Meet keeps the microphone captured through a
// mute, and a call where nobody is speaking is silent but very much alive.
// sharingState is what Gecko reports for all three.
function inCall(tab) {
  const sharing = tab.sharingState;
  if (!sharing) {
    return false;
  }
  return Boolean(sharing.camera || sharing.microphone || sharing.screen);
}

// The active tab of every window is never a candidate: discarding it would
// blank the page in front of someone. That also covers the tab being typed
// into, which is why there is no form detection here -- a tab you left is a
// tab whose last-used stamp stopped moving, and idleMinutes is the guard.
function tabProtected(rule, tab) {
  const protect = rule.protect || {};
  if (tab.active || tab.discarded) {
    return true;
  }
  if (protect.pinned !== false && tab.pinned) {
    return true;
  }
  if (protect.audio !== false && tab.audible) {
    return true;
  }
  if (protect.sharing !== false && inCall(tab)) {
    return true;
  }
  return false;
}

async function sweep() {
  const config = await readConfig();
  const rules = Array.isArray(config.rules) ? config.rules : [];
  const now = new Date();
  const tabs = await browser.tabs.query({});

  // Whatever is in front right now is in use right now, in every window. Doing
  // this before the rules are consulted is what keeps a tab that has been read
  // for an hour from looking like a tab abandoned an hour ago.
  const seen = await readSeen();
  for (const tab of tabs) {
    if (tab.active) {
      seen[tab.id] = now.getTime();
    }
  }

  // Forget tabs that no longer exist, so the map cannot grow for a whole run.
  const live = new Set(tabs.map((tab) => String(tab.id)));
  for (const id of Object.keys(seen)) {
    if (!live.has(id)) {
      delete seen[id];
    }
  }
  await writeSeen(seen);

  const awake = [];
  for (const rule of rules) {
    const idleMs = idleMsNow(rule, now);
    if (idleMs !== null) {
      awake.push({ rule, idleMs });
    }
  }
  if (awake.length === 0) {
    return;
  }

  // Rules are a union, not a chain: a tab is discarded as soon as any rule that
  // covers it has had its time met, so the shortest applicable time wins and
  // the order they are declared in does not matter.
  const doomed = [];
  for (const tab of tabs) {
    for (const { rule, idleMs } of awake) {
      if (!ruleCovers(rule, tab) || tabProtected(rule, tab)) {
        continue;
      }
      if (now.getTime() - lastSeenOf(tab, seen) < idleMs) {
        continue;
      }
      doomed.push(tab.id);
      break;
    }
  }

  if (doomed.length > 0) {
    await browser.tabs.discard(doomed);
  }

  await updateBadge();
}

// The badge is the only thing this extension puts on screen. It carries the
// number of tabs currently not loaded -- blank rather than a zero when they all
// are, since an indicator that is always lit stops being read.
async function updateBadge() {
  try {
    const discarded = await browser.tabs.query({ discarded: true });
    await browser.browserAction.setBadgeText({
      text: discarded.length > 0 ? String(discarded.length) : "",
    });
  } catch (e) {
    // Nothing to do: the badge is decoration, and a failure here must not
    // take the sweep down with it.
  }
}

async function schedule() {
  const config = await readConfig();
  const period = Math.max(1, Number(config.intervalMinutes) || DEFAULTS.intervalMinutes);
  await browser.alarms.clear("sweep");
  browser.alarms.create("sweep", { periodInMinutes: period, delayInMinutes: period });
}

browser.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === "sweep") {
    sweep();
  }
});

// Both ends of a switch: the tab being entered starts its clock now, and the
// tab being left was in use up to this moment, which is the reading Gecko does
// not keep.
browser.tabs.onActivated.addListener(({ tabId, previousTabId }) => {
  const ids = typeof previousTabId === "number" ? [tabId, previousTabId] : [tabId];
  markSeen(ids, Date.now());
});
browser.runtime.onStartup.addListener(schedule);
browser.runtime.onInstalled.addListener(schedule);
browser.storage.onChanged.addListener(schedule);

// A tab is discarded and restored by more than this extension -- Gecko does it
// under memory pressure, and clicking a sleeping tab wakes it -- so the count
// follows the tabs themselves rather than only this extension's own work.
browser.tabs.onUpdated.addListener(updateBadge);
browser.tabs.onRemoved.addListener(updateBadge);
browser.tabs.onCreated.addListener(updateBadge);

// "Suspend now" in the popup, for when the schedule says later and you are
// leaving the desk anyway.
browser.runtime.onMessage.addListener((message) => {
  if (message && message.type === "sweep-now") {
    return sweep().then(() => ({ ok: true }));
  }
  return undefined;
});

schedule();
updateBadge();
