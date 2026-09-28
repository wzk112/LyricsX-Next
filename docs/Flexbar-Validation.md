# Flexbar implementation validation

2026-09-27; branch `codex/flexbar-integration`, application baseline 2.0.37. The coordinator installed the native app and updated plugin 0.2.0 through official flexcli. No Git commit/publication or profile save/upload was performed by the coordinator. The user continued editing the existing draft during validation.

## Native checks

- `swift test --filter flexbar`: 14 tests passed. Covers private directory/socket permissions, stale/live sockets, symlink rejection, bounded output under slow reading, partial and malformed frames, four-connection cap, handshake timeout, writer cancellation with 12 quick restarts, clock-handshake disconnect with 20 peers, first subscription, line/document upgrade, paused same-line seek, offset/conversion, desktop translation independence, and sleep/restart.
- Coordinator ran the complete serial suite: 201 tests in 30 suites passed (48.211s). The later translation-policy change was checked by targeted tests rather than repeating the full suite.
- `swift test --filter flexbarNativeSocketInteroperatesWithActualNodeClient`: one real Swift server/Node client test passed (1.171s). A real Unix socket exchanged nonce-matched clockSync and current lyric; pause retained text and rate=0; same-line seek moved anchor to 3; disconnect/reconnect produced a new session ID. Observed local handshake RTT in that run: 0.148ms. This is IPC timing, not hardware display timing.
- Native targeted coverage totals 15 tests: the 14 native transport/projection/lifecycle tests plus the cross-language interoperability test.
- Coordinator release build and strict code-signature verification passed after the native translation change. The development app was subsequently installed in `/Applications/LyricsX Next.app`, with the previous app backed up under `build/installation-backups/20260927-172333`. Installed/source file hashes and strict signature verification passed; the app was launched and its Flexbar setting was visible.
- Logs: `/tmp/lyricsx-flexbar-tests.log`, `/tmp/lyricsx-flexbar-native-node-interop.log`, coordinator `/tmp/lyricsx-flexbar-full-test.log` and final release `/tmp/lyricsx-flexbar-release-final.log`.

## Plugin checks

- `npm test --prefix Integrations/Flexbar`: 14 Node tests passed, including actual bundled CJS subprocess startup with official-style host arguments, SDK WebSocket startup, portable backend Canvas resolution, normal 720×60 and directDraw 2170×60 PNG drawing requests.
- Other tests cover independent monotonic clock origins/RTT, split JSONL and limits, extended grapheme ranges, unchanged animation origins on anchor corrections, timed overflow keeping singing words visible, 60px height, paused/hidden timers, bounded slow/failing drawing, frame-deadline compensation, device UID isolation, last-key cleanup, completed-word static overflow stopping timers, and paused viewport pagination covering every grapheme.
- `npm run validate --prefix Integrations/Flexbar` checks manifest/key schemas, both UI naming conventions, bundled backend, and pinned Canvas runtime. Official flexcli 1.0.7 `plugin validate` succeeded under local Node 20. Old CLI only incompletely checks object keyLibrary, so its success is supplemented by these checks.
- Official `plugin pack --path com.wzk112.lyricsxnext.plugin` generated the root `.flexplugin`. ZIP CRC and key-entry/source hash comparisons passed. macOS arm64 native Canvas is included; the package is not claimed as a tested x64 build.
- Logs: `/tmp/lyricsx-flexbar-node-tests.log`, `/tmp/lyricsx-flexbar-cli-validate.log`, `/tmp/lyricsx-flexbar-cli-pack.log`.

## Real FlexDesigner host check

The coordinator installed the final package through official flexcli as the new UUID `com.wzk112.lyricsxnext`. FlexDesigner Helper PID 22369 remained running; its log showed normal SDK startup without module-resolution or Canvas errors. The real FlexDesigner key library displayed both “同步歌词” and “整屏歌词”. This verifies installation, backend startup and library registration; it does not verify the Vue configuration panel or physical drawing.

Evidence: `/tmp/lyricsx-flexbar-host-install.log` and `~/Library/Application Support/FlexDesigner/data/plugins/com.wzk112.lyricsxnext/logs/2026-09-27.log`. The existing `Apple2.flexbar*` profile was neither modified nor sent to the device. The user subsequently edited this draft themselves. No coordinator profile save/upload was performed.

## Visual QA and offline benchmark

`npm run qa --prefix Integrations/Flexbar` generates real Canvas PNGs in `Integrations/Flexbar/qa-output`: bilingual, Japanese, emoji/combining characters, narrow, middle/end of a long timed line, pause, loading, instrumental, 2170px immersive, paused reading pages, 60 karaoke frames and seven line-transition frames.

Initial PNG review revealed missing Simplified Chinese glyphs: PingFang SC was not registered by Canvas, and the fallback selected Japanese Hiragino Sans. Font comparison demonstrated that registered Hiragino Sans GB covers the tested Chinese text. Renderer now explicitly uses Hiragino Sans GB and shapes emoji runs with Apple Color Emoji. Regenerated Chinese, Japanese and emoji PNGs were reviewed and contain the tested glyphs without missing-character boxes. No fonts were redistributed.

Latest offline benchmark (90 warm frames per width, rendering plus PNG encoding):

| Width | Mean frame work | Mean PNG bytes |
| --- | ---: | ---: |
| 240 | 0.688ms | 9,852 |
| 720 | 1.228ms | 14,664 |
| 2170 | 2.456ms | 15,902 |

These numbers exclude WebSocket/SDK draw processing, USB transfer, device refresh and input handling. They do not establish actual device frame rate or lyric display latency. Report: `Integrations/Flexbar/qa-output/report.json`.

## Remaining hardware gate

