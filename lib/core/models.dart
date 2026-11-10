enum TvBrand {
  samsung('Samsung', 'Tizen'),
  lg('LG', 'webOS'),
  sony('Sony', 'BRAVIA IP control');

  const TvBrand(this.label, this.platform);
  final String label;
  final String platform;
}

enum RemoteKey {
  power,
  up,
  down,
  left,
  right,
  select,
  back,
  home,
  menu,
  input,
  volumeUp,
  volumeDown,
  mute,
  channelUp,
  channelDown,
  play,
  pause,
  rewind,
  fastForward,
  digit0,
  digit1,
  digit2,
  digit3,
  digit4,
  digit5,
  digit6,
  digit7,
  digit8,
  digit9,
}

class TvDevice {
  const TvDevice({
    required this.host,
    required this.name,
    required this.brand,
    this.mac = '',
  });
  final String host;
  final String name;
  final TvBrand brand;
  final String mac;
  String get id => '${brand.name}@$host';
  Map<String, Object> toJson() => {
    'host': host,
    'name': name,
    'brand': brand.name,
    'mac': mac,
  };
  static TvDevice? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final host = value['host'];
    final name = value['name'];
    final brand = value['brand'];
    final mac = value['mac'];
    if (host is! String ||
        !isLocalIpv4(host) ||
        name is! String ||
        brand is! String) {
      return null;
    }
    final matches = TvBrand.values.where((b) => b.name == brand);
    if (matches.isEmpty) return null;
    return TvDevice(
      host: host,
      name: name,
      brand: matches.first,
      mac: mac is String ? mac : '',
    );
  }
}

/// V1 accepts literal private IPv4 only: no URLs, public hosts or DNS rebinding.
bool isLocalIpv4(String host) {
  final parts = host.split('.');
  if (parts.length != 4) return false;
  final bytes = <int>[];
  for (final part in parts) {
    if (!RegExp(r'^(0|[1-9][0-9]{0,2})$').hasMatch(part)) return false;
    final value = int.parse(part);
    if (value > 255) return false;
    bytes.add(value);
  }
  if (bytes[3] == 0 || bytes[3] == 255) return false;
  return bytes[0] == 10 ||
      (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) ||
      (bytes[0] == 192 && bytes[1] == 168);
}

class TvApp {
  const TvApp(this.id, this.name);
  final String id;
  final String name;
}

class RemoteFailure implements Exception {
  const RemoteFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class DisconnectedFailure extends RemoteFailure {
  const DisconnectedFailure()
    : super('TV disconnected. Reconnect to continue.');
}

abstract class TvRemote {
  Set<RemoteKey> get keys;
  bool get supportsText;
  bool get supportsApps;
  Future<void> connect();
  Future<void> send(RemoteKey key);
  Future<void> sendText(String text);
  Future<List<TvApp>> apps();
  Future<void> launch(TvApp app);
  Future<void> close();
}
