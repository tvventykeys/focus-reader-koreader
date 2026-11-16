# Focus Reader for KOReader

**Read a few lines at a time. Keep your place. Make reading feel less overwhelming.**

Focus Reader is a free, offline KOReader plugin that moves a reading highlight or clear window through your book as you use the usual next/previous page controls — including compatible Bluetooth page-turners. Instead of losing your place on a full page, you can concentrate on the part you want to read. It advances to the next page when you reach the end.

**Free · Open source · Offline · No tracking · No account required**

![Side-by-side Focus Reader modes: Spotlight Focus with book-cover background and Highlight Focus with yellow highlighting](https://github.com/user-attachments/assets/5cbf405e-5908-49bc-aadc-b8dc4caf6e86)

*Left: Spotlight Focus with the current book cover as a background. Right: Highlight Focus with a yellow line highlight. Both examples are from KOReader.*

## Choose how you want to read

- **Highlight Focus** — Gently highlights 1–5 lines using yellow, orange, green, cyan, blue, or pink. Choose a tinted highlight or underline-only presentation where supported.
- **Spotlight: Reading Window** — Keeps your current lines visible while masking text above and below. Masks can be black, white, a custom image, or your current book cover when available.
- **Spotlight: Reading Guide** — Leaves what you've already read visible and masks the text below, like moving a reading guide down the page.
- **Freeform Focus** — A movable clear window for scanned/image-only PDFs or pages without selectable text. Choose a window height from 10% to 75% of the visible reader area; no OCR required.

For text-based books, **Advance by** lets you move one line, one focused group, or one **whole visible paragraph** at a time. EPUB paragraph boundaries are usually more reliable than PDF boundaries, which may be estimated from the page layout. Word-by-word navigation is also available in supported text-based modes, without speech.

## Install and start

**From a KOReader plugin storefront:** Choose **Install** on the Focus Reader listing, then follow that storefront's instructions. If Focus Reader doesn't appear, restart KOReader.

**Manually from GitHub:**

1. Install KOReader first. Focus Reader does not run in Kobo's stock reading app.
2. Get the installable ZIP from the [latest stable release](https://github.com/tvventykeys/focusreader.koplugin/releases/latest), **not** GitHub's automatically generated source archive.
3. Extract the ZIP and copy the `focusreader.koplugin` folder into KOReader's `plugins` directory. On Kobo, use `.adds/koreader/plugins/`.
4. Safely eject the e-reader and fully restart KOReader.
5. Open an EPUB or PDF, then select **Tools → Focus Reader → Start Focus Reader**.

The expected Kobo file path is `.adds/koreader/plugins/focusreader.koplugin/main.lua`. When upgrading a manual install, back up and replace only the plugin folder; your separately stored preferences are preserved.

## Using Focus Reader

With a book open, visit **Tools → Focus Reader** to select your reading mode, highlight color, focused line count, advancement style, or Spotlight mask. Your normal page-forward and page-back actions now step through the focused text or reading window. Reaching the end of a page turns the page; moving backward works too. **Stop Focus Reader** restores normal page turning.

**Want a one-gesture on/off switch?** In KOReader, open **Settings → Taps and gestures → Gesture manager**, choose a gesture, and assign **Reader → Toggle Focus Reader**. The same action can be used with KOReader Profiles, Quick Menus, and compatible ZenOS shortcuts. Choosing Start/Stop from the Focus Reader menu also returns you directly to your book.

### Custom image backgrounds

Make Spotlight Focus your own with a picture instead of a plain black or white mask. On Kobo, copy your chosen image into `.adds/koreader/screensavers/`, then open **Tools → Focus Reader → Spotlight Focus → Mask color** and select your custom image. For transparent PNGs, choose a **black or white background** behind the artwork. You can also use your **current book cover** when available.

These images change only the background around the reading window or guide — **not** your Kobo's sleep screen.

| Custom background — 1 | Custom background — 2 |
|:---:|:---:|
| <img src="https://github.com/user-attachments/assets/0468ced6-1046-4081-a760-f40ad202aabe" alt="Spotlight Focus custom image background, example one" width="220"> | <img src="https://github.com/user-attachments/assets/5bbbafb5-e91a-4bd4-bbe8-e53296e41cc8" alt="Spotlight Focus custom image background, example two" width="220"> |

*Two real Kobo screenshots showing custom backgrounds in Spotlight Focus.*

## Current stable release: v1.2.2

[**Get Focus Reader v1.2.2**](https://github.com/tvventykeys/focusreader.koplugin/releases/tag/v1.2.2) · Released November 16, 2026

- Includes the Toggle Focus Reader gesture/shortcut action and quick return to your book from Start/Stop.
- Includes current-book-cover masks, persistent settings menus, paragraph navigation, Freeform Focus, and image-background options.
- Includes an **experimental** paragraph Reading Window adjustment intended to reduce leftover text fragments on e-ink displays. Physical Kobo/Kindle verification remains pending; some artifacts may persist.
- **Packaging correction:** The older v1.2.1 and v1.2.1-beta.5 installation ZIPs accidentally contained Beta 4-era plugin code. Use the corrected **v1.2.2** stable ZIP instead.

For older changes and technical details, see the [changelog](CHANGELOG.md) and [release notes](https://github.com/tvventykeys/focusreader.koplugin/releases).

## Compatibility and limitations

Focus Reader is for **KOReader**, not the standard Kobo reading app. The plugin was developed and tested interactively on a **Kobo Libra Colour**; features and display refresh behavior may differ across KOReader versions, document layouts, Kindle devices, and other e-ink readers.

Text-aware Highlight and Spotlight modes require usable text positions. PDF paragraph detection is approximate; image-only PDFs should use **Freeform Focus**, which moves a window by fixed amounts instead of tracking recognized words. Freeform does **not** perform OCR. White/image masks and combinations with other display plugins (including PaperDots) may show device-dependent ghosting.

Focus Reader does not provide audio narration, pair Bluetooth devices, or alter the book itself. It is a reading tool, not a medical treatment.

## Privacy, help, and feedback

**Fully offline:** Focus Reader includes no network access, analytics, telemetry, accounts, or upload of book text. It saves only local preferences in KOReader's settings. It does not write annotations or modify your books.

If a feature misbehaves, please report your e-reader model, KOReader version, EPUB/PDF format, steps to reproduce, and any relevant crash-log excerpt. Avoid posting private filenames or copyrighted book pages. Automated Lua tests are available in this repository, but they cannot replace real-device testing.

See [testing notes](TESTING.md) and [the issue tracker](https://github.com/tvventykeys/focusreader.koplugin/issues).

**MIT licensed.** Independent community plugin; not affiliated with KOReader or Kobo.
