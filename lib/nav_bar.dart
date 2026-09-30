import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'nav_tabs.dart';

/// Floating navigation pill modelled on the Instagram app (2026): translucent
/// blurred capsule, icons only, the active item on a lighter capsule that
/// slides (and stretches like liquid glass) to the tapped item. The capsule
/// can also be dragged with the finger: it lifts, follows the finger and
/// drops onto the nearest item when released. Three destinations: Home
/// (Following feed), Messages and Profile. Long-pressing Profile opens
/// NoFeed's settings (in Instagram it opens the account menu).
class NoFeedNavBar extends StatefulWidget {
  const NoFeedNavBar({
    super.key,
    required this.active,
    required this.onTap,
    this.onLongPressProfile,
    this.avatarUrl,
  });

  final NavTab? active;
  final ValueChanged<NavTab> onTap;
  final VoidCallback? onLongPressProfile;

  /// Profile picture of the logged-in account; a person icon if null.
  final Uri? avatarUrl;

  /// Order of the items in the pill.
  static const tabs = [NavTab.home, NavTab.messages, NavTab.profile];

  /// Measured from Instagram app screenshots (points).
  static const double height = 63;
  static const double itemWidth = 87;
  static const double _padding = 3;
  static const double _gap = 12;
  static const double _step = itemWidth + _gap;

  /// Width of the pill's content (without the padding).
  static double get contentWidth => itemWidth * tabs.length + _gap * (tabs.length - 1);

  /// Item under a finger at [dx] (from the content's left edge), as a
  /// fractional index clamped to the items: 0 = first item, 1 = second, …
  static double positionAt(double dx) =>
      ((dx - itemWidth / 2) / _step).clamp(0, tabs.length - 1).toDouble();

  @override
  State<NoFeedNavBar> createState() => _NoFeedNavBarState();
}

class _NoFeedNavBarState extends State<NoFeedNavBar> with TickerProviderStateMixin {
  /// Highlight position as a fractional item index.
  late final AnimationController _position = AnimationController.unbounded(
    vsync: this,
    value: _indexOf(widget.active)?.toDouble() ?? 0,
  );

