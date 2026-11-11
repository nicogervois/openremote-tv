# Developer preview validation

## Simplified remote revision — 2026-11-10

The photo-inspired remote replaces arrow buttons with four annular touch regions and a center select button. Volume/channel rockers have three 48-point touch regions each. Their middle grips mute or open numbers. Secondary controls are under More; playback opens explicit actions instead of assuming playback state.

Local Flutter analysis passes with no issues, and all 20 tests pass. New checks cover ring edges/diagonals/center, inert disabled controls and accessible names, rocker mappings, playback actions, and the complete connected remote fitting a 390×844 iPhone viewport with 47-point top and 34-point bottom safe areas. A separate real Flutter render was visually reviewed. Smaller screens and larger text retain scrolling. Network adapters are unchanged; physical TV validation remains pending.

The native build results below belong to the original preview commit. The new UI commit triggers its own CI build.

## Original preview

Validated 2026-11-10 against application commit `c8953a4`.

| Check | Result |
|---|---|
| Dart formatting | Passed in GitHub Actions |
| Flutter static analysis | Passed, no issues |
| Automated suite | 15 tests passed locally and in CI |
| TLS identity test | Real local TLS server: decline, first-use approval, pin reuse, changed pin rejected |
| Android native build | Debug APK built and uploaded |
| iOS native build | Debug simulator app built and uploaded |
| Rendered Flutter UI | Reviewed local capture with Roboto and Material icon fonts loaded |
| Physical iPhone + Samsung | Pending owner test |
| Physical LG / Sony | Pending |
| App Store / TestFlight signing and distribution | Not configured |

[Successful CI run and build artifacts](https://github.com/nicogervois/openremote-tv/actions/runs/42926781920).

Protocol tests communicate with local HTTP/WebSocket simulators, not real TVs. The capture test is opt-in with `CAPTURE_UI=1`; it was also run separately for visual inspection. Small-screen tests cover a 320×568 viewport at 1.4× text scaling. TLS tests need a private IPv4 interface and explicitly skip if the test host has none.

The iOS artifact is for Simulator only. Follow [the Mac-to-iPhone guide](iphone-quickstart.md) to sign a device build. Discovery entitlement approval, model-specific behavior, network standby and firmware differences remain hardware checks. No universal compatibility claim is made.

Subsequent quickstart and validation documentation commits do not alter application code and skip redundant native builds.
