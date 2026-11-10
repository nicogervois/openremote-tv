# Synthetic TLS fixtures

`tv-key.pem` and `tv-cert.pem` are a **public, test-only key and self-signed certificate**, generated for a local TV simulator. They are not device credentials, production secrets or a trusted CA. Never use them in a shipped app or deployed service.

Generated with `openssl req -x509 -newkey rsa:2048 -keyout tv-key.pem -out tv-cert.pem -sha256 -days 3650 -nodes -subj '/CN=OpenRemote Test TV'`.
