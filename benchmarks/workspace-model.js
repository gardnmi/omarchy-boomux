const assert = require("node:assert/strict")
const crypto = require("node:crypto")
const fs = require("node:fs")
const os = require("node:os")
const model = require("../WorkspaceModel.js")
const { referenceViews } = require("./view-reference.js")

function qualified(nodeId, innerId) {
  return { node_id: nodeId, inner_id: innerId }
}

function fixture(remoteNodeCount, workspaceCount, resourcesPerWorkspace) {
  const localNodeId = "node-local"
  const nodes = [{
    node_id: localNodeId,
    alias: "local",
    local: true,
    route: null,
    registration_revision: null,
    health: "online",
    current: true,
    stale: false,
    observed_at_ms: 100,
    observed_protocol_version: 49,
    observed_helper_version: "1.7.1",
    observed_capabilities: ["global_workspaces", "multi_node_workspace_placements"],
    workspace_owner_eligible: true,
    workspace_owner_unavailable_reason: null,
    local_snapshot: { workspaces: [], focused_terminal: null },
    remote_projection: null
  }]
  const workspaces = Array.from({ length: workspaceCount }, (_, workspaceIndex) => ({
    id: `global-${workspaceIndex}`,
    revision: 1,
    name: `workspace-${workspaceIndex}`,
    closing: false,
    placements: []
  }))

  for (let nodeIndex = 0; nodeIndex < remoteNodeCount; nodeIndex++) {
    const nodeId = `node-${nodeIndex}`
    const projectedWorkspaces = []
    const shells = []
    const launchers = []
    const agents = []
    for (let workspaceIndex = 0; workspaceIndex < workspaceCount; workspaceIndex++) {
      const workspaceId = `owner-${workspaceIndex}`
      projectedWorkspaces.push({
        id: qualified(nodeId, workspaceId),
        revision: 1,
        name: `owner-${workspaceIndex}`,
        item_count: resourcesPerWorkspace * 3,
        attention_count: 0
      })
      workspaces[workspaceIndex].placements.push({
        node_id: nodeId,
        workspace_id: workspaceId,
        owner_workspace_name: `owner-${workspaceIndex}`,
        owner_revision: 1,
        default_cwd: `/srv/workspace-${workspaceIndex}`,
        state: "active"
      })
      for (let resourceIndex = 0; resourceIndex < resourcesPerWorkspace; resourceIndex++) {
        const suffix = `${workspaceIndex}-${resourceIndex}`
        const shellId = `shell-${suffix}`
        const runId = `run-${suffix}`
        shells.push({
          id: qualified(nodeId, shellId),
          workspace_id: qualified(nodeId, workspaceId),
          name: shellId,
          owner: { kind: "user" },
          status: "running",
          run_id: qualified(nodeId, runId)
        })
        launchers.push({
          id: qualified(nodeId, `launcher-${suffix}`),
          workspace_id: qualified(nodeId, workspaceId),
          name: `launcher-${suffix}`
        })
        agents.push({
          id: qualified(nodeId, `agent-${suffix}`),
          workspace_id: qualified(nodeId, workspaceId),
          shell_id: qualified(nodeId, shellId),
          run_id: qualified(nodeId, runId),
          name: `agent-${suffix}`,
          integration: "opencode",
          state: "idle",
          observation_revision: 1,
          observed_at_ms: 100,
          started_at_ms: 50
        })
      }
    }
    nodes.push({
      node_id: nodeId,
      alias: `remote-${nodeIndex}`,
      local: false,
      route: `remote-${nodeIndex}.example`,
      registration_revision: 1,
      health: "online",
      current: true,
      stale: false,
      observed_at_ms: 100,
      observed_protocol_version: 49,
      observed_helper_version: "1.7.1",
      observed_capabilities: ["global_workspaces", "multi_node_workspace_placements"],
      workspace_owner_eligible: true,
      workspace_owner_unavailable_reason: null,
      local_snapshot: null,
      remote_projection: {
        node_id: nodeId,
        workspaces: projectedWorkspaces,
        shells: shells,
        launchers: launchers,
        agents: agents
      }
    })
  }

  return { nodes: nodes, workspaces: workspaces, external_workspaces: [], focused_terminal: null }
}

function percentile(values, fraction) {
  const sorted = values.slice().sort((left, right) => left - right)
  return sorted[Math.min(sorted.length - 1, Math.ceil(sorted.length * fraction) - 1)]
}

function rounded(value) {
  return Number(value.toFixed(3))
}

function snapshotViews(snapshot, completed) {
  const nodesById = model.indexNodes(snapshot.nodes)
  const shellsByIdentity = model.indexShells(snapshot.shells)
  const agentsByRun = model.indexCurrentAgents(snapshot.agents, shellsByIdentity)
  return {
    nodesById,
    visible: model.visibleAgents(snapshot.agents, shellsByIdentity, agentsByRun),
    completed: model.completedAgentCount(snapshot.agents, completed, shellsByIdentity, agentsByRun),
    signature: model.workspaceTreeModelSignature(snapshot.workspaces),
    items: snapshot.workspaces.map(model.workspaceTreeItems)
  }
}

function compactViews(views) {
  return {
    visible: views.visible.map(agent => [agent.node_id, agent.id]),
    completed: views.completed,
    signature: views.signature,
    items: views.items.map(items => items.map(item =>
      [item.key, item.kind, item.name, item.status, item.detail, item.node_id, item.placement_state]))
  }
}

function timings(samples) {
  return {
    median_ms: rounded(percentile(samples, 0.5)),
    p95_ms: rounded(percentile(samples, 0.95)),
    min_ms: rounded(Math.min(...samples))
  }
}

