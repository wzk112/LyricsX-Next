# 2.0.35 (267) validation

Baseline: public `v2.0.34` / build 258 (`135edc6fefa93c98247bab25a9a50339331b258c`). Tested on an Apple-silicon Mac with a 120 Hz display, 2026-09-23.

## Automated checks

- Release configuration, serial full suite: 312 tests passed (98 services, 39 core, 175 app).
- After the final metadata spacing and guide HDR-scope edits, all 13 guide/upgrade tests passed again; the final full run additionally covers the demo-clock correction below.
- Opt-in native suite: all four tests passed, including two light/dark drawing-cadence cases, EDR lifecycle, animated window height and all settings/guide layouts.
- Real `MainView` window at 1040 × 720 and 820 × 600: the playback button stays within 0.5 pt of its starting vertical position through long/short titles, missing lyrics, timed-lyric arrival and delayed album information. Each track transition samples 26 frames.
- Migration covers public glass/frosted settings, legacy dark and local pet-glass values; preserves fonts, colors, sources, disabled options, lyric overrides and window position. Independent glass tint migration is idempotent.
- Guide history covers fresh installs, pre-guide installs, version jumps, build-258 receipts, manual replay and one automatic presentation per edition. Demo preferences and playback are isolated from the user's session.
- The scroll-view demo runs while visible, pauses when hidden and resumes. Its test window supplies a deterministic occlusion signal: command-line test windows can be ordered front while the OS still reports them occluded. It does not substitute a fake renderer or clock.
- Installed-app inspection exposed a separate demo bug: calling `tick` alone reaches the production player's three-second stale-source limit. The guide now supplies fresh samples from its own monotonic clock. A regression test crosses that limit, changes lines, completes a 12-second loop and verifies lyrics are neither reloaded nor searched again.

## Native rendering measurements

| Case | Median draw interval | 95th percentile |
| --- | ---: | ---: |
| Dark test | 8.333 ms | 8.756 ms |
| Light test | 8.334 ms | 8.747 ms |

The native EDR fixture retained above-SDR linear pixel values through hide/show, focus and material changes. Representative peaks were 1.736 for glass, 1.306 for dark frosted and 2.072 for light frosted; EDR disabled capped at 1.0. Height animation produced visible intermediate sizes in both directions.

These are drawing cadence and captured linear pixel measurements, not a GPU power benchmark, guaranteed presentation rate or physical screen luminance measurement. macOS and display headroom still determine visible EDR brightness. Ordinary cached view screenshots cannot establish the appearance of the native backdrop material.

## Installed application checks

- Installed 2.0.35 (267) over the existing configuration after backing up the installed app and preferences.
- First upgrade launch automatically brought the version guide to the front with the five 2.0.35 pages; the real native material and lyric renderer appeared in the guide and independent demo window.
- Restarting did not repeat the automatic guide. Manual replay from About worked; closing it returned to the existing Settings window.
- The original paused music session was preserved. Guide controls use their own playback model; they do not command Apple Music or overwrite personal settings.
- The final installed demo advanced to its second lyric line. Its main-window page switched between short and long titles using the actual view hierarchy, with the transport remaining at the same position.
- A before/after comparison of existing personal appearance, font, lyric, source and overlay-position preferences found no differences.
- Final package verification includes strict code-signature checking, version/build metadata, ZIP extraction and a checksum comparison with the published asset.

The app is ad-hoc signed, not Apple-notarized. Native active-appearance compatibility hooks are isolated in `OverlayMaterialPanel`; they are not a promise of compatibility with future macOS releases.
