# PROJECT_NAME

[English](README.md) | **Bahasa Indonesia**

Project hardware KiCad 10.

<!-- template:start -->
## Menggunakan template ini

1. Klik **Use this template → Create a new repository** di GitHub. Nama repository
   akan menjadi nama project KiCad (mis. `sensor-board`).
2. Workflow **Template init** berjalan otomatis pada push pertama:
   - `PROJECT_NAME` diganti dengan nama repository, di nama file maupun isi file
     (`sources/sensor-board/sensor-board.kicad_pro`, `libraries/sensor-board.kicad_sym`, dst.)
   - UUID root schematic di-generate ulang
   - bagian ini dihapus dari kedua README, lalu hasilnya di-commit oleh `github-actions[bot]`
   - workflow **KiCad CI** dijalankan untuk project yang sudah di-rename
3. `git pull`, lalu buka file `.kicad_pro` di KiCad.

Clone lokal tanpa GitHub? Jalankan sendiri:

```bash
scripts/init.sh nama-project   # tanpa argumen: pakai nama folder repository
```

> Jika push dari workflow ditolak, buka **Settings → Actions → General → Workflow permissions**
> dan pilih **Read and write permissions**, lalu jalankan ulang workflow *Template init*
> (tab Actions → Template init → Run workflow).

Setelah inisialisasi, `scripts/init.sh` dan `.github/workflows/template-init.yml` tidak
melakukan apa-apa lagi dan boleh dihapus.
<!-- template:end -->

## Struktur

```
sources/PROJECT_NAME/        KiCad project (.kicad_pro/.kicad_sch/.kicad_pcb) + lib tables
libraries/
  PROJECT_NAME.kicad_sym     simbol khusus project
  PROJECT_NAME.pretty/       footprint khusus project
  PROJECT_NAME.3dshapes/     model 3D (STEP/WRL)
  external/<nama>/           library eksternal (git submodule)
scripts/                     init.sh, add/remove-library.sh, mcp-kicad.sh
.mcp.json, .vscode/, .cursor/ konfigurasi MCP untuk asisten AI
AGENTS.md, CLAUDE.md         instruksi untuk AI agent
.github/workflows/kicad.yml  ERC, DRC, dan output fabrikasi
```

Library project sudah terdaftar di `sym-lib-table` / `fp-lib-table` project dengan path
`${KIPRJMOD}/../../libraries/...`, jadi tetap jalan setelah di-clone di mana pun.
Untuk model 3D, isi path footprint dengan `${KIPRJMOD}/../../libraries/PROJECT_NAME.3dshapes/<file>.step`.

Title block memakai text variable `${PROJECT}`, `${REVISION}` dan `${CURRENT_DATE}`.
`REVISION` bernilai `dev` di KiCad dan diisi otomatis oleh CI dari tag git / commit.

## Library eksternal (git submodule)

Library KiCad pihak ketiga / bersama ditambahkan sebagai git submodule di `libraries/external/`:

```bash
scripts/add-library.sh https://github.com/<owner>/<kicad-lib>.git          # -> libraries/external/<kicad-lib>
scripts/add-library.sh https://github.com/<owner>/<kicad-lib>.git mylib -b main
git commit -m "Add mylib library"
```

Script ini menjalankan `git submodule add`, lalu mendaftarkan setiap `*.kicad_sym` dan `*.pretty`
di dalam submodule ke `sym-lib-table` / `fp-lib-table` project (nickname = nama file, path lewat
`${KIPRJMOD}`). Nickname yang sudah ada dilewati. Buka ulang project di KiCad setelahnya.

Bekerja dengan submodule:

```bash
git clone --recursive <repo-url>              # clone beserta library
git submodule update --init --recursive       # setelah clone / pull biasa
git submodule update --remote libraries/external/mylib # update library ke commit terbaru
```

Untuk menghapus library:

```bash
scripts/remove-library.sh mylib
git commit -m "Remove mylib library"
```

Script ini melepas dan menghapus submodule (termasuk salinannya di `.git/modules`) serta menghapus
entri-nya dari lib table. Script menolak jalan selama schematic atau board masih memakai simbol atau
footprint dari library tersebut; ganti komponennya dulu, atau pakai `--force`.

Gunakan URL `https://` agar CI bisa mengambilnya. Untuk repository library private, tambahkan
repository secret `SUBMODULE_TOKEN` (PAT dengan akses read); checkout di CI otomatis memakainya.

## Asisten AI (MCP)

Repository ini sudah menyertakan server [Model Context Protocol](https://modelcontextprotocol.io)
untuk KiCad, [kicad-mcp-pro](https://github.com/oaslananka/kicad-mcp-pro), yang langsung mengarah ke project ini:

| Client | Konfigurasi |
| --- | --- |
| Claude Code | `.mcp.json` (setujui server `kicad` saat pertama kali dijalankan) |
| VS Code / Copilot | `.vscode/mcp.json` |
| Cursor | `.cursor/mcp.json` |
| Client lain | perintah `bash scripts/mcp-kicad.sh` (stdio) |

Kebutuhan: [uv](https://docs.astral.sh/uv/getting-started/installation/) (`uvx`) dan KiCad 10
dengan `kicad-cli` di `PATH`. Di Windows, jalankan lewat Git Bash / WSL.
Server mencari `sources/*/*.kicad_pro` sendiri, jadi tidak ada yang perlu diubah per project.

Perilaku server bisa diatur dengan environment variable yang dibaca `scripts/mcp-kicad.sh`:
`KICAD_MCP_OPERATING_MODE` (`readonly`, `write` *(default)*, `manufacturing`),
`KICAD_MCP_PROFILE` (`default`, `review`, `build`, `release`, `full`, ...) dan
`KICAD_MCP_PACKAGE` (mis. `kicad-mcp-pro==3.35.0` untuk mengunci versi).

Aturan project untuk AI agent ada di [`AGENTS.md`](AGENTS.md) (di-import oleh `CLAUDE.md`).

## CI & rilis

Setiap push / pull request menjalankan [`kicad.yml`](.github/workflows/kicad.yml) di
container `kicad/kicad:10.0`:

| Langkah | Output |
| --- | --- |
| ERC, DRC (+ schematic parity) | `reports/erc.rpt`, `reports/drc.rpt` — job gagal jika ada error |
| Schematic | `PROJECT_NAME-schematic.pdf`, `PROJECT_NAME-bom.csv` |
| PCB | `gerbers/` + `PROJECT_NAME-gerbers.zip`, drill + drill map, `PROJECT_NAME-pos.csv`, `PROJECT_NAME-pcb.pdf`, `PROJECT_NAME.step` |

Output bisa diunduh dari tab **Actions** (artifact). Layer Gerber mengikuti pengaturan
**File → Plot** yang tersimpan di board.

Untuk rilis produksi:

```bash
git tag v1.0 && git push origin v1.0
```

Jika ERC/DRC bersih, GitHub Release `v1.0` dibuat dengan zip lengkap, Gerber, schematic, BOM, dan file posisi.
