import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import 'package:signature/signature.dart';

Future<XFile> _persistXFileToDocuments(
  XFile source, {
  required String prefix,
  String? suffix,
}) async {
  try {
    final appDir = await getApplicationDocumentsDirectory();
    if (source.path.startsWith(appDir.path)) {
      return source;
    }

    final ext = p.extension(source.path);
    final safeExt = ext.isNotEmpty ? ext : '.jpg';
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final fileName = suffix == null
        ? '${prefix}_$stamp$safeExt'
        : '${prefix}_${stamp}_$suffix$safeExt';
    final destPath = p.join(appDir.path, fileName);

    await File(source.path).copy(destPath);
    return XFile(destPath);
  } catch (_) {
    return source;
  }
}

Future<String?> _persistPngBytesToDocuments(
  Uint8List bytes, {
  required String prefix,
  String? suffix,
}) async {
  try {
    final appDir = await getApplicationDocumentsDirectory();

    final stamp = DateTime.now().microsecondsSinceEpoch;
    final fileName = suffix == null
        ? '${prefix}_$stamp.png'
        : '${prefix}_${stamp}_$suffix.png';
    final destPath = p.join(appDir.path, fileName);

    final file = File(destPath);
    await file.writeAsBytes(bytes);
    return file.path;
  } catch (_) {
    return null;
  }
}

/// Common text field component with consistent styling
class AppTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int maxLines;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool enabled;
  final VoidCallback? onEditingComplete;
  final List<TextInputFormatter>? inputFormatters;

  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.maxLines = 1,
    this.prefixIcon,
    this.suffixIcon,
    this.enabled = true,
    this.onEditingComplete,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        obscureText: obscureText,
        maxLines: maxLines,
        enabled: enabled,
        onEditingComplete: onEditingComplete,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }
}

/// Common dropdown field component
class AppDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?)? onChanged;
  final String? Function(T?)? validator;

  const AppDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        items: items,
        onChanged: onChanged,
        validator: validator,
        decoration: InputDecoration(labelText: label),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

/// Common elevated button with consistent styling
class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool fullWidth;

  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final button = icon != null
        ? ElevatedButton.icon(
            onPressed: isLoading ? null : onPressed,
            icon: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(icon),
            label: Text(text),
          )
        : ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(text),
          );

    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Common card component for grouping form sections
