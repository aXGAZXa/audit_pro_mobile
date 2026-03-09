import 'package:image_picker/image_picker.dart';

// Prefer `dart.library.html` to reliably detect Flutter Web.
import 'image_persistence_io.dart'
    if (dart.library.html) 'image_persistence_web.dart';

/// Persists picked images and returns stable paths/keys.
///
/// - On device: copies into app documents directory.
/// - On web: returns the current `XFile.path` values (no local file persistence).
Future<List<String>> persistPickedImagePaths(
  List<XFile> images, {
  required String prefix,
}) {
  return persistPickedImagePathsImpl(images, prefix: prefix);
}
