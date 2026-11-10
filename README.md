# OpenRemote TV

A free TV remote for **iOS and Android**. No ads, subscriptions, accounts, analytics, or cloud service. Your phone talks directly to your TV on the same home network.

**Status: 0.1.0 developer preview. Samsung is the first hardware test target. No TV model has been verified on physical hardware yet.** Roku is intentionally out of scope.

## What's in the first version

- Samsung Tizen secure WebSocket pairing and saved tokens.
- LG webOS secure SSAP pairing and pointer-button controls.
- Sony BRAVIA IP control using a user-configured pre-shared key; buttons are queried from the TV.
- SSDP discovery, manual IP entry, multiple saved TVs and forgetting pairings.
- D-pad and swipe navigation, Home/Back/Input/Menu, volume/mute, channels, number pad and playback.
- Keyboard input and app picker on models that expose them.
- Optional Wake-on-LAN using a manually entered MAC address.
- Explicit offline demo, accessible button labels, scrollable phone/tablet layout, setup help and privacy information.

See [the compatibility matrix](docs/compatibility.md) before assuming a feature works on a particular TV. A brand logo alone does not determine its protocol.

## Try it

Install Flutter **3.47.9** (Dart 3.13.7). The repository includes Android and iOS projects.

```sh
flutter pub get
flutter run
```

Select **Try the demo** to explore without a TV. To test Samsung, open **My TVs → Find nearby TVs**, or **Add TV by IP address**. Keep the TV on and approve the prompt using its physical remote. See [Samsung testing](docs/samsung-testing.md).

### Android

Use Android Studio / Android SDK with Java 17. Run `flutter build apk --debug`, then install `build/app/outputs/flutter-apk/app-debug.apk` on your phone. GitHub Actions builds the same APK as a downloadable artifact after successful checks. It is a development build, not a Play Store release.

### iOS

**First test: [Mac → iPhone → Samsung quickstart](docs/iphone-quickstart.md).** Use manual IP entry initially.

Use a Mac with Xcode and the Flutter-recommended native dependencies. Open `ios/Runner.xcworkspace`, select your signing team and a unique bundle identifier, and run on an iPhone. The CI simulator build does **not** install on an iPhone.

The app includes the Local Network permission description. **Automatic SSDP discovery and broadcast Wake-on-LAN on iOS require Apple's multicast entitlement**, approved for the signing team and enabled in the provisioning profile. After approval, copy `ios/Runner/Discovery.entitlements.example` to `Runner.entitlements` and set `CODE_SIGN_ENTITLEMENTS` for Runner. Until then, use manual IP entry. This is deliberately not enabled in the unsigned template, so basic device builds do not falsely imply entitlement approval.

App Store/TestFlight distribution needs your Apple developer signing setup. Neither store submission nor signing credentials are included.

## Checks

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
# macOS only:
flutter build ios --simulator --debug
```

Tests use local HTTP/WebSocket TV simulators to check pairing, credentials, command payloads, app lists, Sony SOAP, LG pointer controls, malformed data, address restrictions and UI behavior. They do not prove firmware compatibility. Record real results in [the hardware checklist](docs/samsung-testing.md), including failures.

## Architecture and privacy

`lib/core` defines device/capability contracts and OS-protected storage. `lib/network` handles bounded discovery, certificate pinning and Wake-on-LAN. `lib/remotes` contains independent Samsung, LG and Sony adapters. `lib/ui` contains the Material interface. There is no server and no runtime Internet endpoint.

Samsung/LG use TLS with explicit trust-on-first-use and a pinned certificate. A changed certificate blocks reconnection until you forget and pair the TV again. The first trust decision assumes a trusted home LAN. No insecure fallback is attempted. Sony's PSK protocol and SSDP descriptions use local HTTP; the UI explains this before Sony pairing. The Android manifest permits cleartext for those protocols, while app code restricts destinations to private IPv4 and rejects discovery redirects. IPv6-only networks and hostnames are not supported in v0.1.

Credentials, IP addresses and pins remain in the phone's secure storage. **Forget TV** deletes that TV's saved records. See [privacy](docs/privacy.md) and [security](SECURITY.md).

## Next milestones

1. Test Samsung pairing, controls and reconnect on the owner's actual TV; fix firmware differences.
2. Validate LG and Sony on physical hardware; expand the verified model matrix.
3. Implement Android TV / Google TV's pairing and remote protocol for compatible Sony, TCL, Hisense and Philips models.
4. Consider casting, voice and other platforms as separate features after the core remote is reliable.

Screen mirroring, casting, voice, infrared, Android/Google TV, Fire TV and Apple TV are not implemented in this preview. This project does not promise universal model coverage.

## License

MIT for original project code. LG registration protocol data is Apache-2.0; see [third-party notices](THIRD_PARTY_NOTICES.md). Free distribution is the product commitment; an open-source license does not constrain every third-party fork's business model. Not affiliated with TV manufacturers.
