import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../core/models.dart';
import '../core/storage.dart';
import '../network/discovery.dart';
import '../network/transport.dart';
import '../remotes/demo.dart';
import '../remotes/lg.dart';
import '../remotes/samsung.dart';
import '../remotes/sony.dart';
import 'dialogs.dart';

const ink = Color(0xff20372f);
const mint = Color(0xffd3efdc);
const paper = Color(0xfff6f5ef);

class OpenRemoteApp extends StatelessWidget {
  const OpenRemoteApp({super.key, this.loadSaved = true});
  final bool loadSaved;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'OpenRemote TV',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: paper,
      colorScheme: ColorScheme.fromSeed(
        seedColor: ink,
        primary: ink,
        surface: paper,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: paper,
        foregroundColor: ink,
        centerTitle: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(48, 52)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 38,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.6,
          color: ink,
        ),
        headlineSmall: TextStyle(fontWeight: FontWeight.w600, color: ink),
      ),
    ),
    home: RemoteHome(loadSaved: loadSaved),
  );
}

class RemoteHome extends StatefulWidget {
  const RemoteHome({super.key, required this.loadSaved});
  final bool loadSaved;
  @override
  State<RemoteHome> createState() => _RemoteHomeState();
}

class _RemoteHomeState extends State<RemoteHome> with WidgetsBindingObserver {
  final store = DeviceStore();
  List<TvDevice> saved = [];
  List<TvDevice> found = [];
  TvRemote? remote;
  TvDevice? selected;
  bool connecting = false;
  bool scanning = false;
  bool sending = false;
  bool touchpad = false;
  int tab = 0;
  int epoch = 0;
  String status = 'Your couch. Your controls.';
  Offset drag = Offset.zero;
  bool get demo => remote is DemoRemote;
  bool get ready => remote != null && !connecting;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.loadSaved) unawaited(load());
  }

  Future<void> load() async {
    try {
      final devices = await store.devices();
      if (mounted) setState(() => saved = devices);
    } catch (_) {
      notice('Saved TVs could not be read. You can still add a TV.');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    epoch++;
    unawaited(remote?.close());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && !demo && ready) {
      unawaited(disconnect());
    }
  }

  void notice(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String readable(Object error) => error is RemoteFailure
      ? error.message
      : error is SocketException ||
            error is TimeoutException ||
            error is HandshakeException
      ? 'Could not reach the TV. Check that it is on, on the same Wi-Fi, and allows mobile control.'
      : 'The TV could not complete this action. Reconnect and try again.';
  Future<bool> trust(String host, String fingerprint) async {
    if (!mounted) return false;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Pair with this TV?'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Check that $host is your TV’s IP address. Pair only on Wi-Fi you trust. We’ll remember this TV’s identity and block changes.',
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Certificate fingerprint',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SelectableText(
                    fingerprint,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Pair TV'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> connect(TvDevice device, {String? psk}) async {
    if (connecting) return;
    final ticket = ++epoch;
    final previous = remote;
    setState(() {
      connecting = true;
      remote = null;
      selected = device;
      tab = 0;
      status = 'Connecting… approve the request on your TV.';
    });
    TvRemote? candidate;
    try {
      await previous?.close();
      if (!isLocalIpv4(device.host)) {
        throw const RemoteFailure(
          'Enter a private IPv4 address from your TV’s network settings.',
        );
      }
      final transport = PinnedSocket(device, store, trust);
      candidate = switch (device.brand) {
        TvBrand.samsung => SamsungRemote(device, store, transport.open),
        TvBrand.lg => LgRemote(device, store, transport.open),
        TvBrand.sony => SonyRemote(
          device,
          psk ?? await store.read('${device.id}.psk') ?? '',
        ),
      };
      await candidate.connect();
      if (!mounted || ticket != epoch) {
        await candidate.close();
        return;
      }
      if (psk != null) await store.write('${device.id}.psk', psk);
      final devices = [...saved.where((d) => d.id != device.id), device];
      await store.saveDevices(devices);
      if (!mounted || ticket != epoch) {
        await candidate.close();
        return;
      }
      setState(() {
        remote = candidate;
        saved = devices;
        status = 'Connected · ${device.brand.platform}';
      });
    } catch (error) {
      await candidate?.close();
      if (mounted && ticket == epoch) setState(() => status = readable(error));
    } finally {
      if (mounted && ticket == epoch) setState(() => connecting = false);
    }
  }

  Future<void> disconnect() async {
    epoch++;
    final old = remote;
    setState(() {
      remote = null;
      connecting = false;
      status = 'Disconnected. Reconnect when you’re ready.';
    });
    await old?.close();
  }

  Future<void> startDemo() async {
    await disconnect();
    if (!mounted) return;
    setState(() {
      selected = null;
      remote = DemoRemote();
      tab = 0;
      status = 'Demo mode · no TV is connected';
    });
  }

  Future<void> perform(
    Future<void> Function(TvRemote) action, {
    String? demoMessage,
  }) async {
    final active = remote;
    if (!ready || sending || active == null) return;
    setState(() => sending = true);
    try {
      await action(active);
      if (demo) notice(demoMessage ?? 'Demo only — no command was sent.');
    } catch (error) {
      notice(readable(error));
      if (error is DisconnectedFailure ||
          error is SocketException ||
          error is StateError ||
          error is WebSocketException) {
        await disconnect();
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> send(RemoteKey key) =>
      perform((r) => r.send(key), demoMessage: 'Demo · ${key.name}');
  Future<void> scan() async {
    if (scanning) return;
    setState(() {
      scanning = true;
      found = [];
    });
    try {
      final devices = await TvDiscovery().scan();
      if (mounted) setState(() => found = devices);
    } catch (error) {
      notice(readable(error));
    } finally {
      if (mounted) setState(() => scanning = false);
    }
  }

  Future<void> addTv() async {
    final result = await showModalBottomSheet<({TvDevice device, String? psk})>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const AddTvSheet(),
    );
    if (result != null && mounted) {
      await connect(result.device, psk: result.psk);
    }
  }

  Future<void> keyboard() async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => const KeyboardDialog(),
    );
    if (text != null) await perform((r) => r.sendText(text));
  }

  Future<void> showApps() async {
    await perform((r) async {
      final apps = await r.apps();
      if (!mounted) return;
      final chosen = await showModalBottomSheet<TvApp>(
        context: context,
        useSafeArea: true,
        builder: (context) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                demo ? 'Demo apps' : 'Your TV apps',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              if (apps.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No apps were returned. Use Home to choose an app.',
                  ),
                ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: apps
                      .map(
                        (app) => ListTile(
                          leading: const Icon(Icons.apps_rounded),
                          title: Text(app.name),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.pop(context, app),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      );
      if (chosen != null) await r.launch(chosen);
    });
  }

  Widget keyButton(
    RemoteKey key,
    IconData icon,
    String label, {
    bool accent = false,
  }) => IconButton.filledTonal(
    onPressed: ready && !sending && remote!.keys.contains(key)
        ? () => send(key)
        : null,
    tooltip: label,
    icon: Icon(icon, size: 25),
    style: IconButton.styleFrom(
      minimumSize: const Size(48, 54),
      backgroundColor: accent ? ink : Colors.white,
      foregroundColor: accent ? Colors.white : ink,
      disabledBackgroundColor: accent
          ? ink.withValues(alpha: .15)
          : Colors.white.withValues(alpha: .5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.settings_remote_outlined, size: 23),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'openremote',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -.7,
              ),
            ),
          ),
        ],
      ),
      actions: [
        if (MediaQuery.sizeOf(context).width >= 380 &&
            MediaQuery.textScalerOf(context).scale(1) <= 1.2)
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: mint,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'FREE. ALWAYS.',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
      ],
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: switch (tab) {
            0 => remotePage(context),
            1 => devicesPage(context),
            _ => helpPage(context),
          },
        ),
      ),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: (value) => setState(() => tab = value),
      backgroundColor: paper,
      indicatorColor: mint,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.gamepad_outlined),
          selectedIcon: Icon(Icons.gamepad),
          label: 'Remote',
        ),
        NavigationDestination(icon: Icon(Icons.tv_outlined), label: 'My TVs'),
        NavigationDestination(
          icon: Icon(Icons.favorite_border),
          label: 'About',
        ),
      ],
    ),
  );
  Widget remotePage(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
    children: [
      Text(
        'Make yourself\nat home.',
        style: Theme.of(context).textTheme.headlineLarge,
      ),
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: mint,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tv_rounded),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    demo
                        ? 'Living room · demo'
                        : selected?.name ?? 'Your TV, one tap away',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                ),
                if (connecting)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(ready ? Icons.check_circle : Icons.wifi_find, size: 20),
              ],
            ),
            const SizedBox(height: 8),
            Text(status, style: const TextStyle(fontSize: 13, height: 1.4)),
            if (!ready && !connecting)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      onPressed: selected != null
                          ? () => connect(selected!)
                          : () => setState(() => tab = 1),
                      child: Text(
                        selected != null ? 'Reconnect' : 'Connect a TV',
                      ),
                    ),
                    if (selected == null)
                      TextButton(
                        onPressed: startDemo,
                        child: const Text('Try the demo'),
                      ),
                    if (selected != null)
                      TextButton(
                        onPressed: () async {
                          final device = selected!;
                          try {
                            await store.forget(device);
                            if (mounted) {
                              setState(() {
                                selected = null;
                                status =
                                    'Pairing forgotten. Add your TV again.';
                              });
                            }
                            await load();
                          } catch (_) {
                            notice('Could not forget the pairing. Try again.');
                          }
                        },
                        child: const Text('Forget pairing'),
                      ),
                  ],
                ),
              ),
            if (connecting)
              TextButton(onPressed: disconnect, child: const Text('Cancel')),
          ],
        ),
      ),
      const SizedBox(height: 18),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          keyButton(
            RemoteKey.power,
            Icons.power_settings_new,
            'Power off',
            accent: true,
          ),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                icon: Icon(Icons.gamepad_outlined),
                tooltip: 'Buttons',
              ),
              ButtonSegment(
                value: true,
                icon: Icon(Icons.swipe_outlined),
                tooltip: 'Swipe',
              ),
            ],
            selected: {touchpad},
            onSelectionChanged: (value) =>
                setState(() => touchpad = value.first),
            showSelectedIcon: false,
          ),
        ],
      ),
      const SizedBox(height: 16),
      if (touchpad)
        Semantics(
          label: 'Swipe pad. Swipe in a direction or tap to select.',
          child: GestureDetector(
            onPanStart: (_) => drag = Offset.zero,
            onPanUpdate: (details) => drag += details.delta,
            onPanEnd: (_) {
              if (drag.distance >= 24) {
                send(
                  drag.dx.abs() > drag.dy.abs()
                      ? (drag.dx > 0 ? RemoteKey.right : RemoteKey.left)
                      : (drag.dy > 0 ? RemoteKey.down : RemoteKey.up),
                );
              }
            },
            onTap: () => send(RemoteKey.select),
            child: Container(
              height: 220,
              decoration: BoxDecoration(
                color: ink,
                borderRadius: BorderRadius.circular(36),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.swipe_rounded, color: mint, size: 36),
                  SizedBox(height: 16),
                  Text(
                    'A little swipe. A big screen.',
                    style: TextStyle(color: Colors.white),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Swipe to move · tap to select',
                    style: TextStyle(color: mint, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        )
      else
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xffeaece3),
            borderRadius: BorderRadius.circular(36),
          ),
          child: Column(
            children: [
              keyButton(RemoteKey.up, Icons.keyboard_arrow_up, 'Up'),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  keyButton(RemoteKey.left, Icons.keyboard_arrow_left, 'Left'),
                  SizedBox(
                    width: 86,
                    height: 70,
                    child: FilledButton(
                      onPressed: ready && !sending
                          ? () => send(RemoteKey.select)
                          : null,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: const Text(
                        'OK',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  keyButton(
                    RemoteKey.right,
                    Icons.keyboard_arrow_right,
                    'Right',
                  ),
                ],
              ),
              keyButton(RemoteKey.down, Icons.keyboard_arrow_down, 'Down'),
            ],
          ),
        ),
      const SizedBox(height: 14),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          keyButton(RemoteKey.back, Icons.arrow_back_rounded, 'Back'),
          keyButton(RemoteKey.home, Icons.home_outlined, 'Home'),
          keyButton(RemoteKey.input, Icons.input, 'Input'),
          keyButton(RemoteKey.menu, Icons.more_horiz, 'Menu'),
        ],
      ),
      const SizedBox(height: 18),
      Row(
        children: [
          Expanded(
            child: rocker('VOLUME', RemoteKey.volumeDown, RemoteKey.volumeUp),
          ),
          const SizedBox(width: 8),
          keyButton(RemoteKey.mute, Icons.volume_off_outlined, 'Mute'),
          const SizedBox(width: 8),
          Expanded(
            child: rocker(
              'CHANNEL',
              RemoteKey.channelDown,
              RemoteKey.channelUp,
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          keyButton(RemoteKey.rewind, Icons.fast_rewind_rounded, 'Rewind'),
          keyButton(RemoteKey.play, Icons.play_arrow_rounded, 'Play'),
          keyButton(RemoteKey.pause, Icons.pause_rounded, 'Pause'),
          keyButton(
            RemoteKey.fastForward,
            Icons.fast_forward_rounded,
            'Fast forward',
          ),
        ],
      ),
      const SizedBox(height: 20),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: ready && !sending && remote!.supportsText
                ? keyboard
                : null,
            icon: const Icon(Icons.keyboard_outlined),
            label: const Text('Keyboard'),
          ),
          OutlinedButton.icon(
            onPressed: ready && !sending && remote!.supportsApps
                ? showApps
                : null,
            icon: const Icon(Icons.apps),
            label: const Text('Apps'),
          ),
          OutlinedButton.icon(
            onPressed: ready ? numbers : null,
            icon: const Icon(Icons.dialpad),
            label: const Text('Numbers'),
          ),
        ],
      ),
      const SizedBox(height: 16),
      const Text(
        'No ads. No subscriptions. Just the remote.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: Color(0xff667469)),
      ),
      if (ready)
        TextButton(
          onPressed: disconnect,
          child: Text(demo ? 'Leave demo' : 'Disconnect'),
        ),
    ],
  );
  Widget rocker(String title, RemoteKey minus, RemoteKey plus) => Column(
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 10,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 6),
      Row(
        children: [
          Expanded(child: keyButton(minus, Icons.remove, '$title down')),
          const SizedBox(width: 4),
          Expanded(child: keyButton(plus, Icons.add, '$title up')),
        ],
      ),
    ],
  );
  Future<void> numbers() => showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.all(24),
      child: GridView.count(
        shrinkWrap: true,
        crossAxisCount: 3,
        childAspectRatio: 1.8,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        children: [
          for (final n in [1, 2, 3, 4, 5, 6, 7, 8, 9, 0])
            FilledButton.tonal(
              onPressed: () =>
                  send(RemoteKey.values.firstWhere((k) => k.name == 'digit$n')),
              child: Text('$n', style: const TextStyle(fontSize: 24)),
            ),
        ],
      ),
    ),
  );
  Widget devicesPage(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Text(
        'Find your\nbig screen.',
        style: Theme.of(context).textTheme.headlineLarge,
      ),
      const SizedBox(height: 12),
      const Text(
        'Connect your phone and TV to the same home Wi-Fi. Keep the TV on while pairing.',
        style: TextStyle(height: 1.5),
      ),
      const SizedBox(height: 24),
      FilledButton.icon(
        onPressed: scanning || connecting ? null : scan,
        icon: scanning
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.wifi_find),
        label: Text(scanning ? 'Looking for TVs…' : 'Find nearby TVs'),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: connecting ? null : addTv,
        icon: const Icon(Icons.add),
        label: const Text('Add TV by IP address'),
      ),
      const SizedBox(height: 24),
      if (saved.isNotEmpty) ...[
        const Text(
          'SAVED TVS',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            fontSize: 11,
          ),
        ),
        ...saved.map((d) => tvTile(d, savedDevice: true)),
        const SizedBox(height: 24),
      ],
      const Text(
        'NEARBY',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
          fontSize: 11,
        ),
      ),
      ...found.map((d) => tvTile(d)),
      if (found.isEmpty)
        Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Column(
            children: [
              Icon(Icons.wifi_tethering, size: 36, color: ink),
              SizedBox(height: 12),
              Text(
                'Your TV belongs here.',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                'Search above to get started. If your TV doesn’t appear, add its IP address from its network settings.',
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.5),
              ),
            ],
          ),
        ),
      const SizedBox(height: 24),
      const Text(
        'FIRST VERSION',
        style: TextStyle(
          fontSize: 11,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'Samsung Tizen · LG webOS · compatible Sony BRAVIA\nFeatures vary by model. Hardware testing is in progress.',
        style: TextStyle(height: 1.6),
      ),
      const SizedBox(height: 12),
      TextButton(
        onPressed: startDemo,
        child: const Text('No TV nearby? Try the demo'),
      ),
    ],
  );
  Widget tvTile(TvDevice device, {bool savedDevice = false}) => Card(
    color: Colors.white,
    elevation: 0,
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: const Icon(Icons.tv),
      title: Text(device.name),
      subtitle: Text('${device.brand.label} · ${device.host}'),
      onTap: connecting
          ? null
          : () async {
              if (device.brand == TvBrand.sony && !savedDevice) {
                notice('Add Sony by IP to enter its pre-shared key.');
                await addTv();
              } else {
                await connect(device);
              }
            },
      trailing: savedDevice
          ? PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'forget') {
                  if (selected?.id == device.id) {
                    await disconnect();
                    if (mounted) setState(() => selected = null);
                  }
                  try {
                    await store.forget(device);
                    await load();
                  } catch (_) {
                    notice('Could not forget the TV. Try again.');
                  }
                } else {
                  try {
                    await wakeTv(device.mac);
                    notice(
                      'Wake request sent. Give the TV a moment, then reconnect.',
                    );
                  } catch (error) {
                    notice(readable(error));
                  }
                }
              },
              itemBuilder: (_) => [
                if (device.mac.isNotEmpty)
                  const PopupMenuItem(value: 'wake', child: Text('Wake TV')),
                const PopupMenuItem(value: 'forget', child: Text('Forget TV')),
              ],
            )
          : const Icon(Icons.chevron_right),
    ),
  );
  Widget helpPage(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Text(
        'A remote.\nWithout the catch.',
        style: Theme.of(context).textTheme.headlineLarge,
      ),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: mint,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Text(
          'Completely free. No ads. No subscription. No account. Your phone talks directly to your TV.',
          style: TextStyle(
            fontSize: 20,
            height: 1.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      const SizedBox(height: 20),
      const ExpansionTile(
        title: Text('Pairing your Samsung'),
        childrenPadding: EdgeInsets.all(16),
        children: [
          Text(
            'Turn on the TV. Find its IP address in Settings → Network → Network Status. Add it here, then approve the connection on the TV with your physical remote. If blocked, check External Device Manager → Device Connect Manager. Menu names vary by model. Tizen TVs with secure control on port 8002 are the first test target.',
          ),
        ],
      ),
      const ExpansionTile(
        title: Text('LG and Sony setup'),
        childrenPadding: EdgeInsets.all(16),
        children: [
          Text(
            'LG: enable mobile app control / LG Connect Apps and accept the pairing prompt. Secure webOS control is required; older plaintext-only models are not supported.\n\nSony: enable IP control with a pre-shared key and enter it when adding the TV. This Sony protocol sends the key over unencrypted local HTTP; use it only on trusted home Wi-Fi.',
          ),
        ],
      ),
      const ExpansionTile(
        title: Text('TV not appearing?'),
        childrenPadding: EdgeInsets.all(16),
        children: [
          Text(
            'Allow Local Network access on iOS. Avoid guest Wi-Fi, VPNs, or router client isolation. If discovery is blocked, add by IP. On iOS, automatic discovery also requires an Apple-approved multicast entitlement in the signed app. Manual IP pairing remains available.',
          ),
        ],
      ),
      const ExpansionTile(
        title: Text('First version compatibility'),
        childrenPadding: EdgeInsets.all(16),
        children: [
          Text(
            'Directional remote, swipe navigation, volume, channels, playback, input, numbers, and saved TVs. Keyboard and app lists depend on TV model and active app. Wake-on-LAN requires a saved MAC address and network standby.\n\nGoogle/Android TV, Fire TV, Apple TV, casting, screen mirroring, voice and infrared are not implemented. Roku is out of scope. No model is hardware-certified yet.',
          ),
        ],
      ),
      const ExpansionTile(
        title: Text('Privacy'),
        childrenPadding: EdgeInsets.all(16),
        children: [
          Text(
            'No backend, analytics, advertising SDK, or tracking. TV addresses, credentials, and certificate identities stay in OS-protected storage on this phone. Forget TV removes them. Search sends local discovery packets; controls and typed text go only to your chosen TV. TV manufacturers and TV apps have their own policies.',
          ),
        ],
      ),
      ListTile(
        title: const Text('Open-source licenses'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => showLicensePage(
          context: context,
          applicationName: 'OpenRemote TV',
          applicationVersion: '0.1.0',
        ),
      ),
      const SizedBox(height: 20),
      const Text(
        'Made for the living room.\nOpenRemote TV · 0.1.0',
        textAlign: TextAlign.center,
        style: TextStyle(height: 1.6, color: Color(0xff667469)),
      ),
    ],
  );
}
