const { test, expect } = require("bun:test")
const fs = require("node:fs")
const vm = require("node:vm")
const model = require("../WorkspaceModel.js")
const source = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")

function body(name) {
  const start = source.indexOf("  function " + name + "(")
  const end = source.indexOf("\n  function ", start + 1)
  return source.slice(start, end < 0 ? source.length : end)
}
function context(extra = {}) {
  let now = 0
  const timer = () => ({ running: false, starts: 0,
    start() { this.running = true; this.starts++ }, stop() { this.running = false } })
  const ctx = { Date: { now: () => now }, WorkspaceModel: model,
    online: true, offlinePollDelay: 1000, eventStreamReady: true,
    workspaceCreateGeneration: 0, daemonStatusCreateGeneration: 0,
    eventSnapshotPending: false, statusRefreshData: true, nextSnapshotReconcileAt: 5000,
    focusEventsSupported: true, federationAvailable: true, backendReady: true,
    daemonProtocolVersion: 49, opened: false, activeTab: "agents", webLifecycleSupported: true,
    nextPassiveRefreshAt: 0, nextWebStatusAt: 0, focusRefreshPending: false,
    daemonStatusProcess: { running: false }, nodeSnapshotProcess: { running: false },
    webStatusProcess: { running: false }, webStartProcess: { running: false },
    webStopProcess: { running: false }, eventRefreshTimer: timer(),
    desktopTerminalRefreshTimer: timer(), eventCursor: "cursor-before",
    sessionRailOpen: false, parseEnvelope: raw => raw,
    shells: [], activeDesktopInitialTitle: "", focusedTerminalKey: "",
    desktopTerminalReadValid: true, nextDesktopTerminalRetryAt: 0,
    desktopTerminalProcess: { running: false },
    activeBoomuxTerminalKey: "", ...extra }
  ctx.root = ctx
  ctx.setNow = value => { now = value }
  vm.createContext(ctx)
  for (const name of ["passiveRefreshInterval", "refreshPassively", "refresh",
    "parseEvents", "requestFocusedTerminalRefresh", "requestDesktopTerminalRefresh",
    "parseDesktopTerminal", "updateDesktopTerminalIdentity", "retryDesktopTerminalIdentity"])
    vm.runInContext(body(name), ctx)
  return ctx
}

test("idle event-backed reconciliation launches status five times less often", () => {
  const ctx = context()
  let reads = 0
  for (let second = 0; second < 60; second++) {
    ctx.setNow(second * 1000)
    ctx.refreshPassively()
    if (ctx.daemonStatusProcess.running) reads++
    ctx.daemonStatusProcess.running = false
  }
  expect(reads).toBe(12)
  ctx.eventStreamReady = false
  expect(ctx.passiveRefreshInterval()).toBe(1000)
  ctx.online = false
  ctx.offlinePollDelay = 15000
  expect(ctx.passiveRefreshInterval()).toBe(15000)
})

test("explicit refresh bypasses passive backoff and coalesces an active snapshot", () => {
  const ctx = context({ nextPassiveRefreshAt: 15000, online: false })
  ctx.refreshPassively()
  expect(ctx.daemonStatusProcess.running).toBe(false)
  ctx.refresh()
  expect(ctx.daemonStatusProcess.running).toBe(true)
  ctx.daemonStatusProcess.running = false
  ctx.nodeSnapshotProcess.running = true
  ctx.refresh()
  expect(ctx.daemonStatusProcess.running).toBe(false)
  expect(ctx.focusRefreshPending).toBe(true)
})

test("one event batch and repeated bursts coalesce, including attention while closed", () => {
  const ctx = context()
  ctx.parseEvents({ cursor: "new-cursor", events: Array.from({ length: 1000 }, () =>
    ({ event: "agent_state_changed" })) })
  ctx.parseEvents({ cursor: "next-cursor", events: [{ event: "node_projection_changed" }] })
  expect(ctx.eventRefreshTimer.starts).toBe(1)
  expect(ctx.daemonStatusProcess.running).toBe(false)
  expect(ctx.nodeSnapshotProcess.running).toBe(false)
  expect(ctx.eventCursor).toBe("next-cursor")
  // Timer callback must check passive status first, even for focus events.
  expect(source).toContain("interval: root.eventSnapshotPending ? 100 : 1000")
  expect(source).toContain("onTriggered: root.refresh(true)")
})

test("event recovery establishes a fresh baseline and ignores output-only invalidation", () => {
  const ctx = context()
  ctx.parseEvents({ cursor: "out", events: [{ event: "output_changed" }] })
  expect(ctx.eventRefreshTimer.starts).toBe(0)
  ctx.eventCursor = ""
  ctx.parseEvents({ cursor: "baseline", events: [] })
  expect(ctx.eventRefreshTimer.starts).toBe(1)
  expect(() => ctx.parseEvents({ cursor: "", events: [] })).toThrow("invalid event batch")
  expect(source).not.toContain("Qt.callLater(function() { root.startEventWait() })")
})

