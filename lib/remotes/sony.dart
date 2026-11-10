import 'dart:convert';
import 'dart:io';
import '../core/models.dart';

class SonyRemote implements TvRemote {
  SonyRemote(this.device, this.psk, {HttpClient? client})
    : _client = client ?? HttpClient();
  final TvDevice device;
  final String psk;
  final HttpClient _client;
  final Map<RemoteKey, String> _codes = {};
  @override
  Set<RemoteKey> get keys => _codes.keys.toSet();
  @override
  bool get supportsText => false;
  @override
  bool get supportsApps => true;
  Future<String> post(String path, String body, {bool soap = false}) async {
    final request = await _client
        .postUrl(Uri(scheme: 'http', host: device.host, path: path))
        .timeout(const Duration(seconds: 5));
    request.followRedirects = false;
    request.headers.set('X-Auth-PSK', psk);
    request.headers.contentType = ContentType(
      soap ? 'text' : 'application',
      soap ? 'xml' : 'json',
      charset: 'utf-8',
    );
    if (soap) {
      request.headers.set(
        'SOAPACTION',
        '"urn:schemas-sony-com:service:IRCC:1#X_SendIRCC"',
      );
    }
    request.write(body);
    final response = await request.close().timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) {
      await response.drain<void>();
      throw const RemoteFailure(
        'Sony rejected the command. Check IP control and the pre-shared key.',
      );
    }
    return response
        .transform(utf8.decoder)
        .join()
        .timeout(const Duration(seconds: 5));
  }

  Future<List<dynamic>> rpc(
    String service,
    String method,
    List<Object> params,
  ) async {
    final raw = await post(
      '/sony/$service',
      jsonEncode({
        'method': method,
        'params': params,
        'id': 1,
        'version': '1.0',
      }),
    );
    final Object? result = jsonDecode(raw);
    if (result is! Map<String, dynamic> ||
        result['error'] != null ||
        result['result'] is! List<dynamic>) {
      throw const RemoteFailure(
        'This Sony model does not support that IP-control feature.',
      );
    }
    return result['result'] as List<dynamic>;
  }

  @override
  Future<void> connect() async {
    final result = await rpc('system', 'getRemoteControllerInfo', []);
    if (result.length < 2 || result[1] is! List<dynamic>) {
      throw const RemoteFailure('No remote buttons were returned.');
    }
    final names = <String, RemoteKey>{
      'PowerOff': RemoteKey.power,
      'Up': RemoteKey.up,
      'Down': RemoteKey.down,
      'Left': RemoteKey.left,
      'Right': RemoteKey.right,
      'Confirm': RemoteKey.select,
      'Return': RemoteKey.back,
      'Home': RemoteKey.home,
      'Options': RemoteKey.menu,
      'Input': RemoteKey.input,
      'VolumeUp': RemoteKey.volumeUp,
      'VolumeDown': RemoteKey.volumeDown,
      'Mute': RemoteKey.mute,
      'ChannelUp': RemoteKey.channelUp,
      'ChannelDown': RemoteKey.channelDown,
      'Play': RemoteKey.play,
      'Pause': RemoteKey.pause,
      'Rewind': RemoteKey.rewind,
      'Forward': RemoteKey.fastForward,
      for (var n = 0; n < 10; n++)
        'Num$n': RemoteKey.values.firstWhere((k) => k.name == 'digit$n'),
    };
    for (final item in result[1] as List<dynamic>) {
      if (item is! Map<String, dynamic>) continue;
      final key = names[item['name']];
      final code = item['value'];
      if (key != null &&
          code is String &&
          RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(code)) {
        _codes[key] = code;
      }
    }
    if (!_codes.containsKey(RemoteKey.select)) {
      throw const RemoteFailure('This TV does not expose a compatible remote.');
    }
  }

  @override
  Future<void> send(RemoteKey key) async {
    final code = _codes[key];
    if (code == null) {
      throw const RemoteFailure(
        'This button is not supported by your Sony TV.',
      );
    }
    await post(
      '/sony/IRCC',
      '<?xml version="1.0"?><s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body><u:X_SendIRCC xmlns:u="urn:schemas-sony-com:service:IRCC:1"><IRCCCode>$code</IRCCCode></u:X_SendIRCC></s:Body></s:Envelope>',
      soap: true,
    );
  }

  @override
  Future<void> sendText(String text) async => throw const RemoteFailure(
    'Keyboard is unavailable on this Sony connection.',
  );
  @override
  Future<List<TvApp>> apps() async {
    final result = await rpc('appControl', 'getApplicationList', []);
    if (result.isEmpty || result.first is! List<dynamic>) return [];
    return (result.first as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .where((a) => a['uri'] is String && a['title'] is String)
        .map((a) => TvApp(a['uri'] as String, a['title'] as String))
        .toList();
  }

  @override
  Future<void> launch(TvApp app) async {
    await rpc('appControl', 'setActiveApp', [
      {'uri': app.id},
    ]);
  }

  @override
  Future<void> close() async {
    _client.close(force: true);
  }
}
