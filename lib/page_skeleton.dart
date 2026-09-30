import 'package:flutter/material.dart';

import 'page_placeholder.dart';

/// Grey shapes in the layout of an Instagram page, shown while the real page
/// loads (see page_placeholder.dart). Drawn by NoFeed itself – nothing is
/// read from or stored about the page. Measured from the Instagram website on
/// an iPhone (points).
class PageSkeleton extends StatefulWidget {
  const PageSkeleton({super.key, required this.kind, this.topInset = 0, this.bottomInset = 0});

  final PagePlaceholder kind;

  /// Height of the status bar when the page reaches under it (iPhone inbox).
  final double topInset;

  /// Space under the chat composer (home indicator).
  final double bottomInset;

  @override
  State<PageSkeleton> createState() => _PageSkeletonState();
}

class _PageSkeletonState extends State<PageSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: FadeTransition(
        opacity: Tween<double>(
          begin: 0.55,
          end: 1,
        ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
        child: CustomPaint(
          size: Size.infinite,
          painter: _SkeletonPainter(
            kind: widget.kind,
            color: theme.colorScheme.onSurface.withValues(alpha: dark ? 0.1 : 0.08),
            topInset: widget.topInset,
            bottomInset: widget.bottomInset,
          ),
        ),
      ),
    );
  }
}

class _SkeletonPainter extends CustomPainter {
  _SkeletonPainter({
    required this.kind,
    required this.color,
    required this.topInset,
    required this.bottomInset,
  });

  final PagePlaceholder kind;
  final Color color;
  final double topInset;
  final double bottomInset;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = color
      ..isAntiAlias = true;

    void bar(double x, double y, double w, double h) => canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(h / 2)),
      fill,
    );
    void circle(double cx, double cy, double d) => canvas.drawCircle(Offset(cx, cy), d / 2, fill);

    canvas.clipRect(Offset.zero & size);
    final w = size.width;
    final t = topInset;

    switch (kind) {
      case PagePlaceholder.inbox:
        bar(w / 2 - 65, t + 14, 130, 18); // account name
        bar(w - 40, t + 11, 24, 24); // new message
        bar(16, t + 45, w - 32, 38); // search
        for (var i = 0; i < 4; i++) {
          final cx = 64.0 + i * 104;
          circle(cx, t + 174, 74); // notes
          bar(cx - 28, t + 221, 56, 10);
        }
        bar(24, t + 244, 90, 16); // "Messages"
        for (var cy = t + 303; cy - 28 < size.height; cy += 72) {
          circle(52, cy, 56);
          bar(92, cy - 17, 120, 13);
          bar(92, cy + 6, (w - 140).clamp(80, 220), 12);
        }
      case PagePlaceholder.chat:
        bar(17, 22, 22, 16); // back
        circle(78, 30, 32);
        bar(102, 17, 110, 13); // name
        bar(102, 36, 70, 9);
        circle(w - 27, 30, 24); // info
        canvas.drawRect(Rect.fromLTWH(0, 60, w, 0.6), fill);
        circle(w / 2, 142, 72); // profile card at the start of a chat
        bar(w / 2 - 55, 190, 110, 14);
        bar(w / 2 - 85, 213, 170, 11);
        // Message composer.
        final composer = RRect.fromRectAndRadius(
          Rect.fromLTWH(16, size.height - bottomInset - 44, w - 32, 44),
          const Radius.circular(22),
        );
        canvas.drawRRect(
          composer,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..isAntiAlias = true,
        );
        bar(36, size.height - bottomInset - 28, 70, 12);
      case PagePlaceholder.feed:
        bar(w - 78, t + 10, 24, 24); // create
        bar(w - 40, t + 10, 24, 24); // activity
        for (var i = 0; i < 4; i++) {
          final cx = 60.0 + i * 102;
          circle(cx, t + 93, 84); // stories
          bar(cx - 30, t + 146, 60, 10);
        }
        circle(28, t + 196, 40); // first post
        bar(58, t + 184, 140, 12);
        bar(58, t + 202, 90, 10);
        canvas.drawRect(Rect.fromLTWH(0, t + 225, w, w * 1.25), fill);
    }
  }

  @override
  bool shouldRepaint(_SkeletonPainter old) =>
      old.kind != kind ||
      old.color != color ||
      old.topInset != topInset ||
      old.bottomInset != bottomInset;
}
