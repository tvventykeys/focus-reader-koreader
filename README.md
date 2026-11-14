# Focus Reader for KOReader

**An offline reading focus tool for people who prefer to read a few lines at a time.**

Focus Reader moves a visual focus region down or up as you press KOReader's usual page-forward/page-back controls (including compatible Bluetooth page-turn clickers). At the end of a page it turns to the next page automatically; the reverse button moves back through the lines and pages.

## Modes

- **Highlight Focus** (default): a gentle native text highlight with **Yellow, Orange, Green, Cyan, Blue, or Pink**. Choose **1–5 focused lines**. The shade has a fixed, gentle strength; no flashing/opacity controls are exposed.
- **Spotlight Focus — Reading Window**: text above and below the focused 1–5 lines is masked **solid black by default**, with an optional white mask.
- **Spotlight Focus — Reading Guide**: text above the reading position stays visible; everything below is masked **solid black by default**, with an optional white mask, like moving a sheet of paper down the page. The Spotlight line count is independent of Highlight Focus.

Focus Reader does **not** require a network connection, create annotations, read audio, or send any book text anywhere. It is independent of any narration or book-sync service.

## Installation

1. Install KOReader first. This plugin does not work in the stock Kobo reader app.
2. Download the **Focus-Reader-v1.1.0-koplugin.zip** release asset (not GitHub's automatically generated source ZIP).
3. Extract it. Copy the **`focusreader.koplugin`** folder itself into KOReader's `plugins/` directory. Do not nest the directory inside another ZIP folder.
   - **Kobo:** `.adds/koreader/plugins/` on the connected e-reader.
   - **Other devices:** find the `plugins` directory inside your KOReader data directory; its location varies.
4. Safely eject your device and fully restart KOReader.
5. Open a text-based EPUB or PDF, then go to **Tools → Focus Reader** and choose **Start Focus Reader**.

Expected path (Kobo): `.adds/koreader/plugins/focusreader.koplugin/main.lua`

> Upgrading? Stop Focus Reader, fully exit KOReader, back up your old `focusreader.koplugin` folder, then replace **only that folder**. Settings are stored separately; they are not removed by replacing the plugin directory.

## Controls and settings

**Tools → Focus Reader**

- Start / Stop Focus Reader
- Reading mode: Highlight Focus / Spotlight Focus: Reading Window / Spotlight Focus: Reading Guide
- Highlight Focus: Color, Focused lines (1–5), Tint + underline or Underline only (EPUB/PDF), Word-by-word navigation (no speech)
- Spotlight Focus: Focused lines (1–5), Mask color (Black default / White optional)

Use the same buttons or clicker inputs that already turn pages in KOReader. A click normally moves by one visual line; if you previously selected block movement in an older release, the stored preference is retained. Stop Focus Reader to restore normal page turning.

## Compatibility and known limitations

- **v1.1.0** adds word-by-word navigation, punctuation/whitespace handling, underline-only EPUB/PDF highlighting, and optional white Spotlight masks (black remains default).
- Word navigation groups common contractions and skips standalone whitespace and punctuation; text extraction and geometry can still vary with fonts, document engines, and layouts.
- Text-based PDFs are supported where KOReader exposes the required MuPDF text geometry. Fixed-layout and reflowed PDF behavior may differ. Scanned/image-only PDFs are not OCR'd.
- PaperDots can be used alongside Focus Reader; appearance depends on its own settings and the screen refresh/rendering order. Compatibility on other devices is not guaranteed.
- Tested interactively on Kobo Libra Colour with KOReader during development; mocked Lua regression tests are not a substitute for testing every document and device.
- Works with page-turn controls recognized by KOReader; it does not pair/configure Bluetooth hardware or handle audio.
- No network access, telemetry, or book-text upload.

## Privacy and safety

No network code, telemetry, user identifiers, tokens, analytics, or cloud services. It writes only Focus Reader preferences to KOReader's settings directory. It does not write into the book, save highlights, delete files, or change Bluetooth/audio settings. It's an independent community plugin, not an official KOReader feature.

## Feedback and troubleshooting

If Focus Reader does not appear, confirm the exact `focusreader.koplugin/main.lua` path, restart KOReader and open an EPUB. If you see an error, include the KOReader version, device, book format, reproduction steps, and the relevant KOReader crash-log excerpt. Please avoid posting copyrighted book pages or personal filenames if you don't want them public.

## Development and releases

The installable release ZIP contains `focusreader.koplugin/`. Source and tests are here in this repository. The `tests/` directory provides mocked Lua checks; those **do not replace hardware tests**. See [TESTING.md](TESTING.md) and [CHANGELOG.md](CHANGELOG.md).

License: MIT. This project is not affiliated with KOReader or Kobo.
