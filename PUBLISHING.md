# Focus Reader — safe publishing

This repository builds and verifies release ZIPs in GitHub Actions. The **Focus Reader Lua checks** workflow is the recommended publication path.

## What is checked automatically

On pull requests to main and pushes to main, the mocked-koreader job:

1. Runs the Lua 5.1 plugin and geometry regression tests.
2. Runs eight Python integrity-verifier regression tests, including a deliberately wrong ZIP containing older plugin code.
3. Builds the release ZIP from that workflow's checked-out source.
4. Checks that the ZIP includes exactly every file under focusreader.koplugin, with byte-for-byte matching contents, a valid versioned filename, and a correct SHA-256 sidecar file.
5. Uploads only the validated ZIP and checksum as CI artifacts.

On a new pushed version tag (v*), it also verifies that the tag name matches the source VERSION and that the checked-out commit matches the pushed commit. The publishing job runs only after the verification job succeeds. It downloads **the same CI-built files**, verifies them again against the tagged source, then creates a release with both the ZIP and checksum.

- Tags containing a hyphen (such as v1.2.3-beta.1) publish as **prereleases** and are not marked Latest.
- Stable tags (such as v1.2.3) publish as **Latest**.
- A pre-existing release is **never overwritten** by this workflow.
- If any test, package check, version check, or artifact download fails, the automated publication is stopped.
- This pipeline does not establish physical compatibility with Kindle, Kobo, PaperDots or every PDF/EPUB: hardware testing remains separate.

## For a future beta or stable version

1. Make changes on a feature branch. Update VERSION to the exact intended tag, such as v1.2.3-beta.1.
2. Open a pull request to main. Wait for the **Focus Reader Lua checks / mocked-koreader** job to pass; review changes and hardware limitations.
3. Merge the PR. Make sure your local main is current and at the intended release commit.
4. Create and push the tag **on that exact commit**. Do not reuse or force-push an existing release tag. In a clean local clone, for example:

    git pull --ff-only origin main
    git tag v1.2.3-beta.1
    git push origin v1.2.3-beta.1

5. GitHub Actions will automatically run the verification and publish that version if it passes. Use these PowerShell commands to inspect the outcome:

    gh run list -R tvventykeys/focusreader.koplugin -L 5
    gh release view v1.2.3-beta.1 -R tvventykeys/focusreader.koplugin

6. Confirm the ZIP plus SHA256 assets exist. Test the exact released ZIP on KOReader before claiming device compatibility.

### Important limitation

A repository administrator can still manually create a release on GitHub or through gh release create, bypassing Actions. This workflow **gates its own automated publishing path**, not every possible manual publication. To maintain the guarantee, do not upload locally prepared ZIPs directly to releases. Stronger restrictions would require additional GitHub rules or permissions.

## Previously corrected packaging

The v1.2.1-beta.5 and v1.2.1 ZIP attachments mistakenly contained Beta 4-era code. The corrected v1.2.2 release was packaged and checked against its source, and earlier release notes now warn users. Existing tags and assets were preserved.
