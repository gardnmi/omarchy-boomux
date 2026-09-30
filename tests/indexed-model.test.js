const { test, expect } = require("bun:test")
const model = require("../WorkspaceModel.js")
const { referenceViews } = require("../benchmarks/view-reference.js")
const { fixture, snapshotViews, compactViews } = require("../benchmarks/workspace-model.js")

function shell(nodeId, id, run = "run", owner = "user") {
  return { id, node_id: nodeId, key: model.resourceKey(nodeId, id), name: id,
    run: { id: run }, owner, status: "running" }
}

function agent(nodeId, shellId, id, extra = {}) {
  return { id, node_id: nodeId, key: model.resourceKey(nodeId, id), shell_id: shellId,
    run_id: "run", ended_at_ms: null, started_at_ms: 1,
    observation: { state: "idle", observed_at_ms: 10 }, ...extra }
}

function snapshot(shells, agents) {
  return { nodes: [], shells, agents,
    workspaces: [{ key: "workspace", id: "workspace", name: "workspace", shells, agents,
      launchers: [{ id: "launcher", node_id: "node", name: "tool", command: ["tool", "a b"] }] }] }
}

function expectParity(data, completed = {}) {
  expect(compactViews(snapshotViews(data, completed)))
    .toEqual(compactViews(referenceViews(data, completed)))
}

test("indexes exact structural Node, Shell and run identities including opaque IDs", () => {
  const nodes = [{ node_id: "__proto__" }, { node_id: "constructor" }, { node_id: "node" }]
  const nodeIndex = model.indexNodes(nodes.concat({ node_id: "node", stale: true }))
  expect(nodeIndex.__proto__).toBe(nodes[0])
  expect(nodeIndex.constructor).toBe(nodes[1])
  expect(nodeIndex.node).toBe(nodes[2])
  const shells = [shell("a\u001fb", "c"), shell("a", "b\u001fc"),
    shell("__proto__", "constructor"), shell("other", "c")]
  const shellsByIdentity = model.indexShells(shells.concat({ ...shells[0], name: "duplicate" }))
  for (const entry of shells)
    expect(model.indexedShell(shellsByIdentity, entry.node_id, entry.id)).toBe(entry)
  expect(model.indexedShell(shellsByIdentity, "missing", "c")).toBeNull()
  const agents = shells.map((entry, i) => agent(entry.node_id, entry.id, "agent-" + i))
  const byRun = model.indexCurrentAgents(agents, shellsByIdentity)
  for (let i = 0; i < shells.length; i++)
    expect(model.latestShellAgent(shells[i], byRun)).toBe(agents[i])
})

test("preserves private ownership, retained historical attention, lifecycle and tie ordering", () => {
  const shells = [shell("a", "shared"), shell("b", "shared"),
    shell("a", "private-string", "run", "schedule"),
    shell("a", "private-object", "run", { kind: "schedule" })]
  const attention = { reason: "completed", observation: { revision: 7, observed_at_ms: 80 } }
  const agents = [
    agent("a", "shared", "original"),
    agent("a", "shared", "z-tie"),
    agent("a", "shared", "earlier-start", { started_at_ms: 0 }),
    agent("b", "shared", "same-other-node"),
    agent("a", "shared", "old-attention", { run_id: "old", attention,
      observation: { state: "done", observed_at_ms: 60 } }),
    agent("a", "removed", "removed-attention", { attention }),
    agent("a", "removed", "removed-no-attention"),
    agent("a", "private-string", "private-string", { attention }),
    agent("a", "private-object", "private-object", { attention }),
    agent("a", "shared", "ended", { ended_at_ms: 50,
      observation: { state: "idle", observed_at_ms: 50 } }),
    agent("a", "shared", "inactive", { observation: { state: "inactive", observed_at_ms: 100 } }),
    agent("a", "shared", "done", { observation: { state: "done", observed_at_ms: 100 } })
  ]
  const completed = Object.fromEntries(agents.map(entry => [entry.key, true]))
  for (const candidates of [agents, agents.slice().reverse()]) {
    const data = snapshot(shells, candidates)
    expectParity(data, completed)
    const byShell = model.indexShells(shells)
    const byRun = model.indexCurrentAgents(candidates, byShell)
    expect(model.latestShellAgent(shells[0], byRun).id).toBe("z-tie")
    expect(model.visibleAgents(candidates, byShell, byRun).map(entry => entry.id))
      .toEqual(["old-attention", "removed-attention", "ended", "same-other-node"])
  }
})

test("fresh index replacements drop removed resources and never reuse prior-run Agents", () => {
  const originalShell = shell("node", "shell")
  const originalAgent = agent("node", "shell", "agent")
  const replacement = { ...originalShell, run: { id: "new-run" } }
  const current = { ...originalAgent, id: "replacement", key: "node\u001freplacement", run_id: "new-run" }
  const byShell = model.indexShells([replacement])
  const byRun = model.indexCurrentAgents([originalAgent, current], byShell)
  expect(model.indexedAgentIsCurrent(originalAgent, byShell)).toBe(false)
  expect(model.indexedAgentIsCurrent(current, byShell)).toBe(true)
  expect(model.latestShellAgent(replacement, byRun)).toBe(current)
  expect(model.latestShellAgent(originalShell, byRun)).toBeNull()
  const emptyShells = model.indexShells([])
  expect(model.indexedShell(emptyShells, "node", "shell")).toBeNull()
  expect(model.visibleAgents([originalAgent], emptyShells,
    model.indexCurrentAgents([originalAgent], emptyShells))).toEqual([])
})

