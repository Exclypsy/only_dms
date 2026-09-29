/// Maps the `accept` attribute of an `<input type="file">` to a system picker.
/// Pure Dart so it can be unit-tested.
library;

enum PickerKind {
  /// System Photo Picker, images only.
  image,

  /// System Photo Picker, videos only.
  video,

  /// System Photo Picker, images and videos.
  imageAndVideo,

  /// System document picker (for anything that is not a photo or video).
  document,
}

class MediaPickRequest {
  const MediaPickRequest({required this.kind, required this.mimeTypes, required this.multiple});

  factory MediaPickRequest.fromAcceptTypes(List<String> acceptTypes, {required bool multiple}) {
    final types = [
      for (final entry in acceptTypes)
        for (final part in entry.split(','))
          if (part.trim().isNotEmpty) _normalize(part.trim().toLowerCase()),
    ];
    final hasImage = types.any((t) => t.startsWith('image/'));
    final hasVideo = types.any((t) => t.startsWith('video/'));
    final onlyMedia =
        types.isNotEmpty && types.every((t) => t.startsWith('image/') || t.startsWith('video/'));

    final PickerKind kind;
    if (!onlyMedia) {
      kind = PickerKind.document;
    } else if (hasImage && hasVideo) {
      kind = PickerKind.imageAndVideo;
    } else {
      kind = hasImage ? PickerKind.image : PickerKind.video;
    }
    return MediaPickRequest(
      kind: kind,
      mimeTypes: [
        for (final t in types.toSet())
          if (t.contains('/')) t,
      ],
      multiple: multiple,
    );
  }

  final PickerKind kind;

  /// MIME types for the document picker (e.g. `image/jpeg`, `video/*`).
  final List<String> mimeTypes;
  final bool multiple;

  Map<String, Object> toMap() => {'kind': kind.name, 'mimeTypes': mimeTypes, 'multiple': multiple};

  static const Map<String, String> _extensions = {
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.png': 'image/png',
    '.gif': 'image/gif',
    '.webp': 'image/webp',
    '.heic': 'image/heic',
    '.heif': 'image/heif',
    '.mp4': 'video/mp4',
    '.mov': 'video/quicktime',
  };

  /// Turns file extensions like `.jpg` into MIME types; unknown ones stay as-is.
  static String _normalize(String type) => _extensions[type] ?? type;
}
