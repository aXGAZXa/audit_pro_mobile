String? getReferrer() => null;

String? getLocalStorage(String key) => null;

void setLocalStorage(String key, String value) {}

void notifyParentComplete({required String ticket, String? returnUrl}) {}

void returnToCaller(
  String returnUrl, {
  required String ticket,
  bool preferClose = true,
  bool openInNewTab = false,
}) {}
