const { describe, expect, test } = require("bun:test")
const fs = require("node:fs")
const model = require("../WorkspaceModel.js")
const protocol38Envelope = require("./fixtures/protocol38-multi-node.json")
const protocol37Envelope = require("./fixtures/protocol37-local.json")

function normalized(envelope = protocol38Envelope) {
  return model.normalizeNodeSnapshot(model.parseEnvelope(envelope, "node.snapshot"))
}

test("compares only valid semantic release versions", () => {
  expect(model.versionIsNewer("v0.18.1", "0.18.0")).toBe(true)
  expect(model.versionIsNewer("0.19.0", "0.18.9")).toBe(true)
  expect(model.versionIsNewer("0.18.0", "0.18.0")).toBe(false)
  expect(model.versionIsNewer("0.17.9", "0.18.0")).toBe(false)
  expect(model.versionIsNewer("main", "0.18.0")).toBe(false)
})

test("keeps guided Node setup feedback visible", () => {
  const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
  expect(panel).toContain(
    "omarchy-launch-tui --app-id=org.omarchy.boomux-node-add boomux __guided-node-add"
  )
})

test("creates coordinated Workspaces without the removed compound command", () => {
  const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
  expect(panel).not.toContain("create-project")
})

describe("CLI envelope normalization", () => {
  test("parses protocol 38 into one task-first multi-placement Workspace", () => {
    const snapshot = normalized()
    const release = snapshot.workspaces.find(workspace => workspace.id === "global-1")
    expect(model.snapshotSupportsGlobalWorkspaces(snapshot.nodes)).toBe(true)
    expect(release.key).toBe("global\u001fglobal-1")
    expect(release.placements).toHaveLength(3)
    expect(release.shells.map(shell => [shell.node_id, shell.id])).toEqual([
      ["node-a", "resource-shared"], ["node-b", "resource-shared"]
    ])
    expect(release.schedules.map(schedule => schedule.workspace_name)).toEqual([
      "release", "release"
    ])
    expect(release.placements[1].default_cwd).toBe("/srv/release")
    const external = snapshot.workspaces.filter(workspace => workspace.is_external)
    expect(external).toHaveLength(2)
    expect(new Set(external.map(workspace => workspace.key)).size).toBe(2)
  })

  test("preserves duplicate inner resource IDs as qualified identities", () => {
    const snapshot = normalized()
    expect(new Set(snapshot.shells.map(shell => shell.key)).size).toBe(2)
    expect(new Set(snapshot.agents.map(agent => agent.key)).size).toBe(2)
    expect(new Set(snapshot.schedules.map(schedule => schedule.key)).size).toBe(2)
    const release = snapshot.workspaces.find(workspace => workspace.is_global)
    expect(new Set(release.launchers.map(launcher => launcher.key)).size).toBe(2)
    const localShell = snapshot.shells.find(shell => shell.node_id === "node-a")
    const remoteShell = snapshot.shells.find(shell => shell.node_id === "node-b")
    const localAgent = snapshot.agents.find(agent => agent.node_id === "node-a")
    const remoteAgent = snapshot.agents.find(agent => agent.node_id === "node-b")
    expect(model.agentMatchesShell(localAgent, localShell)).toBe(true)
    expect(model.agentMatchesShell(remoteAgent, remoteShell)).toBe(true)
    expect(model.agentMatchesShell(localAgent, remoteShell)).toBe(false)
    expect(model.agentMatchesShell(remoteAgent, localShell)).toBe(false)
    expect(model.acknowledgementIdentity(localAgent, 3).agentKey)
      .not.toBe(model.acknowledgementIdentity(remoteAgent, 3).agentKey)
    expect(snapshot.executions[0].schedule_key).toBe("node-b\u001fresource-shared")
  })

  test("rejects a relationship whose qualified Node does not match its projection", () => {
    const envelope = structuredClone(protocol38Envelope)
    envelope.data.nodes[1].remote_projection.agents[0].shell_id.node_id = "node-a"
    expect(() => normalized(envelope)).toThrow("invalid qualified Agent Shell ID")
  })

  test("falls back through the exact protocol 37 owner-local envelope", () => {
    const snapshot = normalized(protocol37Envelope)
    expect(protocol37Envelope.data.workspaces).toEqual([])
    expect(protocol37Envelope.data.external_workspaces).toEqual([])
    expect(model.snapshotSupportsGlobalWorkspaces(snapshot.nodes)).toBe(false)
    expect(snapshot.workspaces).toHaveLength(1)
    expect(snapshot.workspaces[0].key).toBe("local-node\u001flegacy-workspace")
    expect(snapshot.workspaces[0].coordination).toBe("legacy")
    expect(model.workspaceCreationBlockReason(snapshot.workspaces[0], 0)).toBe("")
    expect(model.shellCreateCommand(snapshot.workspaces[0], "shell", "/tmp/legacy",
      "local-node", [])).toEqual([
      "boomux", "shell", "create", "legacy-workspace", "--name", "shell",
      "--cwd", "/tmp/legacy"
    ])
  })

  test("qualifies legacy workspace.inspect resources with the enclosing Node", () => {
    const snapshot = normalized(protocol37Envelope)
    const workspace = snapshot.workspaces[0]
    const node = snapshot.nodes[0]
    const detail = model.normalizeWorkspaceDetail({
      id: "legacy-workspace",
      name: "legacy",
      shells: [{ id: "shared", workspace_id: "legacy-workspace", name: "shell",
        cwd: "/tmp/legacy", owner: "user", status: "running", run: { id: "run" } }],
      launchers: [{ id: "shared", workspace_id: "legacy-workspace", name: "launch",
        cwd: "/tmp/legacy", command: ["printf", "%s", "safe"] }],
      agents: [{ id: "agent", workspace_id: "legacy-workspace", shell_id: "shared",
        run_id: "run", name: "agent", integration: "opencode",
        observation: { revision: 1, state: "working", observed_at_ms: 1 } }],
      schedules: []
    }, workspace, node)
    expect(detail.shells[0].key).toBe("local-node\u001fshared")
    expect(detail.launchers[0].key).toBe("local-node\u001fshared")
    expect(detail.agents[0].shell_key).toBe("local-node\u001fshared")
    expect(detail.shells[0].owner_workspace_id).toBe("legacy-workspace")
    expect(detail.shells[0].placement_state).toBe("active")
    expect(model.agentMatchesShell(detail.agents[0], detail.shells[0])).toBe(true)
    expect(model.resourceActionable(detail.shells[0], true)).toBe(true)
  })
})

