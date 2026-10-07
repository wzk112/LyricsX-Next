# LyricsX Next project guidance

## Local installation rule

Use `scripts/build-local.sh release` for local repair installations and keep the same code-signing identity across updates. Do not silently fall back to ad-hoc signing: its changing designated requirement can invalidate the system-audio recording permission used by the waveform. Back up the installed app and verify the final bundle's signature and hash. Public release packaging still follows `docs/RELEASING.md`.

## Release rule

Every requested release must include a release quality pass before publication. Check the changed features in the real macOS app where possible, run the full Swift test suite and relevant Flexbar tests, and fix release blocking regressions before packaging.

For every version, update the app version and build number, the in-app update pages in `Sources/LyricsXApp/FeatureGuide.swift`, `CHANGELOG.md`, the matching `docs/releases/vX.Y.Z.md` note, and the current version links in `README.md`. Add or update upgrade tests for a one-time in-app introduction. Do not publish a version with a stale or empty in-app change log.

Follow `docs/RELEASING.md` for packaging, signature, archive, GitHub release, and downloaded asset verification. State validation limits honestly, particularly for audio capture permissions, display frame rate, and physical Flexbar output.

Write release notes and in-app introductions in plain feature language. List each important feature's settings location and provide working controls in the introduction where appropriate. Illustrations must use the actual app components or real macOS screenshots, with demonstrations identified accurately. Keep local repair notes separate from published release history until packaging the next version.
