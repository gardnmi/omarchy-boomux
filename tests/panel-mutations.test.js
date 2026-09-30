const { describe, test } = require("bun:test")
const assert = require("node:assert/strict")
const fs = require("node:fs")
const vm = require("node:vm")
const model = require("../WorkspaceModel.js")
const compatibility = require("../compatibility.json")
const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")

// Execute the actual QML JavaScript and process exit callbacks. Process stubs
// only record argv; no test starts Boomux, a terminal, or a real daemon.
function sourceFunction(name) {
  const start = panel.indexOf(`  function ${name}(`)
  assert.notEqual(start, -1, `missing Panel function ${name}`)
  const end = panel.indexOf("\n  }", start)
  assert.notEqual(end, -1)
  return panel.slice(start, end + 4)
}

function sourceExit(id, name) {
  const process = panel.indexOf(`    id: ${id}\n`)
  assert.notEqual(process, -1, `missing Process ${id}`)
  const start = panel.indexOf("    onExited: function(exitCode) {", process)
  const end = panel.indexOf("\n    }\n  }", start)
  assert.notEqual(start, -1)
  assert.notEqual(end, -1)
  return panel.slice(start, end + 6)
    .replace("onExited: function(exitCode)", `function ${name}(exitCode)`)
}

function processStub() {
  let running = false
  return {
    command: [], launches: [],
    get running() { return running },
    set running(value) {
      if (value && !running) this.launches.push(Array.from(this.command))
      running = value
    }
  }
}

function context(functions, state = {}, exits = {}) {
  const s = Object.assign({ WorkspaceModel: model, console, queued: [], failures: [],
    notices: [], opened: true, actionMessage: "", refreshes: 0 }, state)
  for (const [key, value] of Object.entries(state))
    if (typeof value === "function") s[key] = value.bind(s)
  s.root = s
  s.Qt = { callLater(callback) { s.queued.push(callback) } }
  s.showActionFailure = (...args) => s.failures.push(args)
  s.showNotice = (...args) => s.notices.push(args)
  s.currentNoticeScreen = () => null
  s.refresh = () => s.refreshes++
  s.processError = (raw, fallback) => raw || fallback
  s.flush = () => {
    let count = 0
    while (s.queued.length) {
      assert.ok(count++ < 20, "unexpected callback replay loop")
      s.queued.shift()()
    }
  }
  const ctx = vm.createContext(s)
  vm.runInContext(functions.map(sourceFunction).concat(
    Object.entries(exits).map(([id, name]) => sourceExit(id, name))).join("\n"), ctx)
  return ctx
}

function offlineState() {
  return { pollEpoch: 0, eventProcess: processStub(), daemonStartProcess: processStub(),
    workspaceCreateRequested: null, pendingDefaultCwd: null, pendingWorkspaceCreation: null,
    confirmationTarget: null, clearSessionPrivacy() {}, invalidateProjectDiscovery() {} }
}

function node(id, local = false) {
  return { node_id: id, local, current: true, stale: false, health: "online",
    registration_revision: local ? null : 1,
    observed_capabilities: ["persistent_agent_attention"] }
}

function agent(nodeId = "remote-node", revision = 7) {
  return { node_id: nodeId, id: "shared-id", key: model.resourceKey(nodeId, "shared-id"),
    attention: { observation: { revision } } }
}

function ackContext() {
  return context(["nodeFor", "nodeIsActionable", "attentionRevision", "agentCanAcknowledge",
    "acknowledgeAgent", "startNextAcknowledgement", "parseEnvelope", "setOffline"],
  Object.assign(offlineState(), {
    nodes: [node("local-node", true), node("remote-node")], online: true, backendReady: true,
    cliFeatures: ["persistent_agent_attention"], attentionAcknowledgementSupported: true,
    federationAvailable: true, acknowledgeQueue: [], activeAcknowledgement: null,
    acknowledgeProcess: processStub(), acknowledgeStdout: { text: "" },
    acknowledgeStderr: { text: "" }
  }), { acknowledgeProcess: "ackExited" })
}

