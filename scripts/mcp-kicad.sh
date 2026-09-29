#!/usr/bin/env bash
# Start the KiCad MCP server (kicad-mcp-pro) for this repository over stdio.
# Used by .mcp.json (Claude Code), .vscode/mcp.json and .cursor/mcp.json.
#
# The project directory is discovered automatically (sources/*/*.kicad_pro),
# so the same config works for every project created from the template.
#
# Override via environment:
#   KICAD_MCP_OPERATING_MODE  readonly | write | manufacturing   (default: write)
#   KICAD_MCP_PROFILE         default | review | build | release | full | ...  (default: default)
#   KICAD_MCP_PACKAGE         package spec for uvx, e.g. kicad-mcp-pro==3.35.0
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

PRO="$(find "$ROOT/sources" -mindepth 2 -maxdepth 2 -name '*.kicad_pro' | head -n1)"
if [[ -z "$PRO" ]]; then
  echo "mcp-kicad: no .kicad_pro found under $ROOT/sources" >&2
  exit 1
fi

if ! command -v uvx >/dev/null 2>&1; then
  echo "mcp-kicad: 'uvx' not found. Install uv: https://docs.astral.sh/uv/getting-started/installation/" >&2
  exit 1
fi

export KICAD_MCP_OPERATING_MODE="${KICAD_MCP_OPERATING_MODE:-write}"
export KICAD_MCP_PROFILE="${KICAD_MCP_PROFILE:-default}"

# stdout is the MCP channel: nothing else may be printed to it.
exec uvx "${KICAD_MCP_PACKAGE:-kicad-mcp-pro}" --transport stdio --project-dir "$(dirname "$PRO")"