  /// 0 = resting, 1 = lifted by the finger.
  late final AnimationController _lift = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );

  bool _dragging = false;
  int? _hovered;

  static int? _indexOf(NavTab? tab) {
    final index = tab == null ? -1 : NoFeedNavBar.tabs.indexOf(tab);
    return index < 0 ? null : index;
  }

  @override
  void didUpdateWidget(NoFeedNavBar old) {
    super.didUpdateWidget(old);
    final index = _indexOf(widget.active);
    if (!_dragging && index != null && old.active != widget.active) _slideTo(index);
  }

  @override
  void dispose() {
    _position.dispose();
    _lift.dispose();
    super.dispose();
  }

  void _slideTo(int index) => _position.animateTo(
    index.toDouble(),
    duration: const Duration(milliseconds: 420),
    curve: Curves.easeOutCubic,
  );

  void _onDragStart(DragStartDetails details) {
    _dragging = true;
    _hovered = _position.value.round();
    _position.value = NoFeedNavBar.positionAt(details.localPosition.dx);
    _lift.forward();
    HapticFeedback.lightImpact();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _position.value = NoFeedNavBar.positionAt(details.localPosition.dx);
    final hovered = _position.value.round();
    if (hovered != _hovered) {
      _hovered = hovered;
      HapticFeedback.selectionClick();
    }
  }

  void _onDragEnd([DragEndDetails? _]) {
    if (!_dragging) return;
    _dragging = false;
    _lift.reverse();
    final index = _position.value.round();
    _slideTo(index);
    final tab = NoFeedNavBar.tabs[index];
    if (tab != widget.active) widget.onTap(tab);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark
        ? const Color(0xFF16191D).withValues(alpha: 0.8)
        : Colors.white.withValues(alpha: 0.82);
    final border = dark
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.black.withValues(alpha: 0.08);
    final highlight = dark
        ? Colors.white.withValues(alpha: 0.17)
        : Colors.black.withValues(alpha: 0.07);
    final liftedHighlight = dark
        ? Colors.white.withValues(alpha: 0.24)
        : Colors.black.withValues(alpha: 0.11);

    final active = widget.active;
    const radius = NoFeedNavBar.height / 2;
    const innerHeight = NoFeedNavBar.height - 2 * NoFeedNavBar._padding;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.45 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: NoFeedNavBar.height,
            padding: const EdgeInsets.all(NoFeedNavBar._padding),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: border, width: 0.8),
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart: _onDragStart,
              onHorizontalDragUpdate: _onDragUpdate,
              onHorizontalDragEnd: _onDragEnd,
              onHorizontalDragCancel: _onDragEnd,
              child: SizedBox(
                width: NoFeedNavBar.contentWidth,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Sliding highlight: moves to the active item and stretches
                    // (wider, a bit flatter) halfway, like liquid glass. Lifted
                    // (bigger, brighter) while dragged by the finger.
                    AnimatedBuilder(
                      animation: Listenable.merge([_position, _lift]),
                      builder: (context, _) {
                        final position = _position.value;
                        final lift = _lift.value;
                        final travel = _dragging
                            ? 0.0
                            : math.sin(math.pi * (position - position.floorToDouble()));
                        final width = NoFeedNavBar.itemWidth + 26 * travel + 10 * lift;
                        final height = innerHeight * (1 - 0.08 * travel) + 8 * lift;
                        return Positioned(
                          left:
                              position * NoFeedNavBar._step - (width - NoFeedNavBar.itemWidth) / 2,
                          top: (innerHeight - height) / 2,
                          width: width,
                          height: height,
                          child: AnimatedOpacity(
                            opacity: active == null && !_dragging ? 0 : 1,
                            duration: const Duration(milliseconds: 200),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Color.lerp(highlight, liftedHighlight, lift),
                                borderRadius: BorderRadius.circular(height / 2),
                                border: lift > 0
                                    ? Border.all(
                                        color: border.withValues(alpha: border.a * lift),
                                        width: 0.8,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    Row(
                      children: [
                        _NavItem(
                          label: 'Domov',
                          hint: 'Príspevky ľudí, ktorých sleduješ',
                          selected: active == NavTab.home,
                          onTap: () => widget.onTap(NavTab.home),
                          child: _HomeIcon(filled: active == NavTab.home),
                        ),
                        const SizedBox(width: NoFeedNavBar._gap),
                        _NavItem(
                          label: 'Správy',
                          selected: active == NavTab.messages,
                          onTap: () => widget.onTap(NavTab.messages),
                          child: _DirectIcon(filled: active == NavTab.messages),
                        ),
                        const SizedBox(width: NoFeedNavBar._gap),
                        _NavItem(
                          label: 'Profil',
                          hint: 'Podrž pre nastavenia NoFeed',
                          selected: active == NavTab.profile,
                          onTap: () => widget.onTap(NavTab.profile),
                          onLongPress: widget.onLongPressProfile,
                          child: _ProfileIcon(
                            avatarUrl: widget.avatarUrl,
                            selected: active == NavTab.profile,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One tappable item; shrinks a little while pressed and springs back.
class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.child,
    this.onLongPress,
    this.hint,
  });

  final String label;
  final String? hint;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget child;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _pressed = false;

  void _setPressed(bool pressed) {
    if (pressed != _pressed) setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final longPress = widget.onLongPress;
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      hint: widget.hint,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        onLongPress: longPress == null
            ? null
            : () {
                _setPressed(false);
                HapticFeedback.mediumImpact();
                longPress();
              },
        child: SizedBox(
          width: NoFeedNavBar.itemWidth,
          height: NoFeedNavBar.height - 2 * NoFeedNavBar._padding,
          child: Center(
            child: AnimatedScale(
              scale: _pressed ? 0.86 : 1,
              duration: Duration(milliseconds: _pressed ? 90 : 260),
              curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween(begin: 0.8, end: 1.0).animate(animation),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(key: ValueKey(widget.selected), child: widget.child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// House "home" icon in the style of the Instagram app: outlined with a door,
/// or filled with the door cut out when active. Own drawing.
class _HomeIcon extends StatelessWidget {
  const _HomeIcon({required this.filled});

  final bool filled;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size.square(28),
      painter: _HomeIconPainter(color: Theme.of(context).colorScheme.onSurface, filled: filled),
    );
  }
}

class _HomeIconPainter extends CustomPainter {
  _HomeIconPainter({required this.color, required this.filled});

  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    // 24 × 24 design grid: roof at the top, walls down to y = 21.
    final house = Path()
      ..moveTo(12, 2.6)
      ..lineTo(21, 10)
      ..lineTo(21, 21)
      ..lineTo(3, 21)
      ..lineTo(3, 10)
      ..close();
    final door = Path()
      ..moveTo(9.4, 21)
      ..lineTo(9.4, 16.2)
      ..arcToPoint(const Offset(14.6, 16.2), radius: const Radius.circular(2.6))
      ..lineTo(14.6, 21);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    if (filled) {
      canvas.saveLayer(Offset.zero & const Size(24, 24), Paint());
      canvas.drawPath(house, Paint()..color = color);
      canvas.drawPath(house, stroke); // rounds the corners
      canvas.drawPath(
        door..close(),
        Paint()
          ..blendMode = BlendMode.clear
          ..isAntiAlias = true,
      );
      canvas.restore();
    } else {
      canvas.drawPath(house, stroke);
      canvas.drawPath(door, stroke);
    }
  }

  @override
  bool shouldRepaint(_HomeIconPainter old) => old.color != color || old.filled != filled;
}

/// Paper-plane "messages" icon in the style of the Instagram app: outlined
/// with a fold line, or filled with the fold cut out when active. Own drawing.
class _DirectIcon extends StatelessWidget {
  const _DirectIcon({required this.filled});

  final bool filled;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size.square(28),
      painter: _DirectIconPainter(color: Theme.of(context).colorScheme.onSurface, filled: filled),
    );
  }
}

class _DirectIconPainter extends CustomPainter {
  _DirectIconPainter({required this.color, required this.filled});

  final Color color;
  final bool filled;

  // 24 × 24 design grid.
  static const _left = Offset(3.2, 5.0);
  static const _tip = Offset(21.0, 3.6);
  static const _bottom = Offset(11.8, 20.6);
  static const _fold = Offset(9.6, 11.0);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final plane = Path()
      ..moveTo(_left.dx, _left.dy)
      ..lineTo(_tip.dx, _tip.dy)
      ..lineTo(_bottom.dx, _bottom.dy)
      ..close();
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    if (filled) {
      canvas.saveLayer(Offset.zero & const Size(24, 24), Paint());
      canvas.drawPath(plane, Paint()..color = color);
      canvas.drawPath(plane, stroke); // rounds the corners
      canvas.drawLine(
        _tip,
        _fold,
        Paint()
          ..blendMode = BlendMode.clear
          ..strokeWidth = 2.1
          ..strokeCap = StrokeCap.round,
      );
      canvas.restore();
    } else {
      canvas.drawPath(plane, stroke);
      canvas.drawLine(_tip, _fold, stroke);
    }
  }

  @override
  bool shouldRepaint(_DirectIconPainter old) => old.color != color || old.filled != filled;
}

/// Round profile picture like in Instagram's tab bar: a ring with a gap when
/// active, or a person outline when the picture is unknown or fails to load.
class _ProfileIcon extends StatelessWidget {
  const _ProfileIcon({required this.avatarUrl, required this.selected});

  final Uri? avatarUrl;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    final fallback = Icon(
      selected ? Icons.account_circle : Icons.account_circle_outlined,
      size: 30,
      color: color,
    );
    final url = avatarUrl;
    if (url == null) return fallback;
    return Container(
      width: 34,
      height: 34,
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: selected ? color : Colors.transparent, width: 2),
      ),
      child: ClipOval(
        // Kept in Flutter's in-memory image cache only (never written to disk).
        child: Image.network(
          url.toString(),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => FittedBox(child: fallback),
        ),
      ),
    );
  }
}
