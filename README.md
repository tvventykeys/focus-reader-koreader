# Focus Reader for KOReader

**An offline reading focus tool for people who prefer to read a few lines at a time.**

Focus Reader moves a visual focus region down or up as you press KOReader's usual page-forward/page-back controls (including compatible Bluetooth page-turn clickers). At the end of a page it turns to the next page automatically; the reverse button moves back through the lines and pages.

## Modes

- **Highlight Focus** (default): a gentle native text highlight with **Yellow, Orange, Green, Cyan, Blue, or Pink**. Choose **1–5 focused lines**. The shade has a fixed, gentle strength; no flashing/opacity controls are exposed.
- **Spotlight Focus — Reading Window**: text above and below the focused 1–5 lines is masked **solid black by default**, with an optional white mask or custom image background.
- **Spotlight Focus — Reading Guide**: text above the reading position stays visible; everything below is masked **solid black by default**, with an optional white mask or custom image background, like moving a sheet of paper down the page. The Spotlight line count is independent of Highlight Focus.
- **Freeform Focus (development preview)**: a text-independent reading window for scanned/image-only PDFs and other pages where text positions are unavailable. It masks the page above and below a clear, full-width window whose height can be 10%, 15%, 20%, 25%, 30%, 40%, 50% or 75% of the visible reader viewport. Each forward/back click advances one window height. At the bottom or top it turns the real document page, and previous-page navigation starts from the bottom. It reuses the existing Spotlight black, white and custom-image mask settings.

### Paragraph Focus (development preview)

Choose **Tools → Focus Reader → Advance by → Whole paragraph** to focus one visible
paragraph at a time. Next/previous controls move between paragraphs instead of
advancing 1–5 lines. This works in Highlight Focus, Spotlight Reading Window,
and Spotlight Reading Guide. The active region grows to include the whole
paragraph **visible on the current page**, even if it is longer than five lines.
If a paragraph continues onto the next page, normal page turning reveals its
next visible portion; it cannot be displayed across two pages simultaneously.

For EPUB, Focus Reader uses CRengine text-position (XPointer) paragraph elements
when available. For PDFs, which usually do not expose semantic paragraph tags,
it estimates boundaries from spacing, indentation and short preceding lines.
Therefore PDF paragraphs may occasionally be joined or separated incorrectly.
Unlike Freeform Focus, paragraph mode needs extractable text. Paragraph mode and
word-by-word mode are mutually exclusive; choosing one disables the other.

Focus Reader does **not** require a network connection, create annotations, read audio, or send any book text anywhere. It is independent of any narration or book-sync service.

## Installation

