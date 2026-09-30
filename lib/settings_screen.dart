import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'settings.dart';
import 'username_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.initial,
    required this.onChanged,
    required this.onLogout,
    this.onRequestNotifications,
    this.onTestNotification,
  });

  final AppSettings initial;
  final ValueChanged<AppSettings> onChanged;

  /// Clears cookies, cache and storage and shows the login page.
  final Future<void> Function() onLogout;

  /// Asks for notification permission; the switch stays off if refused.
  /// Without it the notifications section is hidden.
  final Future<bool> Function()? onRequestNotifications;
  final Future<void> Function()? onTestNotification;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AppSettings _settings = widget.initial;

  void _update(AppSettings settings) {
    setState(() => _settings = settings);
    widget.onChanged(settings);
  }

  Future<void> _editUsername() async {
    final username = await showUsernameDialog(
      context,
      initial: _settings.username,
    );
    if (username != null) _update(_settings.copyWith(username: username));
  }

  Future<void> _setNotifications(bool enabled) async {
    final request = widget.onRequestNotifications;
    if (enabled && request != null && !await request()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Oznámenia nie sú povolené. Povoliť ich môžeš v nastaveniach telefónu.',
          ),
        ),
      );
      return;
    }
    if (mounted) _update(_settings.copyWith(notificationsEnabled: enabled));
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Odhlásiť a vymazať dáta?'),
        content: const Text(
          'Vymažú sa cookies, cache a úložisko stránky v tejto aplikácii. '
          'Potom sa budeš musieť znova prihlásiť.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Zrušiť'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Odhlásiť'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.onLogout();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    return Scaffold(
      appBar: AppBar(title: const Text('Nastavenia')),
      body: ListView(
        children: [
          const _SectionHeader('Obsah'),
          SwitchListTile(
            title: const Text('Povoliť zdieľané reely (/reel/)'),
            subtitle: const Text(
              'Otvorí reel, ktorý ti niekto pošle v správe.',
            ),
            value: _settings.allowSharedReels,
            onChanged: (v) => _update(_settings.copyWith(allowSharedReels: v)),
          ),
          SwitchListTile(
            title: const Text('Povoliť stories'),
            value: _settings.allowStories,
            onChanged: (v) => _update(_settings.copyWith(allowStories: v)),
          ),
          if (isAndroid) ...[
            const _SectionHeader('Súkromie'),
            SwitchListTile(
              title: const Text('Skryť obsah v prehľade aplikácií'),
              subtitle: const Text(
                'Zablokuje aj snímky a nahrávanie obrazovky.',
              ),
              value: _settings.hideInRecents,
              onChanged: (v) => _update(_settings.copyWith(hideInRecents: v)),
            ),
          ],
          if (widget.onRequestNotifications != null) ...[
            const _SectionHeader('Oznámenia'),
            SwitchListTile(
              title: const Text('Oznámenia o nových správach'),
              subtitle: Text(
                isAndroid
                    ? 'Bez mien a obsahu správ. NoFeed zostane bežať na pozadí '
                          '(ikonka v lište) – nezatváraj ho v prehľade aplikácií.'
                    : 'Bez mien a obsahu správ. Iba kým je NoFeed otvorený – '
                          'iOS appky na pozadí uspí.',
              ),
              value: _settings.notificationsEnabled,
              onChanged: _setNotifications,
            ),
            if (_settings.notificationsEnabled &&
                widget.onTestNotification != null)
              ListTile(
                leading: const Icon(Icons.notifications_outlined),
                title: const Text('Poslať skúšobné oznámenie'),
                onTap: widget.onTestNotification,
              ),
          ],
          const _SectionHeader('Účet'),
          ListTile(
            leading: const Icon(Icons.account_circle_outlined),
            title: const Text('Účet pre tlačidlo Profil'),
            subtitle: Text(
              _settings.username == null
                  ? 'Zistí sa automaticky po načítaní správ'
                  : '@${_settings.username}',
            ),
            onTap: _editUsername,
          ),
          ListTile(
            leading: Icon(Icons.logout, color: theme.colorScheme.error),
            title: Text(
              'Odhlásiť a vymazať dáta',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            onTap: _confirmLogout,
          ),
          const _SectionHeader('O aplikácii'),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Text(
              'NoFeed zobrazuje web instagram.com obmedzený na správy. '
              'Nie je spojená so spoločnosťou Meta Platforms, Inc. ani s Instagramom.\n\n'
              'Aplikácia nezbiera žiadne údaje, nemá server ani analytiku. '
              'Prihlásenie (cookies) je uložené iba v tomto zariadení a nezálohuje sa.',
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
