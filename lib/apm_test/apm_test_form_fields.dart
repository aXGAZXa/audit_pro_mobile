import 'package:flutter/material.dart';

class ApmTestFormFields extends StatelessWidget {
  const ApmTestFormFields({
    super.key,
    required this.formKey,
    required this.formNameController,
    required this.titleController,
    required this.summaryController,
    required this.notesController,
    required this.submitLabel,
    required this.submitIcon,
    required this.isBusy,
    required this.onSubmit,
    this.introText,
    this.readOnlyFormKey = false,
    this.header,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController formNameController;
  final TextEditingController titleController;
  final TextEditingController summaryController;
  final TextEditingController notesController;
  final String submitLabel;
  final Widget submitIcon;
  final bool isBusy;
  final VoidCallback onSubmit;
  final String? introText;
  final bool readOnlyFormKey;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null) ...[header!, const SizedBox(height: 16)],
          if (introText != null && introText!.trim().isNotEmpty) ...[
            Text(introText!, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: formNameController,
            readOnly: readOnlyFormKey,
            decoration: const InputDecoration(
              labelText: 'Form key',
              helperText: 'Logical form identifier stored with the submission.',
            ),
            validator: (value) {
              if ((value ?? '').trim().isEmpty) {
                return 'Form key is required.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: titleController,
            decoration: const InputDecoration(labelText: 'Title'),
            validator: (value) {
              if ((value ?? '').trim().isEmpty) {
                return 'Title is required.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: summaryController,
            decoration: const InputDecoration(labelText: 'Summary'),
            minLines: 2,
            maxLines: 4,
            validator: (value) {
              if ((value ?? '').trim().isEmpty) {
                return 'Summary is required.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: notesController,
            decoration: const InputDecoration(labelText: 'Notes'),
            minLines: 4,
            maxLines: 8,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: isBusy ? null : onSubmit,
            icon: submitIcon,
            label: Text(submitLabel),
          ),
        ],
      ),
    );
  }
}
