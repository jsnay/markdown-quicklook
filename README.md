# QLMarkdown

A native macOS Quick Look extension that renders `.md` / `.markdown` files as styled HTML. Press Space on a Markdown file in Finder and get a GitHub-flavored preview with light/dark mode support.

## Requirements

- macOS 13+
- Xcode 15+ with command line tools
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- An Apple Development signing certificate (free or paid account)

## Build & install

```bash
./build.sh            # auto-detects your team ID
# or: ./build.sh TEAMID1234
```

This generates the Xcode project, builds Release, installs to `/Applications`, and launches the container app to register the extension. If previews don't appear, enable the extension under System Settings → General → Login Items & Extensions → Quick Look.

## Architecture

```
project.yml                       XcodeGen spec (generates QLMarkdown.xcodeproj)
QLMarkdownApp/                    Minimal container app — exists to register the extension
  QLMarkdownApp.swift
QLMarkdownExtension/              The Quick Look preview extension
  PreviewViewController.swift     QLPreviewingController; displays HTML in WKWebView
  MarkdownRenderer.swift          cmark-gfm parsing (tables, task lists, strikethrough, autolinks)
  style.css                       GitHub-flavored CSS, prefers-color-scheme aware
tests/
  fixtures/sample.md              Visual eval fixture
  run-evals.sh                    Automated checks (registration, UTI routing, perf, signing)
```

Markdown parsing uses `cmark-gfm` via SPM (`swiftlang/swift-cmark`, `gfm` branch). Invalid UTF-8 and parse failures degrade to readable text with a warning banner instead of a blank panel.

## Evals

```bash
./tests/run-evals.sh
```

Automated: registration (E1), UTI coverage (E6), large-file performance (E4), invalid UTF-8 (E5), Gatekeeper/signing (E7). Manual: visual rendering (E2), live dark-mode switching (E3), cache-reset regression (E8, requires sudo).

## Notes

- Signed with an Apple Development certificate via automatic signing (more reliable for Quick Look extension registration than ad-hoc).
- The generated `.xcodeproj` is gitignored; `project.yml` is the source of truth.
