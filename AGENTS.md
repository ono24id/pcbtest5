# AGENTS.md

Guidance for AI coding agents (Claude Code, Cursor, Copilot, Codex, ...) working in this repository.

## Project

KiCad 10 hardware project **PROJECT_NAME**.

| Path | Content |
| --- | --- |
| `sources/PROJECT_NAME/PROJECT_NAME.kicad_pro` | KiCad project |
| `sources/PROJECT_NAME/PROJECT_NAME.kicad_sch` | root schematic |
| `sources/PROJECT_NAME/PROJECT_NAME.kicad_pcb` | board |
| `sources/PROJECT_NAME/sym-lib-table`, `fp-lib-table` | project library tables (`${KIPRJMOD}`-relative) |
| `libraries/PROJECT_NAME.kicad_sym`, `.pretty/`, `.3dshapes/` | project-owned symbols, footprints, 3D models |
| `libraries/external/<name>/` | third-party libraries, **git submodules — never edit** |
| `.github/workflows/kicad.yml` | CI: ERC, DRC, fabrication outputs |

## MCP

The `kicad` MCP server ([kicad-mcp-pro](https://github.com/oaslananka/kicad-mcp-pro)) is
configured in `.mcp.json`, `.vscode/mcp.json` and `.cursor/mcp.json`, started via
`scripts/mcp-kicad.sh`, and already points at this project. Prefer its tools
(`run_erc`, `run_drc`, `validate_design`, `sch_*`, `pcb_*`, ...) over hand-editing KiCad files.

## Rules

- KiCad files are S-expressions written by KiCad. If you must edit them directly, keep the
  existing formatting (tabs, one item per line), preserve every `uuid`, and never reorder blocks.
- Do not edit files while they are open in KiCad (a `*.lck` file exists); ask the user to close them.
- Add / remove external libraries only with `scripts/add-library.sh <https-url>` /
  `scripts/remove-library.sh <name>`; do not copy third-party
  libraries into `libraries/PROJECT_NAME.*`.
- New project-owned symbols/footprints go into `libraries/PROJECT_NAME.kicad_sym` / `.pretty/`.
  3D model paths: `${KIPRJMOD}/../../libraries/PROJECT_NAME.3dshapes/<file>.step`.
- Title block uses `${PROJECT}`, `${REVISION}`, `${CURRENT_DATE}`; don't hard-code them.
- Don't commit generated files (`output/`, `*-backups/`, `*.kicad_prl`, `fp-info-cache`).

## Checks

Run before proposing a change as done (or use the MCP `run_erc` / `run_drc` tools):

```bash
kicad-cli sch erc --severity-error --exit-code-violations sources/PROJECT_NAME/PROJECT_NAME.kicad_sch
kicad-cli pcb drc --severity-error --schematic-parity --exit-code-violations sources/PROJECT_NAME/PROJECT_NAME.kicad_pcb
```

Releases are made by pushing a `v*` tag; CI builds Gerbers, drill, BOM, placement, PDFs and STEP.
