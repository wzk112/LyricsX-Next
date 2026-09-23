# Window-local EDR output and brightness controls

Build 268 first validated independent EDR activation locally. Build 269 keeps public version 2.0.35, adds numerical brightness controls and a smaller overlay halo, and replaces the previous release package after validation.

## Change

The lyric clocks and native windows were already separate. Their EDR activation now has an explicit, independently owned native output surface per HDR scope as well. Replace the subpixel SwiftUI black/headroom marker with a window-local CAMetalLayer using extended-linear sRGB, RGBA16Float, explicit content headroom, and CAMetalLayer.wantsExtendedDynamicRangeContent. Its only drawable is a transparent 1×1 pixel; it does not redraw the lyrics, change their layout, capture the desktop, or alter the glass material.

The surface is a native sibling of the host drawing layers, outside SwiftUI opacity/filter snapshots. A zero-size reader retains the existing screen-capability and bounded recovery logic. Visible timed HDR lyrics supply the request; disabled HDR, hover-hidden content, hidden/minimized windows and confirmed SDR screens release it. Each window owns its request and never depends on the key/main window. Visible-state observation also covers ordering changes that do not produce an occlusion notification.

GPU commands are submitted only on activation or bounded lifecycle recovery, not per display frame. There is no new timer, polling loop, helper window, process or screen-brightness setting. Detach removes the layer, visibility observer, pending tasks and Metal device/queue references.

## Why the earlier validation was insufficient

The prior native fixture passed before the fix: captured linear lyric peaks remained >1 while reported display headroom stayed near 1.2. Captured HDR pixels do not establish physical panel luminance or prove that the display request is maintained. A separate native Metal activation experiment raised reported headroom to 4, showing an explicit output request can affect display activation. However, a normally launched old-renderer probe also reported 4; the intermittent user-visible failure is not deterministically reproduced by every fixture. The 1.2→4 comparison must not be presented as definitive proof of the entire root cause.

System display headroom is shared across onscreen apps and can ramp or decay gradually. Validation therefore checks window-local requests/release and native lyric pixels separately, with an HDR-off control. No claim about measured nits or external SDR hardware is made.

## References

- Apple CAMetalLayer EDR switch: https://developer.apple.com/documentation/quartzcore/cametallayer/wantsextendeddynamicrangecontent
- Apple EDR rendering setup: https://developer.apple.com/videos/play/wwdc2022/10114/
- Local SDK CALayer.h documents content headroom and dynamic-range behavior; CAMetalLayer's EDR switch remains supported.

## Build 268 validation history

- 313 ordinary tests passed (98 services, 39 core, 176 app): `/tmp/lyricsx-hdr-268-full-final.log`.
- Playing native overlay lifecycle test passed: `/tmp/lyricsx-hdr-268-native.log`. Cold overlay-only start, main minimize/restore/order-out/close, HDR off/on, hover hiding/reveal and material/theme round trips retain independent output ownership. Overlay request stays 3.5 while closed main request returns to 1. Stable content adds no drawable submissions during a two-second check.
- Native captured lyric peak remains 1.73559 across main-window closure; HDR-off control returns to SDR. These are compositor pixels, not physical panel luminance. The command-line native runner still reports headroom around 1.2 in some runs, so this result is not a guarantee of the intermittent physical-brightness fix.
- Explicit window ordering without occlusion notifications initially exposed a stale native request. The new window-visible observation fixed this, and an ordinary two-window test verifies request isolation, hide/reveal and device release on detach.
- An initial in-view 1-point Metal representable contaminated ImageRenderer snapshots. The final implementation keeps the representable at zero size and attaches only the transparent native layer to the actual window root. All existing image/layout tests pass; no opaque rectangle or additional ink is introduced.
- Build, strict signature validation and installed/executable hash comparison passed. Installed `/Applications/LyricsX Next.app` is 2.0.35 (268), SHA-256 `c384c7c4b6184bdb341a712c95ce6a98d22e9a578079150a140e4ddd42446008`.
- Backup: `/tmp/LyricsX-Next-before-independent-EDR-267.zip`. Existing preferences, player state and cached lyrics were retained. The staged app copy was removed after installation to avoid duplicate app search entries.
- Running installed app was verified with its existing settings UI and HDR enabled at the saved 4.0 setting. No playback/seek commands or display-brightness changes were sent. User reproduction on the installed candidate remains necessary for the reported rare perceptual failure.
- GitHub v2.0.35 remains public and unchanged (asset updated `2026-09-23T12:15:15Z`). No release upload or withdrawal in this task.


## Build 269 validation

- 315 ordinary tests passed (98 services, 39 core, 178 app): `/tmp/lyricsx-269-full-final.log`.
- The opt-in native lifecycle test passed with active cue rendering, main window closed, and changes on the same overlay surface: `/tmp/lyricsx-269-native-final.log`.
- At requested 1, 1.6, 2.5, 4, 2 and 1×, captured linear peaks were light 0.753, 1.127, 1.459, 1.955, 1.275, 0.753; dark 1, 1.197, 1.222, 1.308, 1.207, 1. These are post-composition values, not a calibration of screen nits. Both directions respond and returning to 1× restores the baseline.
- An initial capture was obstructed by another app's menu popover. The fixture now uses the center of the display; that failed capture is not renderer evidence.
- The ordinary chooser deliberately previews SDR. A separate still-frame HDR comparison now uses the real renderer and numerical target, with direct entry, shared 1–4× clamping, and per-display current/potential limits. Display availability refreshes every two seconds only while this setting is onscreen and the app is active; lyric rendering does not follow this polling signal.
- The overlay shadow radius and shadow opacity are scaled to 82% of their prior values. The glyph emitter, cue clock, scale/lift animation and main-window bloom remain unchanged.
- Installed application UI verified direct entry of 2.5×, reverse synchronization from the slider, rejection of invalid text, and preserved 4× user setting after testing. The setting reports current availability separately from the screen's potential limit.
- Release package CRC and strict ad-hoc code signing passed. Executable SHA-256: `7442d3b02ce8422ba949568cc1bb476e941baed2557563044e5b2a36cbdc5938`.
- Native social-post screenshots use isolated demo data and real production windows. No real playback commands or display-brightness changes were sent.
