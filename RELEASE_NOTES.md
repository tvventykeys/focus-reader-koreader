# Focus Reader v1.0.1 — Menu close fix

Fixes the menu remaining on screen after selecting a checked reading option, color, or focused-line count. Focus Reader now closes the menu and returns to the book before repainting. **No changes to the rendering/refresh engine, clicker navigation, or settings formats.**

Install by replacing only `focusreader.koplugin/` inside KOReader's `plugins` directory. Back up the old folder first; exit KOReader before replacing it. Tested by Lua syntax checks and mocked TouchMenu callbacks; a device smoke test is still required before announcing it as stable.
