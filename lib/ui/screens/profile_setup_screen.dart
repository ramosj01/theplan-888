import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/backend.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar.dart';
import '../widgets/glass.dart';

class ProfileSetupScreen extends StatefulWidget {
  final AppUser user;
  const ProfileSetupScreen({super.key, required this.user});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  late final _name = TextEditingController(text: widget.user.email.split('@').first);
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final n = _name.text.trim();
    if (n.isEmpty) return;
    setState(() => _loading = true);
    try {
      await context.read<Backend>().auth.updateDisplayName(n);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save: $e')));
        setState(() => _loading = false);
      }
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
                padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
                children: [
                  Center(
                    child: ValueListenableBuilder(
                      valueListenable: _name,
                      builder: (context, v, _) =>
                          GlossyAvatar(name: v.text.isEmpty ? '?' : v.text, seed: widget.user.id, size: 108),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Center(
                    child: StatusPill(
                      label: 'Email verified',
                      icon: Icons.verified_rounded,
                      color: AppColors.mint,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text('How should people\nsee you?', style: t.headlineMedium, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(
                    'Your name is shown to contacts you connect with.',
                    style: t.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  GlassTextField(
                    controller: _name,
                    hint: 'Display name',
                    icon: Icons.person_rounded,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _save(),
                  ),
                  const SizedBox(height: 28),
                  GlossyButton(label: 'Continue', icon: Icons.check_rounded, loading: _loading, onPressed: _save),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
