# 2.0.37 (272) release verification

- Rendering implementation: one linear HDR color multiply replaces the chained SDR/HDR filters in the colored glyph bloom path. Broad overlay halo radius is 72% of the shared radius, previously 82%; emitter opacity, animation timing and dark-ink rim remain unchanged.
- Full serial test run before release metadata: 98 core, 39 services and 186 app tests passed. Native HDR lifecycle and production main/overlay parity suites both passed with float screen capture. Default glass, dark frosted, independent word colors and cover palettes track 1 / 2.5 / 4 / 1×, with matched main/overlay peaks. See `hdr-independent-output.md` for measurements and limits.
- Release introduction: 14 guide tests passed after version/baseline changes, including first install, cumulative updates and one-time introduction for users upgrading from 2.0.36 (271). The guide uses the existing live production glass illustration.
- No preference migration is required; no user color, brightness or cache values are reset.
- Release is ad-hoc signed for Apple silicon/macOS 26+, not notarized. This task does not claim a physical nits calibration or measured reduction in whole-system power.
