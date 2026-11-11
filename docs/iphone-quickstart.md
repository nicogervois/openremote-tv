# Test OpenRemote TV on your iPhone

You have a Mac and a Samsung TV. This path uses **manual IP pairing**, so it does not require Apple's restricted multicast entitlement.

## Prepare the Mac and phone

Install Flutter 3.47.9 and current Xcode. Complete Xcode's first launch and iOS platform setup; install CocoaPods if Flutter requests it. Check `flutter doctor` for missing components. Connect the iPhone to the Mac, trust the computer and enable Developer Mode on the iPhone when prompted.

These platform steps follow [Flutter's official iOS setup guide](https://docs.flutter.dev/platform-integration/ios/setup). For testing on your own device, a personal Apple developer account can be used; App Store distribution is a separate setup.

In Terminal on the Mac:

```sh
git clone https://github.com/nicogervois/openremote-tv.git
cd openremote-tv
flutter pub get
flutter build ios --config-only --no-codesign
open ios/Runner.xcworkspace
```

In Xcode, select the **Runner target → Signing & Capabilities**. Enable automatic signing, select your team, and change the bundle identifier if Xcode says it is unavailable. Leave the multicast example entitlement disabled for this first test. Choose your connected iPhone as the run destination and press Run. Handle any certificate trust prompts on your own devices.

Alternatively, after configuring signing, use `flutter devices` to find the phone ID and `flutter run -d <device-id>`.

## Pair with the Samsung

1. Put the iPhone and TV on the same home Wi-Fi. Turn the TV on and keep the physical remote handy.
2. Find the TV's IPv4 address in its network settings. Samsung menu wording varies by model.
3. Open OpenRemote TV → **My TVs → Add TV by IP address**. Select Samsung, enter a nickname and that IP. The optional MAC field can stay blank.
4. Allow the iPhone's Local Network permission if requested. Confirm the TV identity shown in the app, then approve the connection request on the TV.
5. Test Home, directional buttons, OK, Back, volume and mute first. Then try an on-screen search field with **More → Keyboard**. App listing and text entry vary by firmware and TV app.
6. Disconnect and reconnect to test token reuse. Use **Forget pairing** if the TV's identity changes or its permission has been revoked, then add it again.

If connection fails, record the Samsung model and firmware plus the app's error message. Do not post tokens, IP/MAC addresses or Wi-Fi details in public issues. The full checklist is [samsung-testing.md](samsung-testing.md).

The GitHub Actions iOS artifact is a **simulator app**, not an installable iPhone package. Your Xcode-signed device build is the correct test installation. The Android APK is unrelated to this iPhone workflow.
