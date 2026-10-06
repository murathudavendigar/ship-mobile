#!/usr/bin/env bash
# Plain-bash tests for bin/ship-mobile. No dependencies. Run: test/run.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
BIN="$HERE/../bin/ship-mobile"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Stub npx: record the call, succeed.
mkdir -p "$TMP/stub"
cat > "$TMP/stub/npx" <<'STUB'
#!/usr/bin/env bash
echo "npx $*" >> "$STUB_LOG"
[[ "${STUB_WHOAMI_FAIL:-0}" == 1 && "$2" == "whoami" ]] && exit 1
exit 0
STUB
chmod +x "$TMP/stub/npx"
export STUB_LOG="$TMP/calls.log"

APP="$TMP/app"
mkdir -p "$APP"
echo '{"build":{"production":{}},"submit":{"production":{}}}' > "$APP/eas.json"
echo '{}' > "$APP/store.config.json"

PASS=0; FAIL=0
OUT=""; CODE=0

ship() {
  : > "$STUB_LOG"
  OUT="$(cd "$APP" && PATH="$TMP/stub:$PATH" "$BIN" "$@" 2>&1 </dev/null)"
  CODE=$?
}

check() { # name, condition-result
  if [[ "$2" == 0 ]]; then PASS=$((PASS+1)); echo "ok   $1"
  else FAIL=$((FAIL+1)); echo "FAIL $1"; echo "$OUT" | sed 's/^/     | /'; fi
}
has()  { [[ "$OUT" == *"$1"* ]]; }
ran()  { grep -qF -- "$1" "$STUB_LOG"; }

ship --platform;                 [[ $CODE -ne 0 ]] && has "--platform needs a value"; check "--platform without value fails loudly" $?
ship --platform bogus;           [[ $CODE -ne 0 ]] && has "Platform must be"; check "bad platform rejected" $?
ship --local --cloud;            [[ $CODE -ne 0 ]] && has "Choose only one"; check "two modes rejected" $?
ship --version;                  [[ $CODE -eq 0 ]] && has "ship-mobile "; check "--version" $?
ship --dry-run;                  [[ $CODE -eq 0 ]] && has "submit --platform ios --profile production --latest"; check "default dry-run submits latest" $?
ship --dry-run;                  [[ ! -s "$STUB_LOG" ]]; check "dry-run runs no commands" $?
ship --dry-run;                  [[ ! -d "$APP/dist" ]]; check "dry-run creates no dist/" $?
ship --dry-run --metadata-only;  has "metadata:push" && ! has "submit"; check "metadata-only stops after push" $?
ship --dry-run --platform all;   has "--platform ios" && has "--platform android"; check "platform all covers both" $?
ship --dry-run --platform android; ! has "metadata:push" && has "Listing push skipped"; check "android skips Apple-only metadata" $?
ship --dry-run --platform all;   [[ "$(grep -o 'metadata:push' <<<"$OUT" | wc -l)" -eq 1 ]]; check "all pushes listing once" $?
ship --metadata-only --platform android; [[ $CODE -ne 0 ]] && has "does not support Google Play"; check "metadata-only android rejected" $?
ship --dry-run --local;          has "--local --output" && has "ship.ipa"; check "local builds ipa" $?
ship --dry-run --cloud;          has "spends one EAS build credit" && has "--auto-submit"; check "cloud warns about credits" $?
echo '{"build":{"production":{},"preview":{}},"submit":{"production":{}}}' > "$APP/eas.json"
ship --dry-run --cloud --profile preview;  [[ $CODE -ne 0 ]] && has "not in the submit section"; check "profile must be in submit" $?
echo '{"build":{"production":{}},"submit":{"production":{},"preview":{}}}' > "$APP/eas.json"
ship --dry-run --local --profile preview;  [[ $CODE -ne 0 ]] && has "not in the build section"; check "profile must be in build for local" $?
ship --dry-run --profile preview;          [[ $CODE -eq 0 ]] && has "submit --platform ios --profile preview"; check "submit-only profile ok for submit" $?
echo '{"build":{"production":{}},"submit":{"production":{}}}' > "$APP/eas.json"
ship --dry-run --profile nope;   [[ $CODE -ne 0 ]] && has "Profile 'nope'"; check "unknown profile rejected" $?
ship;                            ran "whoami" && ran "metadata:push" && ran "--latest"; check "real run calls eas" $?
ship --cloud;                    [[ $CODE -ne 0 ]] && has "Pass --yes"; check "cloud needs --yes when not a tty" $?
ship --cloud;                    ! ran "build"; check "cloud refused before building" $?
ship --cloud --yes;              [[ $CODE -eq 0 ]] && ran "build --platform ios"; check "cloud --yes builds" $?
STUB_WHOAMI_FAIL=1 ship;         [[ $CODE -ne 0 ]] && has "Not logged in"; check "not logged in fails" $?

