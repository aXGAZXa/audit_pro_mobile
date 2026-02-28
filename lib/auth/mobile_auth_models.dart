class ApiResult<T> {
  ApiResult({
    required this.success,
    required this.message,
    required this.data,
    required this.statusCode,
  });

  final bool success;
  final String message;
  final T? data;
  final int statusCode;

  static ApiResult<T> fromJson<T>(
    Map<String, dynamic> json, {
    T? Function(Object? dataJson)? parseData,
  }) {
    final success = json['success'] == true;
    final message = (json['message'] ?? '').toString();
    final statusCode = (json['statusCode'] is int)
        ? (json['statusCode'] as int)
        : int.tryParse((json['statusCode'] ?? '').toString()) ?? 0;

    T? data;
    if (parseData != null) {
      data = parseData(json['data']);
    }

    return ApiResult<T>(
      success: success,
      message: message,
      data: data,
      statusCode: statusCode,
    );
  }
}

class MobileTenantOption {
  MobileTenantOption({required this.tenantId, required this.tenantName});

  final String tenantId;
  final String tenantName;

  factory MobileTenantOption.fromJson(Map<String, dynamic> json) {
    return MobileTenantOption(
      tenantId: (json['tenantId'] ?? '').toString(),
      tenantName: (json['tenantName'] ?? '').toString(),
    );
  }
}

class ApiTenantSelectionRequired implements Exception {
  const ApiTenantSelectionRequired();
}

class PlatformAccessStatus {
  PlatformAccessStatus({
    required this.status,
    required this.platformJwt,
    required this.isAuthorised,
    required this.isDeviceBlocked,
    required this.lastRequestedAtUtc,
  });

  final String status;
  final String? platformJwt;
  final bool isAuthorised;
  final bool isDeviceBlocked;
  final DateTime? lastRequestedAtUtc;

  factory PlatformAccessStatus.fromJson(Map<String, dynamic> json) {
    final status = (json['status'] ?? '').toString();
    final platformJwt = (json['platformJwt'] ?? '').toString().trim();
    final isAuthorised = json['isAuthorised'] == true;
    final isDeviceBlocked = json['isDeviceBlocked'] == true;

    DateTime? lastRequestedAtUtc;
    final raw = (json['lastRequestedAtUtc'] ?? '').toString().trim();
    if (raw.isNotEmpty) {
      lastRequestedAtUtc = DateTime.tryParse(raw);
    }

    return PlatformAccessStatus(
      status: status,
      platformJwt: platformJwt.isEmpty ? null : platformJwt,
      isAuthorised: isAuthorised,
      isDeviceBlocked: isDeviceBlocked,
      lastRequestedAtUtc: lastRequestedAtUtc,
    );
  }
}
