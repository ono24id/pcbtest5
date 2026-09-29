# pcbtest5

**English** | [Bahasa Indonesia](README.id.md)

KiCad 10 hardware project.

## Layout

```
sources/pcbtest5/        KiCad project (.kicad_pro/.kicad_sch/.kicad_pcb) + lib tables
libraries/
  pcbtest5.kicad_sym     project-specific symbols
  pcbtest5.pretty/       project-specific footprints
  pcbtest5.3dshapes/     3D models (STEP/WRL)
  external/<name>/           external libraries (git submodules)
scripts/                     init.sh, add/remove-library.sh, mcp-kicad.sh
.mcp.json, .vscode/, .cursor/ MCP config for AI assistants
AGENTS.md, CLAUDE.md         instructions for AI agents
.github/workflows/kicad.yml  ERC, DRC and fabrication outputs
```

The project libraries are registered in the project's `sym-lib-table` / `fp-lib-table` using
`${KIPRJMOD}/../../libraries/...`, so they keep working wherever the repository is cloned.
For 3D models, set the footprint model path to `${KIPRJMOD}/../../libraries/pcbtest5.3dshapes/<file>.step`.

The title block uses the text variables `${PROJECT}`, `${REVISION}` and `${CURRENT_DATE}`.
`REVISION` is `dev` inside KiCad and is filled in by CI from the git tag / commit.

## External libraries (git submodules)

Third-party / shared KiCad libraries are added as git submodules under `libraries/external/`:

```bash
scripts/add-library.sh https://github.com/<owner>/<kicad-lib>.git          # -> libraries/external/<kicad-lib>
scripts/add-library.sh https://github.com/<owner>/<kicad-lib>.git mylib -b main
git commit -m "Add mylib library"
```

The script runs `git submodule add`, then registers every `*.kicad_sym` and `*.pretty` found in
the submodule in the project's `sym-lib-table` / `fp-lib-table` (nickname = file name, path via
`${KIPRJMOD}`). Nicknames that already exist are skipped. Reopen the project in KiCad afterwards.

Working with submodules:

```bash
git clone --recursive <repo-url>              # clone including libraries
git submodule update --init --recursive       # after a normal clone / pull
git submodule update --remote libraries/external/mylib # update a library to its latest commit
```

To remove a library:

```bash
scripts/remove-library.sh mylib
git commit -m "Remove mylib library"
```

This deinitialises and removes the submodule (including its copy in `.git/modules`) and drops its
entries from the lib tables. It refuses to run while the schematic or board still use a symbol or
footprint from that library; replace those parts first, or pass `--force`.

Use `https://` URLs so CI can fetch them. For private library repositories, add a repository
secret `SUBMODULE_TOKEN` (a PAT with read access); the CI checkout uses it automatically.

## AI assistants (MCP)

The repository ships a ready-to-use [Model Context Protocol](https://modelcontextprotocol.io) server
for KiCad, [kicad-mcp-pro](https://github.com/oaslananka/kicad-mcp-pro), already pointed at this project:

| Client | Config |
| --- | --- |
| Claude Code | `.mcp.json` (approve the `kicad` server on first start) |
| VS Code / Copilot | `.vscode/mcp.json` |
| Cursor | `.cursor/mcp.json` |
| Other clients | command `bash scripts/mcp-kicad.sh` (stdio) |

Requirements: [uv](https://docs.astral.sh/uv/getting-started/installation/) (`uvx`) and KiCad 10
with `kicad-cli` on `PATH`. On Windows, run through Git Bash / WSL.
The server finds `sources/*/*.kicad_pro` itself, so nothing needs to be edited per project.

Behaviour can be tuned with environment variables read by `scripts/mcp-kicad.sh`:
`KICAD_MCP_OPERATING_MODE` (`readonly`, `write` *(default)*, `manufacturing`),
`KICAD_MCP_PROFILE` (`default`, `review`, `build`, `release`, `full`, ...) and
`KICAD_MCP_PACKAGE` (e.g. `kicad-mcp-pro==3.35.0` to pin a version).

Project conventions for AI agents live in [`AGENTS.md`](AGENTS.md) (`CLAUDE.md` imports it).

## CI & releases

Every push / pull request runs [`kicad.yml`](.github/workflows/kicad.yml) in the
`kicad/kicad:10.0` container:

| Step | Output |
| --- | --- |
| ERC, DRC (+ schematic parity) | `reports/erc.rpt`, `reports/drc.rpt` — the job fails on errors |
| Schematic | `pcbtest5-schematic.pdf`, `pcbtest5-bom.csv` |
| PCB | `gerbers/` + `pcbtest5-gerbers.zip`, drill + drill map, `pcbtest5-pos.csv`, `pcbtest5-pcb.pdf`, `pcbtest5.step` |

Outputs can be downloaded from the **Actions** tab (artifacts). Gerber layers follow the
**File → Plot** settings saved in the board.

For a production release:

```bash
git tag v1.0 && git push origin v1.0
```

If ERC/DRC are clean, a GitHub Release `v1.0` is created with the full zip, Gerbers, schematic, BOM and placement file.
