import 'web_editor_return_stub.dart'
    if (dart.library.html) 'web_editor_return_web.dart'
    as impl;

/// Minimal browser helpers for the ticket-launched web editor.
///
/// This uses a conditional import so mobile builds never import `dart:html`.
class WebEditorReturn {
  static String? getReferrer() => impl.getReferrer();

  static String? getLocalStorage(String key) => impl.getLocalStorage(key);

  static void setLocalStorage(String key, String value) =>
      impl.setLocalStorage(key, value);

  static void notifyParentComplete({
    required String ticket,
    String? returnUrl,
  }) => impl.notifyParentComplete(ticket: ticket, returnUrl: returnUrl);

  static void notifyParentError({
    required String ticket,
    required String message,
  }) => impl.notifyParentError(ticket: ticket, message: message);

  /// Attempts to return to the caller.
  ///
  /// - If inside an iframe, prefers notifying parent (via postMessage) and
  ///   then trying top-level navigation (if allowed).
  /// - If not in an iframe, optionally tries to close the tab first.
  static void returnToCaller(
    String returnUrl, {
    required String ticket,
    bool preferClose = true,
    bool openInNewTab = false,
  }) {
    impl.returnToCaller(
      returnUrl,
      ticket: ticket,
      preferClose: preferClose,
      openInNewTab: openInNewTab,
    );
  }
}
