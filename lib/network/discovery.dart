import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:xml/xml.dart';
import '../core/models.dart';

Map<String, String> ssdpHeaders(String packet) {
  final result = <String, String>{};
  if (!packet.startsWith('HTTP/1.1 200')) return result;
  for (final line in packet.split('\r\n').skip(1)) {
    final index = line.indexOf(':');
    if (index > 0) {
      result[line.substring(0, index).trim().toLowerCase()] = line
          .substring(index + 1)
          .trim();
    }
  }
  return result;
}

TvDevice? parseDescription(String xml, String host) {
  if (!isLocalIpv4(host) || xml.length > 131072) return null;
  try {
    final doc = XmlDocument.parse(xml);
    String value(String tag) =>
        doc.findAllElements(tag).firstOrNull?.innerText.trim() ?? '';
    final maker = value('manufacturer').toLowerCase();
    final model =
        '${value('modelName')} ${value('modelDescription')} ${value('deviceType')}'
            .toLowerCase();
    final brand = maker.contains('samsung') && model.contains('tv')
        ? TvBrand.samsung
        : (maker.contains('lg') &&
              (model.contains('tv') || model.contains('webos')))
        ? TvBrand.lg
        : (maker.contains('sony') &&
              (model.contains('tv') || model.contains('bravia')))
        ? TvBrand.sony
        : null;
    if (brand == null) return null;
    final name = value('friendlyName');
    return TvDevice(
      host: host,
      name: name.isEmpty ? '${brand.label} TV' : name,
      brand: brand,
    );
  } on XmlException {
    return null;
  }
}

class TvDiscovery {
  static const _native = MethodChannel('org.openremotetv/network');
  Future<List<TvDevice>> scan() async {
    final found = <String, TvDevice>{};
    final visited = <String>{};
    final pending = <Future<void>>[];
    final sockets = <RawDatagramSocket>[];
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    try {
      if (Platform.isAndroid) {
        await _native.invokeMethod<void>('acquireMulticast');
      }
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );
      for (final interface in interfaces) {
        for (final address in interface.addresses.where(
          (a) => isLocalIpv4(a.address),
        )) {
          final socket = await RawDatagramSocket.bind(address, 0);
          sockets.add(socket);
          socket.listen((event) {
            if (event != RawSocketEvent.read) return;
            final datagram = socket.receive();
            if (datagram == null ||
                datagram.data.length > 16384 ||
                !isLocalIpv4(datagram.address.address)) {
              return;
            }
            final headers = ssdpHeaders(
              utf8.decode(datagram.data, allowMalformed: true),
            );
            final location = Uri.tryParse(headers['location'] ?? '');
            if (location == null ||
                location.scheme != 'http' ||
                location.userInfo.isNotEmpty ||
                location.host != datagram.address.address ||
                !visited.add(location.toString()) ||
                visited.length > 64) {
              return;
            }
            pending.add(() async {
              try {
                final request = await client
                    .getUrl(location)
                    .timeout(const Duration(seconds: 2));
                request.followRedirects = false;
                final response = await request.close().timeout(
                  const Duration(seconds: 2),
                );
                if (response.statusCode != 200) return;
                final bytes = <int>[];
                await for (final chunk in response.timeout(
                  const Duration(seconds: 2),
                )) {
                  bytes.addAll(chunk);
                  if (bytes.length > 131072) return;
                }
                final device = parseDescription(
                  utf8.decode(bytes, allowMalformed: true),
                  location.host,
                );
                if (device != null) found[device.id] = device;
              } on Exception {
                /* A single invalid device must not abort discovery. */
              }
            }());
          });
          for (final target in [
            'ssdp:all',
            'urn:schemas-upnp-org:device:MediaRenderer:1',
          ]) {
            final packet = utf8.encode(
              'M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nMAN: "ssdp:discover"\r\nMX: 2\r\nST: $target\r\n\r\n',
            );
            socket.send(packet, InternetAddress('239.255.255.250'), 1900);
          }
        }
      }
      if (sockets.isEmpty) {
        throw const RemoteFailure(
          'Join your home Wi-Fi network, then search again.',
        );
      }
      await Future<void>.delayed(const Duration(seconds: 4));
      for (final socket in sockets) {
        socket.close();
      }
      await Future.wait(
        pending,
      ).timeout(const Duration(seconds: 6), onTimeout: () => <void>[]);
      return found.values.toList()..sort((a, b) => a.name.compareTo(b.name));
    } finally {
      for (final socket in sockets) {
        socket.close();
      }
      client.close(force: true);
      if (Platform.isAndroid) {
        await _native.invokeMethod<void>('releaseMulticast');
      }
    }
  }
}

List<int> magicPacket(String mac) {
  final normalized = mac.replaceAll(RegExp('[:-]'), '');
  if (!RegExp(r'^[0-9a-fA-F]{12}$').hasMatch(normalized)) {
    throw const RemoteFailure('Enter a valid TV MAC address.');
  }
  final bytes = List<int>.generate(
    6,
    (i) => int.parse(normalized.substring(i * 2, i * 2 + 2), radix: 16),
  );
  return [...List<int>.filled(6, 255), for (var i = 0; i < 16; i++) ...bytes];
}

Future<void> wakeTv(String mac) async {
  final packet = magicPacket(mac);
  final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  try {
    socket.broadcastEnabled = true;
    for (var i = 0; i < 3; i++) {
      socket.send(packet, InternetAddress('255.255.255.255'), 9);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  } finally {
    socket.close();
  }
}
