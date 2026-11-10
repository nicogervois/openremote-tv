import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'models.dart';

abstract class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class DeviceStore implements SecretStore {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  Future<List<TvDevice>> devices() async {
    final raw = await read('devices.v1');
    if (raw == null) return [];
    final Object? value;
    try {
      value = jsonDecode(raw);
    } on FormatException {
      return [];
    }
    if (value is! List<dynamic>) return [];
    return value.map(TvDevice.fromJson).whereType<TvDevice>().toList();
  }

  Future<void> saveDevices(List<TvDevice> devices) =>
      write('devices.v1', jsonEncode(devices.map((d) => d.toJson()).toList()));

  Future<void> forget(TvDevice device) async {
    for (final suffix in ['token', 'pin', 'psk']) {
      await delete('${device.id}.$suffix');
    }
    await saveDevices(
      (await devices()).where((d) => d.id != device.id).toList(),
    );
  }
}
