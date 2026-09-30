const { expect, test } = require("bun:test")
const fs = require("node:fs")
const vm = require("node:vm")
const model = require("../WorkspaceModel.js")
const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")

// Execute the real QML JavaScript functions, with Qt/view and action boundaries mocked.
// This does not instantiate QML or claim a live object-count/frame-time result.
function sourceFunction(name) {
  const match = panel.match(new RegExp(`  function ${name}\\([^]*?\\n  \\}`))
  if (!match) throw new Error(`Missing Panel function: ${name}`)
  return match[0]
}

function workspace(count, node = "node-a", id = "workspace") {
  return {
    id, key: model.resourceKey(node, id), name: "same display name", node_id: node,
    is_global: false, is_external: true, available: true, shells: Array.from(
      { length: count }, (_, i) => ({ id: `shell-${i}`,
        key: model.resourceKey(node, `shell-${i}`), name: `Shell ${i}`,
        node_id: node, node_alias: node, node_current: true, workspace_id: id,
        owner: "user", status: "running", cwd: "/tmp", run: { id: `run-${i}` } })),
    agents: [], launchers: []
  }
}

function harness(workspaces, expandedKey = "") {
  const later = [], positions = [], calls = []
  const state = {
    WorkspaceModel: model, workspaceTreeWorkspaces: workspaces, workspaces,
    expandedWorkspaceKey: expandedKey, workspaceTreeSnapshotSignature: "",
    selectedWorkspaceIndex: 0, selectedWorkspaceItemIndex: 0, focusSection: "workspaces",
    workspaceTreeHeight: 340, pendingWorkspacePositionKey: "", opened: true,
    cliFeatures: [], actionMenuTarget: null, selectedWorkspaceKey: "",
    actionProcess: { running: false },
    Qt: { callLater: callback => later.push(callback) },
    Style: { space: value => value }, ListView: { Contain: "contain", Beginning: "beginning" },
    panel: { height: 800 },
    workspaceTreeList: { contentY: 0, height: 340, contentHeight: 2000,
      positionViewAtIndex: (index, mode) => positions.push({ index, mode }) },
    workspaceCanOpen: () => true, currentNoticeScreen: () => "screen",
    requestWorkspaceSelection: target => calls.push({ kind: "select", target }),
    openWorkspace: target => calls.push({ kind: "open-workspace", target }),
    openWorkspaceTreeItem: target => calls.push({ kind: "open-item", target }),
    showActionMenuAt: target => calls.push({ kind: "menu", target }),
    workspacePositionTimer: { restart() {}, stop() {} }, keyCatcher: { width: 360 },
    ensureFocusSectionVisible() {},
    flush() { while (later.length) later.shift()() }, positions, calls
  }
  state.root = state
  for (const name of ["workspaceTreeItemKey", "projectWorkspaceTree", "workspaceTreeRowIndex",
    "clampWorkspaceCursor", "moveWorkspaceCursor", "movePanelCursor", "revealWorkspaceTreeCursor",
    "applyWorkspacePosition", "positionWorkspace", "cycleFocusSection", "activatePanelCursor",
    "showCursorActionMenu", "toggleWorkspaceExpansion", "activateWorkspaceRow",
    "applyWorkspaceSnapshot", "setWorkspaceTreeHeight", "restoreWorkspaceTreeScroll"])
    vm.runInNewContext(sourceFunction(name), state)
  Object.defineProperties(state, {
    workspaceTreeProjection: { get: () => state.projectWorkspaceTree(
      state.workspaceTreeWorkspaces, state.expandedWorkspaceKey) },
    cursorWorkspace: { get: () => state.workspaceTreeWorkspaces[state.selectedWorkspaceIndex] || null },
    cursorWorkspaceItems: { get: () => model.workspaceTreeItems(state.cursorWorkspace) },
    cursorWorkspaceItem: { get: () => state.cursorWorkspaceItems[state.selectedWorkspaceItemIndex] || null }
  })
  return state
}

