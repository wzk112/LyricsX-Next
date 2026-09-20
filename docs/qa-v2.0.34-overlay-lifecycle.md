# 2.0.34 build 258: window and transition fixes

## Scope

Build 258 keeps the marketing version and public GitHub release at 2.0.34. It
replaces the build 257 asset after verification without withdrawing the
release. This record accompanies the corrected v2.0.34 release.

## Findings and changes

- Overlay resizing used an AppKit animator proxy. Cancelling controller state
  did not give the controller exclusive ownership of subsequent native frame
  writes during a drag. A single cancellable display-link animation now owns
  those writes. Pointer movement relocates both endpoints around the current
  top-center anchor without restarting its size clock. The panel tracks mouse
  drag events instead of invoking a second whole-frame `performDrag` loop.
  Lyric resizing continues during dragging; screen restoration defers until
  release. An unchanged resting frame does not start another resize.
  Drag events use their own delivered window coordinates, not a later global
  pointer sample. A native event test failed with the global-pointer path and
  passed after that correction; all three focused drag tests then passed.
- Overlay blur and arrival cleanup depended on several independent state
  values and rendering callbacks. The transition now has a finite clock and
  separately scheduled settlement. A departing snapshot stays invisible until
  replaced; a delayed completion cannot restore it or cancel a newer arrival.
- Font/reflow interruption cleared the cue timestamp but could retain its
  motion plan. Settlement now clears both, including when playback is paused.
- Artwork and its extracted palette were published separately, allowing two
  consecutive visual changes. Decoding and palette extraction now finish before
  the replacement is published, with cancellation and generation checks.
- Main-window visibility observation is isolated from the entire lyric list.
  Hiding the window no longer also resets browsing. EDR reader updates ignore
  changes that do not affect its rendering output.
- Main row insertion/layout no longer inherits the scrolling transaction.
  Next-cue scrolling uses a bounded, non-overshooting curve. Seeks and window
  restoration position the destination directly rather than sweeping through
  unmaterialized rows. Repeated follow requests are coalesced, distant rows
  share a visual state, and offscreen timed rows stop frame delivery.
- The overlay's whole-window transition is now keyed only to the playback-item
  revision. A new song can move from waiting dots to timed lyrics or the
  artwork card without replaying the header blur. Empty-ID Apple Events reads
  also compare title, artist, and album at both ends of the read so a switch
  cannot publish one mixed metadata frame.
- The overlay header now follows the main window's title transition exactly:
  an old/new `ZStack` keyed by the playback-item revision, the same bounded
  `artworkBlur` transition, and a 0.45-second ease-in-out curve. The lyric body
  owns a separate song-level surface, while a later lyrics-document arrival no
  longer adds a second full-surface blur. This restores the intended title
  blur without the former double pulse.
- Window geometry is committed on every display-link callback. A geometry-only
  experiment reduced synchronous drawing but left old backing pixels stretched
  between occasional redraws, making the resize look visibly low-rate. The
  final path keeps one display-link writer and presents every intermediate
  frame at the selected display refresh limit.
- Manual search keeps its source/status geometry stable and retains the last
  result list until the first replacement is ready. Pressing Search no longer
  briefly replaces a populated view with an empty placeholder.
- A newly selected instrumental or no-lyrics track no longer renders its title
  once in the short loading header and again in the centered song card. The
  loading header is deferred for 0.32 seconds during an active search, so a
  cached card can commit directly; a real longer search still reveals the
  header. Waiting-to-card layout changes use the same bounded non-linear curve.
- The About page now gives separate verified links for the LyricsX Next project,
  releases, issues, license, and each upstream project instead of directing the
  whole upstream row to only the original LyricsX repository.
- Automatic first-run and update presentation now waits for the SwiftUI host
  scene before ordering its dedicated window to the front. Closing it restores
  the window that opened it. The Settings motion preview is a Settings-owned
  sheet, so closing either surface cannot dismiss Settings.

## Completed verification

- The final `swift test --no-parallel` run passed 39 core, 98 service, and 146
  application tests. The transition-focused run also passed 32 tests across
  `OverlayBlurLifecycle`, `OverlayPresentation`, `OverlaySizing`, and
  `ArtworkTransition`. Opt-in live/performance/visual fixtures remain disabled.
  The marketing version remains 2.0.34, internal build 258.
- Added real NSWindow geometry tests for dragging during resize, changing
  lyrics while dragging, screen notifications during drag, release geometry,
  and cancellation of stale animation completions. Expansion and shrink both
  complete while dragging; a separate test samples 60 moving-anchor steps.
- Native variable-height scroll fixture passed with alternating long/short
  lyrics and multiline translations, checking scroll direction and settlement.
- Added native bitmap checks for blur settlement when render callbacks stop,
  plus state tests for interrupted handovers and invisible departing content.
- Added artwork replacement/palette checks and render-equivalent EDR checks.
- Final release build succeeded; installed executable SHA-256 matches it:
  `1b15d158463cbddcaf0f620970a480b3cc59f81af4d1eb0de1065a5ffa230931`.
- A clean QA bundle confirmed that the tutorial is frontmost on first launch.
  Closing it restored the main window; closing the Settings-owned motion
  preview and the manually opened release guide both left Settings visible.
- Installed bundle passed `codesign --verify --deep --strict`.
- Actual installed Apple Music playback was inspected with `Lover` and
  `雪降り ~雪が降っている~ (feat. 結月ゆかり) [Full Ver.]`; active lyrics,
  artwork, translation, and artwork-derived background recovered and remained
  visible and clear after switching.

## Limits

The rare reported persistent blur and mouse-driven jerk were not reliably
reproduced in the installed application. Geometry/state interruption tests
exercise their suspected failure paths but do not prove absence on every
display or event sequence. Installed main-window closing and overlay playback were inspected. Physical
dragging exposed the coordinate mismatch above; later live UI actions were
partly interrupted by changing application state/no-window tool errors. The
final event-coordinate fix passed native event tests, but the rare user-reported
interaction still needs real-device validation.

The final opt-in playback test completed and wrote its result artifact. In a
120 Hz native fixture using the production lyric hierarchy, the switching
phase recorded a median callback interval of 8.33 ms, a 95th percentile of
8.43 ms and a maximum of 36.35 ms. Four close-during-switch repetitions kept
99–101 overlay callbacks over each 0.85-second observation, with 95th
percentiles of 8.51–9.07 ms. These are display-link callback intervals, not
presented GPU frames. Debug-fixture CPU was 41.1% while playing and 66.8%
while repeatedly switching (where 100% represents one CPU core). There is no
controlled before/after power or GPU measurement, so no percentage reduction
is claimed. Earlier runs that exited without a result were inconclusive.

The separate four-test native window suite also passed: variable-height row
scrolling, event-tracking clock delivery, main-window lifecycle frame delivery,
and prelude/late-loading/cached-track/interrupted-scroll restoration. Normal
animation effects and the existing frame-rate preference are retained.
