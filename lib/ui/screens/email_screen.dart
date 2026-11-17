import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../services/auth/auth_service.dart';
import '../../services/backend.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';
import 'verify_screen.dart';

class EmailScreen extends StatefulWidget {
  const EmailScreen({super.key});

  @override
  State<EmailScreen> createState() => _EmailScreenState();
}

class _EmailScreenState extends State<EmailScreen> {
  final _email = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (!isValidEmail(email)) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<Backend>().auth.sendCode(email);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => VerifyScreen(email: email)));
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Could not send the code. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
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
                  _IconBadge(icon: Icons.alternate_email_rounded),
                  const SizedBox(height: 24),
                  Text("What's your email?", style: t.headlineMedium),
                  const SizedBox(height: 8),
                  Text(
                    "We'll send a 6-digit verification code to confirm it's yours. "
                    'Any email provider works - Gmail, Outlook, iCloud, your company mail...',
                    style: t.bodyMedium,
                  ),
                  const SizedBox(height: 28),
                  AutofillGroup(
                    child: GlassTextField(
                      controller: _email,
                      hint: 'you@example.com',
                      icon: Icons.mail_rounded,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.send,
                      autofillHints: const [AutofillHints.email],
                      autofocus: true,
                      onSubmitted: (_) => _submit(),
                      onChanged: (_) {
                        if (_error != null) setState(() => _error = null);
                      },
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    child: _error == null
                        ? const SizedBox(height: 0)
                        : Padding(
                            padding: const EdgeInsets.only(top: 12, left: 6),
                            child: Row(children: [
                              const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
                              ),
                            ]),
                          ),
                  ),
                  const SizedBox(height: 28),
                  GlossyButton(
                    label: 'Send verification code',
                    icon: Icons.send_rounded,
                    loading: _loading,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.shield_moon_rounded, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        AppConfig.demoMode
                            ? 'Demo mode: the code will be shown on screen'
                            : 'New here? Your account is created automatically.',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
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

class _IconBadge extends StatelessWidget {
  final IconData icon;
  const _IconBadge({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: AppColors.accent,
          boxShadow: [BoxShadow(color: AppColors.cyan.withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: Icon(icon, color: Colors.white, size: 34),
      ),
    );
  }
}
