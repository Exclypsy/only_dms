import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'nav_tabs.dart';

/// Floating, Instagram-style navigation pill with only two destinations:
/// Messages and Profile. Translucent blurred capsule; the active item gets a
/// lighter capsule behind a filled icon. The parent positions it over the page.
class NoFeedNavBar extends StatelessWidget {
  const NoFeedNavBar({super.key, required this.active, required this.onTap});

  final NavTab? active;
  final ValueChanged<NavTab> onTap;

  static const double _radius = 32;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark
        ? const Color(0xFF1C1C1E).withValues(alpha: 0.82)
        : Colors.white.withValues(alpha: 0.85);
    final border = dark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.4 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(_radius),
              border: Border.all(color: border, width: 0.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _NavItem(
                    label: 'Správy',
                    selected: active == NavTab.messages,
                    // Paper plane tilted up like Instagram's "send" icon.
                    icon: Transform.rotate(
                      angle: -math.pi / 7,
                      child: Icon(active == NavTab.messages ? Icons.send : Icons.send_outlined),
                    ),
                    onTap: () => onTap(NavTab.messages),
                  ),
                  const SizedBox(width: 4),
                  _NavItem(
                    label: 'Profil',
                    selected: active == NavTab.profile,
                    icon: Icon(
                      active == NavTab.profile
                          ? Icons.account_circle
                          : Icons.account_circle_outlined,
                    ),
                    onTap: () => onTap(NavTab.profile),
                  ),
                ],
              ),
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
    required this.icon,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Widget icon;
  final VoidCallback onTap;

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
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: 88,
          height: 52,
          decoration: BoxDecoration(
            color: selected ? highlight : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Center(
            child: IconTheme.merge(
              data: IconThemeData(size: 28, color: theme.colorScheme.onSurface),
              child: icon,
            ),
          ),
        ),
      ),
    );
  }
}
