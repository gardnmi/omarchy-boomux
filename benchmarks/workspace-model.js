const assert = require("node:assert/strict")
const crypto = require("node:crypto")
const fs = require("node:fs")
const os = require("node:os")
const model = require("../WorkspaceModel.js")

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

function benchmark(name, configuration) {
  const data = fixture(configuration.remoteNodes, configuration.workspaces,
    configuration.resourcesPerWorkspace)
  for (let index = 0; index < configuration.warmups; index++)
    model.normalizeNodeSnapshot(data)

  const samples = []
  let result
  for (let index = 0; index < configuration.runs; index++) {
    const start = process.hrtime.bigint()
    result = model.normalizeNodeSnapshot(data)
    samples.push(Number(process.hrtime.bigint() - start) / 1e6)
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

  const output = JSON.stringify(result)
  return {
    name: name,
    fixture: {
      remote_nodes: configuration.remoteNodes,
      workspaces: configuration.workspaces,
      resources_per_workspace: configuration.resourcesPerWorkspace,
      normalized_resources_per_type: expectedResources
    },
    warmups: configuration.warmups,
    runs: configuration.runs,
    median_ms: rounded(percentile(samples, 0.5)),
    p95_ms: rounded(percentile(samples, 0.95)),
    min_ms: rounded(Math.min(...samples)),
    output_bytes: output.length,
    output_sha256: crypto.createHash("sha256").update(output).digest("hex")
  }
}

function markdown(report) {
  const lines = [
    "## Workspace Model Benchmark",
    "",
    `Bun ${report.runtime.bun} on ${report.runtime.platform}/${report.runtime.arch}.`,
    "Timings are informational and are not a CI failure threshold.",
    "",
    "| Fixture | Median | p95 | Minimum | Output | SHA-256 |",
    "| --- | ---: | ---: | ---: | ---: | --- |"
  ]
  for (const result of report.results) lines.push(
    `| ${result.name} | ${result.median_ms} ms | ${result.p95_ms} ms | `
      + `${result.min_ms} ms | ${result.output_bytes} bytes | `
      + `\`${result.output_sha256.substring(0, 12)}\` |`)
  return lines.join("\n") + "\n"
}

const report = {
  schema: "omarchy-boomux.workspace-model-benchmark/v1",
  runtime: { bun: Bun.version, platform: os.platform(), arch: os.arch() },
  results: [
    benchmark("small", {
      remoteNodes: 2, workspaces: 10, resourcesPerWorkspace: 2, warmups: 10, runs: 31
    }),
    benchmark("large", {
      remoteNodes: 4, workspaces: 250, resourcesPerWorkspace: 4, warmups: 5, runs: 15
    })
  ]
}

if (process.env.GITHUB_STEP_SUMMARY)
  fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, markdown(report))

if (process.argv.includes("--json")) console.log(JSON.stringify(report, null, 2))
else process.stdout.write(markdown(report))
