import { assert, mockHost, mountWorker, test } from 'orca/testing'
import { AgentQueue, start, statusText, type AgentKeys, type AgentStatusEvent } from './worker'

const status = (paneKey: string, state: AgentStatusEvent['state'], receivedAt: number, extra: Partial<AgentStatusEvent> = {}) => ({
  workspaceId: `ws-${paneKey}`,
  paneKey,
  terminalId: `term-${paneKey}`,
  state,
  receivedAt,
  ...extra
})

const newHost = () =>
  mockHost({
    capabilities: ['agent:read', 'workspace:write'],
    results: { 'workspace.open': { opened: true }, 'commands.run': { ran: true }, 'statusBar.update': { ok: true } }
  })

const visit = (queue: AgentQueue, presses: number) =>
  Array.from({ length: presses }, () => queue.next()?.paneKey ?? null)

test('visits approval prompts first, then idle agents, oldest first', () => {
  const queue = new AgentQueue()
  queue.update(status('done-old', 'done', 1))
  queue.update(status('idle', 'waiting', 2))
  queue.update(status('asking-new', 'blocked', 4))
  queue.update(status('asking-old', 'blocked', 3))
  queue.update(status('busy', 'working', 5))
  assert.deepEqual(visit(queue, 4), ['asking-old', 'asking-new', 'idle', 'done-old'])
})

test('moves on when nothing was answered, and wraps without repeating the last one', () => {
  const queue = new AgentQueue()
  queue.update(status('a', 'blocked', 1))
  queue.update(status('b', 'waiting', 2))
  assert.deepEqual(visit(queue, 3), ['a', 'b', 'a'])
})

test('a new request comes next, and an answered one leaves the queue', () => {
  const queue = new AgentQueue()
  queue.update(status('a', 'waiting', 1))
  queue.update(status('b', 'waiting', 2))
  assert.equal(queue.next()?.paneKey, 'a')
  queue.update(status('c', 'blocked', 3))
  assert.equal(queue.next()?.paneKey, 'c')
  queue.update(status('c', 'working', 4))
  assert.equal(queue.next()?.paneKey, 'b')
  assert.deepEqual(queue.counts(), { blocked: 0, ready: 2 })
})

test('the same state reported again keeps its place', () => {
  const queue = new AgentQueue()
  queue.update(status('a', 'blocked', 1))
  queue.update(status('b', 'blocked', 2))
  queue.update(status('a', 'blocked', 9))
  assert.equal(queue.next()?.paneKey, 'a')
})

test('the status bar text names what is waiting', () => {
  assert.equal(statusText({ blocked: 2, ready: 0 }), '2 asking')
  assert.equal(statusText({ blocked: 1, ready: 3 }), '1 asking · 3 ready')
  assert.equal(statusText({ blocked: 0, ready: 2 }), '2 ready')
})

test('next-agent switches to the terminal, falls back to the workspace, and drops what it cannot show', async () => {
  const host = newHost()
  const switched: string[] = []
  let keys: AgentKeys | undefined
  const worker = await mountWorker(
    { default: (orca) => void (keys = start(orca, { switchTerminal: async (id) => (switched.push(id), id !== 'term-gone') })) },
    { host, events: ['agent.status.changed'], commands: ['next-agent', 'focus-mode'] }
  )
  await worker.emit('agent.status.changed', status('gone', 'blocked', 1, { workspaceId: null }))
  await worker.emit('agent.status.changed', status('nonterm', 'blocked', 2, { terminalId: undefined }))
  await worker.emit('agent.status.changed', status('here', 'waiting', 3))

  await keys?.nextAgent()
  assert.deepEqual(switched, ['term-gone'])
  assert.deepEqual(host.callsOf('workspace.open'), [{ workspaceId: 'ws-nonterm' }])

  await keys?.nextAgent()
  assert.deepEqual(switched, ['term-gone', 'term-here'])

  const updates = host.callsOf('statusBar.update')
  assert.deepEqual(updates.at(-1), { id: 'queue', visible: true, text: '1 asking · 1 ready', tone: 'warning' })
  await worker.deactivate()
})

test('the next-agent command returns before a slow switch finishes, so Orca never falls back to its own action', async () => {
  const host = newHost()
  const switched: string[] = []
  const worker = await mountWorker(
    { default: (orca) => void start(orca, { switchTerminal: (id) => (switched.push(id), new Promise<boolean>(() => {})) }) },
    { host, events: ['agent.status.changed'], commands: ['next-agent', 'focus-mode'] }
  )
  await worker.emit('agent.status.changed', status('slow', 'blocked', 1))
  await worker.command('next-agent')
  assert.deepEqual(switched, ['term-slow'])
  await worker.deactivate()
})

test('focus-mode toggles both sidebars', async () => {
  const host = newHost()
  const worker = await mountWorker(
    { default: (orca) => void start(orca, { switchTerminal: async () => true }) },
    { host, events: ['agent.status.changed'], commands: ['next-agent', 'focus-mode'] }
  )
  await worker.command('focus-mode')
  assert.deepEqual(
    host.callsOf('commands.run'),
    [{ action: 'sidebar.left.toggle' }, { action: 'sidebar.right.toggle' }]
  )
  await worker.deactivate()
})
