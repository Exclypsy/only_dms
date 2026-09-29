import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'nav_tabs.dart';

/// Floating navigation pill modelled on the Instagram app (2026): translucent
/// blurred capsule, icons only, the active item on a lighter capsule. Only two
/// destinations: Messages and Profile. Long-pressing Profile opens NoFeed's
/// settings (in Instagram it opens the account menu).
class NoFeedNavBar extends StatelessWidget {
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

  /// Measured from Instagram app screenshots (points).
  static const double height = 59;
  static const double _padding = 5;
  static const double _radius = height / 2;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark
        ? const Color(0xFF1A1E23).withValues(alpha: 0.78)
        : Colors.white.withValues(alpha: 0.82);
    final border = dark
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.black.withValues(alpha: 0.08);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.45 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: height,
            padding: const EdgeInsets.all(_padding),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(_radius),
              border: Border.all(color: border, width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _NavItem(
                  label: 'Správy',
                  selected: active == NavTab.messages,
                  // Paper plane tilted up like Instagram's Direct icon.
                  onTap: () => onTap(NavTab.messages),
                  child: Transform.rotate(
                    angle: -math.pi / 7,
                    child: Icon(active == NavTab.messages ? Icons.send : Icons.send_outlined),
                  ),
                ),
                const SizedBox(width: 24),
                _NavItem(
                  label: 'Profil',
                  hint: 'Podrž pre nastavenia NoFeed',
                  selected: active == NavTab.profile,
                  onTap: () => onTap(NavTab.profile),
                  onLongPress: onLongPressProfile,
                  child: _ProfileIcon(avatarUrl: avatarUrl, selected: active == NavTab.profile),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.selected,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.hint,
  });

  final String label;
  final String? hint;
  final bool selected;
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highlight = theme.brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.black.withValues(alpha: 0.07);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      hint: hint,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        onLongPress: onLongPress == null
            ? null
            : () {
                HapticFeedback.mediumImpact();
                onLongPress!();
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: 77,
          height: NoFeedNavBar.height - 2 * NoFeedNavBar._padding,
          decoration: BoxDecoration(
            color: selected ? highlight : Colors.transparent,
            borderRadius: BorderRadius.circular(NoFeedNavBar._radius),
          ),
          child: Center(
            child: IconTheme.merge(
              data: IconThemeData(size: 28, color: theme.colorScheme.onSurface),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Round profile picture like in Instagram's tab bar (ring when active),
/// or a person icon when the picture is unknown or fails to load.
class _ProfileIcon extends StatelessWidget {
  const _ProfileIcon({required this.avatarUrl, required this.selected});

  final Uri? avatarUrl;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(selected ? Icons.account_circle : Icons.account_circle_outlined);
    final url = avatarUrl;
    if (url == null) return fallback;
    return Container(
      width: 30,
      height: 30,
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? Theme.of(context).colorScheme.onSurface : Colors.transparent,
          width: 1.5,
        ),
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
