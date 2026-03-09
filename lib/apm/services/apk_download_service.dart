import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../app/app_config.dart';

class ApkDownloadResult {
  const ApkDownloadResult({required this.localPath, required this.downloadUrl});

  final String localPath;
  final String downloadUrl;
}

class ApkDownloadService {
  ApkDownloadService({http.Client? httpClient})
    : httpClient = httpClient ?? http.Client();

  final http.Client httpClient;

  Future<ApkDownloadResult> downloadApk({
    required String downloadUrl,
    String? versionName,
    int? versionCode,
    void Function(int received, int total)? onProgress,
  }) async {
    final resolvedUrl = _resolveUrl(downloadUrl);
    final uri = Uri.parse(resolvedUrl);

    final tempDir = await getTemporaryDirectory();
    final fileName = _buildFileName(versionName, versionCode);
    final localPath = p.join(tempDir.path, fileName);

    final req = http.Request('GET', uri);
    final res = await httpClient.send(req);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final body = await res.stream.bytesToString();
      throw HttpException(
        'Download failed (status=${res.statusCode}): ${body.trim().isEmpty ? 'Request failed' : body.trim()}',
        uri: uri,
      );
    }

    final contentType = (res.headers['content-type'] ?? '').toLowerCase();
    final looksLikeText =
        contentType.contains('text/') ||
        contentType.contains('application/json');
    final looksLikeApkContentType =
        contentType.contains('application/vnd.android.package-archive') ||
        contentType.contains('application/octet-stream') ||
        contentType.contains('application/zip');

    // Some proxies/CDNs return a 200 HTML error page for blocked/expired links.
    // If it doesn't look like an APK, read and fail early (avoid writing junk to disk).
    if (looksLikeText && !looksLikeApkContentType) {
      final body = await res.stream.bytesToString();
      final snippet = body.trim().replaceAll(RegExp(r'\s+'), ' ');
      throw HttpException(
        'Download failed (unexpected content-type=$contentType): '
        '${snippet.isEmpty ? 'Response was not an APK' : snippet.substring(0, snippet.length > 240 ? 240 : snippet.length)}',
        uri: uri,
      );
    }

    final total = res.contentLength ?? -1;
    var received = 0;

    final file = File(localPath);
    final sink = file.openWrite();

    try {
      await for (final chunk in res.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (onProgress != null && total > 0) {
          onProgress(received, total);
        }
      }
    } catch (_) {
      try {
        await sink.close();
      } catch (_) {}
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
      rethrow;
    }

    await sink.flush();
    await sink.close();

    if (total > 0 && received != total) {
      try {
        await file.delete();
      } catch (_) {}
      throw FileSystemException(
        'Downloaded APK is incomplete (received $received of $total bytes)',
      );
    }

    final size = await file.length();
    if (size <= 0) {
      try {
        await file.delete();
      } catch (_) {}
      throw const FileSystemException('Downloaded APK is empty');
    }

    // APKs are ZIP files; they should start with "PK".
    try {
      final raf = await file.open(mode: FileMode.read);
      final header = await raf.read(4);
      await raf.close();

      final isZip =
          header.length >= 2 && header[0] == 0x50 && header[1] == 0x4B;
      if (!isZip) {
        try {
          final previewBytes = await file
              .openRead(0, 256)
              .fold<List<int>>(<int>[], (acc, chunk) => acc..addAll(chunk));
          final previewText = String.fromCharCodes(
            previewBytes,
          ).replaceAll(RegExp(r'\s+'), ' ').trim();
          throw FileSystemException(
            'Downloaded file is not a valid APK (missing ZIP header). '
            'content-type=$contentType preview='
            '${previewText.isEmpty ? '(binary)' : previewText.substring(0, previewText.length > 200 ? 200 : previewText.length)}',
          );
        } catch (_) {
          throw FileSystemException(
            'Downloaded file is not a valid APK (missing ZIP header). content-type=$contentType',
          );
        }
      }
    } catch (_) {
      // If validation fails for any reason, treat it as an invalid download.
      rethrow;
    }

    return ApkDownloadResult(localPath: localPath, downloadUrl: resolvedUrl);
  }

  String _resolveUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;

    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasScheme) {
      return trimmed;
    }

    final base = AppConfig.apiBaseUrl.trim();
    if (base.isEmpty) return trimmed;

    final baseUri = Uri.parse(base.endsWith('/') ? base : '$base/');
    final resolved = baseUri.resolve(
      trimmed.startsWith('/') ? trimmed.substring(1) : trimmed,
    );
    return resolved.toString();
  }

  String _buildFileName(String? versionName, int? versionCode) {
    final safeName = (versionName ?? 'update').replaceAll(
      RegExp(r'[^a-zA-Z0-9._+-]'),
      '_',
    );
    final safeCode = versionCode == null ? '' : '_$versionCode';
    return 'audit_pro_mobile_$safeName$safeCode.apk';
  }

  Future<void> deleteLocalApk(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Best-effort.
    }
  }
}