rm "$APP/store.config.json"
ship --dry-run;                  [[ $CODE -ne 0 ]] && has "No store.config.json"; check "missing store.config.json" $?
ship --dry-run --platform android; [[ $CODE -eq 0 ]]; check "android needs no store.config.json" $?
echo '{}' > "$APP/store.config.json"
echo 'nope' > "$APP/eas.json"
ship --dry-run;                  [[ $CODE -ne 0 ]] && has "not valid JSON"; check "bad eas.json" $?

# install.sh
I="$TMP/inst"
inst() { SHIP_MOBILE_BIN_DIR="$I/bin" SHIP_MOBILE_CLAUDE_SKILLS="$I/claude" SHIP_MOBILE_CURSOR_SKILLS="$I/cursor" "$HERE/../install.sh" "$@" 2>&1; }
OUT="$(inst)"; CODE=$?
[[ -L "$I/bin/ship-mobile" && -f "$I/claude/ship-mobile/SKILL.md" && -f "$I/cursor/ship-mobile/SKILL.md" ]]; check "install links all three" $?
OUT="$(inst)"; [[ $? -eq 0 ]]; check "install is idempotent" $?
OUT="$(inst --uninstall)"; [[ ! -e "$I/bin/ship-mobile" && ! -e "$I/claude/ship-mobile" && ! -e "$I/cursor/ship-mobile" ]]; check "uninstall removes links" $?
mkdir -p "$I/bin" && echo keep > "$I/bin/ship-mobile"
OUT="$(inst)"; [[ "$(cat "$I/bin/ship-mobile")" == keep ]] && has "not a symlink"; check "install never clobbers a real file" $?
OUT="$(inst --uninstall)"; [[ "$(cat "$I/bin/ship-mobile")" == keep ]]; check "uninstall never removes a real file" $?

# install.sh --project
P="$TMP/proj"; mkdir -p "$P"
printf '# My app\n\nKeep me.\n' > "$P/AGENTS.md"
proj() { "$HERE/../install.sh" --project "$P" "$@" 2>&1; }
OUT="$(proj)"
[[ -f "$P/GEMINI.md" && -f "$P/.github/copilot-instructions.md" && -f "$P/.windsurf/rules/ship-mobile.md" && -f "$P/.clinerules/ship-mobile.md" && -f "$P/.continue/rules/ship-mobile.md" ]]; check "project writes all agent files" $?
grep -q 'Keep me.' "$P/AGENTS.md" && grep -q 'ship-mobile --dry-run' "$P/AGENTS.md"; check "AGENTS.md keeps user text and gets rules" $?
OUT="$(proj)"; [[ "$(grep -c 'ship-mobile:begin' "$P/AGENTS.md")" -eq 1 ]]; check "project install is idempotent" $?
head -2 "$P/.windsurf/rules/ship-mobile.md" | grep -q 'trigger: model_decision'; check "windsurf frontmatter" $?
OUT="$(proj --uninstall)"
[[ "$(cat "$P/AGENTS.md")" == *"Keep me."* && "$(cat "$P/AGENTS.md")" != *"ship-mobile:begin"* && ! -e "$P/GEMINI.md" && ! -e "$P/.github" && ! -e "$P/.windsurf" ]]; check "project uninstall restores the app" $?
rm -rf "$P"; mkdir -p "$P"
OUT="$(proj --only gemini)"; [[ -f "$P/GEMINI.md" && ! -e "$P/AGENTS.md" ]]; check "--only limits agents" $?
OUT="$(proj --only nope)"; [[ $? -ne 0 ]] && has "Unknown agent"; check "--only rejects unknown agent" $?
mkdir -p "$P/.clinerules"; echo mine > "$P/.clinerules/ship-mobile.md"
OUT="$(proj --only cline)"; [[ "$(cat "$P/.clinerules/ship-mobile.md")" == mine ]] && has "not ours"; check "never overwrites a foreign rule file" $?

echo; echo "$PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
