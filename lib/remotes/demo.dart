import '../core/models.dart';

/// An explicit offline preview. Never constructs a network client.
class DemoRemote implements TvRemote {
  @override
  Set<RemoteKey> get keys => RemoteKey.values.toSet();
  @override
  bool get supportsText => true;
  @override
  bool get supportsApps => true;
  @override
  Future<void> connect() async {}
  @override
  Future<void> send(RemoteKey key) async {}
  @override
  Future<void> sendText(String text) async {}
  @override
  Future<List<TvApp>> apps() async => const [
    TvApp('demo-cinema', 'Cinema'),
    TvApp('demo-music', 'Music'),
    TvApp('demo-live', 'Live TV'),
  ];
  @override
  Future<void> launch(TvApp app) async {}
  @override
  Future<void> close() async {}
}
