import 'package:flutter/material.dart';

import '../../core/config.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';
import 'email_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

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
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
                children: [
                  const Center(child: AppLogo(size: 104)),
                  const SizedBox(height: 32),
                  Center(child: GradientText(AppConfig.appName, style: t.headlineLarge)),
                  const SizedBox(height: 10),
                  Text(
                    'Private conversations that travel directly\nbetween you and the people you trust.',
                    textAlign: TextAlign.center,
                    style: t.bodyMedium?.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 36),
                  const _Feature(
                    icon: Icons.enhanced_encryption_rounded,
                    title: 'End-to-end encrypted',
                    body: 'X25519 key agreement and AES-256-GCM. Keys never leave your device.',
                  ),
                  const SizedBox(height: 12),
                  const _Feature(
                    icon: Icons.hub_rounded,
                    title: 'Truly peer-to-peer',
                    body: 'Messages flow over a direct WebRTC link - no server stores them.',
                  ),
                  const SizedBox(height: 12),
                  const _Feature(
                    icon: Icons.mark_email_read_rounded,
                    title: 'Passwordless sign-in',
                    body: 'Register with any email. A one-time code verifies it\'s really you.',
                  ),
                  const SizedBox(height: 36),
                  GlossyButton(
                    label: 'Get started',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => const EmailScreen())),
                  ),
                  const SizedBox(height: 16),
                  if (AppConfig.demoMode)
                    const Center(
                      child: StatusPill(
                        label: 'Demo mode - no backend configured',
                        icon: Icons.science_rounded,
                        color: AppColors.amber,
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

class _Feature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _Feature({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: AppColors.accent,
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 3),
                Text(body, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
