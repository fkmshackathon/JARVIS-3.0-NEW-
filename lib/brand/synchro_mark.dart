import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The SYNCHRO mark: a two-period grid held inside a rotation cycle — the timetable
/// snapping into step. Painted, not an image, so it stays crisp at any size and can
/// be reused verbatim by the Android adaptive icon.
class SynchroMark extends StatelessWidget {
  const SynchroMark({
    super.key,
    this.size = 44,
    this.badge = true,
    this.onLight = false,
    this.progress,
  });

  final double size;

  /// Draws the navy rounded plate behind the mark. Off for use on dark headers.
  final bool badge;

  /// Set when the mark sits on cream rather than navy; flips only the grid ink.
  final bool onLight;

  /// 0..1 sweep of the orange arc. Null keeps the static, balanced mark.
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _MarkPainter(
          badge: badge,
          progress: progress,
          palette: _Palette.forSurface(badge: badge, onLight: onLight),
        ),
      ),
    );
  }
}

class _Palette {
  const _Palette({
    required this.plate,
    required this.cycle,
    required this.grid,
    required this.accent,
  });

  final Color plate;
  final Color cycle;
  final Color grid;
  final Color accent;

  /// Without a plate the mark paints straight onto the header, so the grid has to
  /// contrast with that surface instead of with navy.
  static _Palette forSurface({required bool badge, required bool onLight}) {
    if (badge) {
      return const _Palette(
        plate: SynchroColors.navy,
        cycle: SynchroColors.onNavyMuted,
        grid: SynchroColors.onNavy,
        accent: SynchroColors.orange,
      );
    }
    return onLight
        ? const _Palette(
            plate: Colors.transparent,
            cycle: SynchroColors.navySoft,
            grid: SynchroColors.navy,
            accent: SynchroColors.orangeDeep,
          )
        : const _Palette(
            plate: Colors.transparent,
            cycle: SynchroColors.onNavyMuted,
            grid: SynchroColors.onNavy,
            accent: SynchroColors.orange,
          );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter({
    required this.badge,
    required this.progress,
    required this.palette,
  });

  final bool badge;
  final double? progress;
  final _Palette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    if (badge) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(size.width * 0.24)),
        Paint()..color = palette.plate,
      );
    }

    final inset = size.width * 0.16;
    final ring = Rect.fromLTWH(
      inset,
      inset,
      size.width - inset * 2,
      size.height - inset * 2,
    );

    // The cycle: two arcs with a gap each side, one ending in an arrowhead.
    final stroke = Paint()
      ..color = palette.cycle
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width * 0.055;
    canvas.drawArc(ring, math.pi * 0.16, math.pi * 0.84, false, stroke);
    canvas.drawArc(ring, math.pi * 1.16, math.pi * 0.84, false, stroke);

    final sweep = (progress ?? 1.0).clamp(0.0, 1.0) * math.pi * 0.84;
    if (sweep > 0.02) {
      canvas.drawArc(
        ring,
        math.pi * 1.16,
        sweep,
        false,
        Paint()
          ..color = palette.accent
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = size.width * 0.055,
      );
    }
    _arrowhead(
      canvas,
      ring,
      math.pi * 0.16 + math.pi * 0.84,
      palette.accent,
      size,
    );

    // The grid: four periods, the lower-left one resolved in orange.
    final cell = size.width * 0.115;
    final gap = cell * 0.42;
    final centre = ring.center;
    final origin = Offset(
      centre.dx - cell - gap / 2,
      centre.dy - cell - gap / 2,
    );
    for (var row = 0; row < 2; row++) {
      for (var column = 0; column < 2; column++) {
        final cellRect = Rect.fromLTWH(
          origin.dx + column * (cell + gap),
          origin.dy + row * (cell + gap),
          cell,
          cell,
        );
        final resolved = row == 1 && column == 0;
        canvas.drawRRect(
          RRect.fromRectAndRadius(cellRect, Radius.circular(cell * 0.28)),
          Paint()..color = resolved ? palette.accent : palette.grid,
        );
      }
    }
    // An original small sprout, not a copyrighted character or remote image.
    final leaf = Path()
      ..moveTo(size.width * .63, size.height * .32)
      ..quadraticBezierTo(
        size.width * .62,
        size.height * .12,
        size.width * .83,
        size.height * .14,
      )
      ..quadraticBezierTo(
        size.width * .84,
        size.height * .32,
        size.width * .63,
        size.height * .32,
      );
    canvas.drawPath(leaf, Paint()..color = palette.accent);
  }

  void _arrowhead(
    Canvas canvas,
    Rect ring,
    double angle,
    Color color,
    Size size,
  ) {
    final tip = Offset(
      ring.center.dx + ring.width / 2 * math.cos(angle),
      ring.center.dy + ring.height / 2 * math.sin(angle),
    );
    final head = size.width * 0.085;
    final direction = angle + math.pi / 2;
    final path = Path()
      ..moveTo(
        tip.dx + head * math.cos(direction),
        tip.dy + head * math.sin(direction),
      )
      ..lineTo(
        tip.dx + head * 0.7 * math.cos(direction + 2.4),
        tip.dy + head * 0.7 * math.sin(direction + 2.4),
      )
      ..lineTo(
        tip.dx + head * 0.7 * math.cos(direction - 2.4),
        tip.dy + head * 0.7 * math.sin(direction - 2.4),
      )
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.badge != badge ||
      old.progress != progress ||
      old.palette.grid != palette.grid ||
      old.palette.cycle != palette.cycle;
}

/// Wordmark lockup used on the splash and in the app bar.
class SynchroWordmark extends StatelessWidget {
  const SynchroWordmark({
    super.key,
    this.size = 44,
    this.onDark = true,
    this.progress,
  });

  final double size;
  final bool onDark;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final ink = onDark ? SynchroColors.onNavy : SynchroColors.navyDeep;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SynchroMark(size: size, badge: true, progress: progress),
          const SizedBox(width: SynchroSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'SYNCHRO',
                style: TextStyle(
                  fontSize: size * 0.42,
                  fontWeight: FontWeight.w700,
                  letterSpacing: SynchroType.overlineTracking * 0.75,
                  color: ink,
                ),
              ),
              Text(
                'SMART CAMPUS SCHEDULING',
                style: TextStyle(
                  fontSize: size * 0.16,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.1,
                  color: onDark
                      ? SynchroColors.onNavyMuted
                      : SynchroColors.inkMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
