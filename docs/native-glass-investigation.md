# Native glass investigation — 2026-09-23

Historical development notes for the material included in 2.0.35. Build-specific “not published” and experiment statements below describe those earlier local snapshots. For final release scope and validation, see [2.0.35](releases/v2.0.35.md) and [release QA](qa-v2.0.35.md).

The new native material replaces the local Liquid Glass option. Build 260 introduced the independent appearance settings; the build 261 follow-up is documented below. GitHub has not been changed. It adds independent application/overlay appearance choices and frame-target sampling.

## What was verified in the installed Codex package

Inspected `/Applications/ChatGPT.app`, bundle identifier `com.openai.codex`, version `26.917.51856`. These findings are from the locally distributed assets and bounded native-binary inspection, not unpublished source access or a documented OpenAI API contract.

The activity bubble's CSS requests native `glass`, variant `regular`, and adaptive appearance `off`. Its native-active styling removes the CSS fallback blur, borders and shadows. A small surface-color underlay remains. The native framework contains `NSGlassEffectView` / `NSGlassEffectContainerView` and a `nativeGlassForcesActiveAppearance` window flag. Its overrides of `_hasActiveAppearance` and `_hasActiveAppearanceIgnoringKeyFocus` return active appearance when that flag is set. The bridge also sets the private adaptive-appearance selector.

This is not just a white border over a translucent blur. AppKit supplies the optical edge and background distortion; the window's appearance state and the native glass compositing path matter.

## Controlled comparison

Separate-process backdrop tests compared native regular / clear, active / inactive appearance, adaptive modes, surface alpha, masks and scrims. The tests used nonactivating panels without making them key.

- Inactive regular glass had substantially flatter edges in the observed configuration. Active appearance produced the rounded refraction and edge highlight.
- Reducing native glass alpha or applying the existing optical alpha mask mixed undistorted desktop content back over the refracted image. Background text acquired sharp ghost detail and the glass effect weakened.
- Heavy contrast tint hid the native optics. A public `NSVisualEffectView` active parent did not reproduce the desired result in this experiment.

The initial build 259–260 replacement therefore used one regular native surface at full alpha, without the existing optical masks, with a small independent contrast gradient and system light/dark appearance. The picker retains two choices: Liquid Glass and frosted reading. Saved `petGlass` experiments migrate to Liquid Glass. This style's blur is owned by the system, rather than represented by a slider that cannot independently change it.

The active-appearance and adaptive-appearance compatibility code uses undocumented AppKit hooks. It is isolated in `OverlayMaterialPanel.swift` and `OverlayGlassBackground.swift`; the dynamic adaptive selectors are checked before use and their original value is restored for dark frosted reading. Light reading also fixes appearance so the material cannot independently invert under dark glyphs. The nonactivating window remains nonactivating. This is an experiment, not a future-macOS compatibility guarantee.

## Lyrics, theme colors and emphasis

The material derives a display palette for the surface appearance. It does not overwrite saved colors, fonts or the cover theme.

- Light surface: sung ink is dark, unsung ink is lighter. Dark surface: sung ink is light, unsung ink is darker. Even identical custom colors are separated by brightness.
- Cover themes use the original accent, then adjust luminance for the surface, rather than reusing the pale palette prepared for the dark main window.
- The karaoke clock, reveal boundary, glyph layout, staggered lift/scale and fade envelope are unchanged.
- Dark glyphs get an independent tinted halo drawn underneath them. Drawing it above the glyph was observed to wash out the black core under EDR; the ordering is now covered by a pixel test. EDR can increase halo brightness without turning the glyph white. Black itself cannot be luminous, and a light-background halo will not look identical to white emission over a dark background.
- Existing foreground shadow surfaces provide light or dark edge protection. There is no additional desktop-capture loop or per-character blur surface. Palette derivation is cached.

The contrast tests use explicit light/dark reference backgrounds. They do not establish a minimum contrast against every possible desktop behind transparent glass. The frosted-reading style remains the more dependable choice over complex content.

## Validation

