# Privacy

OpenRemote TV 0.1 stores saved TV names, addresses, optional MAC addresses, pairing credentials and certificate pins in the operating system's secure storage. It has no account, backend, advertising, subscription, analytics or telemetry. Android backup is disabled to avoid restoring encrypted preferences without their keys.

Discovery sends SSDP packets on your local network and reads local device descriptions. Pairing sends the app's name to the chosen TV. Button commands and text you explicitly submit go to that TV. No text history is persisted. The app does not request microphone, camera, contacts, photo or location access.

Select **Forget TV** to remove that TV's saved information. iOS Keychain storage may survive app uninstall; forgetting before uninstall removes the app's records explicitly. TV-side pairing approvals are managed in the TV's settings. This policy covers this app, not the television's own services.

Local protocols vary: Samsung and LG use pinned TLS; Sony uses PSK-authenticated, unencrypted local HTTP. Use a trusted home network. Developer build tools and GitHub Actions download dependencies, but these are not runtime app data flows.
