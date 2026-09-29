import 'package:flutter/material.dart';

import 'nav_tabs.dart';

/// Asks for the user's own Instagram username (for the Profile button).
/// Returns the normalized username, or null if cancelled.
Future<String?> showUsernameDialog(BuildContext context, {String? initial}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _UsernameDialog(initial: initial),
  );
}

class _UsernameDialog extends StatefulWidget {
  const _UsernameDialog({this.initial});

  final String? initial;

  @override
  State<_UsernameDialog> createState() => _UsernameDialogState();
}

class _UsernameDialogState extends State<_UsernameDialog> {
  late final TextEditingController _text = TextEditingController(text: widget.initial ?? '');
  String? _errorText;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    final username = NavTabs.normalizeUsername(_text.text);
    if (username == null) {
      setState(() => _errorText = 'Len písmená, čísla, bodka a podčiarkovník (max. 30).');
      return;
    }
    Navigator.pop(context, username);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tvoje používateľské meno'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tlačidlo Profil otvorí instagram.com/<meno>. '
            'Meno sa uloží iba v tomto zariadení.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _text,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(prefixText: '@', hintText: 'meno', errorText: _errorText),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Zrušiť')),
        FilledButton(onPressed: _submit, child: const Text('Uložiť')),
      ],
    );
  }
}
