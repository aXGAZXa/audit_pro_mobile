import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audit_pro_mobile/apm/database/database_helper.dart';

class AppAutocompleteField extends StatefulWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final String fieldName;
  final Map<String, String> Function()? filterContext;
  final Function(String)? onChanged;
  final String? Function(String?)? validator;
  final int minCharsForSuggestions;
  final bool enabled;
  final int maxLines;

  const AppAutocompleteField({
    super.key,
    required this.label,
    this.hint,
    required this.controller,
    required this.fieldName,
    this.filterContext,
    this.onChanged,
    this.validator,
    this.minCharsForSuggestions = 3,
    this.enabled = true,
    this.maxLines = 1,
  });

  @override
  State<AppAutocompleteField> createState() => AppAutocompleteFieldState();
}

class AppAutocompleteFieldState extends State<AppAutocompleteField> {
  List<String> _suggestions = [];
  Timer? _debounce;
  final FocusNode _focusNode = FocusNode();
  OverlayEntry? _overlayEntry;
  bool _isSelectingSuggestion = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    widget.controller.removeListener(_onTextChanged);
    _removeOverlay();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      _hideOverlay();
    }
  }

  void _onTextChanged() {
    // Don't load suggestions if we're programmatically setting the text
    if (_isSelectingSuggestion) return;

    final query = widget.controller.text;

    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (query.length >= widget.minCharsForSuggestions) {
      _debounce = Timer(const Duration(milliseconds: 300), () {
        _loadSuggestions(query);
      });
    } else {
      _hideOverlay();
    }
  }

  Future<void> _loadSuggestions(String query) async {
    final db = DatabaseHelper.instance;
    final filterContext = widget.filterContext?.call();

    final suggestions = await db.getSuggestions(
      fieldName: widget.fieldName,
      query: query,
      filterContext: filterContext,
    );

    if (mounted) {
      setState(() {
        _suggestions = suggestions;
      });

      if (suggestions.isNotEmpty) {
        _showOverlay();
      } else {
        _hideOverlay();
      }
    }
  }

  void _showOverlay() {
    _removeOverlay();

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: offset.dx,
        top: offset.dy + size.height,
        width: size.width,
        child: Material(
          elevation: 4,
          shadowColor: Colors.black.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                return InkWell(
                  onTap: () => _selectSuggestion(suggestion),
                  onLongPress: () => _confirmDeleteSuggestion(suggestion),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Text(
                      suggestion,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _removeOverlay();
    setState(() {
      _suggestions = [];
    });
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _selectSuggestion(String value) {
    _isSelectingSuggestion = true;
    widget.controller.text = value;
    _isSelectingSuggestion = false;
    _hideOverlay();
    widget.onChanged?.call(value);
  }

  Future<void> _confirmDeleteSuggestion(String value) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Suggestion'),
        content: Text('Remove "$value" from suggestions?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteSuggestion(value);
    }
  }

  Future<void> _deleteSuggestion(String value) async {
    final db = DatabaseHelper.instance;
    final filterContext = widget.filterContext?.call();

    await db.deleteSuggestion(
      fieldName: widget.fieldName,
      value: value,
      filterContext: filterContext,
    );

    // Refresh suggestions
    final query = widget.controller.text;
    if (query.length >= widget.minCharsForSuggestions) {
      await _loadSuggestions(query);
    }
  }

  /// Save current field value as a suggestion
  /// Call this when the form is saved to persist valid suggestions
  Future<void> saveSuggestion() async {
    final value = widget.controller.text.trim();
    if (value.isEmpty) return;

    final db = DatabaseHelper.instance;
    final filterContext = widget.filterContext?.call();

    await db.saveSuggestion(
      fieldName: widget.fieldName,
      value: value,
      filterContext: filterContext,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        enabled: widget.enabled,
        maxLines: widget.maxLines,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
        ),
        validator: widget.validator,
        onChanged: (value) {
          widget.onChanged?.call(value);
        },
      ),
    );
  }
}
