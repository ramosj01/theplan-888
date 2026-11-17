import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/auth/auth_service.dart';
import '../../state/chat_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar.dart';
import '../widgets/format.dart';
import '../widgets/glass.dart';
import 'chat_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openChat(BuildContext context, PeerProfile p) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<ChatController>(),
        child: ChatScreen(peerId: p.id),
      ),
    ));
  }

  Future<void> _newChat(BuildContext context) async {
    final controller = context.read<ChatController>();
    final peer = await showModalBottomSheet<PeerProfile>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ChangeNotifierProvider.value(value: controller, child: const _NewChatSheet()),
    );
    if (peer != null && context.mounted) _openChat(context, peer);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ChatController>();
    final q = _search.text.trim().toLowerCase();
    final contacts = c.sortedContacts
        .where((p) => q.isEmpty || p.name.toLowerCase().contains(q) || p.email.contains(q))
        .toList();

    return Scaffold(
      body: GlossyBackground(
        child: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Hi, ${c.user.name} 👋',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                              const SizedBox(height: 2),
                              GradientText('Chats', style: Theme.of(context).textTheme.headlineLarge),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => ChangeNotifierProvider.value(value: c, child: const SettingsScreen()),
                          )),
                          child: GlossyAvatar(name: c.user.name, seed: c.user.id, size: 48),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    child: GlassTextField(
                      controller: _search,
                      hint: 'Search conversations',
                      icon: Icons.search_rounded,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
                    child: Row(children: [
                      const StatusPill(
                        label: 'End-to-end encrypted',
                        icon: Icons.lock_rounded,
                        color: AppColors.mint,
                      ),
                      const SizedBox(width: 8),
                      StatusPill(
                        label: '${c.contacts.where((p) => c.online.contains(p.id)).length} online',
                        icon: Icons.circle,
                        color: AppColors.cyan,
                      ),
                    ]),
                  ),
                  Expanded(
                    child: contacts.isEmpty
                        ? _EmptyState(onNew: () => _newChat(context), searching: q.isNotEmpty)
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                            itemCount: contacts.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, i) => _ChatTile(
                              peer: contacts[i],
                              onTap: () => _openChat(context, contacts[i]),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: SizedBox(
        width: 168,
        child: GlossyButton(
          label: 'New chat',
          icon: Icons.add_comment_rounded,
          onPressed: () => _newChat(context),
        ),
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final PeerProfile peer;
  final VoidCallback onTap;
  const _ChatTile({required this.peer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ChatController>();
    final last = c.lastMessage(peer.id);
    final unread = c.unread[peer.id] ?? 0;
    final typing = c.typing.contains(peer.id);
    final link = c.linkState(peer.id);

    return Dismissible(
      key: ValueKey(peer.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Icon(Icons.delete_rounded, color: AppColors.danger),
      ),
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.bgMid,
          title: Text('Remove ${peer.name}?'),
          content: const Text('The conversation is deleted from this device.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove', style: TextStyle(color: AppColors.danger)),
            ),
          ],
        ),
      ),
      onDismissed: (_) => c.removeContact(peer.id),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        onTap: onTap,
        child: Row(
          children: [
            GlossyAvatar(name: peer.name, seed: peer.id, online: c.online.contains(peer.id)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(peer.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16.5)),
                    ),
                    if (link == LinkState.secure) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.lock_rounded, size: 14, color: AppColors.mint),
                    ],
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    typing
                        ? 'typing...'
                        : last == null
                            ? peer.email
                            : '${last.outgoing ? 'You: ' : ''}${last.text}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: typing ? AppColors.cyan : AppColors.textSecondary,
                      fontStyle: typing ? FontStyle.italic : FontStyle.normal,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  last == null ? '' : formatListTime(last.timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: unread > 0 ? AppColors.cyan : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                if (unread > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: AppColors.accent,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: AppColors.cyan.withValues(alpha: 0.5), blurRadius: 8)],
                    ),
                    child: Text('$unread',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                  )
                else
                  const SizedBox(height: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onNew;
  final bool searching;
  const _EmptyState({required this.onNew, required this.searching});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(searching ? Icons.search_off_rounded : Icons.forum_rounded,
                size: 72, color: Colors.white.withValues(alpha: 0.25)),
            const SizedBox(height: 16),
            Text(searching ? 'No matches' : 'No conversations yet',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              searching
                  ? 'Try a different name or email.'
                  : 'Start a private, peer-to-peer chat using\nsomeone\'s email address.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _NewChatSheet extends StatefulWidget {
  const _NewChatSheet();

  @override
  State<_NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends State<_NewChatSheet> {
  final _email = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!isValidEmail(_email.text)) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await context.read<ChatController>().addContactByEmail(_email.text);
      if (mounted) Navigator.of(context).pop(p);
    } on ContactNotFound catch (e) {
      setState(() => _error = e.toString());
    } catch (e) {
      setState(() => _error = 'Lookup failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.read<ChatController>();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: GlassCard(
        radius: 32,
        blur: 30,
        opacity: 0.12,
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(3)),
                ),
              ),
              const SizedBox(height: 20),
              Text('Start a secure chat', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              const Text(
                'Enter the email your contact registered with. You will connect directly, device to device.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              GlassTextField(
                controller: _email,
                hint: 'friend@example.com',
                icon: Icons.person_search_rounded,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                onSubmitted: (_) => _submit(),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10, left: 4),
                  child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
                ),
              if (c.backend.demo) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  children: ['aurora@cipherly.demo', 'milo@cipherly.demo', 'nova@cipherly.demo']
                      .map((e) => ActionChip(
                            label: Text(e, style: const TextStyle(fontSize: 12)),
                            backgroundColor: Colors.white.withValues(alpha: 0.08),
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                            onPressed: () => _email.text = e,
                          ))
                      .toList(),
                ),
              ],
              const SizedBox(height: 22),
              GlossyButton(label: 'Connect', icon: Icons.link_rounded, loading: _loading, onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }
}
