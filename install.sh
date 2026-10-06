#!/usr/bin/env bash
# Install ship-mobile.
#
#   ./install.sh                        link the command and the skill (Claude Code, Cursor)
#   ./install.sh --project DIR          add agent rule files to the app in DIR
#   ./install.sh --project DIR --only agents,gemini
#   ./install.sh --uninstall            remove the links this script made
#   ./install.sh --project DIR --uninstall
#
# Safe to re-run. It never overwrites a file it did not create. In shared files
# (AGENTS.md and similar) it only touches its own marked block.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${SHIP_MOBILE_BIN_DIR:-$HOME/.local/bin}"
CLAUDE_SKILLS="${SHIP_MOBILE_CLAUDE_SKILLS:-$HOME/.claude/skills}"
CURSOR_SKILLS="${SHIP_MOBILE_CURSOR_SKILLS:-$HOME/.cursor/skills}"
SKILL="$REPO/skills/ship-mobile/SKILL.md"

BEGIN='<!-- ship-mobile:begin -->'
END='<!-- ship-mobile:end -->'
DESCRIPTION="Ship an Expo app's store listing and binary with the ship-mobile command. Use when the user asks to ship, release, upload, submit, or push store metadata."

# Agent rule files. Format: name|path|kind
#   block = marked block inside a shared file. file = a file of its own.
TARGETS=(
  "agents|AGENTS.md|block"
  "gemini|GEMINI.md|block"
  "copilot|.github/copilot-instructions.md|block"
  "windsurf|.windsurf/rules/ship-mobile.md|file"
  "cline|.clinerules/ship-mobile.md|file"
  "continue|.continue/rules/ship-mobile.md|file"
)

UNINSTALL=0
PROJECT=""
ONLY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --uninstall) UNINSTALL=1 ;;
    --project)
      [[ $# -ge 2 && -n "$2" ]] || { echo "--project needs a folder." >&2; exit 1; }
      PROJECT="$2"
      shift
      ;;
    --only)
      [[ $# -ge 2 && -n "$2" ]] || { echo "--only needs a list." >&2; exit 1; }
      ONLY="$2"
      shift
      ;;
    -h|--help) sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

# ---------------------------------------------------------------- global links

link() { # source, destination
  mkdir -p "$(dirname "$2")"
  if [[ -e "$2" && ! -L "$2" ]]; then
    echo "skip  $2 exists and is not a symlink" >&2
    return
  fi
  ln -sfn "$1" "$2"
  echo "link  $2 -> $1"
}

unlink_ours() { # destination, expected target
  if [[ -L "$1" && "$(readlink "$1")" == "$2" ]]; then
    rm "$1"
    echo "rm    $1"
  elif [[ -e "$1" || -L "$1" ]]; then
    echo "skip  $1 is not ours" >&2
  fi
}

# ------------------------------------------------------------ project rule files

# The rules are the body of SKILL.md, without its frontmatter. One source of truth.
skill_body() {
  awk 'c >= 2 { print } /^---$/ { c++ }' "$SKILL"
}

managed_block() {
  echo "$BEGIN"
  skill_body
  echo "$END"
}

frontmatter() { # agent name
  case "$1" in
    windsurf)
      printf -- '---\ntrigger: model_decision\ndescription: %s\n---\n\n' "$DESCRIPTION" ;;
    continue)
      printf -- '---\nname: ship-mobile\ndescription: %s\nalwaysApply: false\n---\n\n' "$DESCRIPTION" ;;
  esac
}

has_block() { [[ -f "$1" ]] && grep -qF "$BEGIN" "$1"; }

replace_block() { # file
  local tmp block
  tmp="$(mktemp)"
  block="$(mktemp)"
  managed_block > "$block"
  awk -v b="$BEGIN" -v e="$END" -v f="$block" '
    index($0, b) { while ((getline l < f) > 0) print l; skip = 1; next }
    index($0, e) { skip = 0; next }
    !skip { print }
  ' "$1" > "$tmp"
  cat "$tmp" > "$1"
  rm -f "$tmp" "$block"
}

