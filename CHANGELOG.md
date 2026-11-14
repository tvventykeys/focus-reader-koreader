# Changelog

## v1.1.0 — 2026-11-14

- Added word-by-word navigation without text-to-speech, including regression fixes for spaces, punctuation, curly quotes, and contractions.
- Added PDF focus support using text geometry where available, including readable tint/underline and underline-only styles.
- Added underline-only Highlight Focus for EPUB as well as PDF.
- Added optional white Spotlight masks while retaining black as the default.
- Added read-only word navigation diagnostics and expanded Lua regression checks.
- PaperDots can be used independently; exact overlay appearance depends on device and settings.
- Scanned PDFs without selectable text remain unsupported; cross-device compatibility is not guaranteed.

## v1.0.1 — 2026-11-09

- **Fixed menu staying open after choosing a Focus Reader setting.** KOReader's checked entries are normally persistent; Focus Reader now explicitly closes the menu before applying reading mode, color or focused-line changes.
- Start/Stop closes the menu before updating the page as well.
- All highlighting, blackout, smooth refresh, settings persistence and clicker navigation behavior otherwise unchanged.
- Tested against KOReader TouchMenu callback semantics with mocked menu-close tests; physical Kobo verification pending.

# Changelog

## v1.0.0 — 2026-11-09

First public release candidate based on the privately tested v0.6.5 build.

- Highlight Focus: six selectable gentle text colors, 1–5 lines.
- Spotlight Focus: solid-black Reading Window or Reading Guide, independent 1–5 lines.
- Native CRengine selection for color mode; single smooth UI refresh (no user-facing refresh experiments).
- Regular page-turn inputs are intercepted only during a session; Stop restores normal behavior.
- Source cleanup, compatibility guard for absent native color API, public documentation, license and simulated regression tests.
- Known limitation: some e-ink panels briefly darken during colored highlight changes; no verified hardware fix.

Hardware verification of this exact public ZIP is pending. Do not describe it as tested on other KOReader devices.