1. Install KOReader first. This plugin does not work in the stock Kobo reader app.
2. Download the **Focus-Reader-v1.2.0-koplugin.zip** release asset (not GitHub's automatically generated source ZIP).
3. Extract it. Copy the **`focusreader.koplugin`** folder itself into KOReader's `plugins/` directory. Do not nest the directory inside another ZIP folder.
   - **Kobo:** `.adds/koreader/plugins/` on the connected e-reader.
   - **Other devices:** find the `plugins` directory inside your KOReader data directory; its location varies.
4. Safely eject your device and fully restart KOReader.
5. Open an EPUB or PDF, then go to **Tools → Focus Reader** and choose **Start Focus Reader**. For scanned/image-only PDFs, choose **Reading mode → Freeform Focus (no text needed)** before starting.

Expected path (Kobo): `.adds/koreader/plugins/focusreader.koplugin/main.lua`

> Upgrading? Stop Focus Reader, fully exit KOReader, back up your old `focusreader.koplugin` folder, then replace **only that folder**. Settings are stored separately; they are not removed by replacing the plugin directory.

## Controls and settings

**Tools → Focus Reader**

- Start / Stop Focus Reader
- Reading mode: Highlight Focus / Spotlight Focus: Reading Window / Spotlight Focus: Reading Guide / **Freeform Focus (no text needed)**
- Highlight Focus: Color, Focused lines (1–5), Tint + underline or Underline only (EPUB/PDF), Word-by-word navigation (no speech)
- Advance by: One line / Whole focused group / **Whole paragraph** (paragraph mode overrides the fixed line count)
- Spotlight Focus: Focused lines (1–5), Mask color (Black / White / Custom image / **Current book cover**), Choose custom image from KOReader's screensavers directory, Image background color (Black / White). Transparent PNG areas and unavailable book covers show the selected background color without altering the artwork.
- Freeform Focus: **Window height** as a percentage of the visible page. The same Spotlight mask color/image settings also apply to Freeform; it always uses a moving window, not the Reading Guide.

Use the same buttons or clicker inputs that already turn pages in KOReader. A click normally moves by one visual line; the chosen advancement mode is stored across sessions. Stop Focus Reader to restore normal page turning.

## What's new in v1.2.1 Beta 4

- Focus Reader setting choices stay open so you can make several adjustments without reopening the menu; Start/Stop still returns to the book.
- **Current book cover (when available)** is an optional Spotlight / Freeform mask background. The cover is fetched in memory from KOReader; no book image is exported to disk.
- White and image-based Spotlight masks now request a full reader-viewport UI recomposition on each step to address stale PaperDots pixels. This is **not** an e-ink flashing full refresh, and real Kobo testing is required.

## What's new (unreleased Freeform Focus preview)

- Optional image-only-PDF reading mode without OCR, paragraph lookup or text positions.
- Adjustable percentage-height clear window that advances with existing page-turn controls.
- Works across PDF page boundaries in either direction; remembers its own window size separately from line/paragraph settings.
- Full-viewport smooth redraws to reduce stale mask artifacts (hardware verification pending).

## What's new (paragraph beta)

- Paragraph-aware EPUB highlighting and clicker navigation, with variable-length focus windows.
- Layout-based paragraph fallback for text-based PDFs.
- Existing line and group navigation remain selectable.

## What's new in v1.2.0

- Custom screensaver images as Spotlight masks, including independently selectable black or white backgrounds behind transparent PNG artwork.
- Reading Window and Reading Guide continue to keep the active lines clear, and previous black/white solid masks are still supported.
- Word-by-word navigation, block stepping, and highlight/underline choices added during the 1.1 series.
- More defensive PDF geometry handling during reflow, rotation, and pages with missing selectable text.

## Compatibility and known limitations

- **v1.2.0** brings the new image-background options and all v1.1 improvements together. Transparency rendering has been visually verified on a Kobo Libra Colour; PDF compatibility on a Kindle Scribe is still awaiting confirmation.
- Word navigation groups common contractions and skips standalone whitespace and punctuation; text extraction and geometry can still vary with fonts, document engines, and layouts.
- Text-based PDF Highlight/Spotlight still relies on MuPDF text geometry. Fixed-layout and reflowed PDF behavior may differ. Freeform Focus works without text geometry, including on scanned/image-only pages; it does not OCR them or follow page content automatically. The reading band covers the reader viewport, not a detected PDF text column.
- PaperDots can be used alongside Focus Reader; Beta 4 makes an experimental UI redraw change for white/illustrated masks, but physical ghosting and PaperDots' own refresh behavior remain hardware-dependent.
- Tested interactively on Kobo Libra Colour with KOReader during development; mocked Lua regression tests are not a substitute for testing every document and device.
- Works with page-turn controls recognized by KOReader; it does not pair/configure Bluetooth hardware or handle audio.
- No network access, telemetry, or book-text upload.

## Privacy and safety

No network code, telemetry, user identifiers, tokens, analytics, or cloud services. It writes only Focus Reader preferences (including the selected local image path) to KOReader's settings directory. It does not write into the book, save highlights, delete files, or change Bluetooth/audio settings. It's an independent community plugin, not an official KOReader feature.

## Feedback and troubleshooting

If Focus Reader does not appear, confirm the exact `focusreader.koplugin/main.lua` path, restart KOReader and open an EPUB. If you see an error, include the KOReader version, device, book format, reproduction steps, and the relevant KOReader crash-log excerpt. Please avoid posting copyrighted book pages or personal filenames if you don't want them public.

## Development and releases

The installable release ZIP contains `focusreader.koplugin/`. Source and tests are here in this repository. The `tests/` directory provides mocked Lua checks; those **do not replace hardware tests**. See [TESTING.md](TESTING.md) and [CHANGELOG.md](CHANGELOG.md).

License: MIT. This project is not affiliated with KOReader or Kobo.
