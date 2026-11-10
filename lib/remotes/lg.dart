import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import '../core/models.dart';
import '../core/storage.dart';
import '../network/transport.dart';

class LgRemote implements TvRemote {
  LgRemote(this.device, this.store, this.open);
  final TvDevice device;
  final SecretStore store;
  final OpenSocket open;
  JsonChannel? _channel;
  WebSocket? _pointer;
  int _sequence = 0;
  @override
  Set<RemoteKey> get keys => RemoteKey.values.toSet();
  @override
  bool get supportsText => true;
  @override
  bool get supportsApps => true;
  JsonChannel get channel =>
      _channel ?? (throw const RemoteFailure('Connect to a TV first.'));
  @override
  Future<void> connect() async {
    final payload =
        jsonDecode(await rootBundle.loadString('assets/lg_registration.json'))
            as Map<String, dynamic>;
    final key = await store.read('${device.id}.token');
    if (key != null) payload['client-key'] = key;
    _channel = JsonChannel(
      await open(Uri(scheme: 'wss', host: device.host, port: 3001)),
    );
    try {
      final pending = channel.waitFor(
        (m) => m['type'] == 'registered' || m['type'] == 'error',
        timeout: const Duration(seconds: 45),
      );
      channel.send({'id': 'register', 'type': 'register', 'payload': payload});
      final message = await pending;
      final data = message['payload'];
      if (message['type'] != 'registered' ||
          data is! Map<String, dynamic> ||
          data['client-key'] is! String) {
        throw const RemoteFailure(
          'LG pairing was rejected. Allow the remote on the television.',
        );
      }
      await store.write('${device.id}.token', data['client-key'] as String);
      final pointer = await request(
        'com.webos.service.networkinput/getPointerInputSocket',
      );
      final path = pointer['socketPath'];
      final uri = path is String ? Uri.tryParse(path) : null;
      if (uri == null ||
          uri.host != device.host ||
          uri.scheme != 'wss' ||
          uri.port != 3001) {
        throw const RemoteFailure(
          'This LG model does not provide a secure remote input socket.',
        );
      }
      _pointer = await open(uri);
      _pointer!.listen(
        (dynamic _) {},
        onError: (Object _) {},
        onDone: () {
          _pointer = null;
        },
      );
    } catch (_) {
      await close();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> request(
    String uri, [
    Map<String, Object?> payload = const {},
  ]) async {
    final id = 'request-${++_sequence}';
    final pending = channel.waitFor((m) => m['id'] == id);
    channel.send({
      'id': id,
      'type': 'request',
      'uri': 'ssap://$uri',
      'payload': payload,
    });
    final message = await pending;
    final data = message['payload'];
    if (message['type'] == 'error' ||
        data is! Map<String, dynamic> ||
        data['returnValue'] == false) {
      throw const RemoteFailure(
        'The TV could not perform that action in this app or input.',
      );
    }
    return data;
  }

  @override
  Future<void> send(RemoteKey key) async {
    final endpoint = <RemoteKey, String>{
      RemoteKey.power: 'system/turnOff',
      RemoteKey.volumeUp: 'audio/volumeUp',
      RemoteKey.volumeDown: 'audio/volumeDown',
      RemoteKey.channelUp: 'tv/channelUp',
      RemoteKey.channelDown: 'tv/channelDown',
      RemoteKey.play: 'media.controls/play',
      RemoteKey.pause: 'media.controls/pause',
      RemoteKey.rewind: 'media.controls/rewind',
      RemoteKey.fastForward: 'media.controls/fastForward',
    }[key];
    if (endpoint != null) {
      await request(endpoint);
      return;
    }
    if (key == RemoteKey.mute) {
      final state = await request('audio/getStatus');
      await request('audio/setMute', {'mute': state['mute'] != true});
      return;
    }
    final button =
        <RemoteKey, String>{
          RemoteKey.up: 'UP',
          RemoteKey.down: 'DOWN',
          RemoteKey.left: 'LEFT',
          RemoteKey.right: 'RIGHT',
          RemoteKey.select: 'ENTER',
          RemoteKey.back: 'BACK',
          RemoteKey.home: 'HOME',
          RemoteKey.menu: 'MENU',
          RemoteKey.input: 'INPUT',
        }[key] ??
        (key.name.startsWith('digit') ? key.name.substring(5) : null);
    if (button == null || _pointer?.readyState != WebSocket.open) {
      throw const RemoteFailure(
        'Remote input disconnected. Reconnect to continue.',
      );
    }
    _pointer!.add('type:button\nname:$button\n\n');
  }

  @override
  Future<void> sendText(String text) async {
    if (text.isEmpty || text.length > 500) {
      throw const RemoteFailure('Enter between 1 and 500 characters.');
    }
    await request('com.webos.service.ime/insertText', {
      'text': text,
      'replace': 0,
    });
  }

  @override
  Future<List<TvApp>> apps() async {
    final result = await request('com.webos.applicationManager/listApps');
    final apps = result['apps'];
    if (apps is! List<dynamic>) {
      throw const RemoteFailure('No app list was returned.');
    }
    return apps
        .whereType<Map<String, dynamic>>()
        .where((a) => a['id'] is String && a['title'] is String)
        .map((a) => TvApp(a['id'] as String, a['title'] as String))
        .toList();
  }

  @override
  Future<void> launch(TvApp app) async {
    await request('system.launcher/launch', {'id': app.id});
  }

  @override
  Future<void> close() async {
    final pointer = _pointer;
    _pointer = null;
    await pointer?.close();
    final channel = _channel;
    _channel = null;
    await channel?.close();
  }
}
