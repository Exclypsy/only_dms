import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'chat_wallpaper_store.dart';

/// Settings row for one chat background: a small preview, tap to pick a photo
/// in the system photo picker, a bin to remove it.
class ChatWallpaperTile extends StatelessWidget {
  const ChatWallpaperTile({
    super.key,
    required this.store,
    required this.wallpaperKey,
    required this.title,
    required this.emptySubtitle,
    this.onPicked,
  });

  final ChatWallpaperStore store;

  /// [defaultWallpaperKey] or a chat id.
  final String wallpaperKey;
  final String title;

  /// Shown while no photo is saved for [wallpaperKey].
  final String emptySubtitle;

  /// Called after a photo was picked and saved.
  final VoidCallback? onPicked;

  /// Opens the system photo picker; nothing changes if it is cancelled.
  Future<void> _pick() async {
    if (await store.pick(wallpaperKey)) onPicked?.call();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final saved = store.keys.contains(wallpaperKey);
        return ListTile(
          leading: _Preview(
            // A new photo gets a new preview.
            key: ValueKey('$wallpaperKey@${store.revision(wallpaperKey)}'),
            store: store,
            wallpaperKey: wallpaperKey,
            saved: saved,
          ),
          title: Text(title),
          subtitle: Text(saved ? 'Vlastná fotka. Ťukni pre inú.' : emptySubtitle),
          trailing: saved
              ? IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Odstrániť pozadie',
                  onPressed: () => store.remove(wallpaperKey),
                )
              : null,
          onTap: _pick,
        );
      },
    );
  }
}

class _Preview extends StatefulWidget {
  const _Preview({super.key, required this.store, required this.wallpaperKey, required this.saved});

  final ChatWallpaperStore store;
  final String wallpaperKey;
  final bool saved;

  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  late final Future<Uint8List?> _bytes = widget.saved
      ? widget.store.bytes(widget.wallpaperKey)
      : Future.value();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 40,
        height: 52,
        child: FutureBuilder<Uint8List?>(
          future: _bytes,
          builder: (context, snapshot) {
            final bytes = snapshot.data;
            if (bytes == null) {
              return ColoredBox(
                color: scheme.surfaceContainerHighest,
                child: Icon(Icons.wallpaper_outlined, color: scheme.onSurfaceVariant),
              );
            }
            return Image.memory(
              bytes,
              fit: BoxFit.cover,
              // A thumbnail does not need the full photo in memory.
              cacheWidth: 160,
              gaplessPlayback: true,
              excludeFromSemantics: true,
            );
          },
        ),
      ),
    );
  }
}
