# LyricsX Next project guidance

## Release rule

Every requested release must include a release quality pass before publication. Check the changed features in the real macOS app where possible, run the full Swift test suite and relevant Flexbar tests, and fix release blocking regressions before packaging.

For every version, update the app version and build number, the in-app update pages in `Sources/LyricsXApp/FeatureGuide.swift`, `CHANGELOG.md`, the matching `docs/releases/vX.Y.Z.md` note, and the current version links in `README.md`. Add or update upgrade tests for a one-time in-app introduction. Do not publish a version with a stale or empty in-app change log.

Follow `docs/RELEASING.md` for packaging, signature, archive, GitHub release, and downloaded asset verification. State validation limits honestly, particularly for audio capture permissions, display frame rate, and physical Flexbar output.
