const { test, expect } = require("bun:test")
const fs = require("node:fs")
const vm = require("node:vm")
const model = require("../WorkspaceModel.js")
const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")

function panelFunction(name) {
  const match = panel.match(new RegExp("^  function " + name
    + "\\([^\\n]*\\) \\{[\\s\\S]*?^  \\}", "m"))
  if (!match) throw new Error("Missing Panel function: " + name)
  return match[0]
}

function fixture(nodeId = "remote") {
  const shell = { id: "same-shell", key: model.resourceKey(nodeId, "same-shell"),
    node_id: nodeId, owner: "user", run: { id: "run" }, status: "running" }
  const agent = { id: "agent", key: model.resourceKey(nodeId, "agent"), node_id: nodeId,
    shell_id: shell.id, run_id: "run", ended_at_ms: null, started_at_ms: 1,
    observation: { state: "blocked", observed_at_ms: 10 },
    attention: { reason: "blocked", observation: { revision: 3 } } }
  return { shell, agent }
}

function harness(shells, agents) {
  const acknowledgements = [], failures = []
  const state = { WorkspaceModel: model, shells, agents,
    panel: { exitKeyboardMode() {} }, openProcess: { running: false },
    pendingOpenAgent: null, pendingOpenKey: "", pendingOpenRunKey: "", actionMessage: "",
    resourceKey: model.resourceKey, resourceIsActionable: shell => !shell.node_stale,
    nodeFor: nodeId => ({ node_id: nodeId, local: nodeId === "local" }),
    workspaceForKey: () => null, cliFeatures: [], clearCompletedAgent() {},
    acknowledgeAgent(agent) {
      acknowledgements.push(model.acknowledgementIdentity(agent, agent.attention.observation.revision))
    },
    showActionFailure(...args) { failures.push(args) }
  }
  // Supports both the scan and snapshot-index implementations of the handlers.
  if (model.indexShells) {
    state.shellsByIdentity = model.indexShells(shells)
    state.agentsByRun = model.indexCurrentAgents(agents, state.shellsByIdentity)
  }
  state.root = state
  vm.createContext(state)
  vm.runInContext(["openShell", "openWorkspaceTreeItem", "openWorkspaceItem"]
    .map(panelFunction).join("\n"), state)
  const process = panel.slice(panel.indexOf("    id: openProcess"),
    panel.indexOf("    id: acknowledgeProcess"))
  const exit = process.match(/onExited: (function\(exitCode\) \{[\s\S]*?\n    \})/)
  if (!exit) throw new Error("Missing terminal open exit handler")
  state.exit = vm.runInContext("(" + exit[1] + ")", state)
  return { state, acknowledgements, failures }
}

test("tree mouse and keyboard activation share the current Agent open path", () => {
  expect(panel).toContain("root.openWorkspaceTreeItem(modelData)")
  expect(panel).toContain("openWorkspaceTreeItem(cursorWorkspaceItem)")
  const { shell, agent } = fixture()
  for (const handler of ["openWorkspaceTreeItem", "openWorkspaceItem"]) {
    const { state, acknowledgements } = harness([shell], [agent])
    state[handler]({ kind: "agent", shell })
    expect(state.openProcess.running).toBe(true)
    expect(Array.from(state.openProcess.command))
      .toEqual(["boomux", "open", shell.id, "--node", shell.node_id, "--takeover"])
    expect(acknowledgements).toHaveLength(0)
    state.exit(0)
    expect(acknowledgements).toEqual([model.acknowledgementIdentity(agent, 3)])
  }
})

test("retained tree rows resolve current qualified Shell, run, Agent and attention revision", () => {
  const { shell, agent } = fixture()
  const oldItem = { kind: "agent", shell, agent }
  const restarted = { ...shell, run: { id: "new-run" } }
  const current = { ...agent, id: "new-agent", key: "remote\u001fnew-agent", run_id: "new-run",
    observation: { state: "blocked", observed_at_ms: 20 },
    attention: { reason: "blocked", observation: { revision: 9 } } }
  const wrongNode = fixture("local")
  const newerWrongRun = { ...agent, id: "wrong-run", run_id: "other-run",
    observation: { state: "blocked", observed_at_ms: 999 } }
  const { state, acknowledgements } = harness([wrongNode.shell, restarted],
    [wrongNode.agent, agent, newerWrongRun, current])
  state.openWorkspaceTreeItem(oldItem)
  expect(state.pendingOpenRunKey).toBe(model.resourceKey("remote", "new-run"))
  expect(state.pendingOpenAgent).toBe(current)
  state.exit(0)
  expect(acknowledgements).toEqual([model.acknowledgementIdentity(current, 9)])
})

test("tree open failure, missing Shell and unavailable Shell never acknowledge", () => {
  const { shell, agent } = fixture()
  const item = { kind: "agent", shell }
  const failed = harness([shell], [agent])
  failed.state.openWorkspaceTreeItem(item)
  failed.state.exit(1)
  expect(failed.acknowledgements).toHaveLength(0)
  expect(failed.failures).toHaveLength(1)
  for (const shells of [[], [{ ...shell, node_stale: true }], [fixture("local").shell]]) {
    const { state, acknowledgements } = harness(shells, [agent])
    state.openWorkspaceTreeItem(item)
    expect(state.openProcess.running).toBe(false)
    expect(acknowledgements).toHaveLength(0)
  }
})

test("latest tree Agent uses deterministic lifecycle ordering and excludes ended runs", () => {
  const { shell, agent } = fixture()
  const variants = [
    agent,
    { ...agent, id: "later-start", started_at_ms: 2 },
    { ...agent, id: "z-tie", started_at_ms: 2 },
    { ...agent, id: "ended", ended_at_ms: 30, observation: { state: "blocked", observed_at_ms: 99 } },
    { ...agent, id: "done", observation: { state: "done", observed_at_ms: 99 } },
    { ...agent, id: "inactive", observation: { state: "inactive", observed_at_ms: 99 } }
  ]
  for (const candidates of [variants, variants.slice().reverse()])
    expect(model.latestAgentForShell(shell, candidates).id).toBe("z-tie")
  expect(model.latestAgentForShell({ ...shell, owner: { kind: "schedule" } }, variants)).toBeNull()
  expect(model.latestAgentForShell({ ...shell, run: { id: "other" } }, variants)).toBeNull()
  const { state, acknowledgements } = harness([shell], variants.slice(3))
  state.openWorkspaceTreeItem({ kind: "agent", shell })
  expect(state.openProcess.running).toBe(true)
  expect(state.pendingOpenAgent).toBeNull()
  state.exit(0)
  expect(acknowledgements).toHaveLength(0)
})
