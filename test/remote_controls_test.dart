import 'dart:ui' show SemanticsAction;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openremote_tv/core/models.dart';
import 'package:openremote_tv/ui/app.dart';
import 'package:openremote_tv/ui/remote_controls.dart';

void main() {
  testWidgets('the blank ring maps each edge and center to the correct command', (
    tester,
  ) async {
    final keys = <RemoteKey>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox.square(
              dimension: 220,
              child: NavigationRing(
                onKey: keys.add,
                enabledKeys: RemoteKey.values.toSet(),
              ),
            ),
          ),
        ),
      ),
    );
    final rect = tester.getRect(find.byType(NavigationRing));
    for (final offset in [
      const Offset(110, 20),
      const Offset(200, 110),
      const Offset(110, 200),
      const Offset(20, 110),
      const Offset(110, 110),
    ]) {
      await tester.tapAt(rect.topLeft + offset);
      await tester.pumpAndSettle();
    }
    expect(keys, [
      RemoteKey.up,
      RemoteKey.right,
      RemoteKey.down,
      RemoteKey.left,
      RemoteKey.select,
    ]);
    // A diagonal belongs to its nearest quadrant; dead square corners do not send commands.
    await tester.tapAt(rect.topLeft + const Offset(170, 40));
    await tester.tapAt(rect.topLeft + const Offset(2, 2));
    expect(keys, [
      RemoteKey.up,
      RemoteKey.right,
      RemoteKey.down,
      RemoteKey.left,
      RemoteKey.select,
      RemoteKey.up,
    ]);
    expect(find.byIcon(Icons.keyboard_arrow_up), findsNothing);
  });

  testWidgets('disconnected ring is inert and keeps accessible labels', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox.square(
              dimension: 220,
              child: NavigationRing(onKey: null, enabledKeys: {}),
            ),
          ),
        ),
      ),
    );
    final node = tester.getSemantics(find.byKey(const ValueKey('ring-select')));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
    expect(find.bySemanticsLabel('Up'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets(
    'rocker ends are incremental and middle grip is a separate action',
    (tester) async {
      final actions = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RemoteRocker(
                label: 'Volume',
                centerLabel: 'Mute',
                onUp: () => actions.add('up'),
                onDown: () => actions.add('down'),
                onCenter: () => actions.add('mute'),
              ),
            ),
          ),
        ),
      );
      for (final label in ['Volume up', 'Volume down', 'Mute']) {
        await tester.tap(find.byTooltip(label));
        await tester.pumpAndSettle();
      }
      expect(actions, ['up', 'down', 'mute']);
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.remove), findsOneWidget);
    },
  );

  testWidgets(
    'connected remote fits an iPhone viewport and secondary actions stay in More',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      await tester.pumpWidget(const OpenRemoteApp(loadSaved: false));
      await tester.tap(find.text('Try the demo'));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const ValueKey('remote-body'))).bottom,
        lessThanOrEqualTo(810),
      );
      expect(find.text('Keyboard'), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
      await tester.tap(find.byTooltip('More controls'));
      await tester.pumpAndSettle();
      expect(find.text('Keyboard'), findsOneWidget);
      expect(find.text('TV apps'), findsOneWidget);
      expect(find.text('Input'), findsOneWidget);
      expect(find.text('Number pad'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'playback offers explicit commands instead of guessing TV playback state',
    (tester) async {
      await tester.pumpWidget(const OpenRemoteApp(loadSaved: false));
      await tester.tap(find.text('Try the demo'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Playback controls'));
      await tester.tap(find.byTooltip('Playback controls'));
      await tester.pumpAndSettle();
      expect(find.text('Play'), findsOneWidget);
      expect(find.text('Pause'), findsOneWidget);
      await tester.tap(find.text('Pause'));
      await tester.pumpAndSettle();
      expect(find.text('Demo · pause'), findsOneWidget);
    },
  );
}
