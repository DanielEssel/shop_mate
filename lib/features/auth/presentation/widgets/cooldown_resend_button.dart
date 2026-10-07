import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/entities/auth_failure.dart';
import '../utils/email_input.dart';

/// A "send the email again" button with its own feedback and a cooldown.
///
/// After a successful send it stays disabled for [cooldown], showing the
/// seconds left, so the email endpoint can't be hammered. The timer lives in
/// this widget and ends with it.
class CooldownResendButton extends StatefulWidget {
  const CooldownResendButton({
    super.key,
    required this.label,
    required this.email,
    required this.onSend,
    required this.sentMessage,
    this.cooldown = defaultCooldown,
  });

  static const defaultCooldown = Duration(seconds: 60);

  final String label;

  /// Read when the button is pressed, so it always uses the current address.
  final ValueGetter<String> email;

  /// Sends the email; throws [AuthFailure] on failure.
  final Future<void> Function(String email) onSend;

  final String Function(String email) sentMessage;
  final Duration cooldown;

  @override
  State<CooldownResendButton> createState() => _CooldownResendButtonState();
}

class _CooldownResendButtonState extends State<CooldownResendButton> {
  Timer? _timer;
  int _secondsLeft = 0;
  bool _isSending = false;
  String? _feedback;
  bool _feedbackIsError = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _send() async {
    if (_isSending || _secondsLeft > 0) return;

    final email = widget.email().trim();
    if (!EmailInput.isValid(email)) {
      _showFeedback(AuthFailureKind.invalidEmail.message, isError: true);
      return;
    }

    setState(() {
      _isSending = true;
      _feedback = null;
    });

    try {
      await widget.onSend(email);
      if (!mounted) return;
      _startCooldown();
      _showFeedback(widget.sentMessage(email), isError: false);
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      _showFeedback(failure.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showFeedback(AuthFailureKind.unknown.message, isError: true);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _secondsLeft = widget.cooldown.inSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) timer.cancel();
    });
  }

  void _showFeedback(String message, {required bool isError}) {
    setState(() {
      _feedback = message;
      _feedbackIsError = isError;
    });
  }

  @override
  Widget build(BuildContext context) {
    final coolingDown = _secondsLeft > 0;
    final label = _isSending
        ? 'Sending…'
        : coolingDown
        ? 'Resend available in ${_secondsLeft}s'
        : widget.label;
    final feedback = _feedback;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: _isSending || coolingDown ? null : _send,
          icon: _isSending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.forward_to_inbox_rounded, size: 18),
          label: Text(label),
        ),
        if (feedback != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Semantics(
              liveRegion: true,
              child: Text(
                feedback,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _feedbackIsError ? AppColors.error : AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