describe("qualified commands and action gates", () => {
  test("keeps --node for a local external Workspace that collides with a global ID", () => {
    const snapshot = normalized()
    const global = snapshot.workspaces.find(workspace => workspace.is_global)
    const localExternal = snapshot.workspaces.find(workspace => workspace.is_external
      && workspace.node_id === "node-a")
    expect(global.id).toBe("global-1")
    expect(localExternal.name).toBe("global-1")
    expect(localExternal.node_local).toBe(true)
    expect(model.workspaceCreationBlockReason(localExternal, 2)).toContain("Adopt or link")
    expect(model.workspaceOpenCommand(global)).toEqual([
      "boomux", "workspace", "open", "global-1"
    ])
    expect(model.workspaceOpenCommand(localExternal)).toEqual([
      "boomux", "workspace", "open", "global-1", "--node", "node-a"
    ])
    expect(model.workspaceCloseCommand(global)).toEqual([
      "boomux", "workspace", "close", "global-1"
    ])
  })

  test("keeps unavailable and close-pending placement resources disabled", () => {
    expect(model.resourceActionable({ placement_state: "unavailable" }, true)).toBe(false)
    expect(model.resourceActionable({ placement_state: "close_pending" }, true)).toBe(false)
    expect(model.resourceActionable({ placement_state: "active" }, true)).toBe(true)
    const closing = { is_global: true, closing: true }
    expect(model.workspaceCreationBlockReason(closing, 2)).toContain("closing")
    const envelope = structuredClone(protocol38Envelope)
    envelope.data.workspaces[0].closing = true
    envelope.data.workspaces[0].placements[1].state = "close_pending"
    const remoteShell = normalized(envelope).shells.find(shell => shell.node_id === "node-b")
    const remoteAgent = normalized(envelope).agents.find(agent => agent.node_id === "node-b")
    expect(remoteShell.placement_state).toBe("close_pending")
    expect(model.resourceActionable(remoteShell, true)).toBe(false)
    expect(model.agentOpenTarget(remoteAgent, [remoteShell], true)).toBeNull()
    expect(model.agentOpenTarget(Object.assign({}, remoteAgent, { placement_state: "active" }),
      [Object.assign({}, remoteShell, { placement_state: "active" })], true)).not.toBeNull()
  })

  test("creates coordinated Workspace metadata without assigning a Node or path", () => {
    expect(model.workspaceCreateCommand("release; rm -rf /", "/tmp/$(false)", true))
      .toEqual(["boomux", "workspace", "create", "release; rm -rf /"])
    expect(model.workspaceCreateCommand("legacy", "/tmp/legacy", false)).toEqual([
      "boomux", "workspace", "create", "legacy", "--cwd", "/tmp/legacy"
    ])
    expect(model.defaultCreationNodeId(protocol38Envelope.data.nodes)).toBe("node-a")
    expect(model.defaultCreationNodeId([protocol38Envelope.data.nodes[1]])).toBe("node-b")
    expect(model.defaultCreationNodeId(protocol38Envelope.data.nodes.map(node =>
      Object.assign({}, node, { local: false })))).toBe("")
    expect(model.qualifiedCommand(["boomux", "open"], "shell;$(false)", "node-b", false))
      .toEqual(["boomux", "open", "shell;$(false)", "--node", "node-b"])
  })

  test("qualifies external Shell and Agent creation for local and remote owners", () => {
    const snapshot = normalized()
    const local = snapshot.workspaces.find(workspace => workspace.is_external
      && workspace.node_id === "node-a")
    const remote = snapshot.workspaces.find(workspace => workspace.is_external
      && workspace.node_id === "node-b")
    expect(model.shellCreateCommand(local, "agent", "/tmp/local", "node-a", ["opencode"]))
      .toEqual(["boomux", "shell", "create", "global-1", "--name", "agent",
        "--cwd", "/tmp/local", "--node", "node-a", "--", "opencode"])
    expect(model.shellCreateCommand(remote, "shell", "/tmp/remote", "node-b", []))
      .toEqual(["boomux", "shell", "create", "external-b", "--name", "shell",
        "--cwd", "/tmp/remote", "--node", "node-b"])
  })
})

