# LyricsX Next Flexbar integration

Development preview, version 0.2.1. Native target: macOS 26+; installed FlexDesigner reference: 2.2.3. Device/USB drawing remains a separate verification step; offline Canvas measurements are not USB performance.

## Build and test

Use Node 20 or later. Official flexcli 1.0.7 needs Node 20 because its import assertion syntax fails on Node 26.

```
npm ci --prefix Integrations/Flexbar
npm run build --prefix Integrations/Flexbar
npm ci --prefix com.wzk112.lyricsxnext.plugin/backend --omit=dev
npm test --prefix Integrations/Flexbar
npm run validate --prefix Integrations/Flexbar
npm run qa --prefix Integrations/Flexbar
```

The root plugin directory is the package input. Backend Canvas dependencies must be included when packing: they are resolved relative to backend/plugin.cjs and no machine-specific library path is used. The installed native Canvas binary is architecture-specific; this development package targets macOS arm64. An x64 release requires packaging the matching Canvas optional dependency and a separate runtime test.

SDK source: https://github.com/ENIAC-Tech/flexdesigner-sdk (MIT); npm @eniac/flexdesigner 1.0.9. Build only substitutes import.meta path expressions with the host's --dir argument. The transport adapter corrects SDK reconnect binding/duplicate retries and rejects outstanding calls on host loss. API names, request protocol and drawing methods remain the official SDK's. No device brightness, auto-sleep or global configuration is changed.

## Display behavior

Add either a normal lyrics card (default 720px wide, adjustable in FlexDesigner) or the 2170×60 immersive directDraw key. Auxiliary text can prefer translation, show next lyric, or be hidden. Ultra smooth/Smooth/Balanced/Power saving choices correspond to 60/30/20/15fps targets. The default remains 30fps and existing saved values remain unchanged. Host drawing latency reduces the actual rate; selecting 60fps does not guarantee 60fps on hardware. Diff refresh is off by default because partial updates may tear. Immersive taps are handled through device.touch; that host event and immersive navigation have not yet been verified on hardware. No undocumented exit/navigation command is sent.

Real word ranges drive karaoke masks. Untimed lyrics get line transitions and scroll, without invented per-word timestamps. Timed overflow follows the singing word; untimed overflow uses the line's duration budget. Offscreen text storage uses bounded 400-grapheme chunks. Clicking enters viewport-sized reading pages, including while paused, so every grapheme can be inspected without waiting for an animation. Timed playback auto-switches storage chunks when singing passes a chunk boundary. This does not guarantee that thousands of characters can be read within a short music cue.

Immersive mode defaults to centered primary and auxiliary rows. Hiding the auxiliary row uses a vertically centered 36px primary line. Both modes expose center/left alignment. Immersive orientation defaults to the device screenFlip, with normal/180° overrides. Only immersive output is rotated. The official SDK types declare a boolean, while the installed FlexDesigner 2.2.3 returns numeric 0/1; both are accepted, other values remain unknown. Device orientation is queried on host/key/device events, without polling. A stale startup query can be followed once when a newer device event requires it. Orientation changes force a full frame before optional diff refresh.

Line changes animate only the incoming text with a slight 2px entrance and 90% to 100% brightness. Old text is never overlaid, and very short cues appear immediately.

## Native protocol v1

Private Unix socket: ~/Library/Application Support/LyricsX Next/Flexbar/bridge.sock. Each frame is UTF-8 JSON followed by newline, at most 64KiB. Initial subscription: {version:1,kind:'subscribe',clientTime:<monotonic seconds>,nonce:<random string>}. The initial clockSync echoes clientTime and nonce plus serverUptime. Offset is serverUptime minus the midpoint of client send/receive time, with RTT/2 uncertainty. The same connection currently permits only that first request. Periodic clockSync requests are unsupported; reconnection performs a new handshake.

Snapshot has state, isPlaying, suspended, current/next text and optional translation, sessionID/revision, track/document revisions, clock={hostUptime,position,rate}, timing={start,end,offsetMilliseconds,words:[{location,length,start,end}]}. Cue times are in lyric coordinates; add offsetMilliseconds/1000 to interpolated playback position exactly once. Word ranges use extended grapheme cluster offsets, segmented with Intl.Segmenter. Up to 128 word ranges, 4096 graphemes/8192 encoded-string bytes per field. Text outside mapped ranges stays visible. Full lyrics, paths and artwork are never exported. Same clock corrections do not reset transitions or scrolling. Pausing keeps the current content and stops animation.

Only alive keys are consumers. Dead keys, disconnected devices and host connection loss clear them, stop animation and cancel native bridge reconnect. Reconnect while alive uses 1/2/4/8/16/30-second bounded backoff. Each key has one host drawing call in progress and one latest render request; intermediate frames are discarded. Successful image hashes suppress duplicate drawing; failed drawings are retried with bounded backoff.

## 安装与启用

1. 启动本分支构建的 LyricsX Next，在“设置 → 通用 → Flexbar”启用“在 Flexbar 上显示歌词”。
2. 在 FlexDesigner 的插件页面安装仓库根目录生成的 `com.wzk112.lyricsxnext.flexplugin`。
3. 在按键库中找到 LyricsX Next，添加“同步歌词”普通卡片或“整屏歌词”。普通卡片可以调整宽度。
4. 在该按键设置中选择译文/下一句/关闭辅助行，以及流畅/均衡/省电动画。先保持“部分刷新”关闭。
5. 播放带同步歌词的音乐，确认卡片换句、逐字高亮与暂停；长文暂停时可点击逐页阅读。

应用已安装到 `/Applications/LyricsX Next.app`，插件 0.2.0 已通过官方 CLI 更新到真实 FlexDesigner。普通歌词配置面板已验证加载。未代用户保存或上传正在编辑的 profile。整屏触摸、USB 刷新延迟与可持续帧率仍需要物理设备验收。UI同时提供官方示例使用的后缀文件名及文档使用的完整cid文件名。

Native protocol/renderer gate evidence: [validation record](../../docs/Flexbar-Validation.md).
