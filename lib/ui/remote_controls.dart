import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/models.dart';

const remoteSurface = Color(0xff272e2b);
const remoteHighlight = Color(0xffd3efdc);

/// Four real annular hit regions: the blank ring remains fully usable by touch,
/// VoiceOver, TalkBack and keyboard focus. Corners outside the circle do nothing.
class NavigationRing extends StatelessWidget {
  const NavigationRing({
    super.key,
    required this.onKey,
    required this.enabledKeys,
  });
  final ValueChanged<RemoteKey>? onKey;
  final Set<RemoteKey> enabledKeys;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth;
        return DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xff434c46), Color(0xff303832)],
            ),
            border: Border.all(color: const Color(0xff515a53)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x44000000),
                offset: Offset(0, 5),
                blurRadius: 10,
              ),
            ],
          ),
          child: Stack(
            children: [
              for (final (key, label, angle) in [
                (RemoteKey.up, 'Up', -math.pi * 3 / 4),
                (RemoteKey.right, 'Right', -math.pi / 4),
                (RemoteKey.down, 'Down', math.pi / 4),
                (RemoteKey.left, 'Left', math.pi * 3 / 4),
              ])
                Positioned.fill(
                  child: ClipPath(
                    clipper: _RingSector(angle),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        key: ValueKey('ring-${key.name}'),
                        onTap: onKey != null && enabledKeys.contains(key)
                            ? () => onKey!(key)
                            : null,
                        splashColor: remoteHighlight.withValues(alpha: .18),
                        highlightColor: remoteHighlight.withValues(alpha: .12),
                        child: Semantics(
                          label: label,
                          button: true,
                          enabled: onKey != null && enabledKeys.contains(key),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),
                ),
              Center(
                child: SizedBox.square(
                  dimension: size * .40,
                  child: Tooltip(
                    message: 'Select',
                    child: Semantics(
                      label: 'Select',
                      button: true,
                      enabled:
                          onKey != null &&
                          enabledKeys.contains(RemoteKey.select),
                      child: Material(
                        color: remoteSurface,
                        shape: CircleBorder(
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: .08),
                          ),
                        ),
                        elevation: 2,
                        child: InkWell(
                          key: const ValueKey('ring-select'),
                          customBorder: const CircleBorder(),
                          onTap:
                              onKey != null &&
                                  enabledKeys.contains(RemoteKey.select)
                              ? () => onKey!(RemoteKey.select)
                              : null,
                          child: Center(
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: onKey == null
                                    ? Colors.white24
                                    : remoteHighlight,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _RingSector extends CustomClipper<Path> {
  const _RingSector(this.angle);
  final double angle;
  @override
  Path getClip(Size size) {
    final center = size.center(Offset.zero);
    final outer = size.width / 2;
    final inner = size.width * .24;
    const sweep = math.pi / 2;
    return Path()
      ..moveTo(
        center.dx + outer * math.cos(angle),
        center.dy + outer * math.sin(angle),
      )
      ..arcTo(
        Rect.fromCircle(center: center, radius: outer),
        angle,
        sweep,
        false,
      )
      ..lineTo(
        center.dx + inner * math.cos(angle + sweep),
        center.dy + inner * math.sin(angle + sweep),
      )
      ..arcTo(
        Rect.fromCircle(center: center, radius: inner),
        angle + sweep,
        -sweep,
        false,
      )
      ..close();
  }

  @override
  bool shouldReclip(_RingSector oldClipper) => oldClipper.angle != angle;
}

/// No invented slider value: each end sends a real incremental TV command.
/// The middle grip is mute for volume, or the number pad for channels.
class RemoteRocker extends StatelessWidget {
  const RemoteRocker({
    super.key,
    required this.label,
    required this.onUp,
    required this.onDown,
    required this.onCenter,
    required this.centerLabel,
  });
  final String label;
  final VoidCallback? onUp;
  final VoidCallback? onDown;
  final VoidCallback? onCenter;
  final String centerLabel;

  Widget zone(String label, VoidCallback? action, Widget child) => Tooltip(
    message: label,
    child: Semantics(
      label: label,
      button: true,
      enabled: action != null,
      child: InkWell(
        onTap: action,
        child: SizedBox(width: 72, height: 48, child: Center(child: child)),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Material(
        color: const Color(0xff39413c),
        elevation: 3,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            zone('$label up', onUp, const SizedBox.shrink()),
            zone(
              centerLabel,
              onCenter,
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var n = 0; n < 3; n++)
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      height: 1,
                      width: 19,
                      color: Colors.white.withValues(alpha: .30),
                    ),
                ],
              ),
            ),
            zone('$label down', onDown, const SizedBox.shrink()),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Text(
        label == 'Volume' ? 'VOL' : 'CH',
        style: const TextStyle(
          color: Color(0xffa6b0a9),
          fontSize: 11,
          letterSpacing: 2,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}
