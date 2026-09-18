# Overlay sizing and lyric customization verification

- Overlay size notifications reconcile the controller's current snapshot instead of applying an asynchronous view's potentially stale measurement.
- Font selection participates in sizing invalidation and text-measurement cache keys. Text measurement and rendering use the same installed font, falling back to the system font when unavailable.
- Hidden windows receive their new geometry before being shown. Hover-hidden or temporarily screenless windows settle geometry without a native resize animation.
- When no display is available, the previous panel frame is no longer treated as screen bounds (which previously prevented expansion).
- Menu bar labels use direct text. Removing the separate item when switching to combined mode no longer writes back to the lyric visibility preference. The lyric clock includes menu-bar-only use.
- Settings offer installed fonts, primary and auxiliary colors, a preview using the actual overlay renderer, and a reset action. Preferences persist; invalid saved colors fall back to white.

## Launch and window lifecycle

The app delegate owns the shared model and starts playback observation, overlay and hotkeys in applicationDidFinishLaunching. No main-window onAppear is required.

Floating lyric frame sources ignore transient occlusion flags during other windows’ animations. Their own visibility, miniaturization and running state still stop drawing; regular main-window frame sources retain occlusion-based power saving.

## Validation

Full native test run passed: 92 core, 34 service and 86 app tests (212 total). Includes actual text-rendering and native window sizing tests, hidden replacement/font changes, main-window lifecycle notification isolation, waiting-to-lyrics handover, rapid resize retargeting, same-ID document replacement, menu bar text updates, and preference persistence.
