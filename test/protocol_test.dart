import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:openremote_tv/core/models.dart';
import 'package:openremote_tv/core/storage.dart';
import 'package:openremote_tv/network/transport.dart';
import 'package:openremote_tv/remotes/samsung.dart';
import 'package:openremote_tv/remotes/lg.dart';
import 'package:openremote_tv/remotes/sony.dart';

class MemoryStore implements SecretStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class RealHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HttpServer server;
  late List<WebSocket> sockets;
  late MemoryStore store;
  const samsung = TvDevice(
    host: '192.168.1.20',
    name: 'TV',
    brand: TvBrand.samsung,
  );
  const lg = TvDevice(host: '192.168.1.21', name: 'TV', brand: TvBrand.lg);
  setUp(() async {
    sockets = [];
    store = MemoryStore();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  });
  tearDown(() async {
    for (final socket in sockets) {
      await socket.close();
    }
    await server.close(force: true);
  });
  Future<WebSocket> open(Uri uri) => WebSocket.connect(
    uri.replace(scheme: 'ws', host: '127.0.0.1', port: server.port).toString(),
  );

  test(
    'Samsung approval, token persistence, key/text and app launch over a real socket',
    () async {
      final commands = <Map<String, dynamic>>[];
      final launched = Completer<void>();
      Uri? requested;
      server.listen((request) async {
        requested = request.uri;
        final socket = await WebSocketTransformer.upgrade(request);
        sockets.add(socket);
        socket.add(
          jsonEncode({
            'event': 'ms.channel.connect',
            'data': {'token': 'test-token'},
          }),
        );
        socket.listen((dynamic raw) {
          final message = jsonObject(raw)!;
          commands.add(message);
          final params = message['params'] as Map<String, dynamic>;
          if (params['event'] == 'ed.installedApp.get') {
            socket.add(
              jsonEncode({
                'event': 'ed.installedApp.get',
                'data': {
                  'data': [
                    {'appId': 'app-1', 'name': 'Cinema'},
                    {'bad': true},
                  ],
                },
              }),
            );
          }
          if (params['event'] == 'ed.apps.launch') launched.complete();
        });
      });
      final remote = SamsungRemote(samsung, store, open);
      await remote.connect();
      expect(store.values['${samsung.id}.token'], 'test-token');
      expect(
        utf8.decode(base64Decode(requested!.queryParameters['name']!)),
        'OpenRemote TV',
      );
      await remote.send(RemoteKey.volumeUp);
      await remote.sendText('café 🍿');
      final apps = await remote.apps();
      expect(apps.single.name, 'Cinema');
      await remote.launch(apps.single);
      await launched.future.timeout(const Duration(seconds: 2));
      expect(
        (commands[0]['params'] as Map<String, dynamic>)['DataOfCmd'],
        'KEY_VOLUP',
      );
      expect(
        utf8.decode(
          base64Decode(
            (commands[1]['params'] as Map<String, dynamic>)['Cmd'] as String,
          ),
        ),
        'café 🍿',
      );
      await remote.close();
      await remote.connect();
      expect(requested!.queryParameters['token'], 'test-token');
      await remote.close();
    },
  );
  test('Samsung denied approval never saves credentials', () async {
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.add('{"event":"ms.channel.unauthorized"}');
    });
    final remote = SamsungRemote(samsung, store, open);
    await expectLater(remote.connect(), throwsA(isA<RemoteFailure>()));
    expect(store.values, isEmpty);
  });
  test(
    'LG registers, uses separate pointer socket, and correlates SSAP responses',
    () async {
      final button = Completer<String>();
      final paths = <String>[];
      server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        sockets.add(socket);
        if (request.uri.path == '/pointer') {
          socket.listen((dynamic raw) {
            if (!button.isCompleted) button.complete(raw as String);
          });
          return;
        }
        socket.listen((dynamic raw) {
          final message = jsonObject(raw)!;
          if (message['type'] == 'register') {
            socket.add(
              '{"type":"registered","payload":{"client-key":"lg-key"}}',
            );
          } else {
            final uri = message['uri'] as String;
            paths.add(uri);
            socket.add(
              jsonEncode({
                'id': message['id'],
                'type': 'response',
                'payload': {
                  'returnValue': true,
                  if (uri.endsWith('getPointerInputSocket'))
                    'socketPath': 'wss://192.168.1.21:3001/pointer',
                  if (uri.endsWith('getStatus')) 'mute': false,
                },
              }),
            );
          }
        });
      });
      final remote = LgRemote(lg, store, open);
      await remote.connect();
      await remote.send(RemoteKey.select);
      expect(
        await button.future.timeout(const Duration(seconds: 2)),
        'type:button\nname:ENTER\n\n',
      );
      await remote.send(RemoteKey.mute);
      expect(
        paths,
        containsAll(['ssap://audio/getStatus', 'ssap://audio/setMute']),
      );
      expect(store.values['${lg.id}.token'], 'lg-key');
      await remote.close();
    },
  );
  test(
    'Sony discovers its actual button map and sends authenticated SOAP',
    () async {
      final soap = Completer<String>();
      server.listen((request) async {
        expect(request.headers.value('X-Auth-PSK'), 'test-psk');
        final body = await utf8.decoder.bind(request).join();
        if (request.uri.path == '/sony/system') {
          request.response.write(
            jsonEncode({
              'result': [
                <String, Object>{},
                [
                  {'name': 'Confirm', 'value': 'AAAAAQAAAAEAAABlAw=='},
                ],
              ],
            }),
          );
        } else {
          expect(request.headers.value('SOAPACTION'), contains('X_SendIRCC'));
          soap.complete(body);
          request.response.write('<ok/>');
        }
        await request.response.close();
      });
      final client =
          HttpOverrides.runWithHttpOverrides(
              () => HttpClient(),
              RealHttpOverrides(),
            )
            ..connectionFactory = (uri, proxyHost, proxyPort) =>
                Socket.startConnect('127.0.0.1', server.port);
      final remote = SonyRemote(
        const TvDevice(host: '192.168.1.22', name: 'Sony', brand: TvBrand.sony),
        'test-psk',
        client: client,
      );
      await remote.connect();
      expect(remote.keys, {RemoteKey.select});
      await remote.send(RemoteKey.select);
      expect(
        await soap.future,
        contains('<IRCCCode>AAAAAQAAAAEAAABlAw==</IRCCCode>'),
      );
      await expectLater(
        remote.send(RemoteKey.up),
        throwsA(isA<RemoteFailure>()),
      );
      await remote.close();
    },
  );
  test(
    'transport rejects public, foreign and insecure addresses before opening a socket',
    () async {
      final transport = PinnedSocket(samsung, store, (_, _) async => true);
      for (final uri in [
        'wss://8.8.8.8:8002',
        'wss://192.168.1.21:8002',
        'ws://192.168.1.20:8001',
        'wss://192.168.1.20:443',
      ]) {
        await expectLater(
          transport.open(Uri.parse(uri)),
          throwsA(isA<RemoteFailure>()),
        );
      }
    },
  );
}
