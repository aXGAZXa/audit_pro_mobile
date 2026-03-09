import 'package:flutter/material.dart';
import 'package:gtapp_mobile/gtapp_mobile.dart' show GTNotificationService;

class FormValidationFeedback {
  static const String defaultMessage =
      'Please fix the highlighted fields before saving.';

  static void showValidationError(
    BuildContext context, {
    required String message,
    ScrollController? scrollController,
  }) {
    _showTopBanner(context, message);

    if (scrollController != null && scrollController.hasClients) {
      scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  static bool validate(
    BuildContext context,
    GlobalKey<FormState> formKey, {
    ScrollController? scrollController,
    String message = defaultMessage,
  }) {
    final isValid = formKey.currentState?.validate() ?? true;
    if (isValid) return true;

    showValidationError(
      context,
      message: message,
      scrollController: scrollController,
    );

    return false;
  }

  static void _showTopBanner(BuildContext context, String message) {
    // Prefer the app-standard GT top overlay notification.
    // If we can't access an Overlay (rare), fall back to a MaterialBanner.
    try {
      final overlay = Overlay.maybeOf(context, rootOverlay: true);
      if (overlay != null) {
        GTNotificationService.showError(context, message, overlay: overlay);
        return;
      }
    } catch (_) {
      // Fall through to banner fallback.
    }

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    messenger.hideCurrentMaterialBanner();
    messenger.showMaterialBanner(
      MaterialBanner(
        backgroundColor: colors.errorContainer,
        leading: Icon(Icons.error_outline, color: colors.onErrorContainer),
        content: Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onErrorContainer,
          ),
        ),
        actions: [
          TextButton(
            onPressed: messenger.hideCurrentMaterialBanner,
            style: TextButton.styleFrom(
              foregroundColor: colors.onErrorContainer,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