class AppCard extends StatelessWidget {
  final String? title;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const AppCard({super.key, this.title, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(title!, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

/// Common date picker field
class AppDateField extends StatelessWidget {
  final String label;
  final DateTime? selectedDate;
  final void Function(DateTime) onDateSelected;
  final DateTime? firstDate;
  final DateTime? lastDate;

  const AppDateField({
    super.key,
    required this.label,
    required this.selectedDate,
    required this.onDateSelected,
    this.firstDate,
    this.lastDate,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        controller: TextEditingController(
          text: selectedDate != null
              ? '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'
              : '',
        ),
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: selectedDate ?? DateTime.now(),
            firstDate: firstDate ?? DateTime(1900),
            lastDate: lastDate ?? DateTime(2100),
          );
          if (date != null) {
            onDateSelected(date);
          }
        },
      ),
    );
  }
}

/// Section header for forms
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const SectionHeader({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Photo capture field with camera integration
class AppImageCapture extends StatefulWidget {
  final String label;
  final String? hint;
  final XFile? image;
  final Function(XFile?) onImageChanged;
  final String? Function(XFile?)? validator;

  const AppImageCapture({
    super.key,
    required this.label,
    this.hint,
    required this.image,
    required this.onImageChanged,
    this.validator,
  });

  @override
  State<AppImageCapture> createState() => _AppImageCaptureState();
}

class _AppImageCaptureState extends State<AppImageCapture> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _captureImage() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (photo != null) {
        final persisted = await _persistXFileToDocuments(
          photo,
          prefix: 'capture',
        );
        widget.onImageChanged(persisted);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error capturing image: $e')));
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (photo != null) {
        final persisted = await _persistXFileToDocuments(
          photo,
          prefix: 'gallery',
        );
        widget.onImageChanged(persisted);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
      }
    }
  }

  void _showFullImage(BuildContext context) {
    if (widget.image == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.file(File(widget.image!.path), fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
          ),
          if (widget.hint != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.hint!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (widget.image == null)
            Column(
              children: [
                ElevatedButton.icon(
                  onPressed: _captureImage,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Take Photo'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _pickFromGallery,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Choose from Gallery'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.secondaryContainer,
                    foregroundColor: Theme.of(
                      context,
                    ).colorScheme.onSecondaryContainer,
                  ),
                ),
              ],
            )
          else
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: GestureDetector(
                      onTap: () => _showFullImage(context),
                      child: Stack(
                        children: [
                          Image.file(
                            File(widget.image!.path),
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.cover,
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.zoom_in,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _captureImage,
                            icon: const Icon(Icons.camera_alt, size: 18),
                            label: const Text('Retake'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.secondaryContainer,
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => widget.onImageChanged(null),
                            icon: const Icon(Icons.delete, size: 18),
                            label: const Text('Remove'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.errorContainer,
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (widget.validator != null &&
              widget.validator!(widget.image) != null)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 12),
              child: Text(
                widget.validator!(widget.image)!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Signature capture field with positive "tap to sign / tap to replace" UX.
///
/// Stores signature as a PNG file in app documents, and returns the file path.
class AppSignatureCapture extends StatelessWidget {
  final String label;
  final String? hint;
  final String? signaturePath;
  final ValueChanged<String?> onSignatureChanged;

  /// Prefix used when generating the PNG filename.
  final String filePrefix;

  /// If true, attempts to delete any previous signature file when replaced/removed.
  final bool deletePreviousFile;

  /// Optional validation error message to display.
  final String? validationErrorText;

  const AppSignatureCapture({
    super.key,
    required this.label,
    this.hint,
    required this.signaturePath,
    required this.onSignatureChanged,
    required this.filePrefix,
    this.deletePreviousFile = true,
    this.validationErrorText,
  });

  bool _fileExists(String? path) {
    if (path == null || path.isEmpty) return false;
    return File(path).existsSync();
  }

  Future<void> _deleteIfExists(String? path) async {
    if (!deletePreviousFile) return;
    if (path == null || path.isEmpty) return;

    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Best-effort delete only.
    }
  }

  Future<String?> _showSignatureDialog(BuildContext context) async {
    final SignatureController controller = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Capture Signature'),
        content: SizedBox(
          width: 320,
          height: 220,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: Signature(
              controller: controller,
              backgroundColor: Colors.white,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(onPressed: controller.clear, child: const Text('Clear')),
          ElevatedButton(
            onPressed: () async {
              if (controller.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please add a signature'),
                    duration: Duration(seconds: 2),
                  ),
                );
                return;
              }

              final Uint8List? signatureBytes = await controller.toPngBytes();
              if (signatureBytes == null) return;

              final savedPath = await _persistPngBytesToDocuments(
                signatureBytes,
                prefix: filePrefix,
              );
              if (savedPath != null && dialogContext.mounted) {
                Navigator.of(dialogContext).pop(savedPath);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ).then((value) {
      controller.dispose();
      return value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasSignature = _fileExists(signaturePath);
    final successColor = Colors.green;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(
              hint!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 8),

          if (hasSignature)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: successColor),
                borderRadius: BorderRadius.circular(8),
                color: successColor.withValues(alpha: 0.05),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: successColor, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Signature Captured',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: successColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap "Re-sign" to capture again',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: theme.colorScheme.error),
                    tooltip: 'Remove signature',
                    onPressed: () async {
                      final oldPath = signaturePath;
                      onSignatureChanged(null);
                      await _deleteIfExists(oldPath);
                    },
                  ),
                ],
              ),
            ),

          OutlinedButton.icon(
            onPressed: () async {
              final oldPath = signaturePath;
              final newPath = await _showSignatureDialog(context);
              if (newPath == null) return;

              if (deletePreviousFile && oldPath != null && oldPath != newPath) {
                await _deleteIfExists(oldPath);
              }
              onSignatureChanged(newPath);
            },
            icon: Icon(hasSignature ? Icons.edit : Icons.draw),
            label: Text(hasSignature ? 'Re-sign' : 'Add Signature'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            ),
          ),

          if (validationErrorText != null && validationErrorText!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 12),
              child: Text(
                validationErrorText!,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

/// Question block component with answer options and observation support
class AppQuestionBlock extends StatefulWidget {
  final String questionText;
  final String questionReference;
  final String? sectionName;
  final String? selectedAnswer;
  final Function(String) onAnswerChanged;
  final List<String> answerOptions;
  final int? formId;
  final bool hasObservations;
  final VoidCallback? onObservationsChanged;

  const AppQuestionBlock({
    super.key,
    required this.questionText,
    required this.questionReference,
    this.sectionName,
    this.selectedAnswer,
    required this.onAnswerChanged,
    this.answerOptions = const ['YES', 'NO', 'NA'],
    this.formId,
    this.hasObservations = false,
    this.onObservationsChanged,
  });

  @override
  State<AppQuestionBlock> createState() => _AppQuestionBlockState();
}

class _AppQuestionBlockState extends State<AppQuestionBlock> {
  Future<void> _viewObservations(BuildContext context) async {
    if (widget.formId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please save the form first')),
      );
      return;
    }

    await Navigator.pushNamed(
      context,
      '/observations-list',
      arguments: {
        'formId': widget.formId,
        'questionReference': widget.questionReference,
        'questionText': widget.questionText,
        'sectionName': widget.sectionName,
      },
    );

    // Refresh observations when returning
    if (widget.onObservationsChanged != null) {
      widget.onObservationsChanged!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final showObservationOption = widget.selectedAnswer == 'NO';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.questionText,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          Row(
            children: widget.answerOptions.map((option) {
              final isSelected = widget.selectedAnswer == option;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: SizedBox(
                      width: double.infinity,
                      child: Text(
                        option,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isSelected
                              ? Theme.of(context).colorScheme.onPrimary
                              : null,
                        ),
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        widget.onAnswerChanged(option);
                      }
                    },
                    selectedColor: Theme.of(context).colorScheme.primary,
                    backgroundColor: Colors.white,
                    side: BorderSide.none,
                    elevation: isSelected ? 2 : 0,
                    shadowColor: Colors.black.withValues(alpha: 0.08),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (showObservationOption) ...[
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _viewObservations(context),
              icon: Icon(
                widget.hasObservations ? Icons.list_alt : Icons.add_comment,
                size: 20,
              ),
              label: Text(
                widget.hasObservations
                    ? 'View Observations'
                    : 'Add Observations',
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 40),
                backgroundColor: widget.hasObservations
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Multi-image capture widget for capturing/selecting multiple images
class AppMultiImageCapture extends StatefulWidget {
  final List<XFile> images;
  final Function(List<XFile>) onImagesChanged;
  final int maxImages;

  const AppMultiImageCapture({
    super.key,
    required this.images,
    required this.onImagesChanged,
    this.maxImages = 5,
  });

  @override
  State<AppMultiImageCapture> createState() => _AppMultiImageCaptureState();
}

class _AppMultiImageCaptureState extends State<AppMultiImageCapture> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _captureImage() async {
    if (widget.images.length >= widget.maxImages) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Limit Reached'),
          content: Text('Maximum ${widget.maxImages} images allowed'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (photo != null) {
        final persisted = await _persistXFileToDocuments(
          photo,
          prefix: 'capture',
          suffix: '${widget.images.length}',
        );
        final newImages = [...widget.images, persisted];
        widget.onImagesChanged(newImages);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error capturing image: $e')));
      }
    }
  }

  Future<void> _pickFromGallery() async {
    if (widget.images.length >= widget.maxImages) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Limit Reached'),
          content: Text('Maximum ${widget.maxImages} images allowed'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    try {
      final List<XFile> photos = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (photos.isNotEmpty) {
        final remainingSlots = widget.maxImages - widget.images.length;
        final photosToAdd = photos.take(remainingSlots).toList();

        final List<XFile> persistedPhotosToAdd = [];
        for (int i = 0; i < photosToAdd.length; i++) {
          final persisted = await _persistXFileToDocuments(
            photosToAdd[i],
            prefix: 'gallery',
            suffix: '${widget.images.length + i}',
          );
          persistedPhotosToAdd.add(persisted);
        }

        final newImages = [...widget.images, ...persistedPhotosToAdd];
        widget.onImagesChanged(newImages);

        if (mounted && photos.length > remainingSlots) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Images Added'),
              content: Text(
                'Only $remainingSlots image(s) added. Maximum ${widget.maxImages} images allowed.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking images: $e')));
      }
    }
  }

  void _removeImage(int index) {
    final newImages = List<XFile>.from(widget.images);
    newImages.removeAt(index);
    widget.onImagesChanged(newImages);
  }

  void _showFullImage(BuildContext context, XFile image) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.file(File(image.path), fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: widget.images.length < widget.maxImages
                    ? _captureImage
                    : null,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Take Photo'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: widget.images.length < widget.maxImages
                    ? _pickFromGallery
                    : null,
                icon: const Icon(Icons.photo_library),
                label: const Text('Gallery'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.secondaryContainer,
                  foregroundColor: Theme.of(
                    context,
                  ).colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
        if (widget.images.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            '${widget.images.length} image${widget.images.length != 1 ? 's' : ''}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.images.length,
              itemBuilder: (context, index) {
                final image = widget.images[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => _showFullImage(context, image),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(image.path),
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _removeImage(index),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

/// Media capture block with observation support
/// Common block for capturing media (photos and videos) with consistent UI
class AppMediaBlock extends StatefulWidget {
  final String questionText;
  final String questionReference;
  final String? sectionName;
  final List<XFile> images;
  final Function(List<XFile>) onImagesChanged;
  final int maxImages;
  final int? formId;
  final bool hasObservations;
  final VoidCallback? onObservationsChanged;

  const AppMediaBlock({
    super.key,
    required this.questionText,
    required this.questionReference,
    this.sectionName,
    required this.images,
    required this.onImagesChanged,
    this.maxImages = 5,
    this.formId,
    this.hasObservations = false,
    this.onObservationsChanged,
  });

  @override
  State<AppMediaBlock> createState() => _AppMediaBlockState();
}

class _AppMediaBlockState extends State<AppMediaBlock> {
  Future<void> _viewObservations(BuildContext context) async {
    if (widget.formId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please save the form first')),
      );
      return;
    }

    await Navigator.pushNamed(
      context,
      '/observations-list',
      arguments: {
        'formId': widget.formId,
        'questionReference': widget.questionReference,
        'questionText': widget.questionText,
        'sectionName': widget.sectionName,
      },
    );

    // Refresh observations when returning
    if (widget.onObservationsChanged != null) {
      widget.onObservationsChanged!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.questionText,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        AppMultiImageCapture(
          images: widget.images,
          onImagesChanged: widget.onImagesChanged,
          maxImages: widget.maxImages,
        ),
        if (widget.formId != null) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _viewObservations(context),
              icon: Icon(
                widget.hasObservations ? Icons.list_alt : Icons.add_comment,
                size: 20,
              ),
              label: Text(
                widget.hasObservations
                    ? 'View Observations'
                    : 'Add Observations',
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 40),
                backgroundColor: widget.hasObservations
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class AppSelectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final List<String>? content;

  const AppSelectionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
    this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: selected ? 2 : 0,
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? color : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selected
                    ? color.withValues(alpha: 0.15)
                    : color.withValues(alpha: 0.05),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1F2937),
                              ),
                        ),
                        if (subtitle.isNotEmpty)
                          Text(
                            subtitle,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: const Color(0xFF6B7280)),
                          ),
                      ],
                    ),
                  ),
                  if (selected)
                    Icon(Icons.check_circle, color: color, size: 28)
                  else
                    Icon(
                      Icons.radio_button_unchecked,
                      color: Colors.grey[400],
                      size: 28,
                    ),
                ],
              ),
            ),
            if (content != null && content!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: content!.map((text) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Icon(
                              Icons.circle,
                              size: 4,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              text,
                              style: const TextStyle(
                                height: 1.4,
                                color: Color(0xFF374151),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class AppLabel extends StatelessWidget {
  final String label;
  final bool required;

  const AppLabel({super.key, required this.label, this.required = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      label + (required ? ' *' : ''),
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}