The ordinary key Vue configuration panel was subsequently verified in FlexDesigner. Ordinary-card width behavior, physical DirectDraw/touch delivery, pause/dead power draw, SDK/USB sustained performance and visual latency still require physical-device verification. The coordinator did not save or upload the user's draft profile. Partial refresh stays disabled by default because tearing has not been measured. No undocumented immersive exit/navigation command is implemented. The native connection currently supports clock synchronization only during its initial subscription; no unsupported periodic request is sent.

## Plugin 0.2.0 update

- Fullscreen output follows device orientation, with normal/180-degree manual overrides. Only DirectDraw output rotates; ordinary cards remain under the host's normal rendering path. First frame after orientation change is full, even when diff refresh is enabled.
- Real FlexDesigner 2.2.3 `getDeviceStatus` response on 2026-09-27 returned `deviceData.config.screenFlip` as numeric `1`, despite the SDK boolean declaration. Initial response was stale after a newer device event. Both boolean and numeric 0/1 are normalized; other values are rejected. Event-triggered single-flight followup fixes that startup race without continuous polling.
- Fullscreen primary/auxiliary rows center independently; ordinary cards can choose center or left. With no auxiliary content, 36px single-line text centers vertically using actual glyph bounds. CJK, Latin descenders, combining characters and emoji were checked in generated PNGs.
- Reading pages are cached before text measurement, cover the whole lyric, and return to automatic playback after the last page. Single-page lyrics do not enter a redundant reading mode.
- Incoming-only line entrance avoids old/new text overlap. Very short cues display immediately. Real word karaoke and long-line following remain enabled at the chosen 15/20/30fps ceiling; pause/hidden/disconnected states stop animation.
- PNG review covered independent centering, precise 180-degree pixel inversion, single-line bounds, transitions, karaoke mask and pagination in `Integrations/Flexbar/qa-output/v020`.
- The installed ordinary key's Vue panel showed new alignment controls, confirming UI loading in FlexDesigner. The current unsaved `Apple2.flexbar*` draft was actively edited by the user; changing its hash is not attributed to the plugin installation.
- Physical orientation, touch delivery, sustained device frame rate and actual power draw remain distinct from software/host verification. No undocumented exit/navigation API is used.

### Final installed host evidence

At 18:30:12 local time the final plugin logged `Flexbar screenFlip: true` on the real FlexDesigner host. The one-time structure diagnostic confirmed numeric raw `screenFlip: 1`. This establishes real orientation acquisition, including the startup event race; physical-screen appearance still awaits user confirmation.

Final Node suite: 27/27 passed (327.9ms), including boolean/numeric orientation normalization, rejection of 2/string inputs, stale startup response and one event-authorized followup. Astra reviewed the delta and accepted the generation/revision/disconnection safeguards. Log: `/tmp/lyricsx-flexbar-node-v020-numeric-tests.log`.

Official pack/install succeeded. ZIP CRC plus seven package/source/installed entry comparisons passed, including backend, manifest and all four Vue aliases. Final package SHA-256: `89f6e26c1fe2fb31a76344e53f78cfc17c84775937619f12246e1710beb63444`. Installation record: `build/flexbar-upgrade-record.json`; previous plugin backup: `build/installation-backups/flexbar-20260927-181530`. Native application remains the already installed development build; this update changed only the plugin.

## Plugin 0.2.1: optional 60fps target and latency diagnosis

- User reported Flexbar highlights/line changes slightly behind desktop lyrics. Both plugin modes now accept 60fps, targeting 16.67ms during changing content. Existing/default 30fps remains unchanged. Static, paused, suspended, dead and disconnected cases retain animation cancellation. Native cue-boundary scheduling and monotonic clock remain unchanged.
- The official DirectDraw documentation gives about 15–45fps depending on content, not a guaranteed 60fps. Optional partial refresh can improve small changes but may tear; it remains off by default. API reference: https://eniac-tech.github.io/FlexDocumentation/flexbar/zh_CN/sdk/plugin_structure.html
- Each key lifecycle measures at most its first 30 successful host draw calls; only first/30th summary logs are emitted. No measurement timer or polling is added. The measurement explicitly reports API ACK time, not physical display latency or screen FPS. No blind clock advance is introduced.
- 29/29 Node tests passed (310.7ms), including 60fps delay, legacy30, static cancellation and bounded diagnostics. Astra reviewed source and bundled artifacts. Logs: `/tmp/lyricsx-flexbar-node-v021-tests.log`, `/tmp/lyricsx-flexbar-host-v021-install.log`.
- Official pack/install succeeded. ZIP CRC plus seven package/source/installed entry comparisons passed. Version 0.2.1; SHA-256 `55f38f4bf3826ed23a7763d41599f4336125f3c8e97c22715a855963df116933`. Real host started normally and still read screenFlip=true.
- The existing editor iframe continued displaying its old cached configuration after the hot update. Coordinator did not succeed in selecting60, save or upload the draft; current key remains30 until the user refreshes FlexDesigner and selects60. The user was asked to save their draft, reopen the app, select60 and re-enter the device lyric page. No real draw ACK sample or physical60 result is yet available.
- Backup: `build/installation-backups/flexbar-0.2.1/previous-plugin`, with autosave copy `autosave-before-fps.flexbar`. The coordinator only navigated editor selection/tabs. Native app requires no reinstall.

The user subsequently confirmed selecting60. Native AX state independently showed “超流畅（60 fps 目标）”, value60, in the real ordinary-key settings panel. Host draw ACK samples remain unavailable at this observation; physical60fps and subjective lag improvement are not claimed.

At 18:38:17 and 18:38:18, real ordinary-key UID19 successful draw API ACK first samples were4.371ms and2.462ms across two alive lifecycles. These prove actual draw submission/reply after activation, not final physical presentation timing or a sustained FPS measurement. No30-sample summary was yet available.
