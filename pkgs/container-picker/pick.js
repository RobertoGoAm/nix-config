'use strict'

const DEFAULT_STORE = 'firefox-default'

const target = new URLSearchParams(location.search).get('url') || ''

/**
 * Hand the URL back to the background page, which remakes this tab in the
 * chosen container. Nothing happens here, because a page cannot set its own
 * tab's cookieStoreId.
 *
 * @param {string} cookieStoreId
 */
function choose(cookieStoreId) {
  browser.runtime.sendMessage({
    type: 'open-in-container',
    url: target,
    cookieStoreId,
    remember: document.getElementById('remember').checked
  })
}

/**
 * @param {string} name
 * @param {string} colour CSS colour for the dot
 * @param {string} cookieStoreId
 * @param {?number} key digit that selects this row, or null for none
 * @returns {HTMLLIElement}
 */
function row(name, colour, cookieStoreId, key) {
  const li = document.createElement('li')
  const button = document.createElement('button')
  button.className = 'pick'

  const dot = document.createElement('span')
  dot.className = 'dot'
  dot.style.background = colour

  const label = document.createElement('span')
  label.className = 'name'
  label.textContent = name

  button.append(dot, label)

  if (key !== null) {
    const kbd = document.createElement('kbd')
    kbd.textContent = String(key)
    button.append(kbd)
  }

  button.addEventListener('click', () => choose(cookieStoreId))
  li.append(button)
  return li
}

async function render() {
  const host = (() => {
    try {
      return new URL(target).hostname
    } catch (_) {
      return target
    }
  })()

  document.getElementById('host').textContent = host
  document.getElementById('url').textContent = target
  document.getElementById('rememberHost').textContent = host
  document.title = `Open ${host} in which container?`

  const identities = await browser.contextualIdentities.query({})
  const list = document.getElementById('list')

  const stores = []
  identities.forEach((identity, i) => {
    stores.push(identity.cookieStoreId)
    list.append(row(identity.name, identity.colorCode, identity.cookieStoreId, i + 1))
  })

  stores.push(DEFAULT_STORE)
  list.append(row('No container', 'transparent', DEFAULT_STORE, 0))

  document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') return choose(DEFAULT_STORE)

    const digit = Number(event.key)
    if (!Number.isInteger(digit)) return

    const picked = digit === 0 ? DEFAULT_STORE : stores[digit - 1]
    if (picked) choose(picked)
  })

  const first = list.querySelector('button.pick')
  if (first) first.focus()
}

render()