function ackResult(nodeId, revision = 7) {
  const result = { changed: true,
    agent: { id: "shared-id", attention: null, observation: { revision } } }
  if (nodeId) result.node_id = nodeId
  return result
}

function envelope(command, data) {
  return JSON.stringify({ schema: "boomux.cli/v1", command, data })
}

describe("queued attention acknowledgments", () => {
  for (const transition of ["stale", "removed", "capability", "cli-capability",
    "cli-command", "offline", "role", "registration", "federation"]) {
    test(`consume ${transition} owner requests without local fallback or replay`, () => {
      const s = ackContext()
      s.acknowledgeProcess.running = true
      s.acknowledgeProcess.launches = []
      s.acknowledgeAgent(agent(), true, false)
      assert.equal(s.acknowledgeQueue.length, 1)
      const owner = s.nodes[1]
      if (transition === "stale") Object.assign(owner, { current: false, stale: true })
      if (transition === "removed") s.nodes.pop()
      if (transition === "capability") owner.observed_capabilities = []
      if (transition === "cli-capability") s.cliFeatures = []
      if (transition === "cli-command") s.attentionAcknowledgementSupported = false
      if (transition === "offline") s.online = false
      if (transition === "role") owner.local = true
      if (transition === "registration") owner.registration_revision++
      if (transition === "federation") s.federationAvailable = false
      s.acknowledgeProcess.running = false
      s.startNextAcknowledgement()
      assert.equal(s.acknowledgeProcess.launches.length, 0)
      assert.equal(s.acknowledgeQueue.length, 0)
      assert.equal(s.activeAcknowledgement, null)
      assert.equal(s.failures.length, 1)
      s.nodes = [node("local-node", true), node("remote-node")]
      s.cliFeatures = ["persistent_agent_attention"]
      s.online = s.attentionAcknowledgementSupported = s.federationAvailable = true
      s.startNextAcknowledgement()
      assert.equal(s.acknowledgeProcess.launches.length, 0)
    })
  }

  test("retain exact remote argv and deduplicate an active guarded request", () => {
    const s = ackContext()
    s.acknowledgeAgent(agent(), false, true)
    s.acknowledgeAgent(agent(), true, false)
    assert.deepEqual(s.acknowledgeProcess.launches, [["boomux", "attention", "acknowledge",
      "shared-id", "--observation-revision", "7", "--json", "--node", "remote-node"]])
    assert.equal(s.activeAcknowledgement.dismissed, true)
    assert.equal(s.activeAcknowledgement.automatic, false)
    assert.equal(s.acknowledgeQueue.length, 0)
    s.acknowledgeStdout.text = envelope("attention.acknowledge", ackResult("remote-node"))
    s.acknowledgeProcess.running = false
    s.ackExited(0)
    assert.equal(s.failures.length, 0)
    assert.equal(s.activeAcknowledgement, null)
    assert.equal(s.acknowledgeProcess.launches.length, 1)
  })

  test("skip a lost queued owner and dispatch the next eligible owner once", () => {
    const s = ackContext()
    s.acknowledgeProcess.running = true
    s.acknowledgeProcess.launches = []
    s.acknowledgeAgent(agent())
    s.acknowledgeAgent(agent("local-node"))
    s.nodes.pop()
    s.acknowledgeProcess.running = false
    s.startNextAcknowledgement()
    assert.equal(s.failures.length, 1)
    assert.equal(s.acknowledgeQueue.length, 0)
    assert.equal(s.activeAcknowledgement.nodeId, "local-node")
    assert.deepEqual(s.acknowledgeProcess.launches, [["boomux", "attention", "acknowledge",
      "shared-id", "--observation-revision", "7", "--json"]])
  })

  test("clear queued requests on daemon loss without discarding an active identity", () => {
    const s = ackContext()
    s.acknowledgeAgent(agent("local-node"))
    s.acknowledgeAgent(agent())
    s.setOffline("Stopped")
    assert.equal(s.acknowledgeQueue.length, 0)
    assert.equal(s.activeAcknowledgement.nodeId, "local-node")
    s.nodes = [node("local-node", true), node("remote-node")]
    s.online = true
    s.acknowledgeAgent(agent("remote-node", 8))
    s.acknowledgeProcess.running = false
    s.ackExited(1)
    assert.equal(s.acknowledgeProcess.launches.length, 2)
    assert.equal(s.activeAcknowledgement.revision, 8)
    assert.equal(s.acknowledgeQueue.length, 0)
  })

  test("reject a same-ID wrong-owner success and never retry a failed revision", () => {
    const s = ackContext()
    s.acknowledgeAgent(agent())
    s.acknowledgeStdout.text = envelope("attention.acknowledge", ackResult("local-node"))
    s.acknowledgeProcess.running = false
    s.ackExited(0)
    s.startNextAcknowledgement()
    assert.equal(s.failures.length, 1)
    assert.equal(s.activeAcknowledgement, null)
    assert.equal(s.acknowledgeProcess.launches.length, 1)
  })

  test("reject invalid attention revisions before constructing argv", () => {
    const s = ackContext()
    for (const revision of [NaN, Infinity, -1, 0, 1.5, Number.MAX_SAFE_INTEGER + 1])
      s.acknowledgeAgent(agent("remote-node", revision))
    assert.equal(s.acknowledgeProcess.launches.length, 0)
  })
})

