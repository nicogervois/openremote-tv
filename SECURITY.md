# Security model

- No cloud service or inbound listener in production. No secrets in the repository.
- Only private IPv4 literals are accepted; no DNS or public targets. Discovery checks the description host matches the sender and follows no redirects.
- Samsung/LG TLS uses explicit trust-on-first-use. The certificate is checked again before credentials are sent and pinned for subsequent sessions; changes require forgetting and re-pairing. The initial network must be trusted. No plaintext fallback.
- LG pointer sockets must stay on the selected TV's secure port. Sony discovers valid Base64 IRCC codes before using them in SOAP.
- Credentials and pins use flutter_secure_storage (Keychain / encrypted Android storage). No credential logging or exports. Test fixtures contain only synthetic values.
- Connection, response and discovery timeouts bound common failures. Malformed and oversized JSON/device descriptions are rejected. Unsupported commands are shown as unavailable or return an explanatory error.
- Sony's existing PSK API is unencrypted. This is disclosed before the user supplies a PSK. Do not use it on untrusted networks.

For a security report, do not post credentials or home-network identifiers in a public issue. Use GitHub private vulnerability reporting if enabled; otherwise open an issue describing only the non-sensitive symptom and request a private contact path.

Release review still needs physical-device testing, dependency review, production signing, app-store privacy declarations, and iOS multicast entitlement approval for automatic discovery.
