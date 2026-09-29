import 'package:flutter_test/flutter_test.dart';
import 'package:nofeed/media_pick_request.dart';

void main() {
  MediaPickRequest req(List<String> accept, {bool multiple = false}) =>
      MediaPickRequest.fromAcceptTypes(accept, multiple: multiple);

  test('images only use the photo picker for images', () {
    expect(req(['image/*']).kind, PickerKind.image);
    expect(req(['image/jpeg', 'image/png']).kind, PickerKind.image);
    expect(req(['.jpg,.png']).kind, PickerKind.image);
  });

  test('videos only use the photo picker for videos', () {
    expect(req(['video/mp4']).kind, PickerKind.video);
    expect(req(['.mov']).kind, PickerKind.video);
  });

  test('images and videos (also as one comma-separated entry)', () {
    expect(req(['image/jpeg', 'video/mp4']).kind, PickerKind.imageAndVideo);
    expect(req(['image/jpeg,image/png,video/mp4,video/quicktime']).kind, PickerKind.imageAndVideo);
    expect(req([' IMAGE/JPEG , Video/MP4 ']).kind, PickerKind.imageAndVideo);
  });

  test('anything else falls back to the document picker', () {
    expect(req([]).kind, PickerKind.document);
    expect(req(['']).kind, PickerKind.document);
    expect(req(['application/pdf']).kind, PickerKind.document);
    expect(req(['image/*', 'audio/mpeg']).kind, PickerKind.document);
    expect(req(['.txt']).kind, PickerKind.document);
  });

  test('mime types are normalised and deduplicated', () {
    expect(req(['.jpg', 'image/jpeg', '.pdf']).mimeTypes, ['image/jpeg']);
  });

  test('multiple flag and map for the platform channel', () {
    expect(req(['image/*'], multiple: true).toMap(), {
      'kind': 'image',
      'mimeTypes': ['image/*'],
      'multiple': true,
    });
  });
}