test("acknowledgment results validate owner, Agent, cleared attention and guarded revision", () => {
  const remote = Object.assign(model.acknowledgementIdentity(agent(), 7), { nodeLocal: false })
  const local = Object.assign(model.acknowledgementIdentity(agent("local-node"), 7),
    { nodeLocal: true })
  assert.equal(model.acknowledgementResponseMatches(ackResult("remote-node"), remote), true)
  assert.equal(model.acknowledgementResponseMatches(ackResult(null, 8), local), true)
  const unchanged = ackResult(null)
  unchanged.changed = false
  assert.equal(model.acknowledgementResponseMatches(unchanged, local), true)
  const qualified = ackResult(null)
  qualified.agent.id = { node_id: "remote-node", inner_id: "shared-id" }
  assert.equal(model.acknowledgementResponseMatches(qualified, remote), true)
  for (const mutate of [
    r => { delete r.node_id },
    r => { r.node_id = "local-node" },
    r => { r.agent.id = "other-agent" },
    r => { r.agent.id = { node_id: "local-node", inner_id: "shared-id" } },
    r => { r.agent.node_id = "local-node" },
    r => { delete r.changed },
    r => { r.agent.attention = { observation: { revision: 7 } } },
    r => { delete r.agent.attention },
    r => { delete r.agent.observation },
    r => { r.agent.observation.revision = 6 },
    r => { r.agent.observation.revision = "7" },
    r => { r.observation_revision = 8 }
  ]) {
    const result = ackResult("remote-node")
    mutate(result)
    assert.equal(model.acknowledgementResponseMatches(result, remote), false)
  }
  assert.equal(model.acknowledgementResponseMatches(ackResult("remote-node"), local), false)
})

function selectionContext() {
  return context(["requestWorkspaceSelection", "startWorkspaceSelection", "setOffline"],
  Object.assign(offlineState(), {
    online: true, backendReady: true,
    workspaceSelectionSupported: true, workspaceSelectionAppliedId: "",
    workspaceSelectionRequested: null, workspaceSelectionActive: null,
    workspaceSelectionProcess: processStub(), workspaceSelectionStdout: { text: "" },
    workspaceSelectionStderr: { text: "Could not write default" }
  }), { workspaceSelectionProcess: "selectionExited" })
}

function workspace(id) { return { id, name: id, is_global: true } }
function finishSelection(s, code) {
  s.workspaceSelectionProcess.running = false
  s.selectionExited(code)
  s.flush()
}

