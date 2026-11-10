import 'dart:convert';
import '../core/models.dart';
import '../core/storage.dart';
import '../network/transport.dart';

const samsungKeys = <RemoteKey, String>{
  RemoteKey.power: 'KEY_POWER',
  RemoteKey.up: 'KEY_UP',
  RemoteKey.down: 'KEY_DOWN',
  RemoteKey.left: 'KEY_LEFT',
  RemoteKey.right: 'KEY_RIGHT',
  RemoteKey.select: 'KEY_ENTER',
  RemoteKey.back: 'KEY_RETURN',
  RemoteKey.home: 'KEY_HOME',
  RemoteKey.menu: 'KEY_MENU',
  RemoteKey.input: 'KEY_SOURCE',
  RemoteKey.volumeUp: 'KEY_VOLUP',
  RemoteKey.volumeDown: 'KEY_VOLDOWN',
  RemoteKey.mute: 'KEY_MUTE',
  RemoteKey.channelUp: 'KEY_CHUP',
  RemoteKey.channelDown: 'KEY_CHDOWN',
  RemoteKey.play: 'KEY_PLAY',
  RemoteKey.pause: 'KEY_PAUSE',
  RemoteKey.rewind: 'KEY_REWIND',
  RemoteKey.fastForward: 'KEY_FF',
  RemoteKey.digit0: 'KEY_0',
  RemoteKey.digit1: 'KEY_1',
  RemoteKey.digit2: 'KEY_2',
  RemoteKey.digit3: 'KEY_3',
  RemoteKey.digit4: 'KEY_4',
  RemoteKey.digit5: 'KEY_5',
  RemoteKey.digit6: 'KEY_6',
  RemoteKey.digit7: 'KEY_7',
  RemoteKey.digit8: 'KEY_8',
  RemoteKey.digit9: 'KEY_9',
};

class SamsungRemote implements TvRemote {
  SamsungRemote(this.device, this.store, this.open);
  final TvDevice device;
  final SecretStore store;
  final OpenSocket open;
  JsonChannel? _channel;
  @override
  Set<RemoteKey> get keys => samsungKeys.keys.toSet();
  @override
  bool get supportsText => true;
  @override
  bool get supportsApps => true;
  JsonChannel get channel =>
      _channel ?? (throw const RemoteFailure('Connect to a TV first.'));

  @override
  Future<void> connect() async {
    final token = await store.read('${device.id}.token');
    final uri = Uri(
      scheme: 'wss',
      host: device.host,
      port: 8002,
      path: '/api/v2/channels/samsung.remote.control',
      queryParameters: {
        'name': base64Encode(utf8.encode('OpenRemote TV')),
        'token': ?token,
      },
    );
    _channel = JsonChannel(await open(uri));
    try {
      final response = await channel.waitFor(
        (m) => [
          'ms.channel.connect',
          'ms.channel.unauthorized',
          'ms.channel.timeOut',
          'ms.error',
        ].contains(m['event']),
        timeout: const Duration(seconds: 45),
      );
      if (response['event'] != 'ms.channel.connect') {
        throw const RemoteFailure(
          'Pairing was not approved. Allow OpenRemote TV on the television, then reconnect.',
        );
      }
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        final nextToken = data['token'];
        if (nextToken is String && nextToken.isNotEmpty) {
          await store.write('${device.id}.token', nextToken);
        }
      }
    } catch (_) {
      await close();
      rethrow;
    }
  }

  @override
  Future<void> send(RemoteKey key) async {
    final code = samsungKeys[key];
    if (code == null) {
      throw const RemoteFailure('This button is unavailable on this TV.');
    }
    channel.send({
      'method': 'ms.remote.control',
      'params': {
        'Cmd': 'Click',
        'DataOfCmd': code,
        'Option': 'false',
        'TypeOfRemote': 'SendRemoteKey',
      },
    });
  }

  @override
  Future<void> sendText(String text) async {
    if (text.isEmpty || text.length > 500) {
      throw const RemoteFailure('Enter between 1 and 500 characters.');
    }
    channel.send({
      'method': 'ms.remote.control',
      'params': {
        'Cmd': base64Encode(utf8.encode(text)),
        'DataOfCmd': 'base64',
        'TypeOfRemote': 'SendInputString',
      },
    });
  }

  @override
  Future<List<TvApp>> apps() async {
    final pending = channel.waitFor(
      (m) => m['event'] == 'ed.installedApp.get' || m['event'] == 'ms.error',
    );
    channel.send({
      'method': 'ms.channel.emit',
      'params': {'event': 'ed.installedApp.get', 'to': 'host'},
    });
    final message = await pending;
    final data = message['data'];
    final apps = data is Map<String, dynamic> ? data['data'] : null;
    if (apps is! List<dynamic>) {
      throw const RemoteFailure(
        'This Samsung model does not expose its app list. Use Home to choose an app.',
      );
    }
    return apps
        .whereType<Map<String, dynamic>>()
        .where((a) => a['appId'] is String && a['name'] is String)
        .map((a) => TvApp(a['appId'] as String, a['name'] as String))
        .toList();
  }

  @override
  Future<void> launch(TvApp app) async {
    channel.send({
      'method': 'ms.channel.emit',
      'params': {
        'event': 'ed.apps.launch',
        'to': 'host',
        'data': {'appId': app.id, 'action_type': 'DEEP_LINK', 'metaTag': ''},
      },
    });
  }

  @override
  Future<void> close() async {
    final old = _channel;
    _channel = null;
    await old?.close();
  }
}
