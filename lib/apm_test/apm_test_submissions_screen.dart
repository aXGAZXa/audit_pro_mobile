import 'dart:convert';

import 'package:flutter/material.dart';

import '../auth/auth_session.dart';
import 'apm_test_forms_api.dart';
import 'apm_test_models.dart';

class ApmTestSubmissionsScreen extends StatefulWidget {
  const ApmTestSubmissionsScreen({super.key, required this.session});

  final AuthSession session;

  @override
  State<ApmTestSubmissionsScreen> createState() =>
      _ApmTestSubmissionsScreenState();
}

class _ApmTestSubmissionsScreenState extends State<ApmTestSubmissionsScreen> {
  final _api = ApmTestFormsApi();

  bool _busy = true;
  String _status = '';
  List<ApmTestFormSubmission> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = widget.session.state.value;
    if (auth == null) {
      setState(() {
        _busy = false;
        _status = 'Not signed in.';
        _items = const [];
      });
      return;
    }

    setState(() {
      _busy = true;
      _status = 'Loading…';
    });

    try {
      final result = await _api.listSubmissions(token: auth.token, take: 200);
      if (!mounted) return;

      if (!result.success) {
        setState(() {
          _status = result.message.isEmpty ? 'Load failed' : result.message;
          _items = const [];
        });
        return;
      }

      setState(() {
        _items = result.data ?? const [];
        _status = _items.isEmpty ? 'No submissions yet.' : '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'Error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('APM Test Submissions'),
        actions: [
          IconButton(
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? Center(child: Text(_status))
          : ListView.separated(
              itemCount: _items.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = _items[index];
                return ListTile(
                  title: Text(item.formKey),
                  subtitle: Text(
                    'Rev ${item.revision} • ${item.submittedByEmail}\n${item.submittedAtUtc.toLocal()}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => _SubmissionJsonScreen(submission: item),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _SubmissionJsonScreen extends StatelessWidget {
  const _SubmissionJsonScreen({required this.submission});

  final ApmTestFormSubmission submission;

  @override
  Widget build(BuildContext context) {
    String pretty;
    try {
      final decoded = jsonDecode(submission.payloadJson);
      pretty = const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      pretty = submission.payloadJson;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Submission Payload')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(child: SelectableText(pretty)),
      ),
    );
  }
}
