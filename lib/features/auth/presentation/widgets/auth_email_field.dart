import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../utils/email_input.dart';

/// Email field for the auth forms, with autofill and an optional
/// "Did you mean …?" suggestion for a misspelled domain.
///
/// The address is never changed silently: the suggestion only appears once
/// the user leaves the field (or [revealSuggestion] is set, e.g. after a
/// submit attempt), and only tapping it replaces the text.
class AuthEmailField extends StatefulWidget {
  const AuthEmailField({
    super.key,
    required this.controller,
    required this.focusNode,
    this.onFieldSubmitted,
    this.onChanged,
    this.revealSuggestion = false,
    this.enabled = true,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;
  final bool revealSuggestion;
  final bool enabled;

  @override
  State<AuthEmailField> createState() => _AuthEmailFieldState();
}

class _AuthEmailFieldState extends State<AuthEmailField> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_refresh);
    widget.controller.addListener(_refresh);
  }

  @override
  void didUpdateWidget(AuthEmailField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_refresh);
      widget.focusNode.addListener(_refresh);
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_refresh);
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _accept(String suggestion) {
    widget.controller.value = TextEditingValue(
      text: suggestion,
      selection: TextSelection.collapsed(offset: suggestion.length),
    );
    widget.onChanged?.call(suggestion);
  }

  @override
  Widget build(BuildContext context) {
    final suggestion = EmailInput.suggestCorrection(widget.controller.text);
    final showSuggestion =
        suggestion != null &&
        (!widget.focusNode.hasFocus || widget.revealSuggestion);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          enabled: widget.enabled,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(
            labelText: 'Email',
            hintText: 'you@example.com',
            prefixIcon: Icon(Icons.email_outlined),
          ),
          validator: EmailInput.validate,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onFieldSubmitted,
        ),
        if (showSuggestion)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: widget.enabled ? () => _accept(suggestion) : null,
              icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
              label: Text('Did you mean $suggestion?'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
          ),
      ],
    );
  }
}
