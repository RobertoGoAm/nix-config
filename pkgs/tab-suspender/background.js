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

// A rule:
//   containerIds  [2, 3]        which jars it applies to; empty/absent = all
//   idleMinutes   30            how long untouched before it may be discarded
//   windows       [ { days, from, to } ]   when the rule is awake; absent = always
//   protect       { pinned, audio }        both default to true
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

function ruleAwake(rule, now) {
  const windows = Array.isArray(rule.windows) ? rule.windows : [];
  return windows.length === 0 || windows.some((w) => inWindow(w, now));
}

// "firefox-container-2" -> 2; the default jar and private windows -> 0.
function containerOf(tab) {
  const m = /^firefox-container-(\d+)$/.exec(tab.cookieStoreId || "");
  return m ? Number(m[1]) : 0;
}

function ruleCovers(rule, tab) {
  const ids = rule.containerIds;
  if (!Array.isArray(ids) || ids.length === 0) {
    return true;
  }
  return ids.includes(containerOf(tab));
}

// The active tab of every window is never a candidate: discarding it would
// blank the page in front of someone. That also covers the tab being typed
// into, which is why there is no form detection here -- a tab you left is a
// tab whose lastAccessed stopped moving, and idleMinutes is the guard.
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
  return false;
}

async function sweep() {
  const config = await readConfig();
  const rules = Array.isArray(config.rules) ? config.rules : [];
  const now = new Date();
  const awake = rules.filter((rule) => ruleAwake(rule, now));
  if (awake.length === 0) {
    return;
  }

  const tabs = await browser.tabs.query({});
  const doomed = [];

  for (const tab of tabs) {
    for (const rule of awake) {
      if (!ruleCovers(rule, tab) || tabProtected(rule, tab)) {
        continue;
      }
      const idleMs = Math.max(0, Number(rule.idleMinutes) || 0) * 60000;
      if (idleMs > 0 && now.getTime() - (tab.lastAccessed || 0) < idleMs) {
        continue;
      }
      doomed.push(tab.id);
      break;
    }
  }

  if (doomed.length > 0) {
    await browser.tabs.discard(doomed);
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
browser.runtime.onStartup.addListener(schedule);
browser.runtime.onInstalled.addListener(schedule);
browser.storage.onChanged.addListener(schedule);

schedule();
