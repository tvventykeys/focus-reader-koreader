## v1.2.1-beta.5 — experimental paragraph-window edge cleanup (2026-11-15)

- In Spotlight Focus **Reading Window** with **whole-paragraph** stepping, eliminate the unnecessary 2-pixel clear strip above the first paragraph line without masking any of the reported text bounds.
- Recompose the full KOReader document viewport on paragraph-window steps using the nonflashing `ui` redraw path to test a possible fix for small residual descender fragments.
- Keep Reading Guide, Highlight Focus, Freeform Focus, line/group stepping, and other existing refresh paths unchanged.
- Add mocked regression tests for the tightened top edge, preserved descender room below the final line, forward/reverse navigation, and whole-viewport UI redraw.
- **Experimental:** Physical Kindle/Kobo confirmation is required; the reported artifacts may have another cause.

## v1.2.1-beta.4 — development preview (2026-11-15)

- Settings selections stay open while users change colors, focus sizes, stepping, and masks; Start/Stop still returns to reading.
- Added optional **Current book cover** for Spotlight and Freeform masks using KOReader's in-memory cover API; no cover files are exported, and missing covers fall back to the configured solid backing color.
- Expanded whole-viewport UI recomposition for white and illustrated Spotlight masks to reduce stale PaperDots regions between within-page steps. Does not force a flashing e-ink full refresh or guarantee elimination of hardware ghosting.
- Preserves scanned-PDF Freeform navigation, line/group/paragraph modes, separate user preferences, and normal page turning when stopped.
- Kobo/PaperDots hardware acceptance is still pending.

# Changelog

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
