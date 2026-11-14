# Focus Reader v1.2.0 — Custom Backgrounds & Better Focus

A feature-packed stable update to the offline KOReader reading-focus plugin.

## Highlights

- **Custom image backgrounds in Spotlight Focus:** Choose a local image from KOReader's `screensavers` folder for Reading Window or Reading Guide.
- **Black or white behind transparent PNGs:** Transparent pixels show your selected backing color while the illustration stays intact. Both choices were visually tested on a Kobo Libra Colour.
- **All the original masks:** Solid black and solid white remain available, and the active reading lines are left readable.
- **More ways to follow text:** Word-by-word navigation without audio, more robust punctuation/contraction handling, and customizable line/block stepping.
- **EPUB/PDF underline options:** Underline-only highlighting, plus PDF tint-and-underline where text geometry is available.
- **More robust PDFs:** Defensive behavior if text positions disappear during rotation, reflow, or diagram-heavy pages, restoring normal page turning rather than leaving a focus session stuck.

## Installation

1. Download **Focus-Reader-v1.2.0-koplugin.zip** from this release's Assets section (not GitHub's Source code ZIP).
2. Fully exit KOReader.
3. Extract the archive and replace `.adds/koreader/plugins/focusreader.koplugin` on Kobo with the included `focusreader.koplugin` folder. Back up the previous folder first.
4. Start KOReader and open **Tools → Focus Reader**.

Your saved settings live outside the plugin folder and should remain intact.

## Using custom backgrounds

Go to **Spotlight Focus → Mask color → Choose custom image...** and pick an image in KOReader's screensavers directory. Then select **Spotlight Focus → Image background color → Black** or **White**. The background only covers masked parts of the reading page; the current reading lines remain visible.

## Compatibility notes

- Alpha compositing for transparent PNG custom images has been visually verified on **Kobo Libra Colour**.
- Text-based PDF support depends on KOReader's available text geometry. Kindle Scribe landscape/reflow verification is **still pending**. Scanned PDFs are not OCR'd.
- This is a community plugin and is not affiliated with KOReader or Kobo. No internet connection, telemetry, or book-text upload is required.
