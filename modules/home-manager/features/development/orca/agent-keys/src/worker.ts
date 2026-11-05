import type { OrcaWorkerApi } from 'orca/worker'
import { execFile } from 'node:child_process'

export type AgentState = 'working' | 'blocked' | 'waiting' | 'done'

export interface AgentStatusEvent {
  workspaceId: string | null
  paneKey: string
  terminalId?: string
  title?: string
  state: AgentState
  receivedAt: number
}

export interface PendingAgent {
  paneKey: string
  workspaceId: string | null
  terminalId?: string
  title?: string
  state: Exclude<AgentState, 'working'>
  since: number
}

/** Most urgent first: `blocked` is an approval prompt or a question, `waiting` is idle at its prompt, `done` has finished. */
const RANK: Record<PendingAgent['state'], number> = { blocked: 0, waiting: 1, done: 2 }

export function byUrgency(agents: Iterable<PendingAgent>): PendingAgent[] {
  return [...agents].sort((a, b) => RANK[a.state] - RANK[b.state] || a.since - b.since)
}

/**
 * Agents that are not working, visited most urgent first. Each `next()` returns one not yet
 * visited this round, so repeated presses move on even when nothing was answered, and a new
 * request comes next rather than at the back.
 */
export class AgentQueue {
  private readonly pending = new Map<string, PendingAgent>()
  private readonly visited = new Set<string>()
  private last: string | null = null

  update(event: AgentStatusEvent): void {
    if (event.state === 'working') {
      this.drop(event.paneKey)
      return
    }
    const known = this.pending.get(event.paneKey)
    if (known && known.state === event.state) {
      known.terminalId ??= event.terminalId
      known.workspaceId ??= event.workspaceId
      known.title = event.title ?? known.title
      return
    }
    this.pending.set(event.paneKey, {
      paneKey: event.paneKey,
      workspaceId: event.workspaceId,
      terminalId: event.terminalId,
      title: event.title,
      state: event.state,
      since: event.receivedAt
    })
    this.visited.delete(event.paneKey)
  }

  drop(paneKey: string): void {
    this.pending.delete(paneKey)
    this.visited.delete(paneKey)
  }

  next(): PendingAgent | undefined {
    const queue = byUrgency(this.pending.values())
    if (queue.length === 0) {
      return undefined
    }
    let pick = queue.find((agent) => !this.visited.has(agent.paneKey))
    if (!pick) {
      this.visited.clear()
      pick = queue.find((agent) => agent.paneKey !== this.last) ?? queue[0]
    }
    this.visited.add(pick.paneKey)
    this.last = pick.paneKey
    return pick
  }

  counts(): { blocked: number; ready: number } {
    let blocked = 0
    for (const agent of this.pending.values()) {
      if (agent.state === 'blocked') {
        blocked += 1
      }
    }
    return { blocked, ready: this.pending.size - blocked }
  }
}

export function statusText({ blocked, ready }: { blocked: number; ready: number }): string {
  if (blocked === 0) {
    return `${ready} ready`
  }
  return ready === 0 ? `${blocked} asking` : `${blocked} asking · ${ready} ready`
}

/** The plugin API can show a workspace but not a tab inside it; `orca terminal switch` can. */
const ORCA_CLI = process.env.ORCA_CLI_COMMAND || '/Applications/Orca.app/Contents/Resources/bin/orca'

export function switchWithCli(terminalId: string): Promise<boolean> {
  return new Promise((resolve) => {
    execFile(ORCA_CLI, ['terminal', 'switch', '--terminal', terminalId, '--json'], { timeout: 5000 }, (error) =>
      resolve(!error)
    )
  })
}

export interface Deps {
  switchTerminal: (terminalId: string) => Promise<boolean>
}

export interface AgentKeys {
  queue: AgentQueue
  nextAgent: () => Promise<void>
  focusMode: () => Promise<void>
}

/**
 * `next-agent` stands in for Orca's Workspace Board action, whose key Orca catches even in the chat
 * box; Orca runs the Board itself if a stand-in has not returned within 2 s, so the command returns
 * at once and the jump finishes after. A closed pane sends no event, so an agent that can no longer
 * be shown is dropped and the next one tried.
 */
export function start(orca: OrcaWorkerApi, deps: Deps): AgentKeys {
  const queue = new AgentQueue()

  const render = async (): Promise<void> => {
    const counts = queue.counts()
    const visible = counts.blocked + counts.ready > 0
    try {
      await orca.host.call('statusBar.update', {
        id: 'queue',
        visible,
        ...(visible ? { text: statusText(counts), tone: counts.blocked > 0 ? 'warning' : 'neutral' } : {})
      })
    } catch (error) {
      orca.log(`status bar: ${String(error)}`)
    }
  }

  const show = async (agent: PendingAgent): Promise<boolean> => {
    if (agent.terminalId) {
      if (await deps.switchTerminal(agent.terminalId)) {
        return true
      }
      orca.log(`terminal switch ${agent.terminalId} failed; showing its workspace instead`)
    }
    if (agent.workspaceId) {
      try {
        await orca.host.call('workspace.open', { workspaceId: agent.workspaceId })
        return true
      } catch (error) {
        orca.log(`workspace.open ${agent.workspaceId}: ${String(error)}`)
      }
    }
    return false
  }

  orca.events.on('agent.status.changed', (event: AgentStatusEvent) => {
    queue.update(event)
    void render()
  })

  const nextAgent = async (): Promise<void> => {
    for (let agent = queue.next(); agent; agent = queue.next()) {
      if (await show(agent)) {
        break
      }
      queue.drop(agent.paneKey)
    }
    await render()
  }

  const focusMode = async (): Promise<void> => {
    await orca.host.call('commands.run', { action: 'sidebar.left.toggle' })
    await orca.host.call('commands.run', { action: 'sidebar.right.toggle' })
  }

  orca.commands.register('next-agent', () => {
    void nextAgent()
  })
  orca.commands.register('focus-mode', focusMode)

  void render()
  return { queue, nextAgent, focusMode }
}

export default function activate(orca: OrcaWorkerApi): void {
  start(orca, { switchTerminal: switchWithCli })
}