describe("explicit Workspace selection intents", () => {
  test("consume failed selection once and allow an explicit same-ID retry", () => {
    const s = selectionContext()
    s.requestWorkspaceSelection(workspace("missing"))
    finishSelection(s, 1)
    for (let i = 0; i < 5; i++) s.startWorkspaceSelection()
    assert.equal(s.workspaceSelectionProcess.launches.length, 1)
    assert.equal(s.failures.length, 1)
    assert.equal(s.workspaceSelectionRequested, null)
    s.requestWorkspaceSelection(workspace("missing"))
    assert.equal(s.workspaceSelectionProcess.launches.length, 2)
  })

  for (const code of [0, 1]) {
    test(`dispatch only the newest queued intent after exit ${code}`, () => {
      const s = selectionContext()
      s.requestWorkspaceSelection(workspace("first"))
      s.requestWorkspaceSelection(workspace("obsolete"))
      s.requestWorkspaceSelection(workspace("newest"))
      finishSelection(s, code)
      assert.deepEqual(s.workspaceSelectionProcess.launches, [
        ["boomux", "workspace", "select", "first"],
        ["boomux", "workspace", "select", "newest"]])
      finishSelection(s, code)
      assert.equal(s.workspaceSelectionProcess.launches.length, 2)
      assert.equal(s.workspaceSelectionRequested, null)
    })
  }

  test("first external activation always sends clear despite unknown cached state", () => {
    const s = selectionContext()
    s.requestWorkspaceSelection({ id: "external", is_global: false })
    assert.deepEqual(s.workspaceSelectionProcess.launches, [["boomux", "workspace", "clear"]])
    finishSelection(s, 0)
    // An external CLI can change persisted selection without changing this cache.
    s.requestWorkspaceSelection(null)
    finishSelection(s, 1)
    assert.equal(s.workspaceSelectionProcess.launches.length, 2)
    assert.equal(s.workspaceSelectionRequested, null)
  })

  test("a newer explicit same-ID intent is not mistaken for the completed request", () => {
    const s = selectionContext()
    s.requestWorkspaceSelection(workspace("same"))
    s.requestWorkspaceSelection(workspace("same"))
    finishSelection(s, 0)
    finishSelection(s, 0)
    assert.equal(s.workspaceSelectionProcess.launches.length, 2)
  })

  for (const next of [workspace("queued"), null]) {
    test(`daemon loss consumes an unstarted ${next ? "select" : "clear"} intent`, () => {
      const s = selectionContext()
      s.requestWorkspaceSelection(workspace("first"))
      s.requestWorkspaceSelection(next)
      s.setOffline("Stopped")
      finishSelection(s, 1)
      s.online = true
      s.startWorkspaceSelection()
      assert.equal(s.workspaceSelectionProcess.launches.length, 1)
      assert.equal(s.workspaceSelectionRequested, null)
    })
  }

  for (const eligibility of ["online", "backendReady", "workspaceSelectionSupported"]) {
    test(`dispatch rechecks selection ${eligibility} and consumes lost eligibility once`, () => {
      const s = selectionContext()
      s.requestWorkspaceSelection(workspace("first"))
      s.requestWorkspaceSelection(workspace("queued"))
      s[eligibility] = false
      finishSelection(s, 0)
      assert.equal(s.workspaceSelectionProcess.launches.length, 1)
      assert.equal(s.workspaceSelectionRequested, null)
      assert.equal(s.failures.length, 1)
      s[eligibility] = true
      s.startWorkspaceSelection()
      assert.equal(s.workspaceSelectionProcess.launches.length, 1)
    })
  }
})

