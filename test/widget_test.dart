import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openremote_tv/ui/app.dart';

void main() {
  testWidgets('remote starts disconnected and demo is explicit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const OpenRemoteApp(loadSaved: false));
    expect(find.text('Connect a TV'), findsOneWidget);
    final ok = tester.widget<InkWell>(
      find.byKey(const ValueKey('ring-select')),
    );
    expect(ok.onTap, isNull);
    await tester.tap(find.text('Try the demo'));
    await tester.pumpAndSettle();
    expect(find.text('Demo mode · no TV is connected'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ring-select')));
    await tester.pumpAndSettle();
    expect(find.text('Demo · select'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('manual setup validates IP before attempting any connection', (
    tester,
  ) async {
    await tester.pumpWidget(const OpenRemoteApp(loadSaved: false));
    await tester.tap(find.byTooltip('My TVs'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add TV by IP address'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'TV IP address'),
      '8.8.8.8',
    );
    await tester.ensureVisible(find.text('Connect TV'));
    await tester.tap(find.text('Connect TV'));
    await tester.pumpAndSettle();
    expect(
      find.text('Enter a private IPv4 address from your TV settings.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'small screen and large text remain scrollable without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.4;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(const OpenRemoteApp(loadSaved: false));
      await tester.ensureVisible(find.text('Try the demo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Try the demo'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).first, const Offset(0, 1000));
      await tester.pumpAndSettle();
      expect(find.text('Demo mode · no TV is connected'), findsOneWidget);
      await tester.drag(find.byType(ListView).first, const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('capture the real Flutter remote for visual review', (
    tester,
  ) async {
    if (Platform.environment['CAPTURE_UI'] != '1') return;
    final sdk =
        Platform.environment['FLUTTER_ROOT'] ??
        '${Directory.current.path}/.tooling/flutter';
    await tester.runAsync(() async {
      final font = FontLoader('Roboto')
        ..addFont(
          File(
            '$sdk/bin/cache/artifacts/material_fonts/roboto-regular.ttf',
          ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
      await font.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(
          File(
            '$sdk/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
          ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
      await icons.load();
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(key: key, child: const OpenRemoteApp(loadSaved: false)),
    );
    await tester.tap(find.text('Try the demo'));
    await tester.pumpAndSettle();
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('captures').create(recursive: true);
      await File(
        'captures/remote-simple.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });
}
