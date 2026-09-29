#!/usr/bin/env bash
# Rename the template placeholder to a real project name.
#
#   scripts/init.sh [name]
#
# Without an argument the name is taken from the repository directory.
# INIT_PLACEHOLDER=<old-name> renames from a name other than PROJECT_NAME
# (e.g. a repository that was created from an already-initialised template).
# Runs automatically via .github/workflows/template-init.yml when a new
# repository is created from this template on GitHub.
set -euo pipefail

PLACEHOLDER="${INIT_PLACEHOLDER:-PROJECT_NAME}"

cd "$(dirname "$0")/.."

NAME="${1:-$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")}"

if [[ ! "$NAME" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "error: invalid project name '$NAME' (allowed: letters, digits, '.', '_', '-')" >&2
  exit 1
fi
if [[ "$NAME" == "$PLACEHOLDER" ]]; then
  echo "error: project name must differ from the placeholder" >&2
  exit 1
fi
if [[ ! -d "sources/$PLACEHOLDER" ]]; then
  echo "Already initialised (sources/$PLACEHOLDER not found), nothing to do."
  exit 0
fi

echo "Initialising project '$NAME'"

# Files that must keep the literal placeholder. Workflows check for it, and
# GITHUB_TOKEN is not allowed to push changes to .github/workflows anyway.
is_excluded() {
  case "$1" in
    ./scripts/init.sh|./.github/workflows/*) return 0 ;;
    ./.git/*) return 0 ;;
  esac
  return 1
}

# 1. Replace the placeholder inside text files.
while IFS= read -r -d '' f; do
  is_excluded "$f" && continue
  grep -Iq . "$f" 2>/dev/null || continue          # skip binary / empty files
  grep -q "$PLACEHOLDER" "$f" || continue
  NAME="$NAME" perl -pi -e "s/\Q$PLACEHOLDER\E/\$ENV{NAME}/g" "$f"
  echo "  edited  ${f#./}"
done < <(find . -type f -not -path './.git/*' -print0)

# 2. Drop the template-only section from the READMEs.
for readme in README*.md; do
  [[ -f "$readme" ]] || continue
  perl -0pi -e 's/<!-- template:start -->.*?<!-- template:end -->\n*//s' "$readme"
done

# 3. Rename files and directories (deepest first so parents move last).
while IFS= read -r -d '' p; do
  base="$(basename "$p")"
  new="$(dirname "$p")/${base//$PLACEHOLDER/$NAME}"
  if git ls-files --error-unmatch "$p" >/dev/null 2>&1; then
    git mv "$p" "$new"
  else
    mv "$p" "$new"
  fi
  echo "  renamed ${p#./} -> ${new#./}"
done < <(find . -depth -name "*$PLACEHOLDER*" -not -path './.git/*' -print0)

# 4. Give the schematic a fresh root UUID so projects don't share one.
sch="sources/$NAME/$NAME.kicad_sch"
if [[ -f "$sch" ]]; then
  uuid="$(python3 -c 'import uuid; print(uuid.uuid4())' 2>/dev/null || uuidgen | tr 'A-Z' 'a-z')"
  UUID="$uuid" perl -0pi -e 's/(\(generator_version "[^"]*"\)\s*\(uuid )[0-9a-f-]+/$1$ENV{UUID}/' "$sch"
fi

echo "Done. Open sources/$NAME/$NAME.kicad_pro in KiCad."
