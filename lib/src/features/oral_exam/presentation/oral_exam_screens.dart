import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/praticase_colors.dart';
import '../../../app/theme/praticase_motion.dart';
import '../../../app/theme/praticase_tokens.dart';
import '../../../shared/ui/ui.dart';
import '../../cases/data/voice_exam_adapter.dart';
import '../data/oral_exam_repository.dart';
import '../domain/oral_exam_models.dart';

/// Sözlü sınav kurulum ekranı: persona + branş + süre seçimi.
class OralExamSetupScreen extends StatefulWidget {
  const OralExamSetupScreen({required this.repository, super.key});

  final OralExamRepository repository;

  @override
  State<OralExamSetupScreen> createState() => _OralExamSetupScreenState();
}

class _OralExamSetupScreenState extends State<OralExamSetupScreen> {
  late Future<OralExamCatalog> _catalogFuture;
  OralExamPersona? _persona;
  OralExamBranch? _branch;
  int _durationMinutes = 15;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _catalogFuture = widget.repository.loadCatalog();
  }

  Future<void> _start() async {
    if (_persona == null || _branch == null || _starting) return;
    setState(() => _starting = true);
    try {
      final session = await widget.repository.startSession(
        personaId: _persona!.id,
        branchId: _branch!.id,
        durationSeconds: _durationMinutes * 60,
      );
      if (!mounted) return;
      await PratiCaseHaptics.medium();
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => OralExamRoomScreen(
            repository: widget.repository,
            session: session,
          ),
        ),
      );
    } on OralExamUnavailable catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PratiCaseColors.softSurface,
      appBar: AppBar(title: const Text('Sözlü Sınav')),
      body: FutureBuilder<OralExamCatalog>(
        future: _catalogFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: PratiCaseSpinner());
          }
          if (snapshot.hasError) {
            return _OralExamError(
              message: snapshot.error is OralExamUnavailable
                  ? (snapshot.error! as OralExamUnavailable).message
                  : 'Sözlü sınav modülü açılamadı.',
              onRetry: () => setState(
                () => _catalogFuture = widget.repository.loadCatalog(),
              ),
            );
          }
          final catalog = snapshot.requireData;
          _persona ??= catalog.personas.isEmpty ? null : catalog.personas.first;
          _branch ??= catalog.branches.isEmpty ? null : catalog.branches.first;

          return Stack(
            children: [
              PratiCaseResponsiveListView(
                padding: PratiCaseResponsive.pagePadding(context),
                children: [
                  FadeSlideIn(child: _IntroCard()),
                  const SizedBox(height: 22),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 50),
                    child: _SectionTitle('Hocanı Seç'),
                  ),
                  const SizedBox(height: 10),
                  ...List.generate(catalog.personas.length, (index) {
                    final persona = catalog.personas[index];
                    final selected = _persona?.id == persona.id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: FadeSlideIn(
                        delay: Duration(milliseconds: 80 + index * 40),
                        child: _PersonaTile(
                          persona: persona,
                          selected: selected,
                          onTap: () => setState(() => _persona = persona),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 20),
                  FadeSlideIn(child: _SectionTitle('Branş')),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final branch in catalog.branches)
                        _BranchChip(
                          branch: branch,
                          selected: _branch?.id == branch.id,
                          onTap: () => setState(() => _branch = branch),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  FadeSlideIn(child: _SectionTitle('Sınav Süresi')),
                  const SizedBox(height: 10),
                  _DurationPicker(
                    value: _durationMinutes,
                    onChanged: (value) =>
                        setState(() => _durationMinutes = value),
                  ),
                  const SizedBox(height: 20),
                  FadeSlideIn(
                    child: _BranchDetailCard(branch: _branch),
                  ),
                ],
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: MediaQuery.paddingOf(context).bottom + 16,
                child: SafeArea(
                  top: false,
                  child: FilledButton.icon(
                    onPressed:
                        _persona == null || _branch == null || _starting
                        ? null
                        : _start,
                    icon: _starting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: PratiCaseSpinner(
                              size: 18,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.record_voice_over_rounded),
                    label: Text(
                      _starting ? 'Hoca hazırlanıyor...' : 'Sözlü Sınavı Başlat',
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
      decoration: BoxDecoration(
        gradient: PratiCaseGradients.hero,
        borderRadius: BorderRadius.circular(PratiCaseRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(PratiCaseRadius.md),
                ),
                child: const Icon(
                  Icons.record_voice_over_rounded,
                  color: PratiCaseColors.tealBright,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Sanal Hoca ile Sözlü Sınav',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Hoca vakayı sunar, sokratik takip soruları sorar. Klinik akıl yürütme, '
            'bilgi, iletişim, hız ve profesyonellik 100 puan üzerinden değerlendirilir. '
            'Mikrofona izin verirsen cevaplarını sesli verebilirsin.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: PratiCaseColors.navy,
        fontSize: 16,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _PersonaTile extends StatelessWidget {
  const _PersonaTile({
    required this.persona,
    required this.selected,
    required this.onTap,
  });
  final OralExamPersona persona;
  final bool selected;
  final VoidCallback onTap;

  Color get _accent {
    switch (persona.difficulty) {
      case 'Kolay':
        return PratiCaseColors.successGreen;
      case 'Orta':
        return PratiCaseColors.gold;
      case 'Zor':
        return PratiCaseColors.errorRed;
      default:
        return PratiCaseColors.teal;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: PratiCaseDurations.fast,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? PratiCaseColors.teal.withValues(alpha: 0.08)
              : PratiCaseColors.white,
          borderRadius: BorderRadius.circular(PratiCaseRadius.lg),
          border: Border.all(
            color: selected ? PratiCaseColors.teal : PratiCaseColors.border,
            width: selected ? 1.4 : 1,
          ),
          boxShadow: selected ? null : PratiCaseShadows.card,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                persona.difficulty == 'Zor'
                    ? Icons.gavel_rounded
                    : persona.difficulty == 'Orta'
                        ? Icons.psychology_rounded
                        : Icons.medical_information_rounded,
                color: _accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          persona.title,
                          style: const TextStyle(
                            color: PratiCaseColors.navy,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _accent.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          persona.difficulty,
                          style: TextStyle(
                            color: _accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    persona.description,
                    style: const TextStyle(
                      color: PratiCaseColors.muted,
                      fontSize: 12,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BranchChip extends StatelessWidget {
  const _BranchChip({
    required this.branch,
    required this.selected,
    required this.onTap,
  });
  final OralExamBranch branch;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: PratiCaseDurations.fast,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? PratiCaseColors.teal : PratiCaseColors.white,
          borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
          border: Border.all(
            color: selected ? PratiCaseColors.teal : PratiCaseColors.border,
          ),
        ),
        child: Text(
          branch.title,
          style: TextStyle(
            color: selected ? Colors.white : PratiCaseColors.navy,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _BranchDetailCard extends StatelessWidget {
  const _BranchDetailCard({required this.branch});
  final OralExamBranch? branch;

  @override
  Widget build(BuildContext context) {
    if (branch == null) return const SizedBox.shrink();
    return ClinicalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            branch!.title,
            style: const TextStyle(
              color: PratiCaseColors.navy,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            branch!.description,
            style: const TextStyle(
              color: PratiCaseColors.slateBlue,
              fontSize: 13,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DurationPicker extends StatelessWidget {
  const _DurationPicker({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  static const _options = [10, 15, 20];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final option in _options) ...[
          Expanded(
            child: PressableScale(
              onTap: () => onChanged(option),
              child: AnimatedContainer(
                duration: PratiCaseDurations.fast,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: value == option
                      ? PratiCaseColors.teal.withValues(alpha: 0.10)
                      : PratiCaseColors.white,
                  borderRadius: BorderRadius.circular(PratiCaseRadius.lg),
                  border: Border.all(
                    color: value == option
                        ? PratiCaseColors.teal
                        : PratiCaseColors.border,
                    width: value == option ? 1.4 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '$option',
                      style: TextStyle(
                        color: value == option
                            ? PratiCaseColors.teal
                            : PratiCaseColors.navy,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Text(
                      'dakika',
                      style: TextStyle(
                        color: PratiCaseColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (option != _options.last) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

/// Sözlü sınav odası — gerçek sınav UI'si.
class OralExamRoomScreen extends StatefulWidget {
  const OralExamRoomScreen({
    required this.repository,
    required this.session,
    this.voiceAdapter,
    super.key,
  });

  final OralExamRepository repository;
  final OralExamSession session;
  final VoiceExamAdapter? voiceAdapter;

  @override
  State<OralExamRoomScreen> createState() => _OralExamRoomScreenState();
}

class _OralExamRoomScreenState extends State<OralExamRoomScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<OralExamMessage> _messages = [];
  late final VoiceExamAdapter _voiceAdapter;
  StreamSubscription<VoiceExamState>? _voiceSubscription;
  VoiceExamState _voiceState = const VoiceExamState();
  Timer? _ticker;
  late int _remainingSeconds;
  bool _sending = false;
  bool _voiceMode = false;
  bool _finalizing = false;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.session.durationSeconds;
    _voiceAdapter = widget.voiceAdapter ?? NativeVoiceExamAdapter();
    _voiceState = _voiceAdapter.state;
    _voiceSubscription = _voiceAdapter.states.listen((state) {
      if (!mounted) return;
      setState(() => _voiceState = state);
    });
    _messages.add(
      OralExamMessage(
        speaker: 'mentor',
        message: widget.session.openingMessage,
      ),
    );
    _startTicker();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _speakLatestMentor();
    });
  }

  void _startTicker() {
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _remainingSeconds = (_remainingSeconds - 1).clamp(0, 1 << 30);
      });
      if (_remainingSeconds == 60) {
        unawaited(PratiCaseHaptics.warning());
      }
      if (_remainingSeconds == 0) {
        _ticker?.cancel();
        unawaited(_finalize());
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _voiceSubscription?.cancel();
    _voiceAdapter.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _scrollToBottom() async {
    await Future<void>.delayed(const Duration(milliseconds: 60));
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending || _finalizing) return;
    setState(() {
      _sending = true;
      _messages.add(OralExamMessage(speaker: 'candidate', message: text));
      _messageController.clear();
    });
    unawaited(_scrollToBottom());
    try {
      final response = await widget.repository.sendAnswer(
        sessionId: widget.session.id,
        message: text,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(
          OralExamMessage(
            speaker: 'mentor',
            message: response.mentorMessage,
            isFollowup: response.isFollowup,
          ),
        );
        if (response.remainingSeconds > 0) {
          _remainingSeconds = response.remainingSeconds;
        }
      });
      unawaited(PratiCaseHaptics.selection());
      unawaited(_speakLatestMentor());
      unawaited(_scrollToBottom());
      if (response.shouldEnd) {
        await _finalize();
      }
    } on OralExamUnavailable catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _skip() async {
    if (_sending || _finalizing) return;
    setState(() {
      _sending = true;
      _messages.add(
        const OralExamMessage(
          speaker: 'candidate',
          message: '(bu soruyu pas geçtim)',
          wasSkipped: true,
        ),
      );
    });
    unawaited(_scrollToBottom());
    try {
      final mentor = await widget.repository.skipQuestion(widget.session.id);
      if (!mounted) return;
      setState(() {
        _messages.add(OralExamMessage(speaker: 'mentor', message: mentor));
      });
      unawaited(_speakLatestMentor());
      unawaited(_scrollToBottom());
    } on OralExamUnavailable catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _finalize() async {
    if (_finalizing) return;
    setState(() => _finalizing = true);
    try {
      final result = await widget.repository.finalizeSession(widget.session.id);
      if (!mounted) return;
      unawaited(_voiceAdapter.stopSpeaking());
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => OralExamResultScreen(
            result: result,
            session: widget.session,
          ),
        ),
      );
    } on OralExamUnavailable catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      setState(() => _finalizing = false);
    }
  }

  Future<void> _toggleVoiceMode() async {
    final next = !_voiceMode;
    setState(() => _voiceMode = next);
    if (next) {
      await _voiceAdapter.initialize();
      await _speakLatestMentor();
    } else {
      await _voiceAdapter.stopListening();
      await _voiceAdapter.stopSpeaking();
    }
  }

  Future<void> _toggleListening() async {
    if (_voiceState.listening) {
      await _voiceAdapter.stopListening();
      return;
    }
    await _voiceAdapter.startListening(
      onPartialText: (text) {
        if (!mounted || text.trim().isEmpty) return;
        setState(() {
          _messageController.text = text.trim();
          _messageController.selection = TextSelection.collapsed(
            offset: _messageController.text.length,
          );
        });
      },
      onFinalText: (text) {
        if (!mounted || text.trim().isEmpty) return;
        setState(() {
          _messageController.text = text.trim();
          _messageController.selection = TextSelection.collapsed(
            offset: _messageController.text.length,
          );
        });
        if (_voiceMode) unawaited(_send());
      },
    );
  }

  Future<void> _speakLatestMentor() async {
    if (!_voiceMode || _voiceState.muted) return;
    final mentor = _messages.lastWhere(
      (m) => m.fromMentor,
      orElse: () => const OralExamMessage(speaker: 'mentor', message: ''),
    );
    if (mentor.message.isEmpty) return;
    await _voiceAdapter.speak(mentor.message);
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Color get _timerColor {
    if (_remainingSeconds <= 60) return PratiCaseColors.errorRed;
    if (_remainingSeconds <= 180) return PratiCaseColors.gold;
    return PratiCaseColors.teal;
  }

  Future<bool> _confirmExit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sınavı bitir?'),
        content: const Text(
          'Şu ana kadar verdiğin cevaplar değerlendirilip karne çıkarılacak.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Devam Et'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Bitir ve Değerlendir'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _finalize();
      return false;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _confirmExit();
      },
      child: Scaffold(
        backgroundColor: PratiCaseColors.softSurface,
        appBar: AppBar(
          title: Text(widget.session.branchTitle),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _timerColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 16,
                        color: _timerColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatTime(_remainingSeconds),
                        style: TextStyle(
                          color: _timerColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            _MentorBanner(
              personaTitle: widget.session.personaTitle,
              difficulty: widget.session.difficulty,
              caseBrief: widget.session.caseBrief,
              voiceMode: _voiceMode,
              onToggleVoice: _toggleVoiceMode,
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: _messages.length + (_sending ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_sending && index == _messages.length) {
                    return const _MentorTypingBubble();
                  }
                  return _ExamBubble(message: _messages[index]);
                },
              ),
            ),
            _ComposerBar(
              controller: _messageController,
              sending: _sending,
              finalizing: _finalizing,
              voiceMode: _voiceMode,
              listening: _voiceState.listening,
              onSend: _send,
              onSkip: _skip,
              onToggleListening: _voiceMode ? _toggleListening : null,
              onFinalize: () async {
                await _confirmExit();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MentorBanner extends StatelessWidget {
  const _MentorBanner({
    required this.personaTitle,
    required this.difficulty,
    required this.caseBrief,
    required this.voiceMode,
    required this.onToggleVoice,
  });

  final String personaTitle;
  final String difficulty;
  final String caseBrief;
  final bool voiceMode;
  final VoidCallback onToggleVoice;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 14),
      decoration: const BoxDecoration(
        color: PratiCaseColors.navy,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: PratiCaseColors.teal.withValues(alpha: 0.25),
                child: const Icon(
                  Icons.person_rounded,
                  color: PratiCaseColors.tealBright,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      personaTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Zorluk: $difficulty',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onToggleVoice,
                icon: Icon(
                  voiceMode ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                  color: voiceMode
                      ? PratiCaseColors.tealBright
                      : Colors.white.withValues(alpha: 0.7),
                ),
                tooltip: voiceMode ? 'Sesli mod açık' : 'Sesli mod kapalı',
              ),
            ],
          ),
          if (caseBrief.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                caseBrief,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExamBubble extends StatelessWidget {
  const _ExamBubble({required this.message});
  final OralExamMessage message;

  @override
  Widget build(BuildContext context) {
    final mentor = message.fromMentor;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment:
            mentor ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (mentor) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: PratiCaseColors.teal.withValues(alpha: 0.18),
              child: const Icon(
                Icons.person_rounded,
                color: PratiCaseColors.teal,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: FadeSlideIn(
              offset: const Offset(0, 0.04),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: mentor ? PratiCaseColors.white : PratiCaseColors.teal,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(mentor ? 4 : 16),
                    topRight: Radius.circular(mentor ? 16 : 4),
                    bottomLeft: const Radius.circular(16),
                    bottomRight: const Radius.circular(16),
                  ),
                  border: Border.all(
                    color: mentor
                        ? PratiCaseColors.border
                        : Colors.transparent,
                  ),
                  boxShadow: mentor ? PratiCaseShadows.card : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.isFollowup && mentor)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: PratiCaseColors.gold.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'TAKİP',
                            style: TextStyle(
                              color: PratiCaseColors.gold,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ),
                    if (message.wasSkipped && !mentor)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'PAS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ),
                    Text(
                      message.message,
                      style: TextStyle(
                        color: mentor ? PratiCaseColors.navy : Colors.white,
                        fontSize: 14,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (!mentor) const SizedBox(width: 22),
        ],
      ),
    );
  }
}

class _MentorTypingBubble extends StatelessWidget {
  const _MentorTypingBubble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: PratiCaseColors.teal.withValues(alpha: 0.18),
            child: const Icon(
              Icons.person_rounded,
              color: PratiCaseColors.teal,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: PratiCaseColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: PratiCaseColors.border),
            ),
            child: const SizedBox(
              width: 24,
              height: 8,
              child: _TypingDots(),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (_controller.value - i * 0.18) % 1.0;
            final scale = 0.6 + 0.4 * (1 - (phase - 0.4).abs() * 2).clamp(0, 1);
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: i == 1 ? 4 : 2),
              child: Transform.scale(
                scale: scale.toDouble(),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: PratiCaseColors.muted,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _ComposerBar extends StatelessWidget {
  const _ComposerBar({
    required this.controller,
    required this.sending,
    required this.finalizing,
    required this.voiceMode,
    required this.listening,
    required this.onSend,
    required this.onSkip,
    required this.onToggleListening,
    required this.onFinalize,
  });

  final TextEditingController controller;
  final bool sending;
  final bool finalizing;
  final bool voiceMode;
  final bool listening;
  final Future<void> Function() onSend;
  final Future<void> Function() onSkip;
  final Future<void> Function()? onToggleListening;
  final Future<void> Function() onFinalize;

  @override
  Widget build(BuildContext context) {
    final disabled = sending || finalizing;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: const BoxDecoration(
          color: PratiCaseColors.white,
          border: Border(
            top: BorderSide(color: PratiCaseColors.border),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                if (voiceMode && onToggleListening != null) ...[
                  PressableScale(
                    onTap: disabled ? null : () => onToggleListening!(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: listening
                            ? PratiCaseColors.errorRed
                            : PratiCaseColors.teal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Icon(
                        listening
                            ? Icons.mic_rounded
                            : Icons.mic_none_rounded,
                        color: listening ? Colors.white : PratiCaseColors.teal,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: !disabled,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    decoration: InputDecoration(
                      hintText: listening
                          ? 'Hoca seni dinliyor... konuş'
                          : 'Cevabını yaz veya mikrofona dokun',
                      filled: true,
                      fillColor: PratiCaseColors.softSurface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => onSend(),
                  ),
                ),
                const SizedBox(width: 8),
                PressableScale(
                  onTap: disabled || controller.text.trim().isEmpty
                      ? null
                      : () => onSend(),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: PratiCaseColors.teal,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: disabled ? null : () => onSkip(),
                    icon: const Icon(Icons.skip_next_rounded, size: 18),
                    label: const Text('Pas Geç (-5)'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: disabled ? null : () => onFinalize(),
                    icon: finalizing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: PratiCaseSpinner(size: 16),
                          )
                        : const Icon(Icons.check_circle_rounded, size: 18),
                    label: Text(
                      finalizing ? 'Karne çıkıyor...' : 'Sınavı Bitir',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Sözlü sınav sonuç karnesi.
class OralExamResultScreen extends StatefulWidget {
  const OralExamResultScreen({
    required this.result,
    required this.session,
    super.key,
  });

  final OralExamResult result;
  final OralExamSession session;

  @override
  State<OralExamResultScreen> createState() => _OralExamResultScreenState();
}

class _OralExamResultScreenState extends State<OralExamResultScreen> {
  bool _animated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _animated = true);
      PratiCaseHaptics.success();
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final scoreColor = r.percentage >= 80
        ? PratiCaseColors.successGreen
        : r.percentage >= 60
            ? PratiCaseColors.gold
            : PratiCaseColors.errorRed;

    return Scaffold(
      backgroundColor: PratiCaseColors.softSurface,
      appBar: AppBar(
        title: const Text('Sözlü Sınav Karnesi'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          FadeSlideIn(
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              decoration: BoxDecoration(
                gradient: PratiCaseGradients.hero,
                borderRadius: BorderRadius.circular(PratiCaseRadius.xl),
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(
                            begin: 0,
                            end: _animated ? r.percentage / 100 : 0,
                          ),
                          duration: const Duration(milliseconds: 1100),
                          curve: PratiCaseCurves.overshoot,
                          builder: (context, value, _) {
                            return SizedBox(
                              width: 120,
                              height: 120,
                              child: CircularProgressIndicator(
                                value: value,
                                strokeWidth: 8,
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.18),
                                color: scoreColor,
                                strokeCap: StrokeCap.round,
                              ),
                            );
                          },
                        ),
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(
                            begin: 0,
                            end: _animated ? r.percentage.toDouble() : 0,
                          ),
                          duration: const Duration(milliseconds: 1100),
                          curve: PratiCaseCurves.overshoot,
                          builder: (context, value, _) => Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '%${value.round()}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                '${r.totalScore}/${r.maxScore}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.72),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.session.personaTitle,
                    style: const TextStyle(
                      color: PratiCaseColors.tealBright,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.session.branchTitle} sözlü sınav karnesi',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FadeSlideIn(
            delay: const Duration(milliseconds: 80),
            child: _RubricGrid(result: r),
          ),
          if (r.mentorSummary.isNotEmpty) ...[
            const SizedBox(height: 14),
            FadeSlideIn(
              delay: const Duration(milliseconds: 140),
              child: ClinicalCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.format_quote_rounded,
                            color: PratiCaseColors.teal),
                        SizedBox(width: 6),
                        Text(
                          'Hoca Yorumu',
                          style: TextStyle(
                            color: PratiCaseColors.navy,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      r.mentorSummary,
                      style: const TextStyle(
                        color: PratiCaseColors.slateBlue,
                        fontSize: 14,
                        height: 1.55,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (r.strongPoints.isNotEmpty) ...[
            const SizedBox(height: 14),
            _FeedbackBlock(
              title: 'Güçlü Yönlerin',
              color: PratiCaseColors.successGreen,
              icon: Icons.verified_rounded,
              items: r.strongPoints,
            ),
          ],
          if (r.improvementPoints.isNotEmpty) ...[
            const SizedBox(height: 14),
            _FeedbackBlock(
              title: 'Gelişim Alanların',
              color: PratiCaseColors.gold,
              icon: Icons.trending_up_rounded,
              items: r.improvementPoints,
            ),
          ],
          if (r.missedPoints.isNotEmpty) ...[
            const SizedBox(height: 14),
            _FeedbackBlock(
              title: 'Kaçırılan Noktalar',
              color: PratiCaseColors.errorRed,
              icon: Icons.error_outline_rounded,
              items: r.missedPoints,
            ),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
            icon: const Icon(Icons.replay_rounded),
            label: const Text('Ana Sayfaya Dön'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ],
      ),
    );
  }
}

class _RubricGrid extends StatelessWidget {
  const _RubricGrid({required this.result});
  final OralExamResult result;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Klinik Akıl Yürütme', result.reasoningScore, 40),
      ('Bilgi Doğruluğu', result.knowledgeScore, 30),
      ('İletişim / Özgüven', result.communicationScore, 15),
      ('Soru-Cevap Hızı', result.paceScore, 10),
      ('Profesyonellik', result.professionalismScore, 5),
    ];
    return ClinicalCard(
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _RubricRow(
              title: items[i].$1,
              score: items[i].$2,
              maxScore: items[i].$3,
            ),
            if (i != items.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1, color: PratiCaseColors.border),
              ),
          ],
        ],
      ),
    );
  }
}

class _RubricRow extends StatelessWidget {
  const _RubricRow({
    required this.title,
    required this.score,
    required this.maxScore,
  });
  final String title;
  final int score;
  final int maxScore;

  @override
  Widget build(BuildContext context) {
    final ratio = maxScore == 0 ? 0.0 : (score / maxScore).clamp(0.0, 1.0);
    final color = ratio >= 0.8
        ? PratiCaseColors.successGreen
        : ratio >= 0.5
            ? PratiCaseColors.gold
            : PratiCaseColors.errorRed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: PratiCaseColors.navy,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
            Text(
              '$score / $maxScore',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: PratiCaseColors.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

class _FeedbackBlock extends StatelessWidget {
  const _FeedbackBlock({
    required this.title,
    required this.color,
    required this.icon,
    required this.items,
  });
  final String title;
  final Color color;
  final IconData icon;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return ClinicalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  color: PratiCaseColors.navy,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < items.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      items[i],
                      style: const TextStyle(
                        color: PratiCaseColors.slateBlue,
                        fontSize: 13,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (i != items.length - 1)
              const Divider(height: 1, color: PratiCaseColors.border),
          ],
        ],
      ),
    );
  }
}

class _OralExamError extends StatelessWidget {
  const _OralExamError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: PratiCaseColors.muted,
            ),
            const SizedBox(height: 12),
            const Text(
              'Sözlü sınav modülü açılamadı',
              style: TextStyle(
                color: PratiCaseColors.navy,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: const TextStyle(
                color: PratiCaseColors.muted,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }
}
