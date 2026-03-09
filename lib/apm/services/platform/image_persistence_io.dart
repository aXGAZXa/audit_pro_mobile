import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

Future<List<String>> persistPickedImagePathsImpl(
  List<XFile> images, {
  required String prefix,
}) async {
  if (kIsWeb) {
    return images.map((i) => i.path).toList(growable: false);
  }

  final List<String> paths = [];
  final appDir = await getApplicationDocumentsDirectory();

  for (final image in images) {
    final path = image.path;
    if (path.startsWith(appDir.path)) {
      paths.add(path);
    } else {
      final fileName =
          '${prefix}_${DateTime.now().millisecondsSinceEpoch}_${paths.length}.jpg';
      final savedImage = File('${appDir.path}/$fileName');
      await File(path).copy(savedImage.path);
      paths.add(savedImage.path);
    }
  }

  return paths;
}
