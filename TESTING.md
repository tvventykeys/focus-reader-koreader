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
