import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import '../core/models.dart';
import '../core/storage.dart';

typedef TrustCertificate =
    Future<bool> Function(String host, String fingerprint);
typedef OpenSocket = Future<WebSocket> Function(Uri uri);

/// Trust-on-first-use is explicit. A changed certificate fails closed until the
/// user forgets and pairs again. No global HTTP/TLS overrides are installed.
class PinnedSocket {
  PinnedSocket(this.device, this.store, this.trust);
  final TvDevice device;
  final SecretStore store;
  final TrustCertificate trust;

  Future<WebSocket> open(Uri uri) async {
    if (uri.scheme != 'wss' ||
        uri.host != device.host ||
        !isLocalIpv4(uri.host) ||
        ![8002, 3001].contains(uri.port)) {
      throw const RemoteFailure(
        'The TV returned an unexpected network address.',
      );
    }
    String? observed;
    // Probe sends no credentials or application bytes. The approved certificate
    // is checked again on the authenticated WebSocket connection below.
    final probe = await SecureSocket.connect(
      uri.host,
      uri.port,
      timeout: const Duration(seconds: 5),
      onBadCertificate: (certificate) {
        observed = sha256.convert(certificate.der).toString();
        return true;
      },
    );
    final certificate = probe.peerCertificate;
    if (certificate != null) {
      observed = sha256.convert(certificate.der).toString();
    }
    probe.destroy();
    if (observed == null) {
      throw const RemoteFailure('No TV certificate was received.');
    }
    final pinKey = '${device.id}.pin';
    final saved = await store.read(pinKey);
    if (saved != null && saved != observed) {
      throw const RemoteFailure(
        'This TV’s identity changed. Check its IP address, then forget and pair it again.',
      );
    }
    if (saved == null) {
      if (!await trust(device.host, observed!)) {
        throw const RemoteFailure('Connection cancelled.');
      }
      await store.write(pinKey, observed!);
    }
    final expected = observed;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    client.badCertificateCallback = (cert, host, port) =>
        host == uri.host &&
        port == uri.port &&
        sha256.convert(cert.der).toString() == expected;
    // Verify the pin even for certificates accepted by the system trust store.
    client.connectionFactory = (url, proxyHost, proxyPort) async {
      final task = await Socket.startConnect(url.host, url.port);
      return ConnectionTask.fromSocket(
        task.socket.then((socket) async {
          final secure = await SecureSocket.secure(
            socket,
            host: url.host,
            onBadCertificate: (cert) =>
                sha256.convert(cert.der).toString() == expected,
          );
          if (secure.peerCertificate == null ||
              sha256.convert(secure.peerCertificate!.der).toString() !=
                  expected) {
            secure.destroy();
            throw const RemoteFailure(
              'The TV certificate changed during connection.',
            );
          }
          return secure;
        }),
        task.cancel,
      );
    };
    try {
      return await WebSocket.connect(
        uri.toString(),
        customClient: client,
      ).timeout(const Duration(seconds: 8));
    } finally {
      client.close();
    }
  }
}

Map<String, dynamic>? jsonObject(Object? raw) {
  if (raw is! String || raw.length > 1024 * 1024) return null;
  try {
    final Object? value = jsonDecode(raw);
    return value is Map<String, dynamic> ? value : null;
  } on FormatException {
    return null;
  }
}

class JsonChannel {
  JsonChannel(this.socket) {
    socket.pingInterval = const Duration(seconds: 20);
    subscription = socket.listen(
      (dynamic raw) {
        final message = jsonObject(raw);
        if (message != null) events.add(message);
      },
      onError: (Object error) {
        events.addError(error);
      },
      onDone: () {
        events.close();
      },
    );
  }
  final WebSocket socket;
  final events = StreamController<Map<String, dynamic>>.broadcast();
  late final StreamSubscription<dynamic> subscription;
  bool get connected => socket.readyState == WebSocket.open;
  void send(Map<String, Object?> message) {
    if (!connected) {
      throw const RemoteFailure('TV disconnected. Reconnect to continue.');
    }
    socket.add(jsonEncode(message));
  }

  Future<Map<String, dynamic>> waitFor(
    bool Function(Map<String, dynamic>) predicate, {
    Duration timeout = const Duration(seconds: 8),
  }) => events.stream
      .firstWhere(predicate)
      .timeout(
        timeout,
        onTimeout: () => throw const RemoteFailure(
          'The TV did not respond. Check its connection and try again.',
        ),
      );
  Future<void> close() async {
    await subscription.cancel();
    await socket.close();
    await events.close();
  }
}
