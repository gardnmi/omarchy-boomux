const { expect, test } = require("bun:test")
const fs = require("node:fs")
const model = require("../WorkspaceModel.js")

const rawRequirements = require("../compatibility.json")
const requirements = model.normalizeCompatibility(rawRequirements)

function capabilities(overrides = {}) {
  return {
    cli_version: "1.7.2",
    daemon_protocol_version: 49,
    json_schemas: ["boomux.cli/v1"],
    features: ["exact_session_open"],
    ...overrides
  }
}

test("normalizes the published compatibility declaration", () => {
  expect(requirements).toEqual({
    cli_schema: "boomux.cli/v1",
    minimum_protocol: 49,
    required_capabilities: ["exact_session_open"],
    minimum_boomux: "1.7.0"
  })
  expect(requirements.required_capabilities).not.toContain("session_display_names")
  expect(requirements.required_capabilities).not.toContain("observed_agent_working_contexts")
  expect(requirements.required_capabilities).not.toContain("session_latest_agent_attribution")
  expect(requirements.required_capabilities).not.toContain("session_working_context_push_status")
  expect(requirements.required_capabilities).not.toContain("session_working_context_worktree_status")
  expect(requirements.required_capabilities).not.toContain("workspace_session_hiding")
})

test("rejects malformed compatibility declarations", () => {
  expect(() => model.normalizeCompatibility({ ...rawRequirements, minimum_protocol: 0 }))
    .toThrow("invalid minimum protocol")
  expect(() => model.normalizeCompatibility({
    ...rawRequirements,
    required_capabilities: ["exact_session_open", "exact_session_open"]
  })).toThrow("invalid required capability")
  expect(() => model.normalizeCompatibility({ ...rawRequirements, minimum_boomux: "main" }))
    .toThrow("invalid minimum Boomux version")
  expect(() => model.normalizeCompatibility({ ...rawRequirements, minimum_boomux: "01.7.0" }))
    .toThrow("invalid minimum Boomux version")
})

test("accepts a backend that satisfies the declared contract", () => {
  expect(model.boomuxCompatibility(requirements, capabilities()))
    .toEqual({ compatible: true, reason: "" })
})

test("rejects missing schemas, old protocols, and missing capabilities", () => {
  expect(model.boomuxCompatibility(requirements,
    capabilities({ json_schemas: [] })).reason).toContain("boomux.cli/v1")
  expect(model.boomuxCompatibility(requirements,
    capabilities({ daemon_protocol_version: 48 })).reason).toContain("required protocol 49")
  expect(model.boomuxCompatibility(requirements,
    capabilities({ features: [] })).reason).toContain("exact_session_open")
})

test("treats semantic version as guidance rather than compatibility proof", () => {
  expect(model.boomuxCompatibility(requirements,
    capabilities({ cli_version: "0.1.0" })).compatible).toBe(true)
})

test("checks the negotiated running daemon protocol separately", () => {
  expect(model.daemonCompatibility(requirements, 49).compatible).toBe(true)
  expect(model.daemonCompatibility(requirements, 48)).toEqual({
    compatible: false,
    reason: "The running Boomux daemon uses protocol 48, but this plugin requires protocol 49."
  })
})

test("loads and deploys the compatibility declaration at runtime", () => {
  const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
  const deploy = fs.readFileSync(new URL("../deploy-local.sh", import.meta.url), "utf8")
  expect(panel).toContain('Qt.resolvedUrl("compatibility.json")')
  expect(panel).toContain("WorkspaceModel.boomuxCompatibility(")
  expect(panel).toContain("if (!backendReady) return")
  expect(panel).toContain("if (!backendReady || !focusEventsSupported")
  expect(panel).toContain('"PLUGIN REINSTALL REQUIRED" : "BOOMUX UPDATE REQUIRED"')
  expect(deploy).toContain("compatibility.json")
})
