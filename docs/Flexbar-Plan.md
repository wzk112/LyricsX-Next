# LyricsX Next → Flexbar 实施与验收计划

规划日期：2026-09-27。源码基线：`origin/master` / `035b604c8cc65ecf14b3217607694cf3f7f564b2`，v2.0.37；实施分支：`codex/flexbar-integration`。本文件是 Astra 的实施约束和分阶段检查清单，结果以实际测试记录为准。用户已明确效果优先：保留逐字高亮、换句动效和长句顺滑阅读，在静止/暂停/无显示需求时停止工作。低功耗不作为删去这些效果的理由。

## 已核实的接入条件

- 当前项目是 Swift Package，Swift 6.2、macOS 26；构建入口是 `scripts/build.sh`，测试入口是 `swift test`。未发现适用的 AGENTS.md。旧 CLAUDE.md 的 Xcode 工程说明不作为当前构建依据。
- `AppModel` 持有生产 `LyricsSession`、`PlayerBridge`、`PlaybackTicker`。`start()` / `stop()` 管理生命周期；系统睡眠停止播放器并冻结会话，唤醒重启播放器。
- `LyricsSession.documentRevision` 对每次文档发布递增，包含同 UUID、同当前句索引的候选升级；不能只比较文档 ID。`trackRevision` 标识实际播放项目变化。
- `session.currentLineIndex` 已含歌词偏移和 seek 保护结果；Flexbar 不另建播放时钟，不重新搜索歌词。
- `Preferences.text(_:)` 提供简繁转换。原文、译文、下一句均经过同一转换。
- `LyricTickCadence` 为桌面动画设计，visible 时换句后可能 33ms、密集句 16ms；不能仅把 Flexbar 加入 visible 而引入不必要的动画计时。
- 本机安装 FlexDesigner 2.2.3。主代理已确认真实 Flexbar 连接，当前配置 `Apple2.flexbar*` 有未保存修改；任何实机检查必须保留该状态。

## 官方接口和发行差异

