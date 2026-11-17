import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/chat_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar.dart';
import '../widgets/format.dart';
import '../widgets/glass.dart';
import 'safety_number_screen.dart';

class ChatScreen extends StatefulWidget {
  final String peerId;
  const ChatScreen({super.key, required this.peerId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  late final _focus = FocusNode(onKeyEvent: _onKey);
  late final ChatController _c;

  /// Hardware keyboards: Enter sends, Shift+Enter inserts a newline.
  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    final isEnter = e.logicalKey == LogicalKeyboardKey.enter || e.logicalKey == LogicalKeyboardKey.numpadEnter;
    if (isEnter && !HardwareKeyboard.instance.isShiftPressed) {
      if (e is KeyDownEvent) _send();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void initState() {
    super.initState();
    _c = context.read<ChatController>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _c.openConversation(widget.peerId));
  }

  @override
  void dispose() {
    _c.closeConversation();
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _c.sendText(widget.peerId, text);
    _c.notifyTyping(widget.peerId, false);
    _input.clear();
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ChatController>();
    final peer = c.contact(widget.peerId);
    if (peer == null) return const Scaffold();
    final messages = c.messagesFor(peer.id);
    final typing = c.typing.contains(peer.id);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: GlossyBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                children: [
                  _Header(peer: peer),
                  Expanded(
                    child: ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                      itemCount: messages.length + 2,
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: typing ? const _TypingBubble() : const SizedBox.shrink(),
                          );
                        }
                        if (i == messages.length + 1) return const _EncryptionNotice();
                        final idx = messages.length - i;
                        final m = messages[idx];
                        final showDay = idx == 0 || !sameDay(messages[idx - 1].timestamp, m.timestamp);
                        final grouped = idx > 0 &&
                            messages[idx - 1].outgoing == m.outgoing &&
                            m.timestamp.difference(messages[idx - 1].timestamp).inMinutes < 3;
                        return Column(
                          children: [
                            if (showDay) _DayChip(label: formatDayHeader(m.timestamp)),
                            _Bubble(message: m, grouped: grouped && !showDay),
                          ],
                        );
                      },
                    ),
                  ),
                  _Composer(
                    controller: _input,
                    focusNode: _focus,
                    onSend: _send,
                    onChanged: (v) {
                      setState(() {});
                      c.notifyTyping(peer.id, v.isNotEmpty);
                    },
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

class _Header extends StatelessWidget {
  final PeerProfile peer;
  const _Header({required this.peer});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ChatController>();
    final state = c.linkState(peer.id);
    final online = c.online.contains(peer.id);

    final Widget pill = switch (state) {
      LinkState.secure =>
        const StatusPill(label: 'Encrypted · P2P', icon: Icons.lock_rounded, color: AppColors.success),
      LinkState.connecting =>
        const StatusPill(label: 'Connecting...', icon: Icons.sync, color: AppColors.sky, pulsing: true),
      LinkState.handshaking =>
        const StatusPill(label: 'Exchanging keys...', icon: Icons.key, color: AppColors.violet, pulsing: true),
      LinkState.failed =>
        const StatusPill(label: 'Unreachable · tap to retry', icon: Icons.error_outline, color: AppColors.error),
      LinkState.offline => StatusPill(
          label: online ? 'Online · tap to connect' : 'Offline',
          icon: Icons.circle,
          color: online ? AppColors.sky : context.palette.textSecondary),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: GlassCard(
        radius: 26,
        padding: const EdgeInsets.fromLTRB(6, 8, 10, 8),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            GlossyAvatar(name: peer.name, seed: peer.id, size: 42, online: online),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(peer.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: (state == LinkState.offline || state == LinkState.failed)
                        ? () => c.connect(peer.id)
                        : null,
                    child: pill,
                  ),
                ],
              ),
            ),
            GlassIconButton(
              icon: Icons.verified_user_rounded,
              tooltip: 'Verify safety number',
              color: AppColors.success,
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(value: c, child: SafetyNumberScreen(peerId: peer.id)),
              )),
            ),
          ],
        ),
      ),
    );
  }
}

class _EncryptionNotice extends StatelessWidget {
  const _EncryptionNotice();

