import 'package:flutter/material.dart';

enum LoadErrorKind { offline, generic, redirectLoop }

/// Full-screen error shown instead of a blank page.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.kind, required this.onRetry, this.onOpenSettings});

  final LoadErrorKind kind;
  final VoidCallback onRetry;

  /// There is no toolbar, so settings stay reachable from the error screen.
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final (icon, title, message) = switch (kind) {
      LoadErrorKind.offline => (
        Icons.wifi_off,
        'Si offline',
        'Skontroluj pripojenie na internet a skús to znova.',
      ),
      LoadErrorKind.generic => (
        Icons.error_outline,
        'Stránku sa nepodarilo načítať',
        'Skús to o chvíľu znova.',
      ),
      LoadErrorKind.redirectLoop => (
        Icons.sync_problem,
        'Stránka sa stále presmerúva',
        'Instagram možno zmenil web. Skús to znova, a ak to nepomôže, '
            'treba upraviť pravidlá v aplikácii.',
      ),
    };
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(message, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Skúsiť znova'),
              ),
              if (onOpenSettings != null) ...[
                const SizedBox(height: 8),
                TextButton(onPressed: onOpenSettings, child: const Text('Nastavenia NoFeed')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
