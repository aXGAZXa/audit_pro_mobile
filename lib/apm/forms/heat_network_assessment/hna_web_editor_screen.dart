import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:convert';

import '../../services/portal_api_client.dart';
import 'hna_web_editor_form_screen.dart';
import 'services/hna_web_editor_service.dart';
import 'services/web_editor_return.dart';

class HnaWebEditorScreen extends StatefulWidget {
  const HnaWebEditorScreen({super.key, required this.ticket, this.returnUrl});

  final String ticket;
  final String? returnUrl;

  @override
  State<HnaWebEditorScreen> createState() => _HnaWebEditorScreenState();
}

class _HnaWebEditorScreenState extends State<HnaWebEditorScreen> {
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _session;
  Map<String, dynamic>? _submission;
  List<String>? _clients;

  late final HnaWebEditorService _service;
  String? _returnUrl;

  @override
  void initState() {
    super.initState();
    final baseUrl = kIsWeb ? Uri.base.origin : '';
    _service = HnaWebEditorService(
      apiClient: PortalApiClient(baseUrl: baseUrl),
    );

    _returnUrl = _resolveReturnUrl();
    if (kIsWeb && _returnUrl != null) {
      WebEditorReturn.setLocalStorage(
        _returnStorageKey(widget.ticket),
        _returnUrl!,
      );
    }

    _load();
  }

  String _returnStorageKey(String ticket) => 'hnaEditor:returnUrl:$ticket';

  String? _resolveReturnUrl() {
    final fromParam = widget.returnUrl?.trim();
    if (fromParam != null &&
        fromParam.isNotEmpty &&
        _isAllowedReturnUrl(fromParam)) {
      return fromParam;
    }

    if (kIsWeb) {
      final stored = WebEditorReturn.getLocalStorage(
        _returnStorageKey(widget.ticket),
      );
      if (stored != null &&
          stored.trim().isNotEmpty &&
          _isAllowedReturnUrl(stored)) {
        return stored.trim();
      }

      final referrer = WebEditorReturn.getReferrer();
      if (referrer != null && _isAllowedReturnUrl(referrer)) {
        return referrer;
      }
    }

    return null;
  }

  bool _isAllowedReturnUrl(String url) {
    try {
      final uri = Uri.parse(url);

      // Allow relative navigation.
      if (!uri.hasScheme && url.startsWith('/')) return true;

      if (uri.scheme != 'http' && uri.scheme != 'https') return false;

      final host = uri.host.toLowerCase();
      if (host == 'localhost' || host == '127.0.0.1') return true;

      // Allow our production domains.
      if (host.endsWith('.audit-pro.co.uk') || host == 'audit-pro.co.uk') {
        return true;
      }

      // As a fallback, allow same-origin.
      final origin = Uri.base.origin;
      return uri.origin == origin;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final session = await _service.getSession(ticket: widget.ticket);
      final submission = await _service.getSubmission(ticket: widget.ticket);
      final clients = await _service.getClients(ticket: widget.ticket);

      final payloadJson =
          (submission['payloadJson'] ?? submission['PayloadJson'] ?? '')
              .toString()
              .trim();
      if (payloadJson.isEmpty) {
        throw PortalApiException('Submission payload is empty.');
      }

      final decoded = jsonDecode(payloadJson);
      if (decoded is! Map) {
        throw PortalApiException('Submission payload is not a JSON object.');
      }
      final payload = Map<String, dynamic>.from(decoded);

      final hnaRaw = payload['hna'];
      final hna = hnaRaw is Map
          ? Map<String, dynamic>.from(hnaRaw)
          : <String, dynamic>{};
      final formDataRaw = hna['formData'];
      final formData = formDataRaw is Map
          ? Map<String, dynamic>.from(formDataRaw)
          : <String, dynamic>{};

      final submissionId =
          (submission['submissionId'] ?? submission['SubmissionId'] ?? '')
              .toString()
              .trim();
      final schemaVersionRaw =
          (submission['schemaVersion'] ?? submission['SchemaVersion']);
      final schemaVersion = schemaVersionRaw is int
          ? schemaVersionRaw
          : int.tryParse(schemaVersionRaw?.toString() ?? '');
      final submittedAtRaw =
          (submission['submittedAtUtc'] ?? submission['SubmittedAtUtc'] ?? '')
              .toString()
              .trim();
      final submittedAtUtc = DateTime.tryParse(submittedAtRaw);

      if (!mounted) return;

      setState(() {
        _session = session;
        _submission = submission;
        _clients = clients;
        _loading = false;
      });

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          settings: const RouteSettings(name: '/hna'),
          builder: (_) => HnaWebEditorFormScreen(
            ticket: widget.ticket,
            submissionId: submissionId,
            submittedAtUtc: submittedAtUtc,
            schemaVersion: schemaVersion,
            originalPayload: payload,
            initialFormData: formData,
            clients: clients,
            service: _service,
            returnUrl: _returnUrl,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _MetaRow(session: _session, submission: _submission),
                ],
              ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.session, required this.submission});

  final Map<String, dynamic>? session;
  final Map<String, dynamic>? submission;

  String _readString(Map<String, dynamic>? map, String key) {
    if (map == null) return '';
    final v = map[key] ?? map[_pascal(key)];
    return v?.toString() ?? '';
  }

  String _pascal(String key) {
    if (key.isEmpty) return key;
    return key[0].toUpperCase() + key.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final submissionId = _readString(submission, 'submissionId');
    final schemaVersion = _readString(submission, 'schemaVersion');
    final submittedAtUtc = _readString(submission, 'submittedAtUtc');
    final expiresAtUtc = _readString(session, 'expiresAtUtc');

    final parts = <String>[
      if (submissionId.isNotEmpty) 'Submission: $submissionId',
      if (schemaVersion.isNotEmpty) 'Schema: $schemaVersion',
      if (submittedAtUtc.isNotEmpty) 'Submitted: $submittedAtUtc',
      if (expiresAtUtc.isNotEmpty) 'Ticket expires: $expiresAtUtc',
    ];

    if (parts.isEmpty) return const SizedBox.shrink();

    return Text(
      parts.join(' • '),
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}
