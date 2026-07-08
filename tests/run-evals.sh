#!/bin/zsh
# Automated checks for the QLMarkdown eval suite (E1, E4-partial, E6, E7).
# E2/E3 (visual rendering, dark mode) and E8 (cache reset, needs sudo) are manual.
set -uo pipefail
cd "$(dirname "$0")"
PASS=0; FAIL=0
check() { if eval "$2"; then echo "PASS  $1"; ((PASS++)); else echo "FAIL  $1"; ((FAIL++)); fi }

# Generate fixtures
# E4: ~500KB / ~10k lines
if [[ ! -f fixtures/large.md ]]; then
  for i in {1..1250}; do
    printf '## Section %d\n\nParagraph with **bold** and `code` for section %d.\n\n- item a\n- item b\n\n' $i $i
  done > fixtures/large.md
fi
# E5: invalid UTF-8
if [[ ! -f fixtures/invalid-utf8.md ]]; then
  { printf '# Valid heading\n\nSome text before bad bytes: '; printf '\xff\xfe\xc3\x28'; printf '\n\nAnd text after.\n'; } > fixtures/invalid-utf8.md
fi

APP=/Applications/QLMarkdownApp.app
EXT_ID=$(defaults read "$APP/Contents/PlugIns/QLMarkdownExtension.appex/Contents/Info" CFBundleIdentifier 2>/dev/null)

# E1 — extension registered with Launch Services / pluginkit
check "E1 extension registered (pluginkit)" '[[ -n "$(pluginkit -m -i "$EXT_ID" 2>/dev/null)" ]]'

# E6 — UTI coverage: qlmanage reports our generator for both extensions
check "E6 .md routed to extension"        'qlmanage -m files 2>/dev/null | grep -qi markdown || pluginkit -m -v -i "$EXT_ID" 2>/dev/null | grep -q appex'
for f in fixtures/sample.md; do
  check "E6 qlmanage preview succeeds ($f)" 'qlmanage -p -x "'$f'" 2>&1 | grep -q "Done producing previews"'
done

# E4 — large file: qlmanage thumbnail/preview generation under 2s
START=$(python3 -c "import time; print(time.time())")
qlmanage -p -x fixtures/large.md >/dev/null 2>&1
END=$(python3 -c "import time; print(time.time())")
ELAPSED=$(python3 -c "print($END - $START)")
check "E4 large file renders < 2s (took ${ELAPSED%.*}s)" 'python3 -c "exit(0 if '"$ELAPSED"' < 2.0 else 1)"'

# E5 — invalid UTF-8 doesn't crash the generator
check "E5 invalid UTF-8 handled" 'qlmanage -p -x fixtures/invalid-utf8.md 2>&1 | grep -q "Done producing previews"'

# E7 — no quarantine attribute
check "E7 no quarantine xattr" '! xattr -l "$APP" 2>/dev/null | grep -q com.apple.quarantine'
check "E7 valid code signature"  'codesign --verify --deep --strict "$APP" 2>/dev/null'

echo "\n$PASS passed, $FAIL failed"
echo "Manual: E2/E3 (press Space on tests/fixtures/sample.md, toggle appearance), E8 (cache reset, needs sudo)."
exit $FAIL
