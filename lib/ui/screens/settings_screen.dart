import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../state/chat_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar.dart';
import '../widgets/glass.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ChatController>();
    return Scaffold(
      body: GlossyBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
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
                  const SizedBox(height: 20),
                  GlassCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        GlossyAvatar(name: c.user.name, seed: c.user.id, size: 96),
                        const SizedBox(height: 16),
                        Text(c.user.name, style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 4),
                        Text(c.user.email, style: const TextStyle(color: AppColors.textSecondary)),
                        const SizedBox(height: 12),
                        const StatusPill(label: 'Email verified', icon: Icons.verified_rounded, color: AppColors.mint),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder(
                    future: c.myFingerprint(),
                    builder: (context, s) => _Tile(
                      icon: Icons.fingerprint_rounded,
                      title: 'Identity key fingerprint',
                      subtitle: s.data ?? '...',
                      mono: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const _Tile(
                    icon: Icons.enhanced_encryption_rounded,
                    title: 'Encryption',
                    subtitle: 'X25519 key agreement · HKDF-SHA256 · AES-256-GCM',
                  ),
                  const SizedBox(height: 10),
                  _Tile(
                    icon: Icons.hub_rounded,
                    title: 'Transport',
                    subtitle: c.backend.demo
                        ? 'Demo mode · in-memory peer link'
                        : 'WebRTC data channel (direct peer-to-peer)',
                  ),
                  const SizedBox(height: 10),
                  const _Tile(
                    icon: Icons.storage_rounded,
                    title: 'Local history',
                    subtitle: 'Stored on this device only, encrypted at rest',
                  ),
                  const SizedBox(height: 28),
                  GlossyButton(
                    label: 'Sign out',
                    icon: Icons.logout_rounded,
                    gradient: const LinearGradient(colors: [AppColors.danger, AppColors.pink]),
                    onPressed: () async {
                      Navigator.of(context).popUntil((r) => r.isFirst);
                      await c.backend.auth.signOut();
                    },
                  ),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text('${AppConfig.appName} 1.0.0',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
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

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool mono;
  const _Tile({required this.icon, required this.title, required this.subtitle, this.mono = false});

  @override
  Widget build(BuildContext context) => GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), gradient: AppColors.accent),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                        fontFamily: mono ? 'monospace' : null,
                      )),
                ],
              ),
            ),
          ],
        ),
      );
}
