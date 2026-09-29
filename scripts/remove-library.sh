#!/usr/bin/env bash
# Remove an external KiCad library that was added with scripts/add-library.sh.
#
#   scripts/remove-library.sh <name> [--force]
#
# Deinitialises and removes the submodule libraries/external/<name> and drops
# its entries from the project's sym-lib-table / fp-lib-table. Aborts if the
# schematic or board still reference one of its libraries, unless --force.
set -euo pipefail

usage() { sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

FORCE=0
ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--force) FORCE=1; shift ;;
    -h|--help) usage ;;
    *) ARGS+=("$1"); shift ;;
  esac
done
[[ ${#ARGS[@]} -eq 1 ]] || usage

NAME="${ARGS[0]%/}"
NAME="${NAME##*/}"   # accept libraries/external/<name> as well

cd "$(dirname "$0")/.."

PRO="$(find sources -mindepth 2 -maxdepth 2 -name '*.kicad_pro' | head -n1)"
[[ -n "$PRO" ]] || { echo "error: no .kicad_pro found under sources/" >&2; exit 1; }
PRJ_DIR="$(dirname "$PRO")"
DEST="libraries/external/$NAME"
TABLES=("$PRJ_DIR/sym-lib-table" "$PRJ_DIR/fp-lib-table")

if ! git config -f .gitmodules --get "submodule.$DEST.path" >/dev/null 2>&1; then
  echo "error: $DEST is not a registered submodule" >&2
  exit 1
fi

# Library nicknames that point into this submodule.
NICKS=()
while IFS= read -r n; do
  [[ -n "$n" ]] && NICKS+=("$n")
done < <(grep -h "libraries/external/$NAME/" "${TABLES[@]}" 2>/dev/null \
           | sed -n 's/.*(name "\([^"]*\)").*/\1/p' | sort -u)

# Refuse to remove libraries that are still referenced by the design.
used=0
for n in ${NICKS[@]+"${NICKS[@]}"}; do
  if hits="$(grep -rnF --include='*.kicad_sch' --include='*.kicad_pcb' "\"$n:" sources)"; then
    echo "Library '$n' is still used:" >&2
    echo "$hits" | cut -c1-160 | sed 's/^/  /' >&2
    used=1
  fi
done
if [[ $used -eq 1 && $FORCE -eq 0 ]]; then
  echo "error: replace these parts first, or re-run with --force" >&2
  exit 1
fi

git submodule deinit -f "$DEST"
git rm -q -f "$DEST"
rm -rf "$(git rev-parse --git-dir)/modules/$DEST"
echo "  removed submodule $DEST"

for t in "${TABLES[@]}"; do
  [[ -f "$t" ]] || continue
  DEST="$DEST" perl -ni -e 'print unless index($_, "$ENV{DEST}/") >= 0' "$t"
done
for n in ${NICKS[@]+"${NICKS[@]}"}; do echo "  unregistered $n"; done

if [[ -f .gitmodules && -z "$(tr -d '[:space:]' < .gitmodules)" ]]; then
  git rm -q -f .gitmodules
elif [[ -f .gitmodules ]]; then
  git add .gitmodules
fi
git add "${TABLES[@]}"
echo "Done. Review with 'git status' and commit. Reopen the project in KiCad."
