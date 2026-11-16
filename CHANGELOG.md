# Changelog

## v1.2.3-beta.1 — simplified menu preview (2026-11-16)

- Reorganize the Focus Reader main menu into just **Start / Stop Focus Reader**, **Focus mode**, and **Settings**.
- The **Settings** submenu now contains independent folders for **Highlight Focus**, **Spotlight Focus**, and **Freeform Focus**, including when a mode is not selected.
- Move **Advance by** under Highlight and Spotlight options; Freeform continues to use its own window-height navigation.
- Keep image-background color inside the Spotlight/Freeform **Mask background** configuration and the word-navigation diagnostic under **Highlight → Advanced**.
- Preserve existing preferences, highlighting, paragraph/word navigation, custom backgrounds, and Bluetooth/page-turn behavior; no intentional focus-rendering changes.
- Lua and source/ZIP integrity tests must pass for this exact beta tag; device testing of the reorganized menus and gesture discovery is still required.

## v1.2.2 — corrected Beta 5 code integration (pending publication)

- Carry forward the experimental Spotlight Reading Window paragraph-top boundary and nonflashing viewport redraw from Beta 5's original source branch while preserving newer main-branch gesture support.
- Add regression tests for line bounds, backward/forward paragraph navigation, and UI refresh behavior.
- Correct release traceability: the v1.2.1 and v1.2.1-beta.5 attached ZIPs were built from Beta 4-era plugin source despite their release labels.
- Physical Kindle/Kobo verification of the paragraph rendering experiment remains pending.

## v1.2.1-beta.4 — development preview (2026-11-15)

- Settings selections stay open while users change colors, focus sizes, stepping, and masks; Start/Stop still returns to reading.
- Added optional **Current book cover** for Spotlight and Freeform masks using KOReader's in-memory cover API; no cover files are exported, and missing covers fall back to the configured solid backing color.
- Expanded whole-viewport UI recomposition for white and illustrated Spotlight masks to reduce stale PaperDots regions between within-page steps. Does not force a flashing e-ink full refresh or guarantee elimination of hardware ghosting.
- Preserves scanned-PDF Freeform navigation, line/group/paragraph modes, separate user preferences, and normal page turning when stopped.
- Kobo/PaperDots hardware acceptance is still pending.

## v1.2.0 — 2026-11-14

- Introduced optional custom image backgrounds for Spotlight Reading Window and Reading Guide, chosen from the KOReader screensavers folder.
- Added separate black/white backgrounds for transparent PNG artwork; uses alpha compositing to preserve the image's original colors. Visually confirmed on Kobo Libra Colour.
- Preserved existing solid black and white masks and independent line counts.
- Includes 1.1-series word focus, line/block stepping, EPUB/PDF underline options, and safer handling of missing PDF text positions.
- PDF behavior on Kindle Scribe remains community-testing territory; no scanned-PDF OCR.

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

## v1.0.0 — 2026-11-09

First public release candidate based on the privately tested v0.6.5 build.

- Highlight Focus: six selectable gentle text colors, 1–5 lines.
- Spotlight Focus: solid-black Reading Window or Reading Guide, independent 1–5 lines.
- Native CRengine selection for color mode; single smooth UI refresh (no user-facing refresh experiments).
- Regular page-turn inputs are intercepted only during a session; Stop restores normal behavior.
- Source cleanup, compatibility guard for absent native color API, public documentation, license and simulated regression tests.
- Known limitation: some e-ink panels briefly darken during colored highlight changes; no verified hardware fix.

Hardware verification of this exact public ZIP is pending. Do not describe it as tested on other KOReader devices.