function benchmark(name, configuration, compareBaseline) {
  const samples = { normalization: [], view_derivation: [], snapshot_to_view: [] }
  let result, views
  // Allocate fresh raw input before timing every iteration. Normalization,
  // index construction, visible/completed derivation, tree projection and tree
  // signature generation are all inside the snapshot-to-view measurement.
  for (let index = -configuration.warmups; index < configuration.runs; index++) {
    const data = fixture(configuration.remoteNodes, configuration.workspaces,
      configuration.resourcesPerWorkspace)
    const start = process.hrtime.bigint()
    result = model.normalizeNodeSnapshot(data)
    const normalizedAt = process.hrtime.bigint()
    views = snapshotViews(result, {})
    const end = process.hrtime.bigint()
    if (index < 0) continue
    samples.normalization.push(Number(normalizedAt - start) / 1e6)
    samples.view_derivation.push(Number(end - normalizedAt) / 1e6)
    samples.snapshot_to_view.push(Number(end - start) / 1e6)
  }

  const expectedResources = configuration.remoteNodes * configuration.workspaces
    * configuration.resourcesPerWorkspace
  const launcherCount = result.workspaces.reduce((total, workspace) =>
    total + workspace.launchers.length, 0)
  assert.equal(result.nodes.length, configuration.remoteNodes + 1)
  assert.equal(result.workspaces.length, configuration.workspaces)
  assert.equal(result.shells.length, expectedResources)
  assert.equal(result.agents.length, expectedResources)
  assert.equal(launcherCount, expectedResources)
  assert.deepEqual(compactViews(views), compactViews(referenceViews(result, {})))

  const baselineSamples = []
  if (compareBaseline) {
    for (let index = -configuration.warmups; index < configuration.runs; index++) {
      const data = fixture(configuration.remoteNodes, configuration.workspaces,
        configuration.resourcesPerWorkspace)
      const start = process.hrtime.bigint()
      // Both pipelines use the current normalizer. This conservatively isolates
      // the view improvement and does not credit indexed normalization gains.
      const baseline = referenceViews(model.normalizeNodeSnapshot(data), {})
      const elapsed = Number(process.hrtime.bigint() - start) / 1e6
      if (index >= 0) baselineSamples.push(elapsed)
      assert.deepEqual(compactViews(views), compactViews(baseline))
    }
  }

  const output = JSON.stringify(result)
  return {
    name,
    fixture: {
      remote_nodes: configuration.remoteNodes,
      workspaces: configuration.workspaces,
      resources_per_workspace: configuration.resourcesPerWorkspace,
      normalized_resources_per_type: expectedResources
    },
    warmups: configuration.warmups,
    runs: configuration.runs,
    normalization: timings(samples.normalization),
    view_derivation: timings(samples.view_derivation),
    snapshot_to_view: timings(samples.snapshot_to_view),
    baseline_snapshot_to_view: baselineSamples.length ? timings(baselineSamples) : null,
    parity: true,
    visible_agents: views.visible.length,
    tree_items: views.items.reduce((total, items) => total + items.length, 0),
    output_bytes: output.length,
    output_sha256: crypto.createHash("sha256").update(output).digest("hex")
  }
}

function markdown(report) {
  const lines = [
    "## Workspace Model Benchmark", "",
    `${report.runtime.name} ${report.runtime.version} on ${report.runtime.platform}/${report.runtime.arch}.`,
    "Fresh snapshots include normalization, indexes, Agent views, tree rows and signatures.",
    "Synthetic JavaScript timings are informational, not live QML frame times or CI thresholds.",
    "",
    "| Fixture | Normalize median | Views median | Pipeline median / p95 | Baseline median | Parity |",
    "| --- | ---: | ---: | ---: | ---: | --- |"
  ]
  for (const result of report.results) lines.push(
    `| ${result.name} | ${result.normalization.median_ms} ms | `
      + `${result.view_derivation.median_ms} ms | ${result.snapshot_to_view.median_ms} / `
      + `${result.snapshot_to_view.p95_ms} ms | `
      + `${result.baseline_snapshot_to_view ? result.baseline_snapshot_to_view.median_ms + " ms" : "not timed"} | pass |`)
  return lines.join("\n") + "\n"
}

function main() {
  const report = {
    schema: "omarchy-boomux.workspace-model-benchmark/v2",
    runtime: {
      name: typeof Bun !== "undefined" ? "Bun" : "Node",
      version: typeof Bun !== "undefined" ? Bun.version : process.version,
      platform: os.platform(), arch: os.arch(), cpu: os.cpus()[0]?.model
    },
    methodology: "Fresh fixture per iteration outside timing; current normalizer and complete view "
      + "derivation inside timing. Baseline is the pre-index view algorithm using the same current "
      + "normalizer. No daemon, compositor or QML rendering. Parity is checked for every fixture.",
    results: [
      ["small-40", 2, 10, 2],
      ["1000-agents", 4, 125, 2],
      ["2000-agents", 4, 250, 2],
      ["large-4000", 4, 250, 4],
      ["8000-agents", 4, 500, 4],
      ["single-workspace-4000", 4, 1, 1000]
    ].map(([name, remoteNodes, workspaces, resourcesPerWorkspace]) =>
      benchmark(name, { remoteNodes, workspaces, resourcesPerWorkspace, warmups: 3, runs: 9 },
        process.argv.includes("--compare-baseline")))
  }
  if (process.env.GITHUB_STEP_SUMMARY)
    fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, markdown(report))
  if (process.argv.includes("--json")) console.log(JSON.stringify(report, null, 2))
  else process.stdout.write(markdown(report))
}

module.exports = { fixture, snapshotViews, compactViews }
if (require.main === module) main()
