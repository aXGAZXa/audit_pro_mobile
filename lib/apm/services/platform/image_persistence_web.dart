import 'package:image_picker/image_picker.dart';

import '../../forms/heat_network_assessment/services/hna_web_editor_attachment_context.dart';

Future<List<String>> persistPickedImagePathsImpl(
  List<XFile> images, {
  required String prefix,
}) async {
  final ctx = HnaWebEditorAttachmentContext.instance;
  if (!ctx.isConfigured) {
    return images.map((e) => e.path).toList(growable: false);
  }

  final out = <String>[];
  for (final image in images) {
    // If the image path already exists in the payload attachment map, keep it.
    if (ctx.knowsLocalPath(image.path)) {
      out.add(image.path);
      continue;
    }

    final uploadedLocalPath = await ctx.uploadNewImage(
      image: image,
      prefix: prefix,
    );
    out.add(uploadedLocalPath);
  }

  return out;
}
