'use strict'

const DEFAULT_STORE = 'firefox-default'

/**
 * Container names and colours by cookieStoreId, so a remembered row can be
 * read as "Work" rather than as the opaque id storage holds.
 *
 * @returns {Promise<Object<string, {name: string, colour: string}>>}
 */
async function containersById() {
  const identities = await browser.contextualIdentities.query({})
  const byId = { [DEFAULT_STORE]: { name: 'No container', colour: 'transparent' } }

  for (const identity of identities) {
    byId[identity.cookieStoreId] = { name: identity.name, colour: identity.colorCode }
  }

  return byId
}

/**
 * @param {string} host
 */
async function forget(host) {
  const stored = await browser.storage.local.get('assignments')
  const assignments = { ...(stored.assignments || {}) }

  delete assignments[host]
  await browser.storage.local.set({ assignments })
  await render()
}

/**
 * @param {string} host
 * @param {{name: string, colour: string}} container
 * @returns {HTMLTableRowElement}
 */
function row(host, container) {
  const tr = document.createElement('tr')

  const site = document.createElement('td')
  site.textContent = host

  const where = document.createElement('td')
  where.className = 'container'
  const dot = document.createElement('span')
  dot.className = 'dot'
  dot.style.background = container.colour
  const name = document.createElement('span')
  name.textContent = container.name
  where.append(dot, name)

  const act = document.createElement('td')
  act.className = 'act'
  const button = document.createElement('button')
  button.textContent = 'Forget'
  button.addEventListener('click', () => forget(host))
  act.append(button)

  tr.append(site, where, act)
  return tr
}

async function render() {
  const [stored, byId] = await Promise.all([
    browser.storage.local.get('assignments'),
    containersById()
  ])

  const assignments = stored.assignments || {}
  const hosts = Object.keys(assignments).sort()

  const rows = document.getElementById('rows')
  rows.replaceChildren()

  for (const host of hosts) {
    const container = byId[assignments[host]] || { name: 'Gone', colour: 'transparent' }
    rows.append(row(host, container))
  }

  document.getElementById('table').hidden = hosts.length === 0
  document.getElementById('empty').hidden = hosts.length > 0
}

render()
