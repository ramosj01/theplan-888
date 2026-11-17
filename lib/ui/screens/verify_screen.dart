import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../services/auth/auth_service.dart';
import '../../services/backend.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';

class VerifyScreen extends StatefulWidget {
  final String email;
  const VerifyScreen({super.key, required this.email});

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  final _code = TextEditingController();
  final _focus = FocusNode();
  bool _loading = false;
  String? _error;
  int _cooldown = AppConfig.resendCooldown.inSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = AppConfig.resendCooldown.inSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_cooldown <= 1) t.cancel();
      if (mounted) setState(() => _cooldown--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_code.text.length != AppConfig.codeLength || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<Backend>().auth.verifyCode(widget.email, _code.text);
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
    } on AuthException catch (e) {
      HapticFeedback.mediumImpact();
      setState(() {
        _error = e.message;
        _code.clear();
      });
      _focus.requestFocus();
    } catch (_) {
      setState(() => _error = 'Verification failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    try {
      await context.read<Backend>().auth.sendCode(widget.email);
      _startCooldown();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('A new code is on its way to ${widget.email}')),
      );
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final demoCode = context.read<Backend>().auth.debugLastCode(widget.email);
    return Scaffold(
      body: GlossyBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GlassIconButton(
                      icon: Icons.arrow_back_rounded,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  const SizedBox(height: 36),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        gradient: AppColors.accentWarm,
                        boxShadow: [
                          BoxShadow(color: AppColors.pink.withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 8))
                        ],
                      ),
                      child: const Icon(Icons.mark_email_unread_rounded, color: Colors.white, size: 34),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('Check your inbox', style: t.headlineMedium),
                  const SizedBox(height: 8),
                  Text.rich(
                    TextSpan(children: [
                      const TextSpan(text: 'Enter the 6-digit code we sent to\n'),
                      TextSpan(
                        text: widget.email,
                        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                      ),
                    ]),
                    style: t.bodyMedium,
                  ),
                  if (demoCode != null) ...[
                    const SizedBox(height: 20),
                    GlassCard(
                      padding: const EdgeInsets.all(14),
                      onTap: () {
                        _code.text = demoCode;
                        setState(() {});
                        _verify();
                      },
                      child: Row(children: [
                        const Icon(Icons.science_rounded, color: AppColors.amber),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text.rich(TextSpan(children: [
                            const TextSpan(text: 'Demo inbox: your code is  '),
                            TextSpan(
                              text: demoCode,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, letterSpacing: 3, color: AppColors.amber),
                            ),
                          ])),
                        ),
                        const Text('Tap to use', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 28),
                  _CodeInput(
                    controller: _code,
                    focusNode: _focus,
                    hasError: _error != null,
                    onChanged: (v) {
                      if (_error != null) setState(() => _error = null);
                      setState(() {});
                      if (v.length == AppConfig.codeLength) _verify();
                    },
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    child: _error == null
                        ? const SizedBox(height: 0)
                        : Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 18),
                                const SizedBox(width: 8),
                                Flexible(child: Text(_error!, style: const TextStyle(color: AppColors.danger))),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 28),
                  GlossyButton(
                    label: 'Verify & continue',
                    icon: Icons.verified_rounded,
                    loading: _loading,
                    onPressed: _code.text.length == AppConfig.codeLength ? _verify : null,
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: TextButton.icon(
                      onPressed: _cooldown > 0 ? null : _resend,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(_cooldown > 0 ? 'Resend code in ${_cooldown}s' : 'Resend code'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.cyan,
                        disabledForegroundColor: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const Center(
                    child: Text(
                      "Didn't get it? Check your spam folder.",
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Six glossy digit boxes driven by a single hidden text field (so paste and
/// SMS/email autofill work naturally).
class _CodeInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final bool hasError;

  const _CodeInput({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.hasError,
  });

  @override
  Widget build(BuildContext context) {
    final text = controller.text;
    return GestureDetector(
      onTap: () => focusNode.requestFocus(),
      child: Stack(
        children: [
          Opacity(
            opacity: 0,
            child: SizedBox(
              height: 64,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                maxLength: AppConfig.codeLength,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: onChanged,
                showCursor: false,
                enableInteractiveSelection: false,
              ),
            ),
          ),
          IgnorePointer(
            child: ListenableBuilder(
              listenable: focusNode,
              builder: (context, _) => Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(AppConfig.codeLength, (i) {
                  final filled = i < text.length;
                  final active = focusNode.hasFocus && i == text.length.clamp(0, AppConfig.codeLength - 1);
                  final borderColor = hasError
                      ? AppColors.danger
                      : active
                          ? AppColors.cyan
                          : Colors.white.withValues(alpha: filled ? 0.35 : 0.16);
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 50,
                    height: 62,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: filled ? 0.18 : 0.10),
                          Colors.white.withValues(alpha: 0.03),
                        ],
                      ),
                      border: Border.all(color: borderColor, width: active ? 2 : 1.2),
                      boxShadow: active
                          ? [BoxShadow(color: AppColors.cyan.withValues(alpha: 0.35), blurRadius: 16)]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      filled ? text[i] : '',
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
