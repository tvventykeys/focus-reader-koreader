# Focus Reader for KOReader

Offline focus reading for KOReader. Install this `focusreader.koplugin` folder in KOReader's `plugins` directory, restart KOReader, then open a text-based EPUB or PDF.

Under **Tools → Focus Reader**, choose Highlight Focus, Spotlight Focus (Reading Window / Reading Guide), or **Freeform Focus (no text needed)**. The text-based modes support the **Advance by** controls:
- **One line** (default)
- **Whole focused group** (your chosen 1–5 lines)
- **Whole paragraph** (development preview; highlight or mask the complete paragraph visible on the current page)

**Freeform Focus** is designed for scanned/image-only PDFs and other pages without selectable text. It makes a clear full-width window and covers the page above and below it. Configure **Freeform Focus → Window height** with 10%, 15%, 20%, 25%, 30%, 40%, 50% or 75% of page height. Your page-turn controls move the window down/up one window height and continue onto the next or previous page. Existing Spotlight black/white/custom-image masks apply. It does not use OCR or text positions.

Paragraph mode uses CRengine's EPUB document positions where available. For PDFs, paragraph detection is estimated from line layout, so some PDFs may group paragraphs incorrectly. Long paragraphs that run onto another page continue when you turn the page. Word-by-word focus is a separate, mutually exclusive mode.

Freeform is a development preview and has not been hardware-tested on all Kobo/PDF layouts. The stable release remains v1.2.0. This is not a stable release. For full installation instructions and known device limitations, see the repository README. Licensed MIT; see LICENSE.
