import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/praticase_colors.dart';
import '../../../app/theme/praticase_tokens.dart';
import '../data/theoretical_exam_repository.dart';
import '../domain/theoretical_exam_models.dart';

class TheoreticalExamSetupScreen extends StatefulWidget {
  const TheoreticalExamSetupScreen({required this.repository, super.key});

  final TheoreticalExamRepository repository;

  @override
  State<TheoreticalExamSetupScreen> createState() =>
      _TheoreticalExamSetupScreenState();
}

class _TheoreticalExamSetupScreenState
    extends State<TheoreticalExamSetupScreen> {
  late Future<TheoreticalExamFilters> _filtersFuture;
  Future<List<TheoreticalQuestion>>? _questionsFuture;
  final Set<String> _selectedCourses = <String>{};
  final Set<String> _selectedQuestionIds = <String>{};
  String _selectedTopic = '';
  int _questionCount = 20;

  @override
  void initState() {
    super.initState();
    _filtersFuture = widget.repository.loadFilters();
  }

  Future<void> _refresh() async {
    setState(() {
      _filtersFuture = widget.repository.loadFilters();
      _questionsFuture = null;
      _selectedQuestionIds.clear();
    });
    await _filtersFuture;
  }

  void _toggleCourse(String course) {
    setState(() {
      if (!_selectedCourses.add(course)) _selectedCourses.remove(course);
      _selectedTopic = '';
      _questionsFuture = null;
      _selectedQuestionIds.clear();
    });
  }

  void _loadQuestions() {
    final future = widget.repository.loadQuestions(
      courses: _selectedCourses,
      topic: _selectedTopic,
      limit: _questionCount,
    );
    setState(() {
      _questionsFuture = future;
      _selectedQuestionIds.clear();
    });
    unawaited(
      future.then((questions) {
        if (!mounted) return;
        setState(() {
          _selectedQuestionIds
            ..clear()
            ..addAll(questions.map((question) => question.id));
        });
      }),
    );
  }

  void _startExam(List<TheoreticalQuestion> questions) {
    final selected = [
      for (final question in questions)
        if (_selectedQuestionIds.contains(question.id)) question,
    ];
    if (selected.isEmpty) {
      _showMessage('Deneme için en az bir soru seçmelisin.');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TheoreticalExamSessionScreen(questions: selected),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom + 24;
    return Scaffold(
      backgroundColor: PratiCaseColors.softSurface,
      appBar: AppBar(
        title: const Text(
          'Kuramsal Sınav',
          style: TextStyle(
            color: PratiCaseColors.navy,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
        backgroundColor: PratiCaseColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: PratiCaseColors.navy),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: PratiCaseColors.border),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<TheoreticalExamFilters>(
          future: _filtersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _StateView(
                icon: Icons.assignment_outlined,
                title: 'Qlinik soru bankası yükleniyor',
                body: 'Ders ve konu filtreleri hazırlanıyor.',
              );
            }
            if (snapshot.hasError) {
              return _StateView(
                icon: Icons.cloud_off_rounded,
                title: 'Kuramsal sınav açılamadı',
                body: _errorText(snapshot.error),
              );
            }

            final filters = snapshot.requireData;
            final topics = filters.topicsFor(_selectedCourses);
            return ListView(
              padding: EdgeInsets.fromLTRB(20, 12, 20, bottom),
              children: [
                const _IntroCard(),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Ders Seçimi',
                  child: filters.courses.isEmpty
                      ? const Text('Qlinik soru bankasında ders bulunamadı.')
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final course in filters.courses)
                              FilterChip(
                                label: Text(course),
                                selected: _selectedCourses.contains(course),
                                onSelected: (_) => _toggleCourse(course),
                              ),
                          ],
                        ),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Konu ve Soru Sayısı',
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        key: ValueKey(
                          'topic-$_selectedTopic-${topics.join('|').hashCode}',
                        ),
                        initialValue: _selectedTopic,
                        decoration: const InputDecoration(
                          labelText: 'Konu',
                          prefixIcon: Icon(Icons.topic_outlined),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: '',
                            child: Text('Tüm konular'),
                          ),
                          for (final topic in topics)
                            DropdownMenuItem(value: topic, child: Text(topic)),
                        ],
                        onChanged: (value) => setState(() {
                          _selectedTopic = value ?? '';
                          _questionsFuture = null;
                          _selectedQuestionIds.clear();
                        }),
                      ),
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final count in const [10, 20, 40, 60, 100])
                              ChoiceChip(
                                label: Text('$count soru'),
                                selected: _questionCount == count,
                                onSelected: (_) => setState(() {
                                  _questionCount = count;
                                  _questionsFuture = null;
                                  _selectedQuestionIds.clear();
                                }),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _loadQuestions,
                          icon: const Icon(Icons.manage_search_rounded),
                          label: const Text('Soruları Getir'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_questionsFuture != null)
                  FutureBuilder<List<TheoreticalQuestion>>(
                    future: _questionsFuture,
                    builder: (context, questionSnapshot) {
                      if (questionSnapshot.connectionState !=
                          ConnectionState.done) {
                        return const _SectionCard(
                          title: 'Sorular',
                          child: _InlineLoading(text: 'Sorular hazırlanıyor'),
                        );
                      }
                      if (questionSnapshot.hasError) {
                        return _SectionCard(
                          title: 'Sorular',
                          child: Text(_errorText(questionSnapshot.error)),
                        );
                      }
                      final questions =
                          questionSnapshot.data ??
                          const <TheoreticalQuestion>[];
                      if (questions.isEmpty) {
                        return const _SectionCard(
                          title: 'Sorular',
                          child: Text(
                            'Bu seçim için Qlinik soru bankasında soru bulunamadı.',
                          ),
                        );
                      }
                      return _QuestionPickerCard(
                        questions: questions,
                        selectedIds: _selectedQuestionIds,
                        onToggle: (id) => setState(() {
                          if (!_selectedQuestionIds.add(id)) {
                            _selectedQuestionIds.remove(id);
                          }
                        }),
                        onSelectAll: () => setState(() {
                          _selectedQuestionIds
                            ..clear()
                            ..addAll(questions.map((question) => question.id));
                        }),
                        onClear: () => setState(_selectedQuestionIds.clear),
                        onStart: () => _startExam(questions),
                      );
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class TheoreticalExamSessionScreen extends StatefulWidget {
  const TheoreticalExamSessionScreen({required this.questions, super.key});

  final List<TheoreticalQuestion> questions;

  @override
  State<TheoreticalExamSessionScreen> createState() =>
      _TheoreticalExamSessionScreenState();
}

class _TheoreticalExamSessionScreenState
    extends State<TheoreticalExamSessionScreen> {
  final Map<String, String> _answers = <String, String>{};
  late final DateTime _startedAt;
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  int _index = 0;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_finished) {
        setState(() => _elapsed = DateTime.now().difference(_startedAt));
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _select(String optionId) {
    if (_finished) return;
    setState(() => _answers[question.id] = optionId);
  }

  TheoreticalQuestion get question => widget.questions[_index];

  Future<void> _finish() async {
    final unanswered = widget.questions.length - _answers.length;
    if (unanswered > 0) {
      final shouldFinish = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Denemeyi bitir?'),
          content: Text(
            '$unanswered soru boş. Yine de bitirmek istiyor musun?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Devam Et'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Bitir'),
            ),
          ],
        ),
      );
      if (shouldFinish != true) return;
    }
    setState(() {
      _finished = true;
      _elapsed = DateTime.now().difference(_startedAt);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) {
      return _TheoreticalResultView(
        attempt: TheoreticalExamAttempt(
          questions: widget.questions,
          selectedOptionIds: _answers,
          startedAt: _startedAt,
        ),
        elapsed: _elapsed,
      );
    }

    final bottom = MediaQuery.paddingOf(context).bottom + 18;
    final selectedOption = _answers[question.id];
    return Scaffold(
      backgroundColor: PratiCaseColors.softSurface,
      body: SafeArea(
        child: Column(
          children: [
            _ExamTopBar(
              question: question,
              current: _index + 1,
              total: widget.questions.length,
              elapsed: _elapsed,
              answered: _answers.length,
              onClose: () => Navigator.of(context).maybePop(),
              onFinish: _finish,
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(18, 12, 18, bottom),
                children: [
                  _QuestionCard(question: question),
                  const SizedBox(height: 12),
                  for (final option in question.options) ...[
                    _OptionTile(
                      option: option,
                      selected: selectedOption == option.id,
                      correct: false,
                      wrong: false,
                      reveal: false,
                      onTap: () => _select(option.id),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _index == 0
                            ? null
                            : () => setState(() => _index -= 1),
                        icon: const Icon(Icons.chevron_left_rounded),
                        label: const Text('Önceki'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _index == widget.questions.length - 1
                            ? _finish
                            : () => setState(() => _index += 1),
                        icon: Icon(
                          _index == widget.questions.length - 1
                              ? Icons.flag_rounded
                              : Icons.chevron_right_rounded,
                        ),
                        label: Text(
                          _index == widget.questions.length - 1
                              ? 'Bitir'
                              : 'Sonraki',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: const BoxDecoration(
        gradient: PratiCaseGradients.hero,
        borderRadius: BorderRadius.all(Radius.circular(PratiCaseRadius.xxl)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.school_rounded, color: PratiCaseColors.gold, size: 34),
          const SizedBox(height: 12),
          const Text(
            'Qlinik soru bankasından komite denemesi',
            style: TextStyle(
              color: PratiCaseColors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Dersleri ve konuyu seç, soru sayısını belirle, gelen sorulardan denemene alacaklarını işaretle.',
            style: TextStyle(
              color: PratiCaseColors.white.withValues(alpha: 0.8),
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: PratiCaseColors.navy,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _QuestionPickerCard extends StatelessWidget {
  const _QuestionPickerCard({
    required this.questions,
    required this.selectedIds,
    required this.onToggle,
    required this.onSelectAll,
    required this.onClear,
    required this.onStart,
  });

  final List<TheoreticalQuestion> questions;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggle;
  final VoidCallback onSelectAll;
  final VoidCallback onClear;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Soruları Seç',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${selectedIds.length}/${questions.length} soru seçildi',
                  style: const TextStyle(
                    color: PratiCaseColors.muted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(onPressed: onSelectAll, child: const Text('Tümü')),
              TextButton(onPressed: onClear, child: const Text('Temizle')),
            ],
          ),
          const SizedBox(height: 8),
          for (final question in questions)
            CheckboxListTile(
              value: selectedIds.contains(question.id),
              onChanged: (_) => onToggle(question.id),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: Text(
                question.stem,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text('${question.course} • ${question.topic}'),
            ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: selectedIds.isEmpty ? null : onStart,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Denemeye Başla'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExamTopBar extends StatelessWidget {
  const _ExamTopBar({
    required this.question,
    required this.current,
    required this.total,
    required this.elapsed,
    required this.answered,
    required this.onClose,
    required this.onFinish,
  });

  final TheoreticalQuestion question;
  final int current;
  final int total;
  final Duration elapsed;
  final int answered;
  final VoidCallback onClose;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 12),
      decoration: const BoxDecoration(
        color: PratiCaseColors.white,
        border: Border(bottom: BorderSide(color: PratiCaseColors.border)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Kapat',
              ),
              Expanded(
                child: Text(
                  '$current / $total',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: PratiCaseColors.navy,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton(onPressed: onFinish, child: const Text('Bitir')),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Expanded(child: _MetaPill(text: question.course)),
                const SizedBox(width: 8),
                _MetaPill(text: _difficultyLabel(question.difficulty)),
                const SizedBox(width: 8),
                _MetaPill(text: _formatDuration(elapsed)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
              child: LinearProgressIndicator(
                minHeight: 4,
                value: answered / total,
                backgroundColor: PratiCaseColors.border,
                color: PratiCaseColors.teal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.question});

  final TheoreticalQuestion question;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question.topic,
            style: const TextStyle(
              color: PratiCaseColors.teal,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            question.stem,
            style: const TextStyle(
              color: PratiCaseColors.navy,
              fontSize: 16,
              height: 1.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.option,
    required this.selected,
    required this.correct,
    required this.wrong,
    required this.reveal,
    required this.onTap,
  });

  final TheoreticalQuestionOption option;
  final bool selected;
  final bool correct;
  final bool wrong;
  final bool reveal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = correct
        ? PratiCaseColors.successGreen
        : wrong
        ? PratiCaseColors.errorRed
        : selected
        ? PratiCaseColors.teal
        : null;
    return InkWell(
      onTap: reveal ? null : onTap,
      borderRadius: BorderRadius.circular(PratiCaseRadius.lg),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: accent == null
              ? PratiCaseColors.white
              : accent.withValues(alpha: correct ? 0.10 : 0.08),
          borderRadius: BorderRadius.circular(PratiCaseRadius.lg),
          border: Border.all(
            color: accent ?? PratiCaseColors.border,
            width: accent == null ? 1 : 1.6,
          ),
          boxShadow: [
            BoxShadow(
              color: PratiCaseColors.navy.withValues(alpha: 0.035),
              blurRadius: 14,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: (accent ?? PratiCaseColors.muted).withValues(
                  alpha: accent == null ? 0.10 : 0.16,
                ),
                borderRadius: BorderRadius.circular(PratiCaseRadius.sm),
              ),
              child: Text(
                option.label,
                style: TextStyle(
                  color: accent ?? PratiCaseColors.muted,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                option.text,
                style: const TextStyle(
                  color: PratiCaseColors.ink,
                  height: 1.38,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (correct || wrong) ...[
              const SizedBox(width: 8),
              Icon(
                correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: accent,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TheoreticalResultView extends StatelessWidget {
  const _TheoreticalResultView({required this.attempt, required this.elapsed});

  final TheoreticalExamAttempt attempt;
  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PratiCaseColors.softSurface,
      appBar: AppBar(
        title: const Text(
          'Kuramsal Sınav Sonucu',
          style: TextStyle(
            color: PratiCaseColors.navy,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: PratiCaseColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        iconTheme: const IconThemeData(color: PratiCaseColors.navy),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: PratiCaseColors.border),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Kapat',
              style: TextStyle(color: PratiCaseColors.teal),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.paddingOf(context).bottom + 24,
        ),
        children: [
          _ScoreCard(attempt: attempt, elapsed: elapsed),
          const SizedBox(height: 14),
          for (final question in attempt.questions) ...[
            _ReviewQuestionCard(
              question: question,
              selectedOptionId: attempt.selectedOptionIds[question.id],
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.attempt, required this.elapsed});

  final TheoreticalExamAttempt attempt;
  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: const BoxDecoration(
        gradient: PratiCaseGradients.hero,
        borderRadius: BorderRadius.all(Radius.circular(PratiCaseRadius.xxl)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Deneme skoru',
            style: TextStyle(
              color: PratiCaseColors.white.withValues(alpha: 0.8),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '%${attempt.percent}',
            style: const TextStyle(
              color: PratiCaseColors.white,
              fontSize: 52,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ResultPill(text: '${attempt.correctCount} doğru'),
              _ResultPill(text: '${attempt.answeredCount} cevaplandı'),
              _ResultPill(text: _formatDuration(elapsed)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewQuestionCard extends StatelessWidget {
  const _ReviewQuestionCard({
    required this.question,
    required this.selectedOptionId,
  });

  final TheoreticalQuestion question;
  final String? selectedOptionId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question.topic,
            style: const TextStyle(
              color: PratiCaseColors.teal,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            question.stem,
            style: const TextStyle(
              color: PratiCaseColors.ink,
              height: 1.4,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          for (final option in question.options) ...[
            _OptionTile(
              option: option,
              selected: selectedOptionId == option.id,
              correct: question.correctOptionId == option.id,
              wrong:
                  selectedOptionId == option.id &&
                  question.correctOptionId != option.id,
              reveal: true,
              onTap: () {},
            ),
            const SizedBox(height: 8),
          ],
          if (question.explanation.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              question.explanation,
              style: const TextStyle(
                color: PratiCaseColors.muted,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: PratiCaseColors.softSurface,
        borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
      ),
      child: Text(
        text.isEmpty ? '-' : text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: PratiCaseColors.muted,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ResultPill extends StatelessWidget {
  const _ResultPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: PratiCaseColors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
        border: Border.all(color: PratiCaseColors.white.withValues(alpha: 0.22)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: PratiCaseColors.white,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _InlineLoading extends StatelessWidget {
  const _InlineLoading({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _StateView extends StatelessWidget {
  const _StateView({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        Icon(icon, color: PratiCaseColors.teal, size: 44),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: PratiCaseColors.navy,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: PratiCaseColors.muted,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: PratiCaseColors.white,
    borderRadius: BorderRadius.circular(PratiCaseRadius.xl),
    border: Border.all(color: PratiCaseColors.border),
    boxShadow: PratiCaseShadows.card,
  );
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  final hours = duration.inHours;
  if (hours > 0) return '$hours:$minutes:$seconds';
  return '$minutes:$seconds';
}

String _difficultyLabel(String value) {
  switch (value) {
    case 'easy':
      return 'Kolay';
    case 'medium':
      return 'Orta';
    case 'hard':
      return 'Zor';
    default:
      return value.isEmpty ? '-' : value;
  }
}

String _errorText(Object? error) {
  final text = error?.toString() ?? '';
  if (text.trim().isEmpty) return 'Canlı veri bağlantısı kurulamadı.';
  return text
      .replaceFirst('Exception: ', '')
      .replaceFirst('TheoreticalExamUnavailable: ', '');
}
