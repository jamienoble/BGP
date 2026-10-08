import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:walkies/theme/app_theme.dart';

/// "4,850"
String formatNumber(int value) {
  final digits = value.abs().toString();
  final out = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

/// White rounded card with a hairline border and a soft shadow.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;
  final Color? borderColor;
  final double radius;
  final bool shadow;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.color = AppPalette.white,
    this.borderColor = AppPalette.line,
    this.radius = AppSpacing.radius,
    this.shadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: shadow
            ? const [
                BoxShadow(
                  color: Color(0x0F1E3D33),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Material(
        color: color,
        shape: RoundedRectangleBorder(
          borderRadius: shape,
          side: borderColor == null
              ? BorderSide.none
              : BorderSide(color: borderColor!),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Small uppercase label above a section
class SectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const SectionLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Icon in a tinted rounded square
class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color background;
  final Color foreground;
  final double size;

  const IconBadge(
    this.icon, {
    super.key,
    this.background = AppPalette.sage,
    this.foreground = AppPalette.forest,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, color: foreground, size: size * 0.52),
    );
  }
}

/// Compact rounded label, optionally with an icon
class Pill extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color background;
  final Color foreground;

  const Pill(
    this.text, {
    super.key,
    this.icon,
    this.background = AppPalette.sage,
    this.foreground = AppPalette.forestDeep,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: foreground,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _avatarColours = [
  (Color(0xFFDDEEE6), Color(0xFF2D5A4A)),
  (Color(0xFFFBE6D6), Color(0xFF8A4318)),
  (Color(0xFFE6E4F4), Color(0xFF4A4483)),
  (Color(0xFFF6E3EA), Color(0xFF8A3456)),
  (Color(0xFFE2EEF5), Color(0xFF2B5874)),
  (Color(0xFFF3EBD3), Color(0xFF6D5716)),
];

/// Circle with a person's initial, coloured consistently by name
class InitialAvatar extends StatelessWidget {
  final String name;
  final double size;

  const InitialAvatar(this.name, {super.key, this.size = 36});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) =
        _avatarColours[name.codeUnits.fold(0, (a, b) => a + b) %
            _avatarColours.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text(
        name.isEmpty ? '?' : name.characters.first.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Fraunces',
          fontWeight: FontWeight.w600,
          fontSize: size * 0.44,
          color: fg,
          height: 1,
        ),
      ),
    );
  }
}

const _artPalettes = [
  [Color(0xFF2D5A4A), Color(0xFF5E9B82), Color(0xFFDDEEE6)],
  [Color(0xFFB85C2A), Color(0xFFE3955F), Color(0xFFFBE6D6)],
  [Color(0xFF4A4483), Color(0xFF8B84C9), Color(0xFFE6E4F4)],
  [Color(0xFF8A3456), Color(0xFFD27C9C), Color(0xFFF6E3EA)],
  [Color(0xFF2B5874), Color(0xFF6CA2C2), Color(0xFFE2EEF5)],
];

/// Generated artwork for content without a cover image: a soft gradient
/// with layered circles, coloured consistently by [seed].
class ArtworkPlaceholder extends StatelessWidget {
  final String seed;
  final IconData icon;
  final double iconSize;

  /// Force a palette (0 = forest) instead of choosing one from [seed]
  final int? palette;

  const ArtworkPlaceholder({
    super.key,
    required this.seed,
    required this.icon,
    this.iconSize = 44,
    this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final hash = seed.codeUnits.fold(7, (a, b) => (a * 31 + b) & 0x7fffffff);
    final colours = _artPalettes[(palette ?? hash) % _artPalettes.length];
    return CustomPaint(
      painter: _ArtPainter(colours, hash),
      child: Center(
        child: Icon(
          icon,
          size: iconSize,
          color: Colors.white.withValues(alpha: 0.92),
        ),
      ),
    );
  }
}

class _ArtPainter extends CustomPainter {
  final List<Color> colours;
  final int hash;

  _ArtPainter(this.colours, this.hash);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colours[0], colours[1]],
        ).createShader(rect),
    );
    final random = math.Random(hash);
    for (var i = 0; i < 4; i++) {
      final r = size.shortestSide * (0.35 + random.nextDouble() * 0.5);
      canvas.drawCircle(
        Offset(
          size.width * random.nextDouble(),
          size.height * random.nextDouble(),
        ),
        r,
        Paint()
          ..color = colours[2].withValues(
            alpha: 0.10 + random.nextDouble() * 0.10,
          ),
      );
    }
  }

  @override
  bool shouldRepaint(_ArtPainter old) => old.hash != hash;
}

enum NoticeTone { info, success, warning, danger }

/// Coloured message box with optional actions
class NoticeCard extends StatelessWidget {
  final NoticeTone tone;
  final IconData icon;
  final String title;
  final String? message;
  final List<Widget> actions;

  const NoticeCard({
    super.key,
    required this.tone,
    required this.icon,
    required this.title,
    this.message,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      NoticeTone.info => (AppPalette.sage, AppPalette.forestDeep),
      NoticeTone.success => (AppPalette.sage, AppPalette.forestDeep),
      NoticeTone.warning => (AppPalette.warnSoft, AppPalette.warn),
      NoticeTone.danger => (AppPalette.dangerSoft, AppPalette.danger),
    };
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleSmall!.copyWith(color: fg)),
                if (message != null) ...[
                  const SizedBox(height: 4),
                  Text(message!, style: text.bodySmall!.copyWith(color: fg)),
                ],
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: actions),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Centred icon, title and message for empty, locked and error states
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AppPalette.sage,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 34, color: AppPalette.forest),
          ),
          const SizedBox(height: 18),
          Text(title, textAlign: TextAlign.center, style: text.titleLarge),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(message!, textAlign: TextAlign.center, style: text.bodyMedium),
          ],
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    );
  }
}
