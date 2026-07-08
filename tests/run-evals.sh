#!/bin/zsh
# Automated checks for the QLMarkdown eval suite.
# Verifies rendering via the extension's os_log output (subsystem com.jeremynay.qlmarkdown).
# E2/E3 visual polish and E8 (sudo cache reset) remain manual.
# Note: no pipefail — `grep -q` SIGPIPEs upstream commands and would fail passing checks.
set -u
cd "$(dirname "$0")"
PASS=0; FAIL=0
check() { if eval "$2"; then echo "PASS  $1"; ((PASS++)); else echo "FAIL  $1"; ((FAIL++)); fi }

APP=/Applications/QLMarkdownApp.app
EXT_ID=$(defaults read "$APP/Contents/PlugIns/QLMarkdownExtension.appex/Contents/Info" CFBundleIdentifier 2>/dev/null)

# --- Fixtures ----------------------------------------------------------------
# E4: ~500KB / ~10k lines
if [[ ! -f fixtures/large.md ]]; then
  for i in {1..1250}; do
    printf '## Section %d\n\nParagraph with **bold** and `code` for section %d.\n\n- item a\n- item b\n\n' $i $i
  done > fixtures/large.md
fi
# E5: invalid UTF-8
if [[ ! -f fixtures/invalid-utf8.md ]]; then
  { printf '# Valid heading\n\nBad bytes: '; printf '\xff\xfe\xc3\x28'; printf '\n\nText after.\n'; } > fixtures/invalid-utf8.md
fi

# --- E1: registration ---------------------------------------------------------
check "E1 extension registered (pluginkit)" '[[ -n "$(pluginkit -m -i "$EXT_ID" 2>/dev/null)" ]]'

# --- E6: UTI coverage ----------------------------------------------------------
MDUTI_MD=$(mdls -name kMDItemContentType -raw fixtures/sample.md 2>/dev/null)
check "E6 .md has markdown UTI ($MDUTI_MD)" '[[ "$MDUTI_MD" == *markdown* ]]'
cp fixtures/sample.md /tmp/qleval-sample.markdown
MDUTI_MARKDOWN=$(mdls -name kMDItemContentType -raw /tmp/qleval-sample.markdown 2>/dev/null)
check "E6 .markdown has markdown UTI ($MDUTI_MARKDOWN)" '[[ "$MDUTI_MARKDOWN" == *markdown* ]]'

# --- Render via Quick Look, verified through unified log ------------------------
preview() { # $1 = file; opens QL panel briefly, then closes it
  qlmanage -p "$1" >/dev/null 2>&1 &
  local pid=$!
  sleep 4
  kill $pid 2>/dev/null
}
preview fixtures/sample.md
preview fixtures/large.md
preview fixtures/invalid-utf8.md
sleep 2
# /usr/bin/log — `log` unqualified resolves to a zsh builtin.
RENDER_LOG=$(/usr/bin/log show --last 90s --style compact \
  --predicate 'subsystem == "com.jeremynay.qlmarkdown"' 2>/dev/null)

# E2 (mechanical half): extension actually rendered the sample file
check "E2 sample.md rendered by extension" '[[ "$RENDER_LOG" == *"rendered sample.md"* ]]'

# E4: large file render time < 2000ms
LARGE_MS=$(echo "$RENDER_LOG" | sed -n 's/.*rendered large.md in \([0-9]*\)ms.*/\1/p' | tail -1)
check "E4 large.md rendered in ${LARGE_MS:-?}ms (< 2000)" '[[ -n "$LARGE_MS" && "$LARGE_MS" -lt 2000 ]]'

# E5: invalid UTF-8 rendered with error banner, no crash
check "E5 invalid-utf8.md rendered with banner" '[[ "$RENDER_LOG" == *"rendered invalid-utf8.md"*"banner=true"* ]]'

# --- E7: Gatekeeper / signing ----------------------------------------------------
check "E7 no quarantine xattr"   '! xattr -l "$APP" 2>/dev/null | grep -q com.apple.quarantine'
check "E7 valid code signature"  'codesign --verify --deep --strict "$APP" 2>/dev/null'
# Note: spctl rejects non-notarized builds by design; Gatekeeper only evaluates
# quarantined apps, so "no quarantine + valid Apple Development signature" is the pass bar.
check "E7 signed with Apple Development identity" 'codesign -dvv "$APP" 2>&1 | grep -q "Authority=Apple Development"'

echo ""
echo "$PASS passed, $FAIL failed"
echo "Manual: E2/E3 visual check (Space on tests/fixtures/sample.md, toggle appearance), E8 (sudo cache reset)."
exit $FAIL
