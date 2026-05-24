import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/praticase_colors.dart';
import '../../../app/theme/praticase_tokens.dart';
import '../../../shared/ui/responsive.dart';
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
  static const _defaultCourseQuestionCount = 10;
  static const _maxSelectedCourseCount = 20;
  static const _maxTotalQuestionCount = 100;

  late Future<TheoreticalExamFilters> _filtersFuture;
  final Set<String> _selectedCourses = <String>{};
  final Map<String, int> _questionCountsByCourse = <String, int>{};
  final Map<String, Set<String>> _selectedTopicKeysByCourse =
      <String, Set<String>>{};
  bool _loadingQuestions = false;

  @override
  void initState() {
    super.initState();
    _filtersFuture = widget.repository.loadFilters();
  }

  Future<void> _refresh() async {
    setState(() {
      _filtersFuture = widget.repository.loadFilters();
    });
    await _filtersFuture;
  }

  void _toggleCourse(String course) {
    final isSelected = _selectedCourses.contains(course);
    if (!isSelected && _selectedCourses.length >= _maxSelectedCourseCount) {
      _showMessage('En fazla $_maxSelectedCourseCount ders seçebilirsin.');
      return;
    }
    final remainingQuestionSlot = _maxTotalQuestionCount - _totalQuestionCount;
    if (!isSelected && remainingQuestionSlot <= 0) {
      _showMessage(
        'Toplam soru sayısı en fazla $_maxTotalQuestionCount olabilir.',
      );
      return;
    }
    setState(() {
      if (isSelected) {
        _selectedCourses.remove(course);
        _questionCountsByCourse.remove(course);
        _selectedTopicKeysByCourse.remove(course);
      } else {
        _selectedCourses.add(course);
        _questionCountsByCourse[course] = _defaultCourseQuestionCount
            .clamp(1, remainingQuestionSlot)
            .toInt();
      }
    });
  }

  void _setCourseQuestionCount(String course, int count) {
    final selectedTopicCount = _selectedTopicKeysByCourse[course]?.length ?? 0;
    final normalized = count.clamp(1, _maxTotalQuestionCount).toInt();
    if (normalized < selectedTopicCount) {
      _showMessage(
        '$course için $selectedTopicCount konu seçili; soru sayısı bundan az olamaz.',
      );
      return;
    }
    final current = _questionCountsByCourse[course] ?? 0;
    final nextTotal = _totalQuestionCount - current + normalized;
    if (nextTotal > _maxTotalQuestionCount) {
      _showMessage(
        'Toplam soru sayısı en fazla $_maxTotalQuestionCount olabilir.',
      );
      return;
    }
    setState(() => _questionCountsByCourse[course] = normalized);
  }

  void _toggleTopic(String course, TheoreticalTopicOption topic) {
    final selectedKeys = _selectedTopicKeysByCourse.putIfAbsent(
      course,
      () => <String>{},
    );
    final isSelected = selectedKeys.contains(topic.key);
    final questionCount =
        _questionCountsByCourse[course] ?? _defaultCourseQuestionCount;
    if (!isSelected && selectedKeys.length >= questionCount) {
      _showMessage(
        '$course için $questionCount soru seçili; en fazla $questionCount konu seçebilirsin.',
      );
      return;
    }
    setState(() {
      if (isSelected) {
        selectedKeys.remove(topic.key);
      } else {
        selectedKeys.add(topic.key);
      }
    });
  }

  List<TheoreticalCoursePlan> _plansFor(TheoreticalExamFilters filters) {
    return [
      for (final course in _selectedCourses)
        TheoreticalCoursePlan(
          course: course,
          questionCount:
              _questionCountsByCourse[course] ?? _defaultCourseQuestionCount,
          topics: [
            for (final topic in filters.topicOptionsFor(course))
              if ((_selectedTopicKeysByCourse[course] ?? const <String>{})
                  .contains(topic.key))
                topic,
          ],
        ),
    ];
  }

  int get _totalQuestionCount => _selectedCourses.fold<int>(
    0,
    (total, course) =>
        total +
        (_questionCountsByCourse[course] ?? _defaultCourseQuestionCount),
  );

  Future<void> _startGeneratedExam(TheoreticalExamFilters filters) async {
    if (_selectedCourses.isEmpty) {
      _showMessage('En az bir ders seçmelisin.');
      return;
    }
    final plans = _plansFor(filters);
    final totalQuestionCount = plans.fold<int>(
      0,
      (total, plan) => total + plan.questionCount,
    );
    if (totalQuestionCount > _maxTotalQuestionCount) {
      _showMessage(
        'Toplam soru sayısı en fazla $_maxTotalQuestionCount olabilir.',
      );
      return;
    }
    setState(() => _loadingQuestions = true);
    try {
      final questions = await widget.repository.loadQuestions(
        courses: _selectedCourses,
        plans: plans,
        limit: totalQuestionCount,
      );
      if (!mounted) return;
      setState(() => _loadingQuestions = false);
      if (questions.isEmpty) {
        _showMessage(
          'Bu seçim için Qlinik soru bankasında tekrar etmeyen soru bulunamadı.',
        );
        return;
      }
      if (questions.length < totalQuestionCount) {
        _showMessage(
          'Qlinik bu seçim için ${questions.length}/$totalQuestionCount tekrar etmeyen soru verdi.',
        );
      }
      _openExam(questions);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _loadingQuestions = false);
      _showMessage(_errorText(error));
    }
  }

  void _openExam(List<TheoreticalQuestion> questions) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TheoreticalExamSessionScreen(
          repository: widget.repository,
          questions: questions,
        ),
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
    return Scaffold(
      backgroundColor: PratiCaseColors.softSurface,
      appBar: AppBar(
        title: const Text(
          'Teorik Sınav',
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
                title: 'Teorik sınav açılamadı',
                body: _errorText(snapshot.error),
              );
            }

            final filters = snapshot.requireData;
            final plans = _plansFor(filters);
            final totalQuestionCount = plans.fold<int>(
              0,
              (total, plan) => total + plan.questionCount,
            );
            return PratiCaseResponsiveListView(
              padding: PratiCaseResponsive.pagePadding(
                context,
                top: 12,
                includeNavigationReserve: false,
              ),
              children: [
                const _IntroCard(),
                const SizedBox(height: 16),
                _SharedQuotaCard(
                  remaining: filters.remainingQuestionCount,
                  total: filters.totalQuestionCount,
                ),
                const SizedBox(height: 12),
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
                  title: 'Ders Planı',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_selectedCourses.isEmpty)
                        const Text(
                          'Sınav planı için önce ders seç. Her dersin soru sayısı ayrı belirlenir.',
                        )
                      else
                        for (final course in _selectedCourses) ...[
                          _CoursePlanEditor(
                            course: course,
                            questionCount:
                                _questionCountsByCourse[course] ??
                                _defaultCourseQuestionCount,
                            topicOptions: filters.topicOptionsFor(course),
                            selectedTopicKeys:
                                _selectedTopicKeysByCourse[course] ??
                                const <String>{},
                            onQuestionCountChanged: (count) =>
                                _setCourseQuestionCount(course, count),
                            onTopicToggled: (topic) =>
                                _toggleTopic(course, topic),
                          ),
                          const SizedBox(height: 12),
                        ],
                      _PlanSummary(
                        selectedCourseCount: _selectedCourses.length,
                        totalQuestionCount: totalQuestionCount,
                        maxQuestionCount: _maxTotalQuestionCount,
                        maxCourseCount: _maxSelectedCourseCount,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _loadingQuestions
                              ? null
                              : () => _startGeneratedExam(filters),
                          icon: _loadingQuestions
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.play_arrow_rounded),
                          label: Text(
                            _loadingQuestions
                                ? 'Sınav Hazırlanıyor'
                                : 'Denemeyi Başlat',
                          ),
                        ),
                      ),
                    ],
                  ),
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
  const TheoreticalExamSessionScreen({
    required this.repository,
    required this.questions,
    super.key,
  });

  final TheoreticalExamRepository repository;
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
  Future<TheoreticalExamSubmissionResult>? _submissionFuture;

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
    final elapsed = DateTime.now().difference(_startedAt);
    final attempt = TheoreticalExamAttempt(
      questions: widget.questions,
      selectedOptionIds: Map<String, String>.unmodifiable(_answers),
      startedAt: _startedAt,
    );
    setState(() {
      _finished = true;
      _elapsed = elapsed;
      _submissionFuture = widget.repository.submitAttempt(
        attempt: attempt,
        elapsed: elapsed,
      );
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
        submissionFuture: _submissionFuture,
      );
    }

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
              child: PratiCaseResponsiveListView(
                maxWidth: PratiCaseBreakpoints.flowContentMaxWidth,
                padding: PratiCaseResponsive.pagePadding(
                  context,
                  top: 12,
                  includeNavigationReserve: false,
                ),
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
              child: PratiCaseResponsiveFrame(
                maxWidth: PratiCaseBreakpoints.flowContentMaxWidth,
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
          const Icon(
            Icons.school_rounded,
            color: PratiCaseColors.gold,
            size: 34,
          ),
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
            'Dersleri ve konuları seç, toplam soru sayısını belirle, deneme otomatik hazırlansın.',
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

class _CoursePlanEditor extends StatelessWidget {
  const _CoursePlanEditor({
    required this.course,
    required this.questionCount,
    required this.topicOptions,
    required this.selectedTopicKeys,
    required this.onQuestionCountChanged,
    required this.onTopicToggled,
  });

  final String course;
  final int questionCount;
  final List<TheoreticalTopicOption> topicOptions;
  final Set<String> selectedTopicKeys;
  final ValueChanged<int> onQuestionCountChanged;
  final ValueChanged<TheoreticalTopicOption> onTopicToggled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PratiCaseColors.softSurface,
        borderRadius: BorderRadius.circular(PratiCaseRadius.lg),
        border: Border.all(color: PratiCaseColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _CourseTitle(course: course)),
              const SizedBox(width: 10),
              _QuestionStepper(
                value: questionCount,
                onChanged: onQuestionCountChanged,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            selectedTopicKeys.isEmpty
                ? 'Tüm konulardan otomatik seçilecek.'
                : '${selectedTopicKeys.length} konu seçildi. Konu sayısı soru sayısını geçemez.',
            style: const TextStyle(
              color: PratiCaseColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          if (topicOptions.isEmpty)
            const Text('Bu ders için Qlinik konu verisi bulunamadı.')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Tüm konular'),
                  selected: selectedTopicKeys.isEmpty,
                  onSelected: (_) {
                    for (final topic in topicOptions) {
                      if (selectedTopicKeys.contains(topic.key)) {
                        onTopicToggled(topic);
                      }
                    }
                  },
                ),
                for (final topic in topicOptions)
                  Tooltip(
                    message: topic.subtitle.isEmpty
                        ? '${topic.remainingCount} soru kaldı'
                        : '${topic.subtitle} · ${topic.remainingCount} soru kaldı',
                    child: FilterChip(
                      label: Text(topic.title),
                      selected: selectedTopicKeys.contains(topic.key),
                      onSelected: (_) => onTopicToggled(topic),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CourseTitle extends StatelessWidget {
  const _CourseTitle({required this.course});

  final String course;

  @override
  Widget build(BuildContext context) {
    return Text(
      course,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: PratiCaseColors.navy,
        fontSize: 15,
        fontWeight: FontWeight.w900,
        height: 1.2,
      ),
    );
  }
}

class _QuestionStepper extends StatelessWidget {
  const _QuestionStepper({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: PratiCaseColors.white,
        borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
        border: Border.all(color: PratiCaseColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Soru azalt',
            visualDensity: VisualDensity.compact,
            onPressed: () => onChanged(value - 1),
            icon: const Icon(Icons.remove_rounded, size: 18),
          ),
          SizedBox(
            width: 56,
            child: Text(
              '$value soru',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: PratiCaseColors.navy,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Soru artır',
            visualDensity: VisualDensity.compact,
            onPressed: () => onChanged(value + 1),
            icon: const Icon(Icons.add_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _PlanSummary extends StatelessWidget {
  const _PlanSummary({
    required this.selectedCourseCount,
    required this.totalQuestionCount,
    required this.maxQuestionCount,
    required this.maxCourseCount,
  });

  final int selectedCourseCount;
  final int totalQuestionCount;
  final int maxQuestionCount;
  final int maxCourseCount;

  @override
  Widget build(BuildContext context) {
    final text =
        '$selectedCourseCount/$maxCourseCount ders · $totalQuestionCount/$maxQuestionCount soru';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: PratiCaseColors.teal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(PratiCaseRadius.md),
        border: Border.all(color: PratiCaseColors.teal.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          const Icon(Icons.rule_rounded, color: PratiCaseColors.teal, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: PratiCaseColors.navy,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SharedQuotaCard extends StatelessWidget {
  const _SharedQuotaCard({required this.remaining, required this.total});

  final int remaining;
  final int total;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Qlinik Ortak Soru Hakkı',
      child: Row(
        children: [
          const Icon(
            Icons.account_balance_wallet_outlined,
            color: PratiCaseColors.teal,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$remaining/$total tekrar etmeyen soru kullanılabilir. '
              'Teslim edilen soru Qlinik ve PratiCase boyunca yeniden gösterilmez.',
              style: const TextStyle(
                color: PratiCaseColors.navy,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
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
  const _TheoreticalResultView({
    required this.attempt,
    required this.elapsed,
    required this.submissionFuture,
  });

  final TheoreticalExamAttempt attempt;
  final Duration elapsed;
  final Future<TheoreticalExamSubmissionResult>? submissionFuture;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PratiCaseColors.softSurface,
      appBar: AppBar(
        title: const Text(
          'Teorik Sınav Sonucu',
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
      body: PratiCaseResponsiveListView(
        padding: PratiCaseResponsive.pagePadding(
          context,
          top: 12,
          includeNavigationReserve: false,
        ),
        children: [
          _ScoreCard(attempt: attempt, elapsed: elapsed),
          const SizedBox(height: 14),
          _QlinikSyncCard(submissionFuture: submissionFuture),
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

class _QlinikSyncCard extends StatelessWidget {
  const _QlinikSyncCard({required this.submissionFuture});

  final Future<TheoreticalExamSubmissionResult>? submissionFuture;

  @override
  Widget build(BuildContext context) {
    final future = submissionFuture;
    if (future == null) {
      return const _SyncSurface(
        icon: Icons.sync_problem_rounded,
        title: 'Qlinik senkronu beklemede',
        body: 'Yanıtlar sonuç ekranı açıldığında Qlinik ilerlemene işlenir.',
      );
    }
    return FutureBuilder<TheoreticalExamSubmissionResult>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _SyncSurface(
            icon: Icons.sync_rounded,
            title: 'Qlinik ile senkronlanıyor',
            body: 'Çözdüğün sorular Qlinik tekrar havuzundan düşürülüyor.',
          );
        }
        if (snapshot.hasError) {
          return _SyncSurface(
            icon: Icons.sync_problem_rounded,
            title: 'Senkron tamamlanamadı',
            body: _errorText(snapshot.error),
          );
        }
        final result = snapshot.requireData;
        return _SyncSurface(
          icon: result.fullySynced
              ? Icons.verified_rounded
              : Icons.sync_problem_rounded,
          title: result.fullySynced
              ? 'Qlinik ile senkronlandı'
              : 'Kısmi senkron',
          body: result.fullySynced
              ? '${result.syncedCount} yanıt Qlinik ilerlemene işlendi.'
              : '${result.syncedCount}/${result.submittedCount} yanıt işlendi. ${result.errorMessage}',
        );
      },
    );
  }
}

class _SyncSurface extends StatelessWidget {
  const _SyncSurface({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: PratiCaseColors.teal),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: PratiCaseColors.navy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    color: PratiCaseColors.muted,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
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
        border: Border.all(
          color: PratiCaseColors.white.withValues(alpha: 0.22),
        ),
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
    return PratiCaseResponsiveListView(
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