  @override
  Widget build(BuildContext context) {
    // Amber-700 in light mode keeps the notice readable on pale backgrounds.
    final fg = context.palette.isDark ? AppColors.warning : const Color(0xFFB45309);
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.lock_rounded, size: 16, color: fg),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Messages travel directly between your devices and are end-to-end encrypted. '
                'No server can read or store them.',
                style: TextStyle(color: fg, fontSize: 12.5, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  final String label;
  const _DayChip({required this.label});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: context.palette.glassTop,
            border: Border.all(color: context.palette.glassBorder),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label, style: TextStyle(fontSize: 12, color: context.palette.textSecondary)),
        ),
      );
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final bool grouped;
  const _Bubble({required this.message, required this.grouped});

  @override
  Widget build(BuildContext context) {
    final out = message.outgoing;
    final p = context.palette;
    final r = const Radius.circular(22);
    final tail = const Radius.circular(6);
    final radius = BorderRadius.only(
      topLeft: r,
      topRight: r,
      bottomLeft: out ? r : tail,
      bottomRight: out ? tail : r,
    );
    final maxW = MediaQuery.sizeOf(context).width * 0.74;

    final statusIcon = switch (message.status) {
      MessageStatus.sending => const Icon(Icons.schedule_rounded, size: 13, color: Colors.white70),
      MessageStatus.sent => const Icon(Icons.done_rounded, size: 14, color: Colors.white70),
      MessageStatus.delivered => const Icon(Icons.done_all_rounded, size: 14, color: Color(0xFFB8F7FF)),
      MessageStatus.failed => const Icon(Icons.error_rounded, size: 14, color: AppColors.error),
    };

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message.text, style: TextStyle(color: out ? Colors.white : p.textPrimary, fontSize: 15.5, height: 1.35)),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(formatClock(message.timestamp),
                style: TextStyle(color: out ? Colors.white.withValues(alpha: 0.75) : p.textSecondary, fontSize: 11)),
            if (out) ...[const SizedBox(width: 4), statusIcon],
          ],
        ),
      ],
    );

    final bubble = out
        ? Container(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: p.sentBubbleGradient,
              boxShadow: [
                BoxShadow(color: p.bubbleSent.withValues(alpha: 0.32), blurRadius: 14, offset: const Offset(0, 6)),
              ],
            ),
            child: Stack(children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: 18,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(topLeft: r, topRight: r),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.white.withValues(alpha: 0.28), Colors.white.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ),
              Padding(padding: const EdgeInsets.fromLTRB(16, 11, 14, 8), child: content),
            ]),
          )
        : GlassCard(
            borderRadius: radius,
            blur: 12,
            color: p.bubbleReceived,
            padding: const EdgeInsets.fromLTRB(16, 11, 14, 8),
            child: content,
          );

    return Padding(
      padding: EdgeInsets.only(top: grouped ? 3 : 10),
      child: Align(
        alignment: out ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW.clamp(200, 520)),
          child: GestureDetector(
            onTap: message.status == MessageStatus.failed
                ? () => context.read<ChatController>().retry(message)
                : null,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.85, end: 1),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              builder: (context, s, child) => Transform.scale(
                scale: s,
                alignment: out ? Alignment.bottomRight : Alignment.bottomLeft,
                child: child,
              ),
              child: bubble,
            ),
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _a =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: GlassCard(
          radius: 20,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: AnimatedBuilder(
            animation: _a,
            builder: (context, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final phase = (_a.value - i * 0.18) % 1.0;
                final lift = phase < 0.5 ? (phase * 2) : (2 - phase * 2);
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  transform: Matrix4.translationValues(0, -4 * lift, 0),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color.lerp(context.palette.textSecondary, AppColors.sky, lift),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final ValueChanged<String> onChanged;

  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final canSend = controller.text.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: GlassTextField(
              controller: controller,
              focusNode: focusNode,
              hint: 'Encrypted message',
              icon: Icons.lock_outline_rounded,
              maxLines: 5,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              onChanged: onChanged,
            ),
          ),
          const SizedBox(width: 10),
          AnimatedScale(
            duration: const Duration(milliseconds: 200),
            scale: canSend ? 1 : 0.9,
            child: GestureDetector(
              onTap: canSend ? onSend : null,
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: canSend
                      ? AppColors.accent
                      : LinearGradient(colors: [context.palette.divider, context.palette.divider]),
                  boxShadow: canSend
                      ? [BoxShadow(color: AppColors.indigo.withValues(alpha: 0.4), blurRadius: 18, offset: const Offset(0, 6))]
                      : null,
                ),
                child: Icon(Icons.send_rounded, color: canSend ? Colors.white : context.palette.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
