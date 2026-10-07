# 音乐播放器识别扩展（本地开发记录）

核验日期：2026-10-07。此记录不代表发布或逐款播放兼容性认证。

## 实现

`MusicSourcePolicy` 将应用 Bundle ID 转为小写后进行精确匹配。原有 Apple Music、iTunes、Spotify、网易云、QQ 音乐的两个标识和酷狗继续保留；本次新增 13 款播放器，含明确核实的构建和产品变体，共新增 16 个标识，固定集合合计 23 个标识。

识别顺序维持如下：

1. 无标识、空标识和 LyricsX 自身不接受。
2. 浏览器及其以点分隔的子标识优先排除，即使它宣称自己是音乐类应用。
3. 固定集合精确匹配，忽略大小写，不依赖应用名或分类。Petrichor 的 debug 构建、Pine Player 的 Pro/Origin 变体分别列出，不开放任意后缀。
4. 保留原有 QQ 音乐、网易云的 iOS-on-Mac 后缀规则。
5. 未列出的应用继续通过 `LSApplicationCategoryType = public.app-category.music` 兜底；该分类是发布者提供的元数据，可能也包含音乐制作工具或辅助应用，不等于验证过的播放器。

MediaRemote 读取路径已有 `parentApplicationBundleIdentifier` 优先于进程标识的处理，本次沿用它。应用发现依然缓存结果并由工作区事件失效，分类读取依然缓存；没有新增网络查询、定时扫描、启动播放器或播放轮询。

## 新增标识与证据

| 播放器 | Bundle ID（发布者原始大小写） | 核验来源 |
| --- | --- | --- |
| Petrichor | `org.Petrichor`、`org.Petrichor.debug` | [官方 Xcode 工程](https://github.com/kushalpandya/Petrichor/blob/main/Petrichor.xcodeproj/project.pbxproj)，`PRODUCT_BUNDLE_IDENTIFIER` |
| Swinsian | `com.swinsian.Swinsian` | [官方下载](https://swinsian.com/download-thanks.html)指向的 `https://swinsian.com/sparkle/Swinsian.zip`，3.0.8 主应用 `Contents/Info.plist` |
| Doppler | `co.brushedtype.doppler-macos` | [官方网站](https://brushedtype.co/doppler/)指向的 `https://updates.brushedtype.co/doppler-macos/download`，2.1.22 主应用 `Contents/Info.plist` |
| Cog | `org.cogx.cog` | [App Store](https://apps.apple.com/us/app/cog-kode54/id1630499622)，Apple Search API 的 `bundleId` |
| foobar2000 | `com.foobar2000.mac` | [官方下载](https://www.foobar2000.org/mac)的 2.26 DMG，主应用 `Contents/Info.plist` |
| VOX | `com.coppertino.Vox` | [App Store](https://apps.apple.com/us/app/vox-mp3-flac-music-player/id461369673)，Apple Search API 的 `bundleId` |
| Pine Player / Pro / Pro the Origin | `com.digipine.pineplayer`、`com.digipine.pineplayer.pro`、`com.digipine.pineplayer.origin` | Apple Search API；[普通版](https://apps.apple.com/us/app/pine-player/id1112075769)、[Pro](https://apps.apple.com/us/app/pine-player-pro/id6474128342)、[Origin](https://apps.apple.com/us/app/pine-player-pro-the-origin/id6727009528) |
| Colibri | `gaborhargitai.colibri` | [App Store](https://apps.apple.com/us/app/colibri/id1178295426)，Apple Search API 的 `bundleId` |
| Musique | `org.tordini.flavio.musique` | [App Store](https://apps.apple.com/us/app/musique/id474190659)，Apple Search API 的 `bundleId` |
| Strawberry | `org.strawberrymusicplayer.strawberry` | [官方 Info.plist 模板](https://github.com/strawberrymusicplayer/strawberry/blob/master/dist/macos/Info.plist.in) |
| Listen1 | `com.listen1.listen1` | [官方打包配置](https://github.com/listen1/listen1_desktop/blob/master/package.json)，`build.appId` |
| 洛雪音乐 LX Music | `cn.toside.music.desktop` | [官方打包配置](https://github.com/lyswhut/lx-music-desktop/blob/master/build-config/build-pack.js)，`appId` |
| MusicFree Desktop | `fun.upup.musicfree` | [官方打包配置](https://github.com/maotoumao/MusicFreeDesktop/blob/master/forge.config.ts)，`packagerConfig.appBundleId` |

Apple Search API 查询使用 `https://itunes.apple.com/search?term=<名称>&entity=macSoftware&country=us&limit=15`，逐项核对产品名、发布者、类别和 `bundleId`，排除了同名商业软件、天气应用和 VPN 等无关结果。安装包只用于只读检查元数据，未安装或启动；ZIP 内的辅助应用标识未加入固定集合。

## 范围与待核验项目

识别通过只代表该来源可以进入现有播放状态读取路径。新增播放器沿用系统 MediaRemote 状态，需要播放器提供曲目、时长及进度；本次没有为它们添加专用读取或控制协议。

Issue #8 的浏览器抢占问题仍依赖独立的播放器会话读取及来源选择改造。扩展固定集合不解决系统快照只剩浏览器的情况。

TIDAL、Qobuz、Roon、Plexamp、Audirvana、DeaDBeeF、YesPlayMusic 等候选尚未完成本次 Bundle ID 核验，不猜测加入；如果其已安装应用声明音乐分类，仍可通过现有分类兜底。VLC、IINA 未列入固定集合，以免自动跟随视频。

测试覆盖新增标识缺失/不同分类时的识别、大小写、未知前后缀拒绝、同名无关应用、浏览器子进程优先排除、原有音乐分类与 iOS-on-Mac 规则。逐款真实播放和浏览器抢占未验证。

## 本地验证结果

- `swift test --no-parallel`：退出码 0，Services 123 项、Core 42 项、App 313 项，三个测试目标均通过；应用目标同时完成构建。
- 新增播放器参数化测试的 16 个用例全部通过；无关软件及浏览器边界测试通过。
- `git diff --check` 通过。
- 默认不启用的原生 HDR、绘制频率及窗口专项测试保持跳过；未逐款启动新增播放器测试真实播放、进度和控制。
- 仅完成本地源码扩展，未发布或替换 `/Applications/LyricsX Next.app`。
