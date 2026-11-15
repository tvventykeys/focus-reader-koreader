# Focus Reader for KOReader

Offline focus reading for KOReader. Install this `focusreader.koplugin` folder in KOReader's `plugins` directory, restart KOReader, then open a text-based EPUB or PDF.

Under **Tools → Focus Reader**, choose Highlight Focus or Spotlight Focus (Reading Window / Reading Guide). Both support the **Advance by** controls:
- **One line** (default)
- **Whole focused group** (your chosen 1–5 lines)
- **Whole paragraph** (development preview; highlight or mask the complete paragraph visible on the current page)

Paragraph mode uses CRengine's EPUB document positions where available. For PDFs, paragraph detection is estimated from line layout, so some PDFs may group paragraphs incorrectly. Long paragraphs that run onto another page continue when you turn the page. Word-by-word focus is a separate, mutually exclusive mode.

This is a development preview, not a stable release. For full installation instructions and known device limitations, see the repository README. Licensed MIT; see LICENSE.