test("flat projection uses exact qualified resources and stable type-scoped keys", () => {
  const a = workspace(2), b = workspace(1, "node-b")
  a.shells.push({ ...a.shells[0], id: "private", owner: { kind: "schedule" } })
  a.launchers = [{ id: a.shells[0].id, key: a.shells[0].key,
    name: "same resource ID", node_id: a.node_id, node_alias: a.node_id, command: ["true"] }]
  const state = harness([a, b], a.key)
  const projection = state.workspaceTreeProjection
  expect(projection.rows.map(row => row.kind)).toEqual([
    "workspace", "item", "item", "item", "workspace"
  ])
  expect(new Set(projection.rows.map(row => row.key)).size).toBe(5)
  expect(projection.rows[1].workspace).toBe(a)
  expect(projection.rows[1].item.shell).toBe(a.shells[0])
  expect(projection.rows[3].item.launcher).toBe(a.launchers[0])
  expect(projection.rows[3].item.workspace).toBe(a)
  expect(projection.rows[4].workspace).toBe(b)
  expect(projection.workspaceRows[b.key]).toBe(4)
  const shellKey = projection.rows[1].key
  a.shells[0].name = "Renamed"
  a.shells[0].command = ["true"]
  expect(state.workspaceTreeProjection.rows[1].key).toBe(shellKey)
  a.agents = [{ id: "agent", node_id: a.node_id, shell_id: a.shells[0].id,
    run_id: a.shells[0].run.id, observation: { state: "working" } }]
  expect(state.workspaceTreeProjection.rows[1].item.kind).toBe("agent")
  expect(state.workspaceTreeProjection.rows[1].key).toBe(shellKey)
  state.expandedWorkspaceKey = b.key
  const remoteRow = state.workspaceTreeProjection.rows[2]
  expect(remoteRow.item.shell).toBe(b.shells[0])
  expect(remoteRow.key).not.toBe(shellKey)
})

test("collapsed Workspaces do not project children; only the expanded owner contributes rows", () => {
  const a = workspace(1000), b = workspace(1000, "node-b")
  const state = harness([a, b])
  let projections = 0
  state.WorkspaceModel = { ...model, workspaceTreeItems(value) {
    projections++
    return model.workspaceTreeItems(value)
  } }
  expect(state.workspaceTreeProjection.rows).toHaveLength(2)
  expect(projections).toBe(0)
  state.expandedWorkspaceKey = a.key
  expect(state.workspaceTreeProjection.rows).toHaveLength(1002)
  expect(projections).toBe(1)
  state.expandedWorkspaceKey = b.key
  expect(state.workspaceTreeProjection.rows).toHaveLength(1002)
  expect(projections).toBe(2)
})