[SDK 文档](https://eniac-tech.github.io/FlexDocumentation/flexbar/zh_CN/sdk/sdk_api_reference.html) 规定通过插件后台接收按键生命周期，再用 `plugin.draw(serialNumber, key, 'base64', dataURI)` 更新图片。`plugin.alive` / `plugin.dead` 带设备与按键；`device.status` 提供连接事件。SDK 自己连接 FlexDesigner，LyricsX 只提供本机数据流。

[插件结构文档](https://eniac-tech.github.io/FlexDocumentation/flexbar/zh_CN/sdk/plugin_structure.html) 与 [官方示例 manifest](https://github.com/ENIAC-Tech/Plugin-Example/blob/master/com.eniac.example.plugin/manifest.json) 是 manifest 验证依据。提供普通 default 歌词卡片，并验证 keyType=directDraw 的沉浸整屏模式。DirectDraw 文档注明固定 60px 高、offsetX=0…2170、diffUpdate 仅更新变化区域；部分刷新可能撕裂。用真实 2.2.3 设备比较两路径的流畅性、延迟和传输量，再确定推荐路径。不能把文档的 15–45fps 当成本插件的实测性能。

版本存在必须明确处理的差异：官网写 `@eniactech/flexdesigner-sdk`，但该包及 `-v2` 在 npm 返回 404。当前 [官方 SDK 源码 package](https://github.com/ENIAC-Tech/flexdesigner-sdk/blob/master/package.json) 使用 `@eniac/flexdesigner` 1.0.9，该包可获取；[官方示例](https://github.com/ENIAC-Tech/Plugin-Example/blob/master/package.json) 也依赖旧包名。按已验证可安装版本锁定依赖，记录 lockfile 和源码出处，不自行假设新包可用。

[官方 rollup 示例](https://github.com/ENIAC-Tech/Plugin-Example/blob/master/rollup.config.mjs) 将 SDK 打进后台 CJS，Canvas 保留外部依赖。本机 app.asar 的 package.json 声明 Canvas，但没有单独 SDK 包；应用主逻辑是 bytecode，预装 Canvas 是否能被插件解析仍须启动验证。最终包必须证明它在正常 FlexDesigner 启动方式下能解析 Canvas。

[SDK 类型源码](https://github.com/ENIAC-Tech/flexdesigner-sdk/blob/master/src/types.ts) 中 `getDeviceStatus()` 返回的设备条目与 `device.status` 事件结构不同。不要对初始查询假设 `.status` 或 `.deviceData.connected` 存在；以实际响应、alive 和后续 status 事件共同初始化有效设备集合，防止查询完成覆盖更新事件。

## 结构和数据协议

`LyricsSession → FlexbarSnapshot → 本机 Unix socket → 插件连接管理 → Canvas → plugin.draw`

Swift 保持唯一歌词状态；插件负责像素排版、按键配置、设备生命周期。插件不访问播放器、不请求歌词网站、不读取歌词缓存。首版数据流只读，不增加播放控制入口。

实际文件：`Sources/LyricsXCore/FlexbarSnapshot.swift`、`Sources/LyricsXApp/FlexbarServer.swift`、`FlexbarController.swift`；插件源码放 `Integrations/Flexbar/`，宿主包目录为根目录的 `com.wzk112.lyricsxnext.plugin/`。AppModel 只接生命周期和按需 cadence，设置页只添加启用与状态。

### 通道

- Unix domain stream socket：`~/Library/Application Support/LyricsX Next/Flexbar/bridge.sock`，先验证 Darwin `sun_path` 字节长度。
- 私有目录 0700、socket 0600。拒绝 symlink、异主目录和非 socket 同名文件。仅清理确定属于当前用户且已无监听者的陈旧 socket；第二实例不能抢占活端点。
- 使用 nonblocking I/O / DispatchSource 或等价事件驱动机制，不阻塞主线程，不轮询文件或 HTTP。
- newline 分隔 UTF-8 JSON。插件首帧为 `{"version":1,"kind":"subscribe","clientTime":单调秒数,"nonce":"随机字符串"}`；服务器先回 clockSync，成功后才计为有效消费者，再立即回复当前 snapshot。不带 clientTime 的旧订阅仅用于静态兼容。
- 最多 4 个连接；每帧最多 64 KiB，含未完成帧的累计缓冲限制；首帧有一次性超时。错误只关闭相应连接。
- 输出最多一个发送中帧和一个最新待发 snapshot，慢消费者丢弃旧待发状态而不是累积无限队列。限制状态文本长度，保证编码后的帧上界。
- `stop`、断开和重复取消必须幂等；处理 EPIPE/SIGPIPE、文件描述符复用和取消回调竞态。

### Snapshot v1

稳定字段：`version`、`kind`、`sessionID`（每次服务启动的新 UUID）、`revision`（本会话递增）、`state`、`isPlaying`、`suspended`、`trackRevision`、`documentRevision`、`title`、`artist`、`primary`、`translation`、`nextLine`，以及 `clock` 和当前句 `timing`。

- state 为 `idle/loading/lyrics/song/instrumental/notFound`。暂停由 isPlaying 表示，并保留当前歌词；不要让 paused 覆盖内容模式。
- 当前句不存在、间奏、纯音乐、无匹配、加载中各有稳定可读兜底；间奏不用全屏高速动画。
- 原文、译文、下一句全部发送，插件按用户选择显示辅行。桌面的 showTranslation 开关不隐藏桥接译文，也不触发额外 Flexbar 帧。下一句从有效后续歌词挑选，避免纯空白占位；不得混入其他歌曲。
- 仅导出当前/后续一条必要文本；不导出完整文档、路径、网络令牌、封面字节、任意文件访问入口或持续 position。
- `sessionID/revision` 供接收顺序判断，不纳入内容去重签名。文档 revision 必须触发重新投影，但如果实际像素输入完全相同，插件可继续跳过 draw。

## 时钟和逐字同步协议

实际协议 `clock={hostUptime,position,rate}` 在同一次 `session.presentationPosition(at:hostUptime)` 采样生成，rate 在暂停/睡眠时为0。`timing={start,end,offsetMilliseconds,words:[{location,length,start,end}]}` 保留歌词时间坐标；插件只在一处用 playbackPosition+offsetMilliseconds/1000 转为歌词时间。words 的 location/length 是原文显示串的扩展 grapheme 偏移，最多128项；由 `TimedLyricFragment.make(line:text:)` 的已验证映射生成。主文本至多4096 grapheme且有8192编码字节预算；范围必须落在实际保留文本内。未映射文字仍显示，不编造cue；当前实现不另发文本 fragments 或 lineStart/lineEnd 字段。

host systemUptime 与 Node hrtime 原点不同。subscribe 携带 nonce/clientTime=t0；服务器在回写附近采样 serverUptime=s，回应 `{version:1,kind:"clockSync",echoClientTime:t0,serverUptime:s,nonce}`；插件核对 nonce。客户端接收时 t3，估计 clockOffset=s-(t0+t3)/2，RTT=t3-t0；以后 hostNow≈nodeNow+clockOffset。估计位置=anchor.position+(hostNow-anchor.hostUptime)*rate。此往返估计在单向延迟未知时有约RTT/2不确定度，发送队列与设备显示延迟另测。当前服务器要求首次 clockSync 立即写完；若遇到背压或连接失败则断开，让插件重试，不把滞留时间戳作为新校准结果。

source snapshot、seek、pause/resume、文档/当前句变化携带 anchor；独立于内容签名判定 clock 更新。PlayerBridge 常规 snapshot 在有消费者且偏差超过约50ms时发送校正（包括暂停时外部seek）；播放中距上次 anchor至少5s也允许校正。不读取 position 观察触发每tick发送，same-line显式seek不受5s节流。当前只支持首次订阅的时钟握手，同连接周期clockSync未实现、禁止发送；断线重连/系统唤醒重连重新校准offset。普通暂停恢复通过新anchor处理，sessionID变化重置渲染内容状态。长期连接的跨时钟漂移和端到端同步误差仍需实测。

没有逐字数据时只做真实换句动效；不能给普通LRC估算每字时间然后称为逐字同步。UI帧排队必须使用“执行绘图此刻”的位置，不能画已过期帧。画面晚于源码时间的误差须区分传输、编码、宿主绘制和设备刷新。

## 事件和功耗预算

### 原生侧

默认 `flexbarEnabled=false`。关闭时无监听 socket、无观察订阅、无重试、无绘图。启用但没有有效订阅者时只保留事件驱动 listener，不附加歌词计时或 snapshot 构建。

有消费者时观察 track/document revision、currentLineIndex、isPlaying、phase、相关文字设置。不能在 Observation 闭包读取持续变化的 position、整个文档大对象或 artwork。异步回调使用 generation 防止停止后的任务重新装订观察。

已有 UI 可见时保留现有 cadence。仅 Flexbar 可见时复用同一个 PlaybackTicker，使用无动画的下一句边界间隔：平常至多 250ms 基础更新，临近边界缩短到下一句时间；不因入场效果跑 33/16ms。接入函数保持旧调用默认行为，测试 seek、偏移、最后一句和 nil document。

暂停发布一次冻结状态，然后无周期发送；恢复时携带新 clock anchor，动画不能从旧接收时间继续。系统睡眠先发布 suspended/关闭通知（尽力一次），停止 listener/clients；唤醒根据启用状态重建服务，只接收播放器刷新后的状态，防止旧歌词恢复。退出停止所有句柄和观察。

### 插件侧

用 `serialNumber + key.uid` 作为按键身份，不能只用 uid。只有当前 alive 且设备有效时连接 LyricsX；最后一键 dead 或最后设备断开后断开本机连接、取消重试/分页计时、释放渲染缓存。

- 必须有真实 timing 驱动的逐字高亮、短换句动效和溢出长句平滑滚动。只在这些效果正变化时请求下一帧，静止和暂停时没有动画 timer；无歌词 timing 不编造逐字进度。禁止轮询心跳。
- Node 本地根据 clock anchor 计算当前呈现时间，以 15/20/30Hz 做实测，并在 draw 延迟增加时下调请求速率，不堆积过期帧。当前用户可选30/20/15fps上限，默认30；这是请求上限，实际频率受宿主反馈限制。没有实现自动低电量切换，用户可手动选择省电15fps，功能仍保留。实机测量后才决定最终推荐档。
- 一份源状态服务所有按键，按宽度/辅行/排版配置组合缓存 PNG，缓存有总数和内存上限。
- 同像素输入不重绘；宽度/配置变化、alive 重新出现、重新连接必须使相应缓存失效。
- 每键最多一个 draw 进行中，期间仅保留最新请求。draw 失败不能更新成功签名；重试有退避并能取消，禁止 busy loop。
- LyricsX 未运行而设备有效时允许有上限退避的连接恢复，优先监听私有目录变化触发恢复；无设备/无活跃键时重试计数为零。不要常驻 100ms/1s 探活。
- 不调用 SDK 全局 stop（当前官方实现未提供稳定 stop）；只清理插件自己持有的连接、计时、缓存，宿主 SDK 留给 FlexDesigner 管理。
- 不改 Flexbar 全局亮度、自动休眠、屏幕方向，不主动 sys.wake，不能以“优化”覆盖用户硬件设置。

验收指标是可计数的发送/绘图/定时器活动。CPU 对比需同一机器同一曲目同一窗口状态测量；不以软件单测声称已降低整机瓦数。

## 60px 画面设计

优先以实际事件 key.width 为宽度（并验证旧结构的 style.width fallback），Canvas 精确 60px 高。建议 720px 默认宽；宽度经 SDK 支持范围钳制。深色不透明底、亮色原文、清晰次级色；单原文约 27–30px，双行原文约 24–26px、辅行约 17–19px，按实测字体 metrics 调整。最小字体必须固定，不可为塞入极长句无限缩小。

实际渲染按 Intl.Segmenter 的 grapheme 边界分段并保持协议原文索引；不能先删改文字再沿用旧词范围。正确支持中文、日文、emoji、组合字符。长句默认仅溢出时平滑滚动，有起止停顿，滚动位置以当前行的绝对时间计算，跳转后不能接着旧行滚动。有真实逐字 timing 时尽量保持当前词可见。滚动速度不能为赶歌词无限提高；提供点击分页/定位作为极长或短时句的完整文本阅读入口。新歌词重置状态；暂停固定当前位置，点击可进入按视口宽度计算的分页。所有动作只改变当前键的显示，不触发播放器。

双语模式保留原文与译文关联；辅行可选“译文优先 / 下一句 / 关闭”。无译文可按明确配置回落下一句。不能把过长译文强行覆盖原文；双行各自测量溢出，原文与译文的滚动不能互相遮挡；分页后也有确定性映射。窄宽度降级必须可预期。

不把桌面 HDR/模糊层照搬到 60px 设备；换句过渡和逐字高亮保留清晰字形，动画不能使刚到达的短句不可读。当前实现使用26px原文、18px辅行，Hiragino Sans GB字体并单独绘制Apple Color Emoji run。已核对离线Canvas PNG的中文字形、日文、emoji和组合字符；实机阅读效果仍待核对。

## 分阶段委派 Sol 与验收

### 阶段 1：只读基线（已完成源码与初次测试核对）

已由主代理报告基线 `swift test`：187 tests / 30 suites 通过。报告实际源码/工具链、设备和 FlexDesigner 状态，记录官方 SDK 包名差异。不以旧记忆替代当前源码。禁止改现有配置或未保存 profile。

### 阶段 2：原生协议、投影、设置和生命周期

完成 snapshot、socket server、controller；在 Preferences 默认关闭；设置页展示启用状态和有效消费者数/等待状态。AppModel start/stop/sleep/wake 接入；需要时调整无动画 cadence。

通过标准：

1. 默认关闭无 socket；启用无客户端无附加定时任务；连接后立刻收到有效 JSON；断开计数归零。
2. 100 次普通 position tick 不产生逐 tick payload；时钟校正只走受限事件路径。同 ID 文档内容升级、翻译变化、换歌、same-line seek、offset、简繁设置变化均给出正确文本与 anchor。实际 seek 即使不改变 lineIndex 也必须立即发布。
3. 暂停一次更新后稳定；睡眠/停止清理；唤醒重启；重复 start/stop 无遗留任务。
4. 真 socket 测试覆盖分包、合包、非法 JSON、未知版本、超限帧、无换行上限、首帧超时、慢消费者、第二实例、symlink 和重启陈旧 socket。
5. 新定时策略不改变现有 UI cadence；Flexbar-only 不进入动画频率。Swift 6 Sendable/actor 检查通过。

每阶段给 Astra 代码清单、测试命令/结果、已知限制，审阅后再继续。

### 阶段 3：插件、排版、打包

以官方示例为基础建立最小 macOS 插件，固定 SDK 版本与 lockfile；协议读取、消费者集合、失败退避、Renderer 分离以便 Node 单测。提供可生成 QA PNG 的离线命令。

通过标准：

1. 正常/中文/日文/emoji/组合字符、双语、下一句、窄宽、长句滚动/分页、无歌词、暂停均生成正确尺寸 PNG；生成起唱/中间/结束、换句起中末、长句滚动起中末多帧并逐张看图，确认未截 baseline、重叠或缺字。
2. 相同 snapshot 100 次不会重置时钟/动画或增加重复调度；静止画面首次 draw 后 0 次；有 timing 或滚动时仅实际变化像素绘图。相同 uid 不同设备各正确更新；dead/disconnected/paused 后动画计时为零。
3. 重新 alive 强制绘图；draw 错误可恢复；慢 draw 时 pending 数量≤1，最后画面是最新内容。
4. Node 真 socket 客户端与 Swift server 互通；malformed/过期 revision/更换 sessionID、时钟同步延迟和漂移、same-line seek、零/重叠cue、暂停恢复均有测试。高亮片段拼接必须等于实际显示文本，简繁字符数变化时安全回落。
5. manifest 用官方 CLI validate；打包后检查入口、依赖、资源、mac平台限制及完整性。以 FlexDesigner 实际启动日志证明 require 成功。
6. 对 ordinary draw 和 DirectDraw 以相同画面测试 15/20/30Hz，记录完成帧率、draw p50/p95、丢弃过期帧数、每秒编码字节、进程 CPU；检查diffUpdate撕裂。设备/页面未能安全测试则保留明确未测项，不声称30Hz已实现。

### 阶段 4：整合和实际显示检查

串行执行 Swift 完整测试、Node 测试、插件验证和 release build。现有 UI 回归覆盖窗口/菜单栏/悬浮歌词、搜索、播放暂停、seek、切歌，不为检查而改用户音乐库或歌词缓存。

保护 `Apple2.flexbar*` 未保存状态。优先插件独立预览/不覆盖 profile 的检查；若把新键真正下发必须替换现 profile 或丢弃未保存更改，则先交付可安装包与 PNG，并明确剩余硬件步骤，不擅自保存覆盖。

有实际安全测试入口时检查连接、换句、暂停、拔插、页面离开重进、应用退出重启和睡眠唤醒。记录“源码/测试通过”“FlexDesigner 启动通过”“物理屏幕人工可见确认”各自证据，不能用软件 draw promise 成功代替肉眼可读性。

### 阶段 5：交付

交付可安装应用或已验证 build、`.flexplugin`、简短使用说明、QA PNG、测试摘要和硬件尚未覆盖项。保持默认关闭；说明用户需要启用本机输出并在 FlexDesigner 将歌词键放入适当页面。未经另外授权不发布 release、不改变全局 profile、不把实验显示替换用户现有工作流。

## Astra 审阅特别检查

- Observation 订阅是否真的由消费者需求驱动；是否不小心读取 position 导致每 tick 构建/编码。
- Swift socket 的 write 并非假设一次发完；close、取消 handler、陈旧端点清理是否有竞争。
- plugin.alive 不是永久有效状态；按页生命周期、多设备、重新连接必须正确。
- 文档更新、转换、nextLine 和暂停恢复是否会漏发；签名是否只在成功绘图后更新。
- 逐字高亮、换句动效、溢出长句滚动是功能要求；帧率、同步误差、功耗瓦数和“最佳显示”达成程度用实际画面和测量说明，不用删功能来满足低负载测试。

## 已完成 gate（2026-09-27）

阶段 2 原生实现与 14 项针对性测试完成；协调者完整串行 Swift 回归 201 项通过。新增真实 Swift server ↔ Node LyricsBridge 跨语言 socket 测试通过，验证 nonce 时钟握手、初始歌词、暂停、同句 seek、重连 session 更新。

阶段 3 插件模块、14 项 Node 测试（含 bundled CJS mock host）、自有结构验证、官方 CLI validate/pack、当前 Canvas 字体的 PNG QA 和离线渲染 benchmark 完成。按键 UI 同时输出完整 cid 与后缀入口，等待真实宿主确认加载约定。安装包内包含 macOS arm64 Canvas 本地依赖和第三方许可。

实际命令、日志、字体修复证据、离线性能数字和未测硬件范围见 [Flexbar-Validation.md](Flexbar-Validation.md)。目前阶段 4 真实 FlexDesigner/设备检查仍为待验收项；源码 gate 和模拟 host 成功不替代物理屏幕证据。


## 2026-09-27 Astra 正式审核记录

### 阶段2：通过

Astra只读核对最终原生代码；主代理核验14/14 Flexbar测试通过。已关闭三项实质回归：读写DispatchSource各持独立FD并在各自cancel回调释放；仅第一消费者初始化去重基线，后续消费者不吞已有客户端广播；clockSync握手只有成功后才计入countedSubscriber，失败不下溢。暂停中的同句外部seek、100次position tick去重、转换/offset、慢消费者与快速重连均有针对性测试。桌面翻译关闭仍传译文的后续小改按独立回归纳入验证。

### 阶段3：代码与离线画面通过，准入打包/实机阶段

Astra已直接查看 bilingual、japanese、emoji、narrow、long-middle、karaoke、paused-page 和 transition 多帧PNG。中文字体修复有效，组合emoji保留；窄屏当前词跟随可见，暂停点击分页可读取后续文本。短cue避免淡出遮挡，普通换句使用约0.18秒交叉淡化，实机可再评估叠字观感。

只读代码审核确认：暂停/静止停止动画timer，完成的长句不继续仅为哈希去重而重复编码；最后dead键清空旧clock与snapshot，重入等待新数据；每键一个进行中draw和一个最新请求，调度扣除本帧已消耗时间；多设备用serial+uid隔离。Node14/14与CJS mock-host/便携Canvas依赖加载通过由执行代理报告，Astra已审对应测试代码；实际宿主设备仍是下一gate。

唯一包装入口修正：官网描述按完整cid命名Vue，但官方Example使用cid后缀，不能依赖未经证实的key.configPage。已输出lyrics.vue、immersive.vue及两个完整cid别名，四个文件SHA-256一致，manifest已移除key.configPage依赖；Astra只读复核完成。真实设置入口仍由FlexDesigner按键编辑器验证。当前没有剩余阶段3代码阻断。

### 尚未证明的硬件结果

- 普通draw和DirectDraw实际15/20/30fps、USB吞吐、绘制p95延迟、同步误差和整机功耗；现有report.json只测Canvas+PNG，排除宿主和USB。
- 真实FlexDesigner 2.2.3按键设置、device.touch分页、DirectDraw进入/退出与partial-refresh撕裂。没有虚构返回页面API，沉浸导航保持未验证限制。
- 物理设备拔插、实际页面切换、宿主/原生退出重启、真实睡眠唤醒后的端到端表现。
- 真实Flexbar显示的字体清晰度与交叉淡化观感。离线720×60 PNG通过不等于物理屏幕效果已经确认。

主代理报告最终应用release build及strict codesign完成；Astra未在本审核阶段另跑构建。用户未保存的Apple2.flexbar*配置必须继续保留，不能为了实机gate覆盖或丢弃。
