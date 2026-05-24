part of '../cases_screen.dart';

class _PatientBanner extends StatelessWidget {
  const _PatientBanner({required this.session});

  final ExamSessionOverview session;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PratiCaseColors.white,
        borderRadius: BorderRadius.circular(PratiCaseRadius.lg),
        border: Border.all(color: PratiCaseColors.border),
        boxShadow: PratiCaseShadows.card,
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: PratiCaseColors.teal.withValues(alpha: 0.10),
              shape: BoxShape.circle,
              border: Border.all(
                color: PratiCaseColors.teal.withValues(alpha: 0.18),
              ),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: PratiCaseColors.teal,
              size: 30,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.patient.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PratiCaseColors.navy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _PatientMiniPill(
                      icon: Icons.cake_outlined,
                      text: '${session.patient.age}, ${session.patient.gender}',
                    ),
                    _PatientMiniPill(
                      icon: Icons.local_hospital_outlined,
                      text: session.patient.applicationSetting,
                    ),
                    _PatientMiniPill(
                      icon: Icons.schedule_rounded,
                      text: session.patient.complaintDuration,
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton.outlined(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              builder: (context) => SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.patient.name,
                        style: const TextStyle(
                          color: PratiCaseColors.navy,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text('${session.patient.age}, ${session.patient.gender}'),
                      Text(session.patient.mainComplaint),
                      Text(session.patient.applicationSetting),
                      Text(session.patient.complaintDuration),
                    ],
                  ),
                ),
              ),
            ),
            tooltip: 'Hasta bilgileri',
            icon: const Icon(Icons.badge_outlined, size: 20),
          ),
        ],
      ),
    );
  }
}