- Final focused run: **33 tests passed**, including custom font geometry, original HDR rendering, timing, ink adaptation, saved-setting preservation, panel appearance and dark-core/halo pixels. Log: `/tmp/lyricsx-glass-ink-tests.log`.
- Actual screen compositing: light/dark/color/text backdrops, SDR/EDR rendering requests, inline/detached controls, transparency extremes and resized native surfaces. Capture test passed; images were visually inspected. A successful capture by itself is not an automated optics assertion.
- After the final halo-order change, repeated real-panel captures on light/dark reference backdrops with a yellow artwork accent; both retained legible hue and state separation. Log: `/tmp/lyricsx-native-material-theme-final.log`.
- An earlier complete test batch had timing/raster issues in three AppKit window tests; those three passed when rerun in isolation. Do not describe that earlier batch as a clean full-suite pass. Build 259 subsequently passed 289 serial tests and was observed running with live Apple Music and the two-card settings picker. Prolonged installed-app use remains a user-validation surface.

Review images are in the sibling `../glass-material-study` output folder (relative to the repository root's parent), including `light.png`, `dark.png`, `theme-light.png`, `theme-dark.png`, and the dark-ink SDR/EDR samples.

## Primary references

- [Apple NSGlassEffectView](https://developer.apple.com/documentation/appkit/nsglasseffectview)
- [Apple glass styles](https://developer.apple.com/documentation/appkit/nsglasseffectview/style-swift.enum)
- [Apple: Meet Liquid Glass](https://developer.apple.com/videos/play/wwdc2025/219/)
- [Electron native glass implementation](https://github.com/Meridius-Labs/electron-liquid-glass/blob/main/src/glass_effect.mm)
- [Lunar native overlay implementation](https://github.com/alin23/Lunar/blob/master/Lunar/Views/OSDWindow.swift)
- [Active-appearance overlay example](https://gist.github.com/AryanRogye/d6c6c6bf6b501c45c5d25d397e6a0759)

These external implementations corroborate available native techniques; they are not evidence of Codex's exact configuration. The Codex-specific statements above come from the inspected local package.

## Independent themes and cadence follow-up

- Settings → General controls main application, settings and guide appearance. Settings → Overlay controls the floating lyric and control windows independently. Both support system/light/dark. App appearance uses window-scoped SwiftUI preferences, not `NSApp.appearance`, so it cannot override an overlay following the system.
- Light main-window artwork uses the same cached backdrop with a lighter base and dark foreground. Light/dark palettes each have a bounded cache to avoid thrashing when the two windows use different themes.
- Settings sidebar is 176 pt; header/card margins share 20/14 pt spacing. The reading column still depends on actual window width, never the sidebar animation's intermediate width.
- Lyric and resize updates sample the display link's target timestamp rather than callback arrival time. Stale targets over 33 ms are rejected. This removes callback scheduling jitter from visual progress; it does not change lyric timestamps, animation curves, or guarantee compositor presentation.
- Actual `HeldNoteRenderer.draw` cadence, native glass, glyph scale/glow and requested EDR: 840 sampled drawing intervals per appearance on a 120 Hz screen. Light median 8.332 ms / p95 8.585 ms; dark median 8.333 ms / p95 8.578 ms. Maximum about 15.3 ms. Log `/tmp/lyricsx-native-drawing-cadence.log`. These are drawing intervals, not GPU-completed frames or measured power.
- Before this follow-up, native production-overlay CPU fixture completed all six phases: hidden 3.32–3.48%, display/120 Hz 16.54–16.58%, 60 Hz 10.04–10.30%. Log `/tmp/lyricsx-native-glass-cadence-before.log`. No claim of actual electrical or GPU savings is made; display-following remains selected.

Final verification: 293 serial tests passed; after the last search-preview theme correction, 10 search/theme tests passed. Every settings section was rendered; general, overlay, lyrics, both appearance layouts and the light main window were visually inspected. Installed build 260 passed strict code-signature verification and its executable SHA-256 matched staging. Native UI showed separate app/overlay selectors; changing the overlay to dark retained light settings. User playback and preferences were preserved. Generated staging `.app` removed after installation to avoid duplicate application discovery.


## Build 261: actual transparency and explicit theme propagation

The user reported that transparency and overlay appearance did not seem to work.
The build 260 glass opacity was always 1; only a 0–14.4% top scrim changed.
Same-backdrop captures confirmed that 20% and 80% were almost indistinguishable.
Reading frost also cancelled most transparency changes at high frost values.

The material now fades independently from foreground lyrics. Liquid Glass maps
20–80% transparency to 0.8–0.2 material opacity. Reading glass retains frost
adjustment but caps its added coverage at 45% rather than 90%, keeping the
transparency control effective. This deliberately trades some optical-edge
strength for see-through at high values; it does not promise full refraction
strength at every opacity. The UI explains that consequence.

Theme settings now apply explicitly to material, lyric host and inline/detached
control host, with a stable SwiftUI environment wrapper. They no longer rely
solely on the panel's inherited appearance. Baseline native fixtures did switch
light/dark successfully; they did not reproduce every reported installed-app
failure. This change strengthens propagation rather than claiming a proven
single cause for the intermittent theme complaint.

The compositing harness now changes Preferences.overlayTheme instead of writing
panel.appearance behind the controller. Live controller tests cover repeated
light/dark/system switches while hidden/shown, both styles, app/overlay theme
independence, detached controls, opaque lyric foregrounds, unchanged geometry,
and system Reduce Transparency restoration.

Validation: 295 serial tests passed (98 services, 39 core, 158 app), plus the
opt-in native composite capture check (88 images across both styles, SDR/EDR,
inline/detached controls, backdrop and transparency/frost settings). Inspected
same-white-backdrop 20/80% pairs, colored backdrops, light/dark glyphs and reading
frost. Native text drawing on this 120 Hz display had medians 8.353/8.358 ms and
p95 13.283/12.945 ms for light/dark; these are draw intervals, not GPU-completed
frames, and do not establish lower power or perfect frame delivery.

Logs: `/tmp/lyricsx-material-controls-all-tests.log`,
`/tmp/lyricsx-controls-all-fixed.log`, `/tmp/lyricsx-material-opacity-cadence.log`.
Installed and launched 2.0.34 build 261 with strict signature verification;
staging/installed executable SHA-256 both
`48af2e4bc72272edb8d6d0f52eb665601da80f5979bec975c0c932c9516c6a59`.
Native settings UI was exercised for app dark/overlay light, 20/80% slider values,
and restored to app system, overlay dark, transparency 32%. Playback was paused
by the user during this inspection; real lyric-window material verification used
the production controller in native fixtures, rather than claiming playback QA
of the installed application. Old installed build backed up at
`/tmp/LyricsX-Next-before-opacity-260.zip`; generated staging app removed to avoid
duplicate application discovery. No GitHub changes.


## Build 262: reject whole-glass alpha as a transparency control

The user correctly identified a visual regression in build 261. That change
made transparency measurable by fading the entire optical surface, mixing sharp
unrefracted desktop detail back into the distorted image. The prior unit checks
verified settings propagation and opacity, not preserved optical quality; they
were insufficient to accept that material change.

A separate-process native six-way comparison on light/dark striped-text
backdrops compared build 261 alpha 0.8, native alpha 1, native tint at 0.12/0.50,
and content shades at 0.12/0.50. Results:
`/tmp/lyricsx-refraction-study/comparison-light.png` and `comparison-dark.png`.
Full native alpha removed the sharp ghost image and restored optical edge
curvature. Native tint can also strongly cover the optics at high density, so
it is not used as an opacity substitute.

Liquid Glass now keeps native alpha exactly 1 for every slider value. The
independent gradient maps the saved 20–80% range to a 34–0% top shade, tapering
to zero at the bottom. Its UI name is **底色透明度** and explains that it adjusts
the gradient, while retaining system blur and refraction. This is an explicit
limit of this control, not a claim that the native material itself becomes
fully transparent. Reading glass keeps its existing separate opacity behavior.
No copied backdrop, additional blur surface, optical alpha mask or fabricated
bevel was added. Independent window themes, glyph colors and animation logic
are unchanged from build 261.

Validation: 33 relevant theme, sizing, handover and drag tests passed; live panel
tests now require full glass alpha through hidden/shown and detached-control
transitions while also requiring a meaningful gradient range. Native production
controller composites were captured over light, dark, colored and text-pattern
backgrounds in both explicit themes (12 captures); inspected edge distortion
and disappearance of sharp background ghosts. Logs:
`/tmp/lyricsx-refraction-restored-tests.log`,
`/tmp/lyricsx-refraction-restored-light.log`,
`/tmp/lyricsx-refraction-restored-dark.log`.

Installed and launched 2.0.34 build 262; strict code-signature verification passed
and staging/installed executable SHA-256 matched:
`c59e7614de8347b46d5f1060c8ebf70c35990e179e28e2b751c2532f09adf880`.
Installed UI shows the revised tint control and separate themes. The user was
actively adjusting the new slider during inspection; those changes were left
intact. The build 261 app is backed up at
`/tmp/LyricsX-Next-before-refraction-261.zip`; staging app was removed to avoid
duplicate discovery. No GitHub publication in this turn.


## Build 263: separate tint, readable ink and EDR emission

User report: tint range was awkward, HDR lyric glow had become weak/missing,
light-background readability was poor, and glass edge highlights looked faint.
A failing extended-linear rendering test reproduced the lyric bug: light-theme
neutral halo luminance was 0.16–0.28 and multiplied by requested headroom,
often remaining below SDR white even at brightness 3.5. Existing HDR coverage
only proved white/cyan ink; the dark-ink test only measured a visible halo.

Dark glyphs now use a separate lightly tinted EDR emitter while preserving the
opaque core and the original karaoke timing. A closer halo retains visible
extended-range peaks without adding another filter/surface. Ordinary SDR ink
and unsupported displays retain the contrasting SDR halo. Light unsung ink is
now in linear luminance 0.13–0.15; sung ink 0–0.025 and translation 0–0.06.
A tighter opposite-color shadow protects text against background detail using
the same two existing text-shadow passes.

Glass tint has its own saved 0–100% control: 0 gives the strongest independent
shade (60% at the top, tapering to clear below), 100 removes the extra shade.
It does not mean the native material is fully transparent. Migration from the
previous shared 20–80% control preserves the exact old shade; reading glass
retains its prior value. Native glass remains regular, alpha 1, untinted, with
unchanged corner radius, optical composition and appearance compatibility.
Apple's public NSGlassEffectView API exposes style/tint/corners/content, not an
independent blur/refraction transparency or HDR edge-brightness control:
https://developer.apple.com/documentation/appkit/nsglasseffectview
Its edge remains system-rendered and naturally less distinct on a uniform
background. The application's EDR toggle controls lyrics, not AppKit's edge.

Validation:
- Baseline failure: /tmp/lyricsx-hdr-baseline.log (6 missing-EDR cases).
- Full serial run: /tmp/lyricsx-glass-hdr-all-tests.log, 297 passed
  (98 services, 39 core, 160 app). Tests now check extended-linear EDR peaks,
  fully opaque dark cores (excluding antialiased edges), SDR fallback, tint
  migration, independent persistence, and unchanged native optical surfaces.
- Neutral/color light-ink rendered peaks at brightness 3.5: 1.332–1.338 over
  white and 1.158–1.162 over a 0.65-linear backdrop; SDR remained <= 1.
- Native controller composites: /tmp/lyricsx-material-263-light-hdr,
  /tmp/lyricsx-material-263-dark-hdr and /tmp/lyricsx-material-263-accent,
  18 captures, including full-range endpoints and actual separate-process
  backdrops. PNG inspection checks contrast and optics, not physical HDR nits.
- /tmp/lyricsx-hdr-263-cadence.*.json: light/dark rendering on 120Hz display,
  median around 8.34 ms and p95 around 8.65 ms. These are text-draw intervals,
  not a GPU utilization, energy measurement, or every-frame presentation guarantee.

Installed and launched 2.0.34 build 263. Strict signature verification passed;
staging and installed executable SHA-256 both:
`dafb551245710c7f530a45cc9979f9615616c73f3a7861969948f43c38ad5c4a`.
Build 262 backup: `/tmp/LyricsX-Next-before-hdr-262.zip`.
The installed settings UI was exercised at 0% and 100%, then restored to 68%
(the old 46% maps to 67.8889%; UI step rounding changes top shade by <0.001).
HDR remains enabled at the user's 3.5 setting. Long-note preview opened and
closed normally, retaining Settings; the player's paused state was untouched.
The staging app was removed to avoid a second discoverable copy. No GitHub
publication was performed.

## Build 264: clear native glass and window-lifecycle EDR recovery

The user requested the high-transparency, strongly refracting native demo as
the actual Liquid Glass material. Liquid Glass now uses NSGlassEffectView's
public `clear` style, with native alpha exactly 1 and no native tint. The
separate black gradient remains adjustable without fading the optical surface.
New installations start at 60% tint transparency; existing explicit values
and legacy shade migrations are preserved. Frosted Reading keeps its separate
material settings and light/dark appearance choice. Liquid Glass uses one
fixed appearance, bright lyric ink and local dark shadows for contrast.

Changing only the style was insufficient in the production overlay. Controlled
native comparisons isolated window attachment from clipping, layer backing,
SwiftUI text hosting and the controls child window. The production controller
previously enabled its active-glass compatibility behavior only in `sync()`,
after attaching the hosting tree. Enabling it immediately when creating the
panel, before attaching any views, restores clear native optics in the actual
controller. Side-by-side desktop composites confirm visible background colors
and curved edge distortion rather than the former flat gray material.

The existing, isolated private adaptive/active-appearance compatibility hooks
are still present. This is not a claim that Apple exposes public controls for
refraction strength, independent blur or HDR edge brightness. No additional
private selectors, desktop capture loop or duplicate backdrop blur was added
to production. Clear glass intentionally reveals background detail: bright
ink and two existing shadow passes protect lyrics, but a very busy background
can still be easier to read in Frosted Reading.

HDR capability observation now binds on view attachment, resolves the owning
window's display, preserves the last confirmed output through a transient nil
screen, and immediately honors a confirmed SDR display. Focus, visibility,
display and wake events schedule bounded recovery checks and an output-only
redraw. All observers and pending tasks are removed on detachment. Recovery
does not reset lyric identity, word progress or the animation clock.

Validation after the clear-glass initialization fix:
- Full serial tests: 301 passed (98 services, 39 core, 164 app), recorded in
  `/tmp/lyricsx-264-clear-early-full.log`.
- Production controller composites over white, dark, colored and text-heavy
  desktop backdrops, plus 0/20/80/100% tint endpoints:
  `/tmp/lyricsx-264-clear-installed-qa`.
- Native HDR fixture checks cover a nonactivating overlay, main-window
  minimize/restore/hide, attachment and cancellation. Floating-point desktop
  capture checks actual composed EDR pixels; PNGs cannot establish HDR output.
  With a constant SDR backdrop, overlay peaks remained 1.73252 in all four
  phases, and the main fixture remained 1.43346 when visible. The backdrop is
  essential: an earlier capture included changing desktop content through the
  clear material, which changed the measured peak without losing EDR output.
  Final passing log: `/tmp/lyricsx-264-clear-early-native-hdr.log`.
- Text drawing cadence before the final initialization-only fix measured
  median 8.33 ms, p95 13.10 ms on a 120 Hz screen. This is a draw-cadence result,
  not a GPU utilization, energy saving or physical brightness measurement.

Physical HDR brightness still follows the display and macOS headroom. The
reported screen had potential headroom 16 and current headroom about 1.2.
The rare user-reported physical brightness failure has not been conclusively
reproduced; lifecycle tests verify the application's capability and output
recovery rather than promising that macOS always supplies requested headroom.

Installed and launched 2.0.34 build 264 from `/Applications/LyricsX Next.app`.
Strict signature verification passed and packaged/installed executable SHA-256
matched: `640c1031e371ef1f8dbea904d1334fc61b2d2862a3f11fd4cbafd11e3d45d68b`.
The installed settings show the new clear-glass description, 60% tint and no
light/dark selector for Liquid Glass. User HDR brightness remains 3.5. The
music player's paused state and position were preserved. Build 263 backup:
`/tmp/LyricsX-Next-before-readability-263.zip`. Removed the verified staging
app to prevent duplicate app discovery. No GitHub publication was performed.

## Build 265: retain the halo when HDR headroom is limited

The user reported that HDR still looked absent and that the height animation
occasionally jumped; they later confirmed animation was working again and
asked to prioritize HDR. No resize timing or material optics were changed in
this follow-up. A production-controller fixture records expansion/contraction
and validates multiple visible intermediate heights with a stable top edge.
The compositor recording `/tmp/lyricsx-265-resize-before.mp4` also shows the
glass edge following intermediate frames. It does not reproduce the reported
intermittent jump, so that report is not claimed as fixed.

A failing renderer test exposed a concrete HDR visibility problem: the HDR
branch reduced the envelope to 80%, dimmed the shadow to 85%, and narrowed the
halo. Under low headroom this made enabling HDR produce a weaker visible halo
than SDR. The same test now keeps the ordinary halo's envelope, opacity and
radius, while adding EDR brightness in the existing drawing pass. Dark-ink
glass keeps its close emitter and opaque core. No extra blur surface, permanent
timer, system brightness change or additional rendering pass was introduced.

Baseline at simulated headroom 1.2: SDR halo energy 337.46, HDR 233.92 (failure).
After the change: SDR 337.46, HDR 365.40 (pass). These are sums over background
pixels outside glyph cores in a controlled float rendering, not physical nits
or a claim of a percentage increase in perceived brightness.

Hover-hidden content now cancels pending HDR redraw recovery and explicitly
recovers when it becomes visible again. Previously this path only waited for
window/focus notifications, even though hover fading does not change window
visibility. Tests cover recovery without a focus event and observer cleanup.

Native HDR capture now measures the central lyric area, excluding the glass
rim and controls, and includes an HDR-off negative control. With a constant
SDR backdrop, overlay peaks were 1.73865 before/after main minimize, restore,
hide, HDR toggle and hover reveal; turning HDR off gave 1.0. The main fixture
peak was 1.65604. Log: `/tmp/lyricsx-265-native-hdr.log`. This validates lyric
EDR output, not the panel's physical luminance; macOS still reported current
headroom about 1.2 on this display.

The tint-slider note now explicitly says it changes only the extra gradient
shade, preserves native transmission/refraction, and may look subtle on some
backgrounds. Full serial tests: 303 passed (98 services, 39 core, 166 app),
recorded in `/tmp/lyricsx-265-full.log`.

Native renderer cadence remained around 120 draws/s on the 120 Hz display:
median 8.33 ms and p95 8.51 ms or less in both ink fixtures
(`/tmp/lyricsx-265-cadence.dark.json`, `.light.json`). These are drawing
intervals, not measurements of GPU power or guaranteed physical presentation.

Installed and launched 2.0.34 build 265. Strict signature verification passed;
installed/package executable SHA-256:
`16101eb2212ba99d36cfa910ff800a67ed6af02b191587a21ce7488173860d20`.
Backup: `/tmp/LyricsX-Next-before-hdr-halo-264.zip`. Installed UI verification
confirmed the new transparency note, 60% tint, HDR enabled at the user's 3.5
setting, and a working long-note preview. A preview screenshot checks ordinary
composition, not physical HDR brightness. Playback was left paused at its
existing position. The duplicate staging app was removed; no GitHub upload.

## Build 266: output metadata, hover composition and optical-state switching

The user reports that build 265 still loses visible HDR after hiding or losing
focus, and that switching materials/themes sometimes leaves opaque glass.
This is treated as a regression, not expected inactive-window behavior.
Comparing HEAD (build 258) and the current sources did not identify a single
proven cause for the intermittent physical-brightness loss. The previous
float-pixel fixture also passed before these changes: that test alone cannot
prove this user-reported regression fixed.

Apple documents that color headroom metadata both requests display headroom
and controls tone mapping:
https://developer.apple.com/documentation/swiftui/color/headroom(_:)
The SwiftEDR author's implementation separately declares output headroom after
effects because filters may disrupt metadata propagation:
https://github.com/Jiropole/SwiftEDR/blob/main/Sources/SwiftEDR/Component/HeadroomAsserter.swift
This is corroborating implementation experience, not proof that every macOS
version exhibits the same failure. No third-party library was added.

The production change aggregates headroom from actual active timed-lyric
emitters and declares it outside the blur/opacity passes. A subpixel black
color carries metadata; it introduces no bright test pixel. Hidden content,
HDR off, ordinary lyrics and confirmed SDR screens request no extra headroom.
Focus/wake/appearance recovery renews only this declaration and the renderer
revision, preserving text identity and cue time. Screen-headroom notifications
refresh capability without starting another recovery cycle, avoiding a
request/notification feedback loop. No permanent polling was introduced.

Hover fading now happens in SwiftUI inside the HDR scope. The native lyric
hosting view stays at alpha 1. The native glass sibling keeps its existing
fade. An experiment adding an extended-linear drawingGroup was rejected:
native captures showed a rectangular compositing artifact and weaker dark-ink
highlights. It is absent from the final code; no extra lyric raster target
or full-window HDR drawing group is used.

For optical changes, native material configuration is atomic and prepares
appearance/activity before attachment. Only changing material, resolved theme
or accessibility transparency mode replaces the native glass backdrop. Slider
changes and height animation reuse it; the lyric host and contrast-gradient
view retain identity. Both styles keep fixed appearance so AppKit cannot
choose a light backdrop independently of the application's white lyric ink.
This also prevents old regular-material backing from surviving a switch to
clear glass merely because the style property already reports `.clear`.

The native fixture now covers repeated/interrupted hover fades, orderOut/
orderFront, both materials, dark/light/system themes and running timed lyrics.
A trial using a regular activation policy could not activate the test runner;
it also allowed the installed overlay to contaminate the test's backdrop.
Those results are rejected as focus/HDR evidence. The isolated fixture uses
a higher-level opaque SDR backdrop and is explicitly not a real focus test.
Installed-app UI checks are separate, and screenshots do not measure physical
HDR luminance.

Final build-266 validation: 305 ordinary tests passed (98 services, 39 core,
168 app) in `/tmp/lyricsx-266-full-final.log`. Four opt-in native tests passed
in `/tmp/lyricsx-266-native.log`, covering both ink draw-cadence variants,
playing overlay lifecycle and intermediate window heights. The clear overlay
emitter stayed at 1.73559 across hide/reveal and material round trips; HDR off
measured 1.0. Frosted dark/light measured 1.30571/2.07152 without a collapse
after hide/reveal. These values are captured linear pixels, not panel nits.
Cadence median was 8.33–8.34 ms and p95 8.46–8.47 ms on the 120 Hz display.
No GPU wattage measurement or guaranteed physical 120 Hz claim is made.

Installed 2.0.34 build 266; executable SHA-256
`40fdcf07373b06a8b5b8effde4e36f76f0a6da7df35f7c0416d8cdeb73112442`.
Signature verification passed. Backup:
`/tmp/LyricsX-Next-before-hdr-output-265.zip`. The staged duplicate app was
removed. Installed UI exercised frosted light/dark/system and a return to
clear glass, then main-window close while real lyrics continued. The user's
music kept playing independently; no track/seek control was sent. Final prefs
retain glass, system application/frosted theme, 60% glass tint, 30% reading
transparency, HDR enabled at 4.0 and hover hiding. No GitHub upload. The
intermittent physical-brightness loss still requires user confirmation on the
installed build; the pre-fix fixture passing is explicitly retained above.