test("normalized legacy and federated fixtures preserve reference snapshot-to-view output", () => {
  for (const name of ["protocol37-local", "protocol38-multi-node"])
    expectParity(model.normalizeNodeSnapshot(require("./fixtures/" + name + ".json").data))
  for (const configuration of [[2, 10, 2], [4, 25, 4], [4, 1, 100]])
    expectParity(model.normalizeNodeSnapshot(fixture(...configuration)))
})

test("seeded mixed-lifecycle snapshot derivations match the pre-index reference", () => {
  let seed = 20260930
  const random = limit => {
    seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0
    return seed % limit
  }
  for (let iteration = 0; iteration < 80; iteration++) {
    const shells = Array.from({ length: 12 }, (_, i) => shell("node-" + i % 3,
      "shell-" + Math.floor(i / 3), "run-" + random(3),
      random(5) === 0 ? (random(2) ? "schedule" : { kind: "schedule" }) : "user"))
    const agents = Array.from({ length: 50 }, (_, i) => {
      const owner = shells[random(shells.length)]
      const state = ["idle", "working", "blocked", "done", "inactive"][random(5)]
      return agent(owner.node_id, random(10) ? owner.id : "removed", "agent-" + i, {
        run_id: "run-" + random(3), started_at_ms: random(4), ended_at_ms: random(5) ? null : 12,
        observation: { state, observed_at_ms: random(4) },
        attention: random(4) ? null : { reason: random(2) ? "blocked" : "completed",
          observation: { revision: random(3), observed_at_ms: random(100) } }
      })
    })
    const completed = Object.fromEntries(agents.filter(() => random(2)).map(entry => [entry.key, true]))
    expectParity(snapshot(shells, agents), completed)
  }
})

test("single-Workspace projection and relationship indexing read linearly many records", () => {
  function visits(size) {
    let reads = 0
    const shells = Array.from({ length: size }, (_, i) => shell("node", "shell-" + i))
    const agents = shells.map((entry, i) => {
      const value = agent("node", entry.id, "agent-" + i)
      const observation = value.observation
      Object.defineProperty(value, "observation", { enumerable: true,
        get() { reads++; return observation } })
      return value
    })
    const data = snapshot(shells, agents)
    const result = snapshotViews(data, {})
    expect(result.visible).toHaveLength(size)
    expect(result.items[0]).toHaveLength(size + 1)
    return reads
  }
  const small = visits(200), large = visits(400)
  expect(large).toBeLessThan(small * 2.5)
  expect(large).toBeLessThan(400 * 60)
})

test("tree signature remains stable for lifecycle updates and changes for structural fields", () => {
  const data = snapshot([shell("node", "shell")], [agent("node", "shell", "agent")])
  const before = model.workspaceTreeModelSignature(data.workspaces)
  data.agents[0].attention = { reason: "blocked", observation: { revision: 10 } }
  data.agents[0].observation.observed_at_ms = 100
  expect(model.workspaceTreeModelSignature(data.workspaces)).toBe(before)
  data.shells[0].status = { exited: 2 }
  expect(model.workspaceTreeModelSignature(data.workspaces)).not.toBe(before)
  data.shells[0].status = "running"
  data.agents[0].ended_at_ms = 101
  expect(model.workspaceTreeModelSignature(data.workspaces)).not.toBe(before)
})


test("legacy local list preserves qualified run IDs in indexed Agent views", () => {
  const fs = require("node:fs")
  const vm = require("node:vm")
  const source = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
  const start = source.indexOf("  function parseShells(")
  const end = source.indexOf("\n  function ", start + 1)
  const ctx = vm.createContext({ shells: [], online: false, console,
    resourceKey: model.resourceKey, parseEnvelope: model.parseEnvelope })
  vm.runInContext(source.slice(start, end), ctx)
  ctx.parseShells(JSON.stringify({ schema: "boomux.cli/v1", command: "list", data: {
    shells: [{ id: "shell", workspace_id: "workspace", owner: "user",
      run: { id: { node_id: "local", inner_id: "run" } } }]
  } }))
  expect(ctx.online).toBe(true)
  const current = agent("local", "shell", "current")
  const historical = { ...current, id: "historical", key: "local\u001fhistorical", run_id: "old" }
  const byShell = model.indexShells(ctx.shells)
  const byRun = model.indexCurrentAgents([historical, current], byShell)
  expect(model.indexedAgentIsCurrent(current, byShell)).toBe(true)
  expect(model.indexedAgentIsCurrent(historical, byShell)).toBe(false)
  expect(model.visibleAgents([historical, current], byShell, byRun)).toEqual([current])
  expect(model.latestShellAgent(ctx.shells[0], byRun)).toBe(current)
  ctx.shells[0].run.id.node_id = "wrong-node"
  const wrongOwnerShells = model.indexShells(ctx.shells)
  const wrongOwnerRuns = model.indexCurrentAgents([current], wrongOwnerShells)
  expect(model.indexedAgentIsCurrent(current, wrongOwnerShells)).toBe(false)
  expect(model.visibleAgents([current], wrongOwnerShells, wrongOwnerRuns)).toEqual([])
  expect(model.latestShellAgent(ctx.shells[0], wrongOwnerRuns)).toBeNull()
})
