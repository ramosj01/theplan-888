import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../state/chat_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar.dart';
import '../widgets/glass.dart';

class SafetyNumberScreen extends StatelessWidget {
  final String peerId;
  const SafetyNumberScreen({super.key, required this.peerId});

  @override
  Widget build(BuildContext context) {
    final c = context.read<ChatController>();
    final peer = c.contact(peerId)!;
    final t = Theme.of(context).textTheme;

    return Scaffold(
      body: GlossyBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: FutureBuilder(
                future: Future.wait([c.safetyNumberWith(peerId), c.myFingerprint(), c.peerFingerprint(peerId)]),
                builder: (context, snap) {
                  final data = snap.data;
                  return ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: GlassIconButton(
                          icon: Icons.arrow_back_rounded,
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GlossyAvatar(name: c.user.name, seed: c.user.id, size: 72),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: ShaderMask(
                              shaderCallback: (r) => AppColors.accent.createShader(r),
                              child: const Icon(Icons.sync_lock_rounded, size: 40, color: Colors.white),
                            ),
                          ),
                          GlossyAvatar(name: peer.name, seed: peer.id, size: 72),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text('Verify safety number', style: t.headlineMedium, textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      Text(
                        'Compare these numbers with ${peer.name} in person or over a call. '
                        'If they match, nobody is intercepting your conversation.',
                        style: t.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      GlassCard(
                        child: data == null
                            ? const SizedBox(
                                height: 140,
                                child: Center(child: CircularProgressIndicator(color: AppColors.cyan)),
                              )
                            : Column(children: [
                                GridView.count(
                                  crossAxisCount: 4,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  childAspectRatio: 2.0,
                                  children: data[0]
                                      .split(' ')
                                      .map((g) => Center(
                                            child: Text(
                                              g,
                                              style: const TextStyle(
                                                fontFamily: 'monospace',
                                                fontSize: 19,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 1.5,
                                              ),
                                            ),
                                          ))
                                      .toList(),
                                ),
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: data[0]));
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(const SnackBar(content: Text('Safety number copied')));
                                  },
                                  icon: const Icon(Icons.copy_rounded, size: 18),
                                  label: const Text('Copy'),
                                  style: TextButton.styleFrom(foregroundColor: AppColors.cyan),
                                ),
                              ]),
                      ),
                      const SizedBox(height: 16),
                      if (data != null) ...[
                        _KeyRow(label: 'Your key', value: data[1]),
                        const SizedBox(height: 10),
                        _KeyRow(label: "${peer.name}'s key", value: data[2]),
                      ],
                      const SizedBox(height: 20),
                      const Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textSecondary),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Each session also uses fresh ephemeral keys, so past messages stay '
                              'private even if a device is later compromised.',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KeyRow extends StatelessWidget {
  final String label;
  final String value;
  const _KeyRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.key_rounded, color: AppColors.violet, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5)),
                ],
              ),
            ),
          ],
        ),
      );
}
