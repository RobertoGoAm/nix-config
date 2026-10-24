'use strict'

const PICKER = browser.runtime.getURL('pick.html')

const FRESH_MS = 1500

/** @type {Map<number, {born: number, hasOpener: boolean}>} */
const fresh = new Map()

/** @type {Object<string, string>} host -> cookieStoreId */
let assignments = {}

browser.tabs.onCreated.addListener((tab) => {
  fresh.set(tab.id, {
    born: Date.now(),
    hasOpener: tab.openerTabId !== undefined
  })
})

browser.tabs.onRemoved.addListener((tabId) => fresh.delete(tabId))

browser.storage.onChanged.addListener((changes, area) => {
  if (area === 'local' && changes.assignments) {
    assignments = changes.assignments.newValue || {}
  }
})

async function loadAssignments() {
  const stored = await browser.storage.local.get('assignments')
  assignments = stored.assignments || {}
}

/**
 * @param {string} url
 * @returns {?string} hostname, or null for anything unparseable
 */
function hostOf(url) {
  try {
    return new URL(url).hostname
  } catch (_) {
    return null
  }
}

/**
 * Whether a navigation came from outside the browser.
 *
 * An external link has no document behind it, so originUrl and documentUrl are
 * both absent -- that rules out every link clicked on a page. Address-bar
 * typing and bookmarks arrive the same way, and the tab's age separates them:
 * an external link creates a tab and navigates it in one breath, while a person
 * opening a tab and then typing takes longer than FRESH_MS.
 *
 * @param {object} details webRequest.onBeforeRequest details
 * @returns {boolean}
 */
function isExternal(details) {
  if (details.frameId !== 0 || details.tabId < 0) return false
  if (details.originUrl || details.documentUrl) return false

  const seen = fresh.get(details.tabId)
  if (!seen || seen.hasOpener) return false

  return Date.now() - seen.born < FRESH_MS
}

/**
 * Replace a tab with one in the wanted container, same window and position.
 *
 * Every path ends here because cookieStoreId is settable only at tabs.create
 * time: no API moves a live tab between containers.
 *
 * @param {number} tabId
 * @param {string} url
 * @param {string} cookieStoreId
 */
async function reopen(tabId, url, cookieStoreId) {
  const tab = await browser.tabs.get(tabId)

  await browser.tabs.create({
    url,
    cookieStoreId,
    windowId: tab.windowId,
    index: tab.index,
    active: tab.active
  })

  await browser.tabs.remove(tabId)
}

/**
 * Holds an external navigation and sends the tab to the picker instead.
 *
 * Blocking, and in webRequest rather than tabs.onUpdated, because by the time a
 * tab event arrives the request is already on the wire in whichever container
 * the tab was born in, and a cookie set in the wrong jar cannot be taken back.
 * Synchronous for the same reason the state above is in memory: an async
 * handler would hold every top-level request in the browser for a storage read.
 */
browser.webRequest.onBeforeRequest.addListener(
  (details) => {
    if (!isExternal(details)) return {}

    fresh.delete(details.tabId)

    const host = hostOf(details.url)
    const known = host && assignments[host]

    if (known) {
      reopen(details.tabId, details.url, known)
      return { cancel: true }
    }

    return { redirectUrl: `${PICKER}?url=${encodeURIComponent(details.url)}` }
  },
  { urls: ['http://*/*', 'https://*/*'], types: ['main_frame'] },
  ['blocking']
)

browser.runtime.onMessage.addListener(async (message, sender) => {
  if (message.type !== 'open-in-container') return

  if (message.remember) {
    const host = hostOf(message.url)
    if (host) {
      assignments = { ...assignments, [host]: message.cookieStoreId }
      await browser.storage.local.set({ assignments })
    }
  }

  await reopen(sender.tab.id, message.url, message.cookieStoreId)
})

loadAssignments()