function creationContext() {
  return context(["refresh", "workspaceMutationBusy", "requestGeneratedWorkspace",
    "requestFreshWorkspaceCreateStatus", "requestFreshWorkspaceCreateSnapshot",
    "parseDaemonStatus", "setOffline", "failWorkspaceCreation", "parseEnvelope"],
  Object.assign(offlineState(), {
    backendReady: true, opened: false, atomicWorkspaceCreationSupported: true,
    federationAvailable: true, globalWorkspacesAvailable: true,
    workspaceCreateGeneration: 0, daemonStatusCreateGeneration: 0,
    workspaceCreateStatusActive: false, workspaceCreateStatusQueued: false,
    workspaceCreateSnapshotActive: false, workspaceCreateSnapshotQueued: false,
    workspaceCreateSnapshotGeneration: 0, defaultCwdRequest: null,
    daemonStatusProcess: processStub(), nodeSnapshotProcess: processStub(),
    workspaceCreateProcess: processStub(), defaultCwdProcess: processStub(),
    actionProcess: processStub(), openProcess: processStub(),
    compatibilityRequirements: compatibility, daemonStatusStdout: { text: "" },
    daemonStartStdout: { text: "" }, daemonStartStderr: { text: "" },
    daemonStartRequested: false, passiveRefreshes: 0,
    refreshData() { this.passiveRefreshes++ }, startEventWait() {}
  }), { daemonStatusProcess: "statusExited", daemonStartProcess: "startExited" })
}

function finishStatus(s, status, code = 0) {
  s.daemonStatusStdout.text = status === "malformed" ? "{}"
    : envelope("daemon.status", { status, protocol_version: 49 })
  s.daemonStatusProcess.running = false
  s.statusExited(code)
}

describe("Workspace creation request generations", () => {
  for (const result of ["stopped", "malformed", "exit-failure", "running"]) {
    test(`a pre-intent passive ${result} result cannot cancel a queued creation`, () => {
      const s = creationContext()
      s.refresh()
      assert.equal(s.daemonStatusCreateGeneration, 0)
      s.requestGeneratedWorkspace("/new/project")
      assert.equal(s.workspaceCreateStatusQueued, true)
      assert.equal(s.workspaceCreateRequested.generation, 1)
      finishStatus(s, result, result === "exit-failure" ? 1 : 0)
      assert.equal(s.workspaceCreateRequested.generation, 1)
      assert.equal(s.daemonStartProcess.launches.length, 0)
      assert.equal(s.failures.length, 0)
      s.flush()
      assert.equal(s.daemonStatusProcess.launches.length, 2)
      assert.equal(s.daemonStatusCreateGeneration, 1)
      assert.equal(s.workspaceCreateStatusActive, true)
      finishStatus(s, "stopped")
      assert.equal(s.daemonStartProcess.launches.length, 1)
      assert.equal(s.workspaceCreateRequested.generation, 1)
      s.daemonStartProcess.running = false
      s.startExited(0)
      s.flush()
      finishStatus(s, "running")
      assert.equal(s.workspaceCreateSnapshotActive, true)
      assert.equal(s.workspaceCreateSnapshotGeneration, 1)
      assert.equal(s.nodeSnapshotProcess.launches.length, 1)
    })
  }

  for (const result of ["malformed", "exit-failure"]) {
    test(`a fresh explicit ${result} result consumes its creation without startup`, () => {
      const s = creationContext()
      s.requestGeneratedWorkspace("/new/project")
      finishStatus(s, result, result === "exit-failure" ? 1 : 0)
      s.flush()
      assert.equal(s.workspaceCreateRequested, null)
      assert.equal(s.daemonStartProcess.launches.length, 0)
      assert.equal(s.daemonStatusProcess.launches.length, 1)
      assert.equal(s.failures.length, 1)
    })
  }

  test("a later passive stop still cancels creation after its fresh status baseline", () => {
    const s = creationContext()
    s.requestGeneratedWorkspace("/new/project")
    finishStatus(s, "running")
    s.refresh()
    finishStatus(s, "stopped")
    assert.equal(s.workspaceCreateRequested, null)
    assert.equal(s.workspaceCreateSnapshotQueued, false)
    assert.equal(s.failures.length, 1)
  })

  test("a superseded explicit check cannot start the daemon for a newer intent", () => {
    const s = creationContext()
    s.requestGeneratedWorkspace("/old/project")
    s.failWorkspaceCreation("Cancelled by a newer authoritative failure")
    s.requestGeneratedWorkspace("/new/project")
    finishStatus(s, "stopped")
    assert.equal(s.workspaceCreateRequested.generation, 2)
    assert.equal(s.daemonStartProcess.launches.length, 0)
    s.flush()
    finishStatus(s, "running")
    assert.equal(s.workspaceCreateSnapshotGeneration, 2)
  })

  test("a superseded snapshot does not authorize creation or cancel the new generation", () => {
    const s = creationContext()
    s.finishRefresh = () => {}
    s.nodeSnapshotStderr = { text: "" }
    s.nodeSnapshotStdout = { text: "" }
    s.focusRefreshPending = s.sessionSnapshotRefreshQueued = false
    s.parseNodeSnapshot = (_raw, explicit) => assert.equal(!!explicit, false)
    vm.runInContext(sourceExit("nodeSnapshotProcess", "snapshotExited"), s)
    s.requestGeneratedWorkspace("/old/project")
    finishStatus(s, "running")
    s.failWorkspaceCreation("Cancelled")
    s.requestGeneratedWorkspace("/new/project")
    finishStatus(s, "running")
    assert.equal(s.workspaceCreateSnapshotQueued, true)
    s.nodeSnapshotProcess.running = false
    s.snapshotExited(0)
    assert.equal(s.workspaceCreateRequested.generation, 2)
    s.flush()
    assert.equal(s.workspaceCreateSnapshotGeneration, 2)
    assert.equal(s.nodeSnapshotProcess.launches.length, 2)
  })
})

