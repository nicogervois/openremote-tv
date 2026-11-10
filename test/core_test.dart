import 'package:flutter_test/flutter_test.dart';
import 'package:openremote_tv/core/models.dart';
import 'package:openremote_tv/network/discovery.dart';
import 'package:openremote_tv/network/transport.dart';

void main() {
  test('only literal private unicast IPv4 is accepted', () {
    for (final ip in ['192.168.1.42', '10.0.0.2', '172.16.0.1', '172.31.9.2']) {
      expect(isLocalIpv4(ip), isTrue, reason: ip);
    }
    for (final ip in [
      '8.8.8.8',
      '127.0.0.1',
      '0.0.0.0',
      '169.254.1.2',
      '172.32.0.2',
      '192.168.1.255',
      '192.168.1.256',
      '192.168.001.2',
      'http://192.168.1.2',
      'tv.local',
      '::1',
    ]) {
      expect(isLocalIpv4(ip), isFalse, reason: ip);
    }
  });
  test('saved records validate external data', () {
    expect(
      TvDevice.fromJson({'host': '8.8.8.8', 'name': 'TV', 'brand': 'samsung'}),
      isNull,
    );
    expect(
      TvDevice.fromJson({
        'host': '192.168.1.2',
        'name': 42,
        'brand': 'samsung',
      }),
      isNull,
    );
    const tv = TvDevice(
      host: '192.168.1.2',
      name: 'Living room',
      brand: TvBrand.samsung,
    );
    expect(TvDevice.fromJson(tv.toJson())?.id, tv.id);
  });
  test('SSDP is case insensitive and descriptions exclude non-TV devices', () {
    expect(
      ssdpHeaders(
        'HTTP/1.1 200 OK\r\nLocation: http://192.168.1.2:9197/desc.xml\r\n',
      )['location'],
      contains('9197'),
    );
    expect(
      ssdpHeaders('NOTIFY * HTTP/1.1\r\nLOCATION: http://example.com\r\n'),
      isEmpty,
    );
    expect(
      parseDescription(
        '<root><device><manufacturer>Samsung Electronics</manufacturer><modelName>Smart TV</modelName><friendlyName>Den &amp; TV</friendlyName></device></root>',
        '192.168.1.2',
      )?.name,
      'Den & TV',
    );
    expect(
      parseDescription(
        '<root><manufacturer>Samsung</manufacturer><modelName>Printer</modelName></root>',
        '192.168.1.2',
      ),
      isNull,
    );
    expect(parseDescription('<broken>', '192.168.1.2'), isNull);
  });
  test('Wake-on-LAN packet has header and sixteen MAC repetitions', () {
    final packet = magicPacket('AA:BB:CC:DD:EE:FF');
    expect(packet.length, 102);
    expect(packet.take(6), List<int>.filled(6, 255));
    for (var n = 0; n < 16; n++) {
      expect(packet.sublist(6 + n * 6, 12 + n * 6), [
        170,
        187,
        204,
        221,
        238,
        255,
      ]);
    }
    expect(() => magicPacket('invalid'), throwsA(isA<RemoteFailure>()));
  });
  test('malformed TV messages cannot escape the parser', () {
    expect(jsonObject('not json'), isNull);
    expect(jsonObject('[1,2]'), isNull);
    expect(jsonObject('{"event":"ok"}')?['event'], 'ok');
  });
}
