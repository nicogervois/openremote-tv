# Compatibility and scope

Implementation status is separate from hardware verification. All physical-device results are currently **pending**.

| Platform | Pairing | Basic remote | Keyboard | App list / launch | Notes |
|---|---|---|---|---|---|
| Samsung Tizen | On-TV approval, token, TLS port 8002 | Implemented | Implemented; active TV text field required | Implemented; firmware-dependent | First hardware test target. Older Samsung protocols and plaintext-only TVs excluded. |
| LG webOS | On-TV approval, client key, TLS port 3001 | Implemented, including pointer socket buttons | Implemented; TV app-dependent | Implemented | Secure pointer endpoint required. Legacy NetCast excluded. Some TVs display the protocol's LG Remote App pairing name. |
| Sony BRAVIA IP control | User-set PSK, local HTTP | Implemented using TV-reported IRCC codes | Unavailable | Implemented; model-dependent | Requires IP control; not equivalent to generic Google TV support. |
| Android TV / Google TV | Not implemented | Not implemented | Not implemented | Not implemented | Roadmap: pairing certificates and remote protocol, not just Chromecast discovery. |
| Roku | Out of scope | — | — | — | Explicit product decision. |
| Fire TV / Apple TV / other platforms | Not implemented | — | — | — | Separate protocols and validation required. |

Power on uses Wake-on-LAN if the TV supports network standby and a MAC address is saved. Power button sends a Samsung power key or LG/Sony power-off command to an already connected TV. Neither can wake a TV whose network interface is off. Swipes emulate directional presses, not a native mouse cursor. Channel commands only apply to compatible tuner contexts. External audio receivers can change volume behavior.

Discovery supports private IPv4 SSDP responses. It is bounded (4-second search, at most 64 description requests, description size cap), deduplicated and ignores devices not identified as compatible TVs. Manual IP entry is the fallback for missing SSDP advertisements and iOS entitlement restrictions. It does not scan every IP address on the subnet.

## Reference material reviewed

- [BoostVision reference app](https://play.google.com/store/apps/details?id=com.boost.universal.remote): discovery, remote, text and casting baseline. Casting/mirroring deferred.
- [CodeMatics reference app](https://play.google.com/store/apps/details?id=codematics.universal.tv.remote.control): remote and smart-TV feature baseline.
- [SensusTech reference app](https://play.google.com/store/apps/details?id=sensustech.universal.tv.remote.control): universal-remote feature baseline.
- [Samsung protocol implementation reference](https://github.com/xchwarze/samsung-tv-ws-api): message formats; original Dart implementation, no Python code copied.
- [LG protocol reference](https://github.com/home-assistant-libs/aiowebostv): SSAP and registration manifest. Exact vendored revision and license in THIRD_PARTY_NOTICES.md.
- [Sony network control](https://pro-bravia.sony.net/remote-display-control/): REST and IRCC-IP interfaces. Professional-display documentation does not establish support on every consumer TV.
- [Apple multicast entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.networking.multicast).

Reviewed 2026-11-10. TV firmware, permissions and available APIs can change independently of the app.