class _PatientMiniPill extends StatelessWidget {
  const _PatientMiniPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: PratiCaseColors.softSurface,
        borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: PratiCaseColors.muted, size: 13),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: PratiCaseColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    required this.fromCandidate,
    this.isOpening = false,
    this.isPending = false,
  });

  final String message;
  final bool fromCandidate;
  final bool isOpening;
  final bool isPending;

  @override
  Widget build(BuildContext context) {
    final label = fromCandidate
        ? isPending
              ? 'Aday - gönderiliyor'
              : 'Aday'
        : isOpening
        ? 'Hasta - açılış'
        : 'Hasta';
    return Align(
      alignment: fromCandidate ? Alignment.centerRight : Alignment.centerLeft,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: fromCandidate ? null : PratiCaseColors.white,
          gradient: fromCandidate
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [PratiCaseColors.teal, PratiCaseColors.gradientEnd],
                )
              : null,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(fromCandidate ? 16 : 5),
            bottomRight: Radius.circular(fromCandidate ? 5 : 16),
          ),
          border: fromCandidate
              ? null
              : Border.all(color: PratiCaseColors.border),
          boxShadow: PratiCaseShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  fromCandidate ? Icons.school_outlined : Icons.person_rounded,
                  color: fromCandidate
                      ? PratiCaseColors.white.withValues(alpha: 0.82)
                      : PratiCaseColors.teal,
                  size: 14,
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    color: fromCandidate
                        ? PratiCaseColors.white.withValues(alpha: 0.82)
                        : PratiCaseColors.teal,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: TextStyle(
                color: fromCandidate
                    ? PratiCaseColors.white.withValues(
                        alpha: isPending ? 0.82 : 1,
                      )
                    : PratiCaseColors.navy,
                height: 1.36,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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

class _TypingBubbleState extends State<_TypingBubble>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (index) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      ),
    );
    _animations = _controllers
        .map(
          (controller) => Tween<double>(begin: 0.3, end: 1.0).animate(
            CurvedAnimation(parent: controller, curve: Curves.easeInOut),
          ),
        )
        .toList();
    _startAnimations();
  }

  void _startAnimations() {
    for (var i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 180), () {
        if (mounted) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: PratiCaseColors.softSurface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(5),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: PratiCaseColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              FadeTransition(
                opacity: _animations[i],
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: PratiCaseColors.teal,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              if (i < 2) const SizedBox(width: 5),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChatComposer extends StatelessWidget {
  const _ChatComposer({
    required this.controller,
    required this.sending,
    required this.voiceState,
    required this.voiceExamMode,
    required this.onSend,
    required this.onNext,
    required this.onToggleVoiceMode,
    required this.onToggleListening,
  });

  final TextEditingController controller;
  final bool sending;
  final VoiceExamState voiceState;
  final bool voiceExamMode;
  final VoidCallback onSend;
  final VoidCallback? onNext;
  final VoidCallback onToggleVoiceMode;
  final VoidCallback onToggleListening;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 4),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: PratiCaseColors.white,
          border: Border(top: BorderSide(color: PratiCaseColors.border)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _VoiceModeChip(
                      enabled: voiceExamMode,
                      listening: voiceState.listening,
                      speaking: voiceState.speaking,
                      onTap: onToggleVoiceMode,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _ComposerIconButton(
                    tooltip: voiceState.listening
                        ? 'Dinlemeyi bitir'
                        : 'Sesle yaz',
                    icon: voiceState.listening
                        ? Icons.stop_rounded
                        : Icons.mic_none_rounded,
                    active: voiceState.listening,
                    onPressed: sending ? null : onToggleListening,
                  ),
                ],
              ),
              if (voiceState.errorMessage?.trim().isNotEmpty ?? false) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    voiceState.errorMessage!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: PratiCaseColors.errorRed,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => sending ? null : onSend(),
                      decoration: InputDecoration(
                        hintText: 'Hastaya sorunuzu yazın...',
                        prefixIcon: Icon(
                          voiceState.listening
                              ? Icons.hearing_rounded
                              : Icons.record_voice_over_outlined,
                          color: voiceState.listening
                              ? PratiCaseColors.gold
                              : PratiCaseColors.teal,
                        ),
                        filled: true,
                        fillColor: PratiCaseColors.softSurface,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: PratiCaseSpacing.md,
                          vertical: PratiCaseSpacing.md,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            PratiCaseRadius.xl,
                          ),
                          borderSide: const BorderSide(
                            color: PratiCaseColors.border,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            PratiCaseRadius.xl,
                          ),
                          borderSide: const BorderSide(
                            color: PratiCaseColors.border,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            PratiCaseRadius.xl,
                          ),
                          borderSide: const BorderSide(
                            color: PratiCaseColors.teal,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    identifier: 'chat.send',
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: IconButton.filled(
                        onPressed: sending ? null : onSend,
                        tooltip: 'Gönder',
                        style: IconButton.styleFrom(
                          backgroundColor: PratiCaseColors.teal,
                          foregroundColor: PratiCaseColors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              PratiCaseRadius.md,
                            ),
                          ),
                        ),
                        icon: sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: PratiCaseColors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: onNext,
                  icon: const Icon(
                    Icons.health_and_safety_outlined,
                    color: PratiCaseColors.teal,
                  ),
                  label: const Text(
                    'Muayeneye Geç',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: PratiCaseColors.teal,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: PratiCaseColors.teal,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(PratiCaseRadius.md),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VoiceModeChip extends StatelessWidget {
  const _VoiceModeChip({
    required this.enabled,
    required this.listening,
    required this.speaking,
    required this.onTap,
  });

  final bool enabled;
  final bool listening;
  final bool speaking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = enabled
        ? listening
              ? 'Sesli Sınav: dinliyor'
              : speaking
              ? 'Sesli Sınav: hasta konuşuyor'
              : 'Sesli Sınav açık'
        : 'Sesli Sınav';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: enabled
              ? PratiCaseColors.teal.withValues(alpha: 0.10)
              : PratiCaseColors.softSurface,
          borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
          border: Border.all(
            color: enabled ? PratiCaseColors.teal : PratiCaseColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              enabled ? Icons.graphic_eq_rounded : Icons.mic_external_on,
              color: enabled ? PratiCaseColors.teal : PratiCaseColors.muted,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: enabled ? PratiCaseColors.teal : PratiCaseColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposerIconButton extends StatelessWidget {
  const _ComposerIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.active = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 38,
      child: IconButton.filledTonal(
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: active
              ? PratiCaseColors.gold.withValues(alpha: 0.20)
              : PratiCaseColors.teal.withValues(alpha: 0.10),
          foregroundColor: active ? PratiCaseColors.gold : PratiCaseColors.teal,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PratiCaseRadius.md),
          ),
        ),
        icon: Icon(icon, size: 20),
      ),
    );
  }
}
