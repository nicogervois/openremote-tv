# First Samsung hardware test

Status: **not yet run on a physical TV**. Automated mocks are not a substitute for this checklist.

Record TV model/year, firmware, phone model, OS, app commit and router conditions. Do not publish IP/MAC addresses, pairing tokens, certificate fingerprints or your Wi-Fi name in public issues.

1. Install the Android debug APK, or build/sign the iOS app on a Mac. Connect to the same non-guest Wi-Fi as the TV; turn the TV on with its existing remote.
2. In **My TVs**, try **Find nearby TVs**. If absent, use the TV's network settings to find its IP and choose **Add TV by IP address → Samsung**.
3. Confirm the app shows the correct IP. Approve first-use TV identity in the app and the connection prompt on the television. Samsung menu paths differ; mobile-device permissions are commonly under External Device Manager / Device Connect Manager.
4. Test Up/Down/Left/Right/OK, Back, Home, Menu and Input. Verify a single tap produces a single action.
5. Test volume, mute and channels in live TV. Repeat with any soundbar/receiver and note limitations.
6. Test Play/Pause/Rewind/Fast-forward within a media app. Some apps ignore these commands.
7. Open a search field on the TV, send simple text, then accented characters. Do not use a password field for this test.
8. Open Apps and launch one returned app. If firmware withholds the list, verify the app displays an explanation and Home navigation still works.
9. Background/foreground the phone app. Reconnect and confirm that the saved token works. Power off/on the TV and repeat. Restart the app and check the saved TV.
10. Deny a first-time pairing on the TV; verify an error rather than a connected state. Disconnect Wi-Fi and verify errors are actionable. Revoke the app in Samsung settings; forget and re-pair.
11. Optional: save the MAC address and enable the TV's network standby/power-on-with-mobile option. Power off, select **My TVs → menu → Wake TV**, wait and reconnect. A wake packet is not proof that the TV woke.
12. Forget TV and verify its saved listing and credentials are gone. If its IP later changes, add the new address.

## Result record

| Field | Result |
|---|---|
| TV model / firmware | Pending |
| Phone / OS | Pending |
| App commit | Pending |
| Discovery | Pending |
| First pairing / denial | Pending |
| Buttons / volume / inputs | Pending |
| Keyboard / app list | Pending |
| Reconnect / token reuse | Pending |
| Network loss / revoked pairing | Pending |
| Wake-on-LAN | Pending / optional |

If the secure port is unavailable, record the model as unsupported rather than switching to an insecure connection automatically.
