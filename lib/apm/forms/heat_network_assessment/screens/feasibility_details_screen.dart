import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../../components/app_info_panel.dart';
import '../../../components/app_scaffold.dart';
import '../../../components/form_widgets.dart';

class FeasibilityDetailsScreen extends StatefulWidget {
  const FeasibilityDetailsScreen({super.key});

  @override
  State<FeasibilityDetailsScreen> createState() =>
      _FeasibilityDetailsScreenState();
}

class _FeasibilityDetailsScreenState extends State<FeasibilityDetailsScreen> {
  final _reasonController = TextEditingController();
  List<XFile> _images = [];
  String _title = 'Assessment Details';
  String _infoText = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    if (args != null) {
      if (args['title'] != null) _title = args['title'];
      if (args['infoText'] != null) _infoText = args['infoText'];

      if (_reasonController.text.isEmpty && args['reason'] != null) {
        _reasonController.text = args['reason'];
      }

      if (_images.isEmpty && args['imagePaths'] != null) {
        final paths = args['imagePaths'] as List<String>;
        _images = paths.map((path) => XFile(path)).toList();
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 50,
      );

      if (image != null) {
        setState(() {
          _images.add(image);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
      }
    }
  }

  Future<void> _saveAndClose() async {
    // Return data to previous screen
    final imagePaths = <String>[];

    // Save images to persistent storage if needed, or pass back paths
    // For this simple implementation, we assume we just pass back the paths
    // In a real app, you might want to save them to the app's document directory here if they are temp files

    final appDir = await getApplicationDocumentsDirectory();

    for (var image in _images) {
      if (!image.path.contains(appDir.path)) {
        // It's a temp file, copy it
        final fileName = image.name;
        final savedImage = await File(
          image.path,
        ).copy('${appDir.path}/$fileName');
        imagePaths.add(savedImage.path);
      } else {
        imagePaths.add(image.path);
      }
    }

    if (mounted) {
      Navigator.pop(context, {
        'reason': _reasonController.text,
        'imagePaths': imagePaths,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _title,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_infoText.isNotEmpty) ...[
                    AppInfoPanel(title: 'Guidance', child: Text(_infoText)),
                    const SizedBox(height: 24),
                  ],

                  const Text(
                    'Feasibility Assessment',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  AppTextField(
                    label:
                        'Please explain why sub-metering is not feasible or requires investigation',
                    controller: _reasonController,
                    maxLines: 6,
                  ),

                  const SizedBox(height: 24),
                  const Text(
                    'Evidence Photos',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                    itemCount: _images.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _images.length) {
                        return Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.add_a_photo),
                            onPressed: () => _pickImage(ImageSource.camera),
                          ),
                        );
                      }
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(_images[index].path),
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.black54,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _images.removeAt(index);
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: AppButton(
                text: 'Save Details',
                onPressed: _saveAndClose,
                fullWidth: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
