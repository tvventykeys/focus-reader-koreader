# Publishing Focus Reader v1.0.1

This is a **public-release candidate** until the exact v1.0.1 ZIP passes the Kobo smoke test in `TESTING.md`.

## Recommended distribution: GitHub Releases

1. Create a **public GitHub repository** named something like `focusreader.koplugin`. Choose a public-facing GitHub account you are comfortable associating with the project.
2. Unzip `Focus-Reader-v1.0.1-source.zip` and upload its contents to the repository root. The plugin directory must be named `focusreader.koplugin` exactly.
3. Add a GitHub repository description such as: `Offline line-by-line reading focus for KOReader: highlight, blackout window, and reading guide.`
4. Optionally add GitHub topics `koreader`, `koreader-plugin`, `ereader`, `reading`, `accessibility`.
5. On your Kobo Libra Colour, install and test the **exact** `Focus-Reader-v1.0.1-koplugin.zip` release asset using the checklist in `TESTING.md`.
6. After that passes, create a GitHub Release with tag `v1.0.1`, using `RELEASE_NOTES.md` as a starting point, and attach `Focus-Reader-v1.0.1-koplugin.zip` and its `.sha256` file from `dist/`.
7. Copy the permanent GitHub Release URL and replace the placeholder in `REDDIT_POST_DRAFT.md`.
8. Post on `r/koreader`, following the current community rules. Consider a short phone demo or screenshots using **your own or public-domain text**, showing Highlight Focus and Spotlight Reading Guide.
9. Collect reports in GitHub Issues. Ask testers for KOReader version, e-reader model, file format, what they expected, what happened, and whether they used a physical button or Bluetooth clicker.

## Important

- The sandbox links in this chat are for transferring release assets to you. Use **GitHub Releases**, not the sandbox URL, as the public download link.
- Do not include screenshots that show your account identifiers, Wi-Fi SSIDs, private book filenames, or purchased copyrighted pages without permission.
- Do not claim this is an official KOReader plugin or a medical treatment.
- Before announcing support for new platforms, obtain a real test report from that platform.
- If you prefer a different public license or contributor credit, edit `LICENSE` before posting the code.