test("10/100/1000-item fixtures have flat O(items) data and viewport-bounded row geometry", () => {
  for (const count of [10, 100, 1000]) {
    const expanded = workspace(count)
    const state = harness([expanded, workspace(1, "node-b")], expanded.key)
    const projection = state.workspaceTreeProjection
    expect(projection.rows).toHaveLength(count + 2)
    expect(projection.items).toHaveLength(count)
    expect(state.workspaceTreeRowIndex(0, count - 1)).toBe(count)
    expect(state.workspaceTreeRowIndex(1, -1)).toBe(count + 1)
    // Static geometry estimate, NOT a measured Qt object count. No row is less
    // than 40 logical pixels, so a 340px viewport intersects at most 10 rows.
    expect(Math.ceil(state.workspaceTreeList.height / 40) + 1).toBe(10)
    expect(projection.rows.every(row => row.children === undefined)).toBe(true)
  }
  const tree = panel.slice(panel.indexOf("id: workspaceTreeList"),
    panel.indexOf("id: workspaceResizeHandle"))
  expect(tree).not.toMatch(/Repeater\s*\{/)
  expect(tree).toContain("model: root.workspaceTreeProjection.rows")
  expect(tree).toContain("cacheBuffer: 0")
  expect(tree).toContain("reuseItems: true")
  expect(tree).toContain("clip: true")
  expect(tree).toContain("ScrollBar.vertical: ScrollBar")
  expect(tree).toContain("sourceComponent: workspaceTreeRow.modelData.kind")
})

test("keyboard movement and reveal use flat row indexes even for uninstantiated children", () => {
  const a = workspace(1000), b = workspace(2, "node-b")
  const state = harness([a, b], a.key)
  state.moveWorkspaceCursor(1)
  expect(state.selectedWorkspaceIndex).toBe(1)
  expect(state.positions.pop()).toEqual({ index: 1001, mode: "contain" })
  state.selectedWorkspaceIndex = 0
  state.selectedWorkspaceItemIndex = 999
  state.revealWorkspaceTreeCursor()
  state.flush()
  expect(state.positions.pop()).toEqual({ index: 1000, mode: "contain" })
  state.focusSection = "workspace-items"
  state.movePanelCursor(0, 1)
  state.flush()
  expect(state.selectedWorkspaceItemIndex).toBe(999)
  state.movePanelCursor(0, -1)
  state.flush()
  expect(state.selectedWorkspaceItemIndex).toBe(998)
  expect(state.positions.pop()).toEqual({ index: 999, mode: "contain" })
  state.movePanelCursor(-1, 0)
  expect(state.focusSection).toBe("workspaces")
  expect(state.workspaceTreeRowIndex(1, 0)).toBe(-1)
  expect(state.workspaceTreeRowIndex(0, 1000)).toBe(-1)
  expect(state.workspaceTreeRowIndex(2, -1)).toBe(-1)
  state.applyWorkspacePosition(b.key)
  // A fresh snapshot can move the target before the deferred callback.
  state.workspaceTreeWorkspaces = [b, a]
  state.flush()
  expect(state.positions.pop()).toEqual({ index: 0, mode: "beginning" })
})

test("section cycling skips empty or collapsed children and exact item menus/activation survive flattening", () => {
  const a = workspace(2), state = harness([a], a.key)
  state.cycleFocusSection(1)
  expect(state.focusSection).toBe("workspace-items")
  state.selectedWorkspaceItemIndex = 1
  state.activatePanelCursor()
  expect(state.calls.pop().target.shell).toBe(a.shells[1])
  state.showCursorActionMenu()
  expect(state.calls.pop().target.shell).toBe(a.shells[1])
  state.cycleFocusSection(1)
  expect(state.focusSection).toBe("lower")
  state.focusSection = "workspaces"
  state.expandedWorkspaceKey = ""
  state.cycleFocusSection(1)
  expect(state.focusSection).toBe("lower")
  a.shells = []
  state.expandedWorkspaceKey = a.key
  state.focusSection = "workspaces"
  expect(state.workspaceTreeProjection.rows.map(row => row.kind)).toEqual(["workspace", "empty"])
  state.cycleFocusSection(1)
  expect(state.focusSection).toBe("lower")
})

test("chevron only expands while activation selects and opens the exact Workspace", () => {
  const a = workspace(10), state = harness([a])
  state.toggleWorkspaceExpansion(a)
  state.flush()
  expect(state.expandedWorkspaceKey).toBe(a.key)
  expect(state.calls).toHaveLength(0)
  expect(state.positions.pop()).toEqual({ index: 0, mode: "beginning" })
  state.toggleWorkspaceExpansion(a)
  expect(state.expandedWorkspaceKey).toBe("")
  state.activateWorkspaceRow(a)
  expect(state.calls.map(call => call.kind)).toEqual(["select", "open-workspace"])
  expect(state.calls.every(call => call.target === a)).toBe(true)
  expect(state.expandedWorkspaceKey).toBe(a.key)
  expect(state.opened).toBe(true)
  const tree = panel.slice(panel.indexOf("id: workspaceTreeList"),
    panel.indexOf("id: workspaceResizeHandle"))
  expect(tree).toContain("root.toggleWorkspaceExpansion(workspaceTreeDelegate.modelData)")
  expect(tree).toContain("root.activateWorkspaceRow(workspaceTreeDelegate.modelData)")
  expect(tree).toContain("root.openWorkspaceTreeItem(modelData)")
  expect(tree).toContain("root.showActionMenu(modelData, treeItemMenuButton)")
  expect(tree).toContain("workspace: workspaceTreeDelegate.modelData }, workspaceMenuButton)")
})

test("snapshot reorder preserves qualified Workspace and child cursors, then clamps removed children", () => {
  const a = workspace(3), b = workspace(1, "node-b"), state = harness([a, b], a.key)
  state.selectedWorkspaceItemIndex = 2
  const next = { ...a, shells: [a.shells[2], a.shells[0], a.shells[1]] }
  expect(state.applyWorkspaceSnapshot([b, next])).toBe(true)
  expect(state.selectedWorkspaceIndex).toBe(1)
  expect(state.selectedWorkspaceItemIndex).toBe(0)
  expect(state.cursorWorkspaceItem.shell).toBe(a.shells[2])
  const priorTree = state.workspaceTreeWorkspaces
  expect(state.applyWorkspaceSnapshot([b, next])).toBe(false)
  expect(state.workspaceTreeWorkspaces).toBe(priorTree)
  state.selectedWorkspaceItemIndex = 2
  state.applyWorkspaceSnapshot([b, { ...next, shells: [a.shells[2]] }])
  expect(state.selectedWorkspaceItemIndex).toBe(0)
  state.focusSection = "workspace-items"
  state.applyWorkspaceSnapshot([b])
  expect(state.focusSection).toBe("workspaces")
  state.applyWorkspaceSnapshot([])
  expect(state.workspaceTreeProjection.rows).toHaveLength(0)
  expect(state.workspaceTreeRowIndex(0, -1)).toBe(-1)
})

test("divider height stays bounded and snapshot scroll restoration respects explicit navigation", () => {
  const a = workspace(100), state = harness([a], a.key)
  state.workspaceTreeList.contentY = 700
  state.setWorkspaceTreeHeight(10000)
  expect(state.workspaceTreeHeight).toBe(540)
  expect(state.workspaceTreeList.contentY).toBe(700)
  state.setWorkspaceTreeHeight(1)
  expect(state.workspaceTreeHeight).toBe(150)
  state.restoreWorkspaceTreeScroll(700)
  state.flush()
  expect(state.workspaceTreeList.contentY).toBe(700)
  state.restoreWorkspaceTreeScroll(9999)
  state.flush()
  expect(state.workspaceTreeList.contentY).toBe(1660)
  state.pendingWorkspacePositionKey = a.key
  state.restoreWorkspaceTreeScroll(0)
  state.flush()
  expect(state.workspaceTreeList.contentY).toBe(1660)
})
