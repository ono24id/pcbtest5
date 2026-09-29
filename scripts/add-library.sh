#!/usr/bin/env bash
# Add an external KiCad library as a git submodule and register it in the
# project's sym-lib-table / fp-lib-table.
#
#   scripts/add-library.sh <git-url> [name] [-b branch]
#
# The submodule is placed in libraries/external/<name> (name defaults to the repository
# name). Every *.kicad_sym file and *.pretty directory found inside it is added
# to the project library tables with a ${KIPRJMOD}-relative path.
set -euo pipefail

usage() { sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

BRANCH=""
ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -b|--branch) BRANCH="${2:?missing branch}"; shift 2 ;;
    -h|--help) usage ;;
    *) ARGS+=("$1"); shift ;;
  esac
done
[[ ${#ARGS[@]} -ge 1 ]] || usage

URL="${ARGS[0]}"
NAME="${ARGS[1]:-$(basename "${URL%/}" .git)}"

cd "$(dirname "$0")/.."

PRO="$(find sources -mindepth 2 -maxdepth 2 -name '*.kicad_pro' | head -n1)"
[[ -n "$PRO" ]] || { echo "error: no .kicad_pro found under sources/" >&2; exit 1; }
PRJ_DIR="$(dirname "$PRO")"
DEST="libraries/external/$NAME"

if [[ "$URL" == git@* ]]; then
  echo "warning: SSH URL used; CI and other users need access via SSH. Prefer https://" >&2
fi

if [[ -e "$DEST" ]]; then
  echo "$DEST already exists, only (re)registering its libraries."
else
  git submodule add ${BRANCH:+-b "$BRANCH"} "$URL" "$DEST"
fi

# Append a (lib ...) entry unless the nickname is already present.
register() {  # table nickname uri
  local table="$1" nick="$2" uri="$3"
  if grep -q "(name \"$nick\")" "$table"; then
    echo "  skip    $nick (already in $(basename "$table"))"
    return
  fi
  NICK="$nick" URI="$uri" DESCR="$NAME (submodule)" perl -0pi -e '
    my $e = "\t(lib (name \"$ENV{NICK}\") (type \"KiCad\") (uri \"$ENV{URI}\") (options \"\") (descr \"$ENV{DESCR}\"))\n";
    s/\)\s*\z/$e)\n/;' "$table"
  echo "  added   $nick -> $(basename "$table")"
}

found=0
while IFS= read -r -d '' f; do
  register "$PRJ_DIR/sym-lib-table" "$(basename "$f" .kicad_sym)" "\${KIPRJMOD}/../../$f"
  found=1
done < <(find "$DEST" -name '*.kicad_sym' -not -path '*/.git/*' -print0 | sort -z)

while IFS= read -r -d '' d; do
  register "$PRJ_DIR/fp-lib-table" "$(basename "$d" .pretty)" "\${KIPRJMOD}/../../$d"
  found=1
done < <(find "$DEST" -type d -name '*.pretty' -not -path '*/.git/*' -print0 | sort -z)

[[ $found -eq 1 ]] || echo "warning: no .kicad_sym or .pretty found in $DEST" >&2

git add .gitmodules "$DEST" "$PRJ_DIR/sym-lib-table" "$PRJ_DIR/fp-lib-table"
echo "Done. Review with 'git status' and commit. Reopen the project in KiCad to load the libraries."