remove_block() { # file
  local tmp
  tmp="$(mktemp)"
  awk -v b="$BEGIN" -v e="$END" '
    index($0, b) { skip = 1; next }
    index($0, e) { skip = 0; next }
    !skip { print }
  ' "$1" > "$tmp"
  if [[ -z "$(tr -d '[:space:]' < "$tmp")" ]]; then
    rm -f "$1"
    echo "rm    $1"
  else
    cat "$tmp" > "$1"
    echo "edit  $1 (removed our block)"
  fi
  rm -f "$tmp"
}

prune_empty() { # file: remove now-empty parent folders, never the project itself
  local d
  d="$(dirname "$1")"
  while [[ "$d" != "$PROJECT" && "$d" == "$PROJECT"/* ]] && rmdir "$d" 2>/dev/null; do
    d="$(dirname "$d")"
  done
}

install_target() { # agent, path, kind
  local agent="$1" file="$PROJECT/$2" kind="$3"
  if [[ "$UNINSTALL" -eq 1 ]]; then
    if has_block "$file"; then
      if [[ "$kind" == "file" ]]; then rm -f "$file"; echo "rm    $file"; else remove_block "$file"; fi
      prune_empty "$file"
    fi
    return
  fi
  mkdir -p "$(dirname "$file")"
  if [[ "$kind" == "block" ]]; then
    if has_block "$file"; then
      replace_block "$file"
      echo "edit  $file (updated our block)"
    elif [[ -f "$file" ]]; then
      { echo; managed_block; } >> "$file"
      echo "edit  $file (appended our block)"
    else
      managed_block > "$file"
      echo "new   $file"
    fi
  else
    if [[ -e "$file" ]] && ! has_block "$file"; then
      echo "skip  $file exists and is not ours" >&2
      return
    fi
    { frontmatter "$agent"; managed_block; } > "$file"
    echo "new   $file"
  fi
}

wanted() { # agent
  [[ -z "$ONLY" ]] && return 0
  [[ ",$ONLY," == *",$1,"* ]]
}

if [[ -n "$PROJECT" ]]; then
  [[ -d "$PROJECT" ]] || { echo "No such folder: $PROJECT" >&2; exit 1; }
  PROJECT="$(cd "$PROJECT" && pwd)"
  if [[ -n "$ONLY" ]]; then
    IFS=',' read -r -a asked <<< "$ONLY"
    for a in "${asked[@]}"; do
      known=0
      for t in "${TARGETS[@]}"; do [[ "${t%%|*}" == "$a" ]] && known=1; done
      [[ "$known" -eq 1 ]] || { echo "Unknown agent '$a'. Choose from: agents, gemini, copilot, windsurf, cline, continue." >&2; exit 1; }
    done
  fi
  for t in "${TARGETS[@]}"; do
    IFS='|' read -r agent path kind <<< "$t"
    wanted "$agent" && install_target "$agent" "$path" "$kind"
  done
  exit 0
fi

if [[ "$UNINSTALL" -eq 1 ]]; then
  unlink_ours "$BIN_DIR/ship-mobile" "$REPO/bin/ship-mobile"
  unlink_ours "$CLAUDE_SKILLS/ship-mobile" "$REPO/skills/ship-mobile"
  unlink_ours "$CURSOR_SKILLS/ship-mobile" "$REPO/skills/ship-mobile"
  exit 0
fi

chmod +x "$REPO/bin/ship-mobile"
link "$REPO/bin/ship-mobile" "$BIN_DIR/ship-mobile"
link "$REPO/skills/ship-mobile" "$CLAUDE_SKILLS/ship-mobile"
link "$REPO/skills/ship-mobile" "$CURSOR_SKILLS/ship-mobile"

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) echo "warn  $BIN_DIR is not on PATH. Add: export PATH=\"$BIN_DIR:\$PATH\"" >&2 ;;
esac

echo
echo "For other agents, add rule files to an app: ./install.sh --project path/to/app"
