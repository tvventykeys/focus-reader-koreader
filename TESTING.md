# Beta 4 acceptance tests — Kobo hardware needed

This checklist supplements the existing mocked Lua checks; mark hardware results only after running the packaged Beta 4 ZIP on a Kobo.

- [ ] Change Highlight color, focused lines, Spotlight mask color, group/paragraph stepping and Freeform height; each setting should preserve the currently open menu panel and update its checkmark.
- [ ] Start / Stop Focus Reader; the menu should close and clicker/page-turn behavior should remain correct.
- [ ] Under **Spotlight Focus → Mask color**, select **Current book cover (when available)** on an EPUB with a known cover; verify the cover fills masked regions only and the reading window stays clear.
- [ ] Try the same option on a PDF or EPUB without cover art; verify the black/white fallback without a crash, stall or repeated file access.
- [ ] Switch between custom PNG, book cover, solid white and solid black. Rotate the device, close/open a different book, and restart KOReader; verify masks and settings are not borrowed from the previous book.
- [ ] With PaperDots enabled, advance and reverse **whole groups** inside a page using white Spotlight Reading Window and Reading Guide; compare stale dots with Beta 3.
- [ ] Repeat with PaperDots disabled, with custom image / book-cover masks, and with Freeform Focus on scanned PDFs.
- [ ] Check that the full-viewport redraw does not cause disruptive flashes or excessive lag; visible e-ink ghosting may still require device-level full-refresh tuning.

## Prior testing guidance

# Testing and compatibility

## v1.1.0 release verification

Use a Kobo Libra Colour (the known working device) and a plain EPUB:

- [ ] Install the v1.1.0 release ZIP and confirm **Tools → Focus Reader** appears.
- [ ] Choose a color, checked reading mode, and focused-line count. Each choice should close the menu and return directly to the book (no extra middle tap).
- [ ] Start/Stop from the menu: the menu should close before the page repaints.
- [ ] Start Highlight Focus: verify yellow, 1–5 lines, color changes and clicker down/up.
- [ ] Move past the last line: confirm forward page-turn. Move backward past the first line.
- [ ] Select Spotlight Focus → Reading Window: check solid-black above/below, 1–5 lines.
- [ ] Select Spotlight Focus → Reading Guide: check the lower black "sheet of paper" boundary.
- [ ] Switch back to Highlight Focus and stop; confirm normal page-turn controls restored.
- [ ] Restart KOReader; confirm no auto-start, settings retained, and no error log.
- [ ] Test text-based fixed-layout and reflowed PDFs, including underline-only mode; scanned/image-only PDFs must fail safely.
- [ ] Verify word navigation skips punctuation-only boxes, preserves contractions, and moves one word per click.
- [ ] Verify white and black Spotlight masks with PaperDots enabled and disabled.

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

## Additional device and format regression matrix

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