describe("guided local update verification", () => {
  for (const current of [undefined, null, "", "unknown", "1.2", "1.2.2", "1.2.3+",
    "1.2.3-", "1.2.3-rc.1", ["1.2.3"], { version: "1.2.3" }]) {
    test(`does not report success for current version ${JSON.stringify(current)}`, () => {
      const s = updateContext()
      s.parseLocalUpdateStatus(envelope("update.status", { current }))
      assert.equal(s.localUpdateVerificationPending, true)
      assert.equal(s.localUpdateVerificationAttempts, 1)
      assert.equal(s.notices.length, 0)
      assert.equal(s.installedRefreshes, 0)
    })
  }
  for (const current of ["1.2.3", "v1.2.3", "1.3.0"]) {
    test(`positively verifies valid equal/newer version ${current}`, () => {
      const s = updateContext()
      s.parseLocalUpdateStatus(envelope("update.status", { current }))
      assert.equal(s.localUpdateVerificationPending, false)
      assert.equal(s.cliVersion, current)
      assert.equal(s.notices.length, 1)
      assert.equal(s.installedRefreshes, 1)
    })
  }
  test("bounds malformed responses without announcing update completion", () => {
    const s = updateContext()
    for (let i = 0; i < 60; i++)
      s.parseLocalUpdateStatus(envelope("update.status", {}))
    assert.equal(s.localUpdateVerificationPending, false)
    assert.equal(s.installedRefreshes, 0)
    assert.equal(s.notices.length, 1)
    assert.equal(s.notices[0][0], "Boomux update did not complete")
  })
  test("an unknown target version cannot prove update completion", () => {
    const s = updateContext()
    s.localUpdateExpectedVersion = "unknown"
    s.parseLocalUpdateStatus(envelope("update.status", { current: "1.2.3" }))
    assert.equal(s.localUpdateVerificationPending, true)
    assert.equal(s.notices.length, 0)
  })
})

function updateContext() {
  return context(["parseEnvelope", "parseLocalUpdateStatus", "continueLocalUpdateVerification"], {
    boomuxRepositoryUrl: "https://github.com/gardnmi/boomux",
    localUpdateVerificationPending: true, localUpdateVerificationAttempts: 0,
    localUpdateExpectedVersion: "1.2.3", installedRefreshes: 0,
    localUpdateVerificationTimer: { stop() {}, restart() {} },
    refreshInstalledState() { this.installedRefreshes++ }
  })
}
