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
2. Download the **Focus-Reader-v1.0.1-koplugin.zip** release asset (not GitHub's automatically generated source ZIP).
3. Extract it. Copy the **`focusreader.koplugin`** folder itself into KOReader's `plugins/` directory. Do not nest the directory inside another ZIP folder.
   - **Kobo:** `.adds/koreader/plugins/` on the connected e-reader.
   - **Other devices:** find the `plugins` directory inside your KOReader data directory; its location varies.
4. Safely eject your device and fully restart KOReader.
5. Open a reflowable book, such as EPUB, then go to **Tools → Focus Reader** and choose **Start Focus Reader**.

Expected path (Kobo): `.adds/koreader/plugins/focusreader.koplugin/main.lua`

> Upgrading? Stop Focus Reader, fully exit KOReader, back up your old `focusreader.koplugin` folder, then replace **only that folder**. Settings are stored separately; they are not removed by replacing the plugin directory.

## Controls and settings

**Tools → Focus Reader**

- Start / Stop Focus Reader
- Reading mode: Highlight Focus / Spotlight Focus: Reading Window / Spotlight Focus: Reading Guide
- Highlight Focus: Color, Focused lines (1–5)
- Spotlight Focus: Focused lines (1–5), Mask color (Black default / White optional)

Use the same buttons or clicker inputs that already turn pages in KOReader. A click normally moves by one visual line; if you previously selected block movement in an older release, the stored preference is retained. Stop Focus Reader to restore normal page turning.

## Compatibility and known limitations

- Developed and previously tested on **Kobo Libra Colour with KOReader** (private v0.6.x versions). **The public v1.0.1 package needs an installation smoke test on the device before public announcement.**
- Designed for **reflowable documents supported by KOReader's CRengine** (for example EPUB), not PDF or image-only pages.
- Other KOReader devices/builds are **not tested**. Color selection may not be available everywhere; Spotlight Focus requires the underlying text-position API too. Grayscale screens will not show the palette as color.
- E-ink hardware may briefly darken colored highlights during refresh. Focus Reader uses the working non-flashing UI refresh; it cannot guarantee perfectly transition-free updates on every e-ink panel.
- Existing native text selections or another plugin that controls selections can conflict. Stop one focus/highlighting session before using the other.
- Works with **page-turn controls already recognized by KOReader**; it does not pair/configure Bluetooth hardware or handle audio.
- Does not diagnose or treat ADHD, dyslexia, or other medical conditions; it is a reading preference/accessibility aid.

## Privacy and safety

No network code, telemetry, user identifiers, tokens, analytics, or cloud services. It writes only Focus Reader preferences to KOReader's settings directory. It does not write into the book, save highlights, delete files, or change Bluetooth/audio settings. It's an independent community plugin, not an official KOReader feature.

## Feedback and troubleshooting

If Focus Reader does not appear, confirm the exact `focusreader.koplugin/main.lua` path, restart KOReader and open an EPUB. If you see an error, include the KOReader version, device, book format, reproduction steps, and the relevant KOReader crash-log excerpt. Please avoid posting copyrighted book pages or personal filenames if you don't want them public.

## Development and releases

The installable release ZIP contains `focusreader.koplugin/`. Source and tests are here in this repository. The `tests/` directory provides mocked Lua checks; those **do not replace hardware tests**. See [TESTING.md](TESTING.md) and [CHANGELOG.md](CHANGELOG.md).

License: MIT. This project is not affiliated with KOReader or Kobo.


## Development branch: accessibility requests (not a release)

The `feature/spotlight-white-mask` branch adds optional white masking to both Spotlight layouts while retaining black as the default. This is **unverified on hardware**.

Additional requests under investigation, **not implemented yet**:

- **Word-by-word focus without speech:** requires verified word-level geometry and text selection APIs, including wrapped lines and bidirectional text; do not approximate positions with character widths.
- **PDF / reflowed PDF:** current registration and navigation require rolling CRengine document APIs. KOReader PDF engines may not expose compatible text positions; image-only PDFs require OCR, which this plugin does not perform. Do not enable support without testing both fixed-layout and reflowed PDFs.
- **PaperDots:** white mask drawing can cover dots painted earlier. Integration requires checking PaperDots rendering order and whether it exposes a supported overlay hook. Do not claim compatibility until both plugins are tested together.

The development branch must pass Lua regression checks and a real KOReader/Kobo smoke test before packaging or release.