describe("request identity", () => {
  test("retains the selected exact run until its focused refresh replaces it", () => {
    const current = [
      { id: "exact-local", schedule_key: "node-a\u001fschedule" },
      { id: "old-remote", schedule_key: "node-b\u001fother" }
    ]
    const snapshot = [
      { id: "stale-selected", schedule_key: "node-a\u001fschedule" },
      { id: "fresh-remote", schedule_key: "node-b\u001fother" }
    ]

    expect(model.mergeSnapshotExecutions(current, snapshot,
      "node-a\u001fschedule")).toEqual([
      { id: "fresh-remote", schedule_key: "node-b\u001fother" },
      { id: "exact-local", schedule_key: "node-a\u001fschedule" }
    ])
    expect(model.mergeSnapshotExecutions(current, snapshot, "")).toBe(snapshot)
  })

  test("queues project discovery for the latest rapidly selected Node", () => {
    const requested = model.projectDiscoveryIdentity("node-b")
    const active = model.projectDiscoveryIdentity("node-a")
    expect(model.projectDiscoveryResponseCurrent(requested, active, "node-b")).toBe(false)
    expect(model.projectDiscoveryCommand(protocol38Envelope.data.nodes[1])).toEqual([
      "boomux", "project", "list", "--json", "--node", "node-b"
    ])
    expect(model.projectDiscoveryResponseCurrent(requested, requested, "node-b")).toBe(true)
  })

  test("keys suggestions by global Workspace, Node, and equal owner Workspace ID", () => {
    const local = model.suggestionIdentity("global\u001fglobal-1", "node-a", "owner-shared")
    const remote = model.suggestionIdentity("global\u001fglobal-1", "node-b", "owner-shared")
    expect(local.key).not.toBe(remote.key)
    expect(model.suggestionResponseMatches({ node_id: "node-a", workspace_id: "owner-shared" },
      local, true, true)).toBe(true)
    expect(model.suggestionResponseMatches({ workspace_id: "owner-shared" },
      local, true, true)).toBe(false)
    expect(model.suggestionResponseMatches({ node_id: "node-b", workspace_id: "owner-shared" },
      remote, false)).toBe(true)
    expect(model.suggestionResponseMatches({ node_id: "node-a", workspace_id: "owner-shared" },
      remote, false)).toBe(false)
  })

  test("resolves a deferred Agent Shell once by exact Workspace and Node", () => {
    const snapshot = normalized()
    const pending = { workspaceKey: "global\u001fglobal-1", nodeId: "node-b",
      name: "tests", armed: true }
    const resolved = model.resolvePendingShell(pending, snapshot.workspaces)
    expect(resolved.identity).toEqual({
      workspaceKey: "global\u001fglobal-1",
      nodeId: "node-b",
      shellId: "resource-shared",
      runId: "run-shared"
    })
    expect(model.resolvePendingShell(null, snapshot.workspaces)).toBeNull()
    expect(model.resolvePendingShell(Object.assign({}, pending, { nodeId: "node-a" }),
      snapshot.workspaces)).toBeNull()
    const consumed = model.consumePendingShell(pending, snapshot.workspaces)
    expect(consumed.pending).toBeNull()
    expect(model.consumePendingShell(consumed.pending, snapshot.workspaces).resolved).toBeNull()
  })
})
