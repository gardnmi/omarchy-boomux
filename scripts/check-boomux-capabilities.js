#!/usr/bin/env bun

const { spawnSync } = require("node:child_process")
const fs = require("node:fs")
const os = require("node:os")
const path = require("node:path")
const model = require("../WorkspaceModel.js")
const requirements = model.normalizeCompatibility(require("../compatibility.json"))

const binary = process.argv[2]
if (!binary) {
  console.error("usage: check-boomux-capabilities.js BINARY")
  process.exit(2)
}

const isolatedHome = fs.mkdtempSync(path.join(os.tmpdir(), "omarchy-boomux-contract-"))
const environment = {
  ...process.env,
  HOME: isolatedHome,
  XDG_CONFIG_HOME: path.join(isolatedHome, "config"),
  XDG_DATA_HOME: path.join(isolatedHome, "data"),
  XDG_RUNTIME_DIR: path.join(isolatedHome, "runtime"),
  BOOMUX_NO_UPDATE_CHECK: "1"
}
fs.mkdirSync(environment.XDG_RUNTIME_DIR, { mode: 0o700 })

const result = spawnSync(binary, ["capabilities", "--json"], {
  encoding: "utf8",
  env: environment
})
if (result.status !== 0) {
  console.error(result.stderr || `capabilities exited with ${result.status}`)
  process.exit(1)
}

let data
try {
  data = model.parseEnvelope(result.stdout, "capabilities")
} catch (error) {
  console.error(`invalid capabilities response: ${error.message}`)
  process.exit(1)
}
const compatibility = model.boomuxCompatibility(requirements, data)
if (!compatibility.compatible) {
  console.error(`${data.cli_version || binary}: ${compatibility.reason}`)
  process.exit(1)
}

const status = spawnSync(binary, ["daemon", "status", "--json"], {
  encoding: "utf8",
  env: environment
})
try {
  if (status.status === 0) {
    const statusData = model.parseEnvelope(status.stdout, "daemon.status")
    if (statusData.status !== "stopped" && statusData.status !== "running")
      throw new Error("invalid daemon status")
  } else {
    const response = JSON.parse(status.stderr || status.stdout)
    if (response.schema !== requirements.cli_schema || response.command !== "daemon.status"
        || !response.error || response.error.code !== "daemon_unavailable")
      throw new Error(`unexpected daemon status failure ${status.status}`)
  }
} catch (error) {
  console.error(`invalid daemon status response: ${error.message}`)
  process.exit(1)
} finally {
  fs.rmSync(isolatedHome, { recursive: true, force: true })
}
console.log(`Boomux ${data.cli_version} satisfies the plugin compatibility contract`)
