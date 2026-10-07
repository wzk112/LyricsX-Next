# LyricsX Next release process

This checklist applies to every public version. The release tag and GitHub asset must correspond to the exact tested source commit.

1. Confirm the current GitHub latest release, branch, worktree status, and intended version/build number. Review all tracked and untracked changes; include every source and test file needed by the app and exclude local dependencies, QA output, and backups.
2. Complete the release gate: `swift test --no-parallel`, targeted native UI and audio lifecycle tests, `git diff --check`, and Flexbar `npm test`/`npm run validate` if its integration changed. Inspect actual app windows and changed user flows. Fix release blocking findings before proceeding.
3. Update `Resources/Info.plist`, `GuideContent` in `Sources/LyricsXApp/FeatureGuide.swift`, the guide upgrade tests, `CHANGELOG.md`, `README.md`, and `docs/releases/vX.Y.Z.md`. Verify an existing installation sees the new in-app update once; a version jump includes intervening pages, while a first install still shows the tutorial. Check that release notes describe only validated behavior.
4. Build a clean release app with `Scripts/build.sh release`. Verify the bundled version/build, architecture, resources, dependency loading, and strict code signature. Launch this exact bundle, confirm settings survive an upgrade, and inspect the changed native flows. The current public distribution uses ad-hoc signing and is not notarized; document this accurately until the signing pipeline changes.
5. Commit the complete source and documentation. Use the full commit SHA for an annotated version tag and GitHub release target. Package the tested app into `LyricsX-Next-X.Y.Z.zip`; confirm the extracted app's plist, executable hash, and signature match the tested bundle. If offering an optional Flexbar plugin asset, run its build/test/validation and identify its independent plugin version and validation limits.
6. Push the commit and tag. Create a **draft** GitHub release from that exact full SHA and upload the verified asset(s). Download the assets from GitHub, compare SHA-256, inspect the extracted app, then publish the draft. Confirm `/releases/latest` points to the new version and the app update check can discover it. Record the tag, commit, tests, signature type, and asset hashes in the release verification notes.

If a release gate cannot be verified, report the specific gap in the notes and decide whether it is acceptable for the optional feature before publication. Do not claim a native permission flow, physical device frame rate, or Apple notarization from simulated tests alone.

## Local installation signing

For local repair builds use `scripts/build-local.sh release`. It uses the existing Apple Development / Developer ID Application certificate when exactly one is available, or an explicitly selected `LYRICSX_SIGN_IDENTITY`. It refuses an ad-hoc fallback. Keep the same bundle identifier and certificate identity across local updates so macOS can recognize existing audio recording permissions. The first migration from an ad-hoc app may require granting the existing system-audio-only permission again; never reset the entire privacy database or add screen recording access just to repair a waveform.

This local signing workflow does not change the public distribution identity or imply notarization. `scripts/build.sh` remains the packaging entry point for the release checklist above.
