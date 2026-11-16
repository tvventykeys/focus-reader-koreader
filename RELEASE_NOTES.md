# Focus Reader v1.2.3-beta.1 — Cleaner Menus

**Beta preview for KOReader testers.** The current recommended stable release remains v1.2.2.

## What's improved

- **Three main options:** Start/Stop Focus Reader, Focus mode, and Settings.
- **Settings for every mode:** Configure Highlight, Spotlight or Freeform without switching away from the current mode.
- **More logical submenus:** Advance by lives inside Highlight and Spotlight. Freeform has its own window-height control.
- **Less clutter:** Custom-image backing color is grouped inside mask options; the word diagnostic is under Highlight → Advanced.
- **Everything else preserved:** Color highlighting, Spotlight, scanned-PDF Freeform, paragraph/word stepping, backgrounds, saved preferences and page controls.

## Please test on Kobo

1. Open a book and choose **Tools → Focus Reader**. Confirm the three-item main menu.
2. Set a mode, then change settings in a different mode's folder. Confirm the selected mode does not change.
3. Confirm **Start/Stop** returns immediately to the book, and colors, line counts, masks and backgrounds still work.
4. Try an existing Bluetooth page-turner and, if available, the **Toggle Focus Reader** gesture action.
5. Report your device, KOReader version, and any menu, ghosting or page-turn problems.

**Important:** This beta is not yet verified on physical devices. The gesture-action discoverability issue is not claimed fixed by this menu-only update.

## Installation

Use the **installable ZIP attached to this beta release** (not GitHub's source-code ZIP). Close KOReader, back up the old `focusreader.koplugin` folder, replace that folder in `.adds/koreader/plugins/` on Kobo, and fully restart KOReader. Your saved preferences live outside the plugin folder.

The beta ZIP is generated and integrity-verified by GitHub Actions from the exact tagged source commit; do not upload a manually assembled ZIP in its place.
