# Testing and compatibility

## Before publishing this as stable v1.0.1

Use a Kobo Libra Colour (the known working device) and a plain EPUB:

- [ ] Install the v1.0.1 release ZIP and confirm **Tools → Focus Reader** appears.
- [ ] Choose a color, checked reading mode, and focused-line count. Each choice should close the menu and return directly to the book (no extra middle tap).
- [ ] Start/Stop from the menu: the menu should close before the page repaints.
- [ ] Start Highlight Focus: verify yellow, 1–5 lines, color changes and clicker down/up.
- [ ] Move past the last line: confirm forward page-turn. Move backward past the first line.
- [ ] Select Spotlight Focus → Reading Window: check solid-black above/below, 1–5 lines.
- [ ] Select Spotlight Focus → Reading Guide: check the lower black "sheet of paper" boundary.
- [ ] Switch back to Highlight Focus and stop; confirm normal page-turn controls restored.
- [ ] Restart KOReader; confirm no auto-start, settings retained, and no error log.
- [ ] Test an unsupported PDF/image page and verify plugin does not interfere.

After these pass, make a GitHub release from this commit and share the **release asset** URL. Don't claim Kindle, PocketBook, Android, or other Kobo models work until tested.

## Automated checks

If `lua`/`luajit` is installed, run from the repository root:

```sh
lua tests/test_plugin.lua
lua tests/test_logic.lua
```

The packaging command (Python 3):

```sh
python3 scripts/build_release.py
```

This produces the installable ZIP in `dist/`. The tests mock KOReader API calls and validate behavior; they do not emulate an actual e-ink controller.

## Development: Reddit requests (not stable)

### White Spotlight and PaperDots

- [ ] Confirm legacy settings (no `spotlight_mask_color`) still paint black.
- [ ] Change Spotlight → Mask color → White; verify both Reading Window and Reading Guide.
- [ ] Restart KOReader; confirm white preference persists, but Focus Reader does not auto-start.
- [ ] Enable PaperDots with each style (Random, Newsprint, Fibers, Linen), testing both "Only inside books" and "Hide dots on menus".
- [ ] Inspect white masked regions for dots and ensure the focused text remains unobstructed.
- [ ] Change focus with clicker, page forward/back, open/close menu, and stop. Watch for stale dots, missing refreshes, or texture painted over menus.
- [ ] Disable PaperDots and confirm Focus Reader's normal black and white rendering is unchanged.

PaperDots paints only near-white pixels just before screen refresh; its current source uses a threshold of 0xF0. This is a compatibility hypothesis, not a verified integration. Do not change PaperDots' source or intercept its hooks without a demonstrated failure.

### Word-by-word focus

- [ ] Verify reliable word boundaries and exact rendered coordinates from the active KOReader engine; test punctuation, wrapped lines, hyphenation, mixed direction, and page boundaries.
- [ ] Confirm manual clicker forward/backward works before considering any automatic pacing.
- [ ] Ensure existing line and block modes remain unchanged.

### PDF

- [ ] Identify fixed-layout PDF backend and whether it provides text geometry compatible with the plugin.
- [ ] Test reflowed text PDF separately from fixed-layout PDF.
- [ ] Show a clear unsupported message for scanned/image-only PDFs; no OCR is included.
- [ ] Verify that opening unsupported documents never intercepts page-turn controls.
