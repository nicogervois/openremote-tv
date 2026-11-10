import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:openremote_tv/core/models.dart';
import 'package:openremote_tv/network/transport.dart';
import 'protocol_test.dart' show MemoryStore, RealHttpOverrides;

void main() {
  test(
    'real TLS requires consent, pins identity, and blocks changed pins before sending data',
    () async {
      final addresses =
          (await NetworkInterface.list(type: InternetAddressType.IPv4))
              .expand((network) => network.addresses)
              .where((address) => isLocalIpv4(address.address));
      if (addresses.isEmpty) {
        markTestSkipped(
          'TLS simulator needs a private IPv4 interface on this host.',
        );
        return;
      }
      final address = addresses.first;
      final context = SecurityContext()
        ..useCertificateChain('test/fixtures/tv-cert.pem')
        ..usePrivateKey('test/fixtures/tv-key.pem');
      final server = await HttpServer.bindSecure(address, 3001, context);
      final sockets = <WebSocket>[];
      var requests = 0;
      server.listen((request) async {
        requests++;
        final socket = await WebSocketTransformer.upgrade(request);
        sockets.add(socket);
        socket.listen((dynamic data) => socket.add(data));
      });
      try {
        await HttpOverrides.runWithHttpOverrides(() async {
          final store = MemoryStore();
          final device = TvDevice(
            host: address.address,
            name: 'Local test TV',
            brand: TvBrand.lg,
          );
          final uri = Uri(scheme: 'wss', host: address.address, port: 3001);
          final declined = PinnedSocket(device, store, (_, _) async => false);
          await expectLater(declined.open(uri), throwsA(isA<RemoteFailure>()));
          expect(requests, 0);
          expect(store.values, isEmpty);
          var approvals = 0;
          final accepted = PinnedSocket(device, store, (
            host,
            fingerprint,
          ) async {
            approvals++;
            expect(host, address.address);
            expect(fingerprint.length, 64);
            return true;
          });
          final socket = await accepted.open(uri);
          socket.add('hello local TV');
          expect(await socket.first, 'hello local TV');
          await socket.close();
          expect(approvals, 1);
          expect(requests, 1);
          final second = await accepted.open(uri);
          await second.close();
          expect(approvals, 1);
          store.values['${device.id}.pin'] = 'changed-test-pin';
          await expectLater(accepted.open(uri), throwsA(isA<RemoteFailure>()));
          expect(requests, 2);
        }, RealHttpOverrides());
      } finally {
        for (final socket in sockets) {
          await socket.close();
        }
        await server.close(force: true);
      }
    },
  );
}
