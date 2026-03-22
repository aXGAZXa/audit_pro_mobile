// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

String? getReferrer() {
  final ref = html.document.referrer;
  return ref.trim().isEmpty ? null : ref.trim();
}

String? getLocalStorage(String key) {
  try {
    return html.window.localStorage[key];
  } catch (_) {
    return null;
  }
}

void setLocalStorage(String key, String value) {
  try {
    html.window.localStorage[key] = value;
  } catch (_) {
    // ignore
  }
}

bool _isInIFrame() {
  try {
    return html.window.parent != null && html.window.parent != html.window;
  } catch (_) {
    return false;
  }
}

void notifyParentComplete({required String ticket, String? returnUrl}) {
  if (!_isInIFrame()) return;
  try {
    final message = {
      'type': 'editor-complete',
      'ticket': ticket,
      'returnUrl': returnUrl,
    };
    html.window.parent!.postMessage(jsonEncode(message), '*');
  } catch (_) {
    // ignore
  }
}

void notifyParentError({required String ticket, required String message}) {
  if (!_isInIFrame()) return;
  try {
    final payload = {
      'type': 'editor-error',
      'ticket': ticket,
      'message': message,
    };
    html.window.parent!.postMessage(jsonEncode(payload), '*');
  } catch (_) {
    // ignore
  }
}

void returnToCaller(
  String returnUrl, {
  required String ticket,
  bool preferClose = true,
  bool openInNewTab = false,
}) {
  // If embedded (future iframe scenario), ask the parent to handle navigation.
  notifyParentComplete(ticket: ticket, returnUrl: returnUrl);

  if (_isInIFrame()) {
    // Try to navigate the top-level window when allowed (same-origin).
    try {
      final top = html.window.top;
      if (top != null) {
        top.location.href = returnUrl;
        return;
      }
      return;
    } catch (_) {
      // Cross-origin iframe; parent must handle via postMessage.
      return;
    }
  }

  if (openInNewTab) {
    try {
      html.window.open(returnUrl, '_blank');
      return;
    } catch (_) {
      // fallback below
    }
  }

  if (preferClose) {
    // Only works if tab was opened by script.
    try {
      html.window.close();
    } catch (_) {
      // ignore
    }
  }

  html.window.location.href = returnUrl;
}
