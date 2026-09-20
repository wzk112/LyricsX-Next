# 2.0.34 发布介绍覆盖检查

对照上一公开版本 2.0.28（b6345f78d139d0a88847532112abd4c7afdcc2a2）与当前代码，新增项目必须有明确说明；已存在的功能仅作为教程或改进介绍，不重复宣称新增。

| 变化 | 代码依据 | 更新介绍 | 新手教程 |
| --- | --- | --- | --- |
| 本机字体选择、自动后备、实时排版预览和恢复 | LyricTypographySettings / LyricTypography | font34 | fonts |
| 主歌词和辅助文字独立颜色、持久化 | Preferences / LyricTypographySettings | color34 | colors |
| 已唱与未唱独立颜色、动态进度预览 | LyricTypographySettings / WordHighlight | word34 | wordColors |
| 封面主题色、明暗配色、缺图回退、手动颜色保留 | ArtworkTheme / Preferences | theme34 | theme |
| 主背景封面取色改进 | AmbientArtwork / ArtworkTheme | theme34 | theme |
| 搜索预览与应用分离、双语逐字预览、保留列表 | SearchView / SearchLyricPreview | search34 | search |
| 手动选择恢复显示、专辑单曲例外、过期结果保护 | AppModel / SearchSelectionTests | search34 | search / timing |
| 设置重排、侧栏、动态选项与开发者入口 | PreferencesView | settings34 | 各功能页 / privacy |
| 首次教程、版本更新、关于重看、关闭后释放示例 | FeatureGuide | guide34 | privacy |
| 启动、菜单栏、悬浮窗高度、自定义字体布局 | OverlayController / OverlaySizing / LyricsXApp | overlay34 | main / overlay / fonts |
| 逐字缩放、辉光、封面背景过渡与资源管理 | WordHighlight / ArtworkDecoder / PlaybackTimeline | playback34 | effects |
| 简繁逐字、EDR、歌词源和缓存兼容修复 | Preferences / HDRDisplaySupport / LyricsXServices | compatibility34 | text / effects / library |

已有功能：音乐来源识别、搜索来源排序、严格匹配、完整搜索、悬浮窗穿透和鼠标经过隐藏、两种材质、字号、偏移、文件导入导出、帧率模式。本次教程仍完整说明，但不作为新功能重新发布。

介绍内容改为 10 页更新与 14 页完整教程。字体、颜色、逐字双色、封面配色使用不同的可交互示意；搜索示意包含独立的预览与应用按钮。示意不保存偏好、不控制播放器。更新后的介绍按“版本＋内容修订”记录，看过旧 2.0.34 介绍的用户会收到一次补全版，之后不重复；手动重看不改变自动显示记录。

## 换句动画补充检查

- 播放位置通知晚到时，从已经显示的下一句位置开始移动，不跳过动画前段；只缩短剩余运动时间，逐字进度仍使用音乐时钟。
- 旧句从实际运动位置退出，普通速度淡出上限由 0.16 秒调整为 0.24 秒。快速歌词仍按可用时间缩短；暂停、隐藏和更换内容不会积累退出图层。
- 回弹、模糊和淡出曲线平滑收尾。文字框保持固定布局，运动只使用绘制偏移；没有逐字数据的文字复用渲染内容。
- 自动检查包含晚到 120 毫秒时单行、双行的像素位置连续性、连续快句、不重复启动、被打断的运动位置，以及静态文字和逐字时钟分离。

验证：129 项应用测试使用 `swift test --no-parallel --filter LyricsXAppTests` 全部通过。AppKit 时序测试需要显式关闭并发；默认运行器并发执行时出现等待超时，串行复查通过。教程、更新与设置共生成 33 张最小窗口截图；安装版本实际验证了补全介绍自动出现、重启不重复和关于页面手动重看。

本机 120 Hz 屏幕、Release 原生悬浮文字测试（每种 10 秒，独立测试偏好，无真实播放器）：普通歌词动画更新间隔中位数从 8.33 ms 到 8.34 ms，p95 从 14.17 ms 到 13.84 ms，进程 CPU 从约 6.42% 到 4.64%；逐字歌词中位数 8.33 ms、p95 12.83 ms。测量的是文字视图更新节奏，不是 GPU 呈现帧率或整机功耗；测试背景为固定黑色，不能据此推算玻璃材质或其他设备的耗电。