test("Hyprland bursts coalesce and snapshots remap cached window identity without reads", () => {
  const ctx = context()
  for (let i = 0; i < 100; i++) ctx.requestDesktopTerminalRefresh()
  expect(ctx.desktopTerminalRefreshTimer.starts).toBe(1)
  ctx.parseDesktopTerminal(JSON.stringify({ initialTitle: "unmanaged" }))
  expect(ctx.activeDesktopInitialTitle).toBe("unmanaged")
  expect(ctx.activeBoomuxTerminalKey).toBe("")
  const snapshot = body("parseNodeSnapshot")
  expect(snapshot).toContain("updateDesktopTerminalIdentity()")
  expect(snapshot).not.toContain("refreshDesktopTerminal()")
})

test("web status reads have an independent five-second budget", () => {
  const ctx = context({ opened: true })
  for (let i = 0; i < 5; i++) {
    ctx.setNow(i * 100)
    ctx.refresh()
    expect(ctx.webStatusProcess.running).toBe(i === 0)
    ctx.webStatusProcess.running = false
    ctx.daemonStatusProcess.running = false
  }
  ctx.setNow(5000)
  ctx.refresh()
  expect(ctx.webStatusProcess.running).toBe(true)
})


test("output-only renewal checks status without rebuilding a fresh view", () => {
  const ctx = context()
  ctx.parseEvents({ cursor: "output", events: [{ event: "output_changed" }] })
  ctx.refresh(true)
  expect(ctx.daemonStatusProcess.running).toBe(true)
  expect(ctx.statusRefreshData).toBe(false)
  ctx.daemonStatusProcess.running = false
  ctx.parseEvents({ cursor: "attention", events: [{ event: "agent_completed" }] })
  ctx.refresh(true)
  expect(ctx.statusRefreshData).toBe(true)
  expect(ctx.eventSnapshotPending).toBe(false)
})


test("output-only renewal during a slow snapshot does not queue another snapshot", () => {
  const ctx = context({ nodeSnapshotProcess: { running: true } })
  ctx.refresh(true)
  expect(ctx.daemonStatusProcess.running).toBe(true)
  expect(ctx.statusRefreshData).toBe(false)
  expect(ctx.focusRefreshPending).toBe(false)
  ctx.parseEvents({ cursor: "changed", events: [{ event: "agent_state_changed" }] })
  ctx.refresh(true)
  expect(ctx.focusRefreshPending).toBe(true)
})


test("status-only renewal cannot postpone the five-second reconciliation deadline", () => {
  const ctx = context({ nextPassiveRefreshAt: 5000 })
  ctx.setNow(4900)
  ctx.refresh(true)
  expect(ctx.statusRefreshData).toBe(false)
  expect(ctx.nextPassiveRefreshAt).toBe(5000)
  ctx.daemonStatusProcess.running = false
  ctx.setNow(5000)
  ctx.refreshPassively()
  expect(ctx.daemonStatusProcess.running).toBe(true)
  expect(ctx.statusRefreshData).toBe(true)
})

test("failed Hyprland reads recover on bounded reconciliation without window events", () => {
  const ctx = context()
  ctx.parseDesktopTerminal("invalid JSON")
  expect(ctx.desktopTerminalReadValid).toBe(false)
  ctx.refresh()
  expect(ctx.desktopTerminalRefreshTimer.starts).toBe(1)
  ctx.desktopTerminalRefreshTimer.running = false
  ctx.setNow(1000)
  ctx.refresh()
  expect(ctx.desktopTerminalRefreshTimer.starts).toBe(1)
  ctx.setNow(5000)
  ctx.refresh()
  expect(ctx.desktopTerminalRefreshTimer.starts).toBe(2)
  ctx.parseDesktopTerminal(JSON.stringify({ initialTitle: "unmanaged" }))
  expect(ctx.desktopTerminalReadValid).toBe(true)
  ctx.setNow(10000)
  ctx.desktopTerminalRefreshTimer.running = false
  ctx.refresh()
  expect(ctx.desktopTerminalRefreshTimer.starts).toBe(2)
})


test("status-only renewal stamps its creation generation and promotion retains it", () => {
  const ctx = context({ workspaceCreateGeneration: 7 })
  ctx.refresh(true)
  expect(ctx.daemonStatusProcess.running).toBe(true)
  expect(ctx.daemonStatusCreateGeneration).toBe(7)
  expect(ctx.statusRefreshData).toBe(false)
  ctx.workspaceCreateGeneration = 8
  ctx.refresh()
  expect(ctx.statusRefreshData).toBe(true)
  expect(ctx.daemonStatusCreateGeneration).toBe(7)
  ctx.daemonStatusProcess.running = false
  ctx.refresh()
  expect(ctx.daemonStatusCreateGeneration).toBe(8)
})
