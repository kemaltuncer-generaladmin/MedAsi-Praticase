import 'package:flutter/material.dart';

import '../../../app/theme/praticase_colors.dart';
import '../data/cases_repository.dart';
import '../domain/osce_case.dart';

class CasesScreen extends StatefulWidget {
  const CasesScreen({required this.repository, super.key});

  final CasesRepository repository;

  @override
  State<CasesScreen> createState() => _CasesScreenState();
}

class _CasesScreenState extends State<CasesScreen> {
  final _searchController = TextEditingController();
  String? _difficulty;
  late Future<List<OsceCaseSummary>> _casesFuture;

  @override
  void initState() {
    super.initState();
    _casesFuture = widget.repository.loadCases();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search() {
    setState(() {
      _casesFuture = widget.repository.loadCases(
        query: _searchController.text,
        difficulty: _difficulty,
      );
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _casesFuture = widget.repository.loadCases(
        query: _searchController.text,
        difficulty: _difficulty,
      );
    });
    await _casesFuture;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<OsceCaseSummary>>(
      future: _casesFuture,
      builder: (context, snapshot) {
        final bottom = MediaQuery.paddingOf(context).bottom + 106;
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(20, 18, 20, bottom),
            children: [
              const _MobileHeader(title: 'PratiCase'),
              const SizedBox(height: 22),
              const _PageTitle(
                title: 'Vakalar',
                subtitle:
                    'Klinik becerini geliştir, vakaları çöz ve puan kazan!',
              ),
              const SizedBox(height: 16),
              _SearchBox(controller: _searchController, onChanged: _search),
              const SizedBox(height: 12),
              const _FilterRail(),
              const SizedBox(height: 18),
              if (snapshot.connectionState != ConnectionState.done)
                const _CenteredState(
                  icon: Icons.hourglass_empty_rounded,
                  title: 'Canlı vakalar yükleniyor',
                  body: 'PratiCase vaka kütüphanesi Supabase’den okunuyor.',
                )
              else if (snapshot.hasError)
                _CenteredState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Canlı veri bağlantısı gerekli',
                  body: _errorText(snapshot.error),
                )
              else if (snapshot.requireData.isEmpty)
                const _CenteredState(
                  icon: Icons.assignment_outlined,
                  title: 'Yayınlanmış vaka yok',
                  body:
                      'praticase.cases tablosunda is_published=true vaka olduğunda burada listelenir.',
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${snapshot.requireData.length} vaka bulundu',
                        style: const TextStyle(
                          color: PratiCaseColors.navy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _openFilters,
                      icon: const Icon(Icons.tune_rounded),
                      label: Text(_difficulty ?? 'Filtrele'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF506178),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final item in snapshot.requireData) ...[
                  _CaseListCard(
                    item: item,
                    onTap: () => _openDetail(context, item.id),
                  ),
                  const SizedBox(height: 14),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  void _openDetail(BuildContext context, String caseId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            CaseDetailScreen(repository: widget.repository, caseId: caseId),
      ),
    );
  }

  Future<void> _openFilters() async {
    final selected = await Navigator.of(context).push<String?>(
      MaterialPageRoute<String?>(
        builder: (_) => CaseSearchFilterScreen(selectedDifficulty: _difficulty),
      ),
    );
    if (!mounted) return;
    setState(() {
      _difficulty = selected;
      _casesFuture = widget.repository.loadCases(
        query: _searchController.text,
        difficulty: _difficulty,
      );
    });
  }
}

class CaseSearchFilterScreen extends StatefulWidget {
  const CaseSearchFilterScreen({required this.selectedDifficulty, super.key});

  final String? selectedDifficulty;

  @override
  State<CaseSearchFilterScreen> createState() => _CaseSearchFilterScreenState();
}

class _CaseSearchFilterScreenState extends State<CaseSearchFilterScreen> {
  String? _difficulty;

  @override
  void initState() {
    super.initState();
    _difficulty = widget.selectedDifficulty;
  }

  @override
  Widget build(BuildContext context) {
    return _FlowScaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: [
          const _StepTopBar(title: 'Arama & Filtreleme'),
          const SizedBox(height: 18),
          const _FormLabel('Zorluk Seviyesi'),
          const SizedBox(height: 12),
          _SegmentScroller(
            items: const ['Kolay', 'Orta', 'Zor'],
            selectedIndex: ['Kolay', 'Orta', 'Zor'].indexOf(_difficulty ?? ''),
            onSelected: (index) {
              setState(() => _difficulty = ['Kolay', 'Orta', 'Zor'][index]);
            },
          ),
          const SizedBox(height: 22),
          _SectionCard(
            title: 'Filtreler',
            child: Column(
              children: [
                _FilterSummaryRow(
                  label: 'Klinik Dal',
                  value: 'Canlı vaka verisine göre',
                ),
                _FilterSummaryRow(
                  label: 'Vaka Türü',
                  value: 'Tüm yayınlanmış vakalar',
                ),
                _FilterSummaryRow(
                  label: 'Süre',
                  value: 'Vaka süresine göre listelenir',
                ),
              ],
            ),
          ),
        ],
      ),
      bottom: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Temizle'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: () => Navigator.pop(context, _difficulty),
              child: const Text('Uygula'),
            ),
          ),
        ],
      ),
    );
  }
}

class CaseDetailScreen extends StatefulWidget {
  const CaseDetailScreen({
    required this.repository,
    required this.caseId,
    super.key,
  });

  final CasesRepository repository;
  final String caseId;

  @override
  State<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends State<CaseDetailScreen> {
  late Future<OsceCaseDetail> _detailFuture;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _detailFuture = widget.repository.loadCaseDetail(widget.caseId);
  }

  Future<void> _start() async {
    setState(() => _starting = true);
    try {
      final session = await widget.repository.startSession(widget.caseId);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => PatientChatScreen(
            repository: widget.repository,
            sessionId: session.id,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _FlowScaffold(
      body: FutureBuilder<OsceCaseDetail>(
        future: _detailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _CenteredState(
              icon: Icons.hourglass_empty_rounded,
              title: 'Vaka hazırlanıyor',
              body: 'Canlı vaka detayları yükleniyor.',
            );
          }
          if (snapshot.hasError) {
            return _CenteredState(
              icon: Icons.cloud_off_rounded,
              title: 'Vaka açılamadı',
              body: _errorText(snapshot.error),
            );
          }
          final detail = snapshot.requireData;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 110),
            children: [
              _StepTopBar(
                title: 'Vaka Detay',
                trailing: IconButton(
                  onPressed: null,
                  icon: Icon(
                    detail.summary.isBookmarked
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color: PratiCaseColors.navy,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ChipTag(label: detail.summary.setting),
                  _ChipTag(label: detail.summary.branch),
                  _ChipTag(
                    label: 'Zorluk: ${detail.summary.difficulty.label}',
                    tone: _difficultyColor(detail.summary.difficulty),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _DetailHero(detail: detail),
              const SizedBox(height: 22),
              _FlowCard(steps: detail.flowSteps),
              const SizedBox(height: 18),
              _PatientInfoCard(patient: detail.patient),
              const SizedBox(height: 18),
              _GoalsCard(goals: detail.goals),
            ],
          );
        },
      ),
      bottom: _BottomAction(
        label: _starting ? 'Başlatılıyor...' : 'Vaka Çözümüne Başla',
        onPressed: _starting ? null : _start,
      ),
    );
  }
}

class PatientChatScreen extends StatefulWidget {
  const PatientChatScreen({
    required this.repository,
    required this.sessionId,
    super.key,
  });

  final CasesRepository repository;
  final String sessionId;

  @override
  State<PatientChatScreen> createState() => _PatientChatScreenState();
}

class _PatientChatScreenState extends State<PatientChatScreen> {
  final _messageController = TextEditingController();
  late Future<_ChatBundle> _bundleFuture;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _bundleFuture = _load();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<_ChatBundle> _load() async {
    final session = await widget.repository.loadSession(widget.sessionId);
    final messages = await widget.repository.loadMessages(widget.sessionId);
    return _ChatBundle(session: session, messages: messages);
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      _messageController.clear();
      await widget.repository.sendPatientQuestion(
        sessionId: widget.sessionId,
        message: text,
      );
      setState(() => _bundleFuture = _load());
      await _bundleFuture;
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _next() async {
    final session = (await _bundleFuture).session;
    await widget.repository.advanceSession(
      sessionId: widget.sessionId,
      step: 'physical_exam',
    );
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PhysicalExamScreen(
          repository: widget.repository,
          sessionId: widget.sessionId,
          caseId: session.caseId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _FlowScaffold(
      resizeToAvoidBottomInset: true,
      body: FutureBuilder<_ChatBundle>(
        future: _bundleFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _CenteredState(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Görüşme açılıyor',
              body: 'Canlı session ve mesajlar yükleniyor.',
            );
          }
          if (snapshot.hasError) {
            return _CenteredState(
              icon: Icons.cloud_off_rounded,
              title: 'Görüşme açılamadı',
              body: _errorText(snapshot.error),
            );
          }
          final bundle = snapshot.requireData;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Column(
                  children: [
                    const _StepTopBar(title: 'PratiCase', step: 1),
                    const SizedBox(height: 12),
                    _PatientBanner(session: bundle.session),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => CaseProgressScreen(
                                  repository: widget.repository,
                                  sessionId: widget.sessionId,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.timeline_rounded),
                            label: const Text('Vaka İlerlemesi'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => AddNoteScreen(
                                  repository: widget.repository,
                                  caseId: bundle.session.caseId,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.note_add_outlined),
                            label: const Text('Not Ekle'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  children: [
                    if (bundle.messages.isEmpty)
                      _ChatBubble(
                        message: bundle.session.patient.openingLine,
                        fromCandidate: false,
                      )
                    else
                      for (final message in bundle.messages)
                        _ChatBubble(
                          message: message.message,
                          fromCandidate: message.fromCandidate,
                        ),
                  ],
                ),
              ),
              _ChatComposer(
                controller: _messageController,
                sending: _sending,
                onSend: _send,
                onNext: _next,
              ),
            ],
          );
        },
      ),
    );
  }
}

class PhysicalExamScreen extends StatefulWidget {
  const PhysicalExamScreen({
    required this.repository,
    required this.sessionId,
    required this.caseId,
    super.key,
  });

  final CasesRepository repository;
  final String sessionId;
  final String caseId;

  @override
  State<PhysicalExamScreen> createState() => _PhysicalExamScreenState();
}

class _PhysicalExamScreenState extends State<PhysicalExamScreen> {
  late Future<_PhysicalBundle> _bundleFuture;
  String? _selectedGroupId;

  @override
  void initState() {
    super.initState();
    _bundleFuture = _load();
  }

  Future<_PhysicalBundle> _load() async {
    final groups = await widget.repository.loadPhysicalExamGroups(
      widget.caseId,
    );
    final options = await widget.repository.loadPhysicalExamOptions(
      sessionId: widget.sessionId,
      caseId: widget.caseId,
    );
    return _PhysicalBundle(groups: groups, options: options);
  }

  Future<void> _select(String optionId) async {
    await widget.repository.selectPhysicalExam(
      sessionId: widget.sessionId,
      optionId: optionId,
    );
    setState(() => _bundleFuture = _load());
  }

  Future<void> _next() async {
    await widget.repository.advanceSession(
      sessionId: widget.sessionId,
      step: 'tests',
    );
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TestsScreen(
          repository: widget.repository,
          sessionId: widget.sessionId,
          caseId: widget.caseId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _FlowScaffold(
      body: FutureBuilder<_PhysicalBundle>(
        future: _bundleFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _CenteredState(
              icon: Icons.health_and_safety_outlined,
              title: 'Muayene seçenekleri yükleniyor',
              body: 'Canlı bulgu listesi Supabase’den okunuyor.',
            );
          }
          if (snapshot.hasError) {
            return _CenteredState(
              icon: Icons.cloud_off_rounded,
              title: 'Muayene açılamadı',
              body: _errorText(snapshot.error),
            );
          }
          final bundle = snapshot.requireData;
          final groupId =
              _selectedGroupId ??
              (bundle.groups.isNotEmpty ? bundle.groups.first.id : null);
          final visible = bundle.options
              .where((item) => item.groupId == groupId)
              .toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            children: [
              const _StepTopBar(title: 'Fizik Muayene', step: 2),
              const SizedBox(height: 18),
              const Text(
                'Sistem seçerek muayene edin.',
                style: TextStyle(
                  color: Color(0xFF4F5E72),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              _SegmentScroller(
                items: bundle.groups.map((item) => item.title).toList(),
                selectedIndex: bundle.groups.indexWhere(
                  (item) => item.id == groupId,
                ),
                onSelected: (index) {
                  setState(() => _selectedGroupId = bundle.groups[index].id);
                },
              ),
              const SizedBox(height: 18),
              const _BodyMapCard(),
              const SizedBox(height: 18),
              _FindingsCard(options: visible, onSelect: _select),
            ],
          );
        },
      ),
      bottom: _BottomAction(label: 'Devam Et', onPressed: _next),
    );
  }
}

class TestsScreen extends StatefulWidget {
  const TestsScreen({
    required this.repository,
    required this.sessionId,
    required this.caseId,
    super.key,
  });

  final CasesRepository repository;
  final String sessionId;
  final String caseId;

  @override
  State<TestsScreen> createState() => _TestsScreenState();
}

class _TestsScreenState extends State<TestsScreen> {
  late Future<_TestsBundle> _bundleFuture;
  String? _selectedGroupId;

  @override
  void initState() {
    super.initState();
    _bundleFuture = _load();
  }

  Future<_TestsBundle> _load() async {
    final session = await widget.repository.loadSession(widget.sessionId);
    final groups = await widget.repository.loadTestGroups(widget.caseId);
    final options = await widget.repository.loadTestOptions(
      sessionId: widget.sessionId,
      caseId: widget.caseId,
    );
    return _TestsBundle(session: session, groups: groups, options: options);
  }

  Future<void> _request(String optionId) async {
    await widget.repository.requestTest(
      sessionId: widget.sessionId,
      optionId: optionId,
    );
    setState(() => _bundleFuture = _load());
  }

  Future<void> _next() async {
    await widget.repository.advanceSession(
      sessionId: widget.sessionId,
      step: 'diagnosis',
    );
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DiagnosisScreen(
          repository: widget.repository,
          sessionId: widget.sessionId,
          caseId: widget.caseId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _FlowScaffold(
      body: FutureBuilder<_TestsBundle>(
        future: _bundleFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _CenteredState(
              icon: Icons.science_outlined,
              title: 'Tetkikler yükleniyor',
              body: 'Canlı tetkik listesi Supabase’den okunuyor.',
            );
          }
          if (snapshot.hasError) {
            return _CenteredState(
              icon: Icons.cloud_off_rounded,
              title: 'Tetkik ekranı açılamadı',
              body: _errorText(snapshot.error),
            );
          }
          final bundle = snapshot.requireData;
          final groupId =
              _selectedGroupId ??
              (bundle.groups.isNotEmpty ? bundle.groups.first.id : null);
          final visible = bundle.options
              .where((item) => item.groupId == groupId)
              .toList();
          final selectedCount = bundle.options
              .where((item) => item.isSelected)
              .length;
          final selectedCost = bundle.options
              .where((item) => item.isSelected)
              .fold<int>(0, (sum, item) => sum + item.pointCost);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            children: [
              _StepTopBar(
                title: 'Tetkik İsteme',
                step: 3,
                subtitle:
                    'Bütçe Puanı ${bundle.session.remainingPoints} / ${bundle.session.budgetPoints}',
              ),
              const SizedBox(height: 18),
              _SegmentScroller(
                items: bundle.groups.map((item) => item.title).toList(),
                selectedIndex: bundle.groups.indexWhere(
                  (item) => item.id == groupId,
                ),
                onSelected: (index) {
                  setState(() => _selectedGroupId = bundle.groups[index].id);
                },
              ),
              const SizedBox(height: 18),
              for (final item in visible) ...[
                _TestOptionTile(
                  item: item,
                  onTap: () => _request(item.id),
                  onOpenDetail: () => _openTestDetail(item),
                ),
                const SizedBox(height: 10),
              ],
              if (visible.isEmpty)
                const _CenteredState(
                  icon: Icons.science_outlined,
                  title: 'Bu kategoride tetkik yok',
                  body: 'Canlı tetkik seçenekleri eklendiğinde burada görünür.',
                ),
              const SizedBox(height: 18),
              _SelectionSummary(
                text: 'İstem Listem ($selectedCount)',
                subtext: '$selectedCost puan',
              ),
            ],
          );
        },
      ),
      bottom: _BottomAction(label: 'Devam Et', onPressed: _next),
    );
  }

  void _openTestDetail(TestOption item) {
    final lower = item.title.toLowerCase();
    if (lower.contains('usg') ||
        lower.contains('bt') ||
        lower.contains('mr') ||
        lower.contains('röntgen') ||
        lower.contains('grafi')) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ImagingResultScreen(
            repository: widget.repository,
            testOptionId: item.id,
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LabResultScreen(
          repository: widget.repository,
          testOptionId: item.id,
        ),
      ),
    );
  }
}

class DiagnosisScreen extends StatefulWidget {
  const DiagnosisScreen({
    required this.repository,
    required this.sessionId,
    required this.caseId,
    super.key,
  });

  final CasesRepository repository;
  final String sessionId;
  final String caseId;

  @override
  State<DiagnosisScreen> createState() => _DiagnosisScreenState();
}

class _DiagnosisScreenState extends State<DiagnosisScreen> {
  final _primaryController = TextEditingController();
  final _reasoningController = TextEditingController();
  late Future<_DiagnosisBundle> _bundleFuture;
  final _selected = <String>{};

  @override
  void initState() {
    super.initState();
    _bundleFuture = _load();
  }

  @override
  void dispose() {
    _primaryController.dispose();
    _reasoningController.dispose();
    super.dispose();
  }

  Future<_DiagnosisBundle> _load() async {
    final session = await widget.repository.loadSession(widget.sessionId);
    final answer = await widget.repository.loadDiagnosisAnswer(
      widget.sessionId,
    );
    final options = await widget.repository.loadDiagnosisOptions(
      sessionId: widget.sessionId,
      caseId: widget.caseId,
    );
    _primaryController.text = answer?.primaryDiagnosis ?? '';
    _reasoningController.text = answer?.reasoning ?? '';
    _selected
      ..clear()
      ..addAll(answer?.selectedOptionIds ?? const []);
    return _DiagnosisBundle(session: session, options: options);
  }

  Future<void> _save() async {
    await widget.repository.saveDiagnosisAnswer(
      sessionId: widget.sessionId,
      primaryDiagnosis: _primaryController.text,
      selectedOptionIds: _selected.toList(),
      reasoning: _reasoningController.text,
    );
    await widget.repository.advanceSession(
      sessionId: widget.sessionId,
      step: 'management',
    );
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ManagementPlanScreen(
          repository: widget.repository,
          sessionId: widget.sessionId,
          caseId: widget.caseId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _FlowScaffold(
      resizeToAvoidBottomInset: true,
      body: FutureBuilder<_DiagnosisBundle>(
        future: _bundleFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _CenteredState(
              icon: Icons.fact_check_outlined,
              title: 'Tanı ekranı yükleniyor',
              body: 'Canlı tanı seçenekleri hazırlanıyor.',
            );
          }
          if (snapshot.hasError) {
            return _CenteredState(
              icon: Icons.cloud_off_rounded,
              title: 'Tanı ekranı açılamadı',
              body: _errorText(snapshot.error),
            );
          }
          final bundle = snapshot.requireData;
          return ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 130),
            children: [
              _StepTopBar(
                title: 'Tanı ve Ayırıcı Tanı',
                step: 4,
                subtitle:
                    'Kalan Puan ${bundle.session.remainingPoints} / ${bundle.session.budgetPoints}',
              ),
              const SizedBox(height: 18),
              _InputBlock(
                label: 'En olası tanınız nedir?',
                controller: _primaryController,
                hint: 'Tanı yazın',
                maxLines: 1,
              ),
              const SizedBox(height: 16),
              const _FormLabel('Ayırıcı Tanılarınızı seçin'),
              const SizedBox(height: 8),
              for (final option in bundle.options) ...[
                _DiagnosisTile(
                  title: option.title,
                  selected: _selected.contains(option.id),
                  onChanged: (value) {
                    setState(() {
                      if (value) {
                        _selected.add(option.id);
                      } else {
                        _selected.remove(option.id);
                      }
                    });
                  },
                ),
                const SizedBox(height: 8),
              ],
              if (bundle.options.isEmpty)
                const _CenteredState(
                  icon: Icons.fact_check_outlined,
                  title: 'Tanı seçeneği yok',
                  body:
                      'praticase.diagnosis_options verisi eklendiğinde burada görünür.',
                ),
              const SizedBox(height: 14),
              _InputBlock(
                label: 'Tanı gerekçenizi yazın',
                controller: _reasoningController,
                hint: 'Klinik bulgular ve laboratuvar sonuçlarını özetleyin.',
                maxLines: 6,
              ),
            ],
          );
        },
      ),
      bottom: _BottomAction(label: 'Devam Et', onPressed: _save),
    );
  }
}

class ManagementPlanScreen extends StatefulWidget {
  const ManagementPlanScreen({
    required this.repository,
    required this.sessionId,
    required this.caseId,
    super.key,
  });

  final CasesRepository repository;
  final String sessionId;
  final String caseId;

  @override
  State<ManagementPlanScreen> createState() => _ManagementPlanScreenState();
}

class _ManagementPlanScreenState extends State<ManagementPlanScreen> {
  final _diagnosisController = TextEditingController();
  final _noteController = TextEditingController();
  late Future<_ManagementBundle> _bundleFuture;
  final _selected = <String>{};

  @override
  void initState() {
    super.initState();
    _bundleFuture = _load();
  }

  @override
  void dispose() {
    _diagnosisController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<_ManagementBundle> _load() async {
    final session = await widget.repository.loadSession(widget.sessionId);
    final answer = await widget.repository.loadManagementPlan(widget.sessionId);
    final options = await widget.repository.loadManagementOptions(
      sessionId: widget.sessionId,
      caseId: widget.caseId,
    );
    _diagnosisController.text = answer?.diagnosis ?? '';
    _noteController.text = answer?.note ?? '';
    _selected
      ..clear()
      ..addAll(answer?.selectedOptionIds ?? const []);
    return _ManagementBundle(session: session, options: options);
  }

  Future<void> _save() async {
    await widget.repository.saveManagementPlan(
      sessionId: widget.sessionId,
      diagnosis: _diagnosisController.text,
      selectedOptionIds: _selected.toList(),
      note: _noteController.text,
    );
    await widget.repository.advanceSession(
      sessionId: widget.sessionId,
      step: 'completed',
    );
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ResultScreen(
          repository: widget.repository,
          sessionId: widget.sessionId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _FlowScaffold(
      resizeToAvoidBottomInset: true,
      body: FutureBuilder<_ManagementBundle>(
        future: _bundleFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _CenteredState(
              icon: Icons.assignment_turned_in_outlined,
              title: 'Yönetim planı yükleniyor',
              body: 'Canlı tedavi seçenekleri hazırlanıyor.',
            );
          }
          if (snapshot.hasError) {
            return _CenteredState(
              icon: Icons.cloud_off_rounded,
              title: 'Yönetim planı açılamadı',
              body: _errorText(snapshot.error),
            );
          }
          final bundle = snapshot.requireData;
          final grouped = <String, List<ManagementOption>>{};
          for (final option in bundle.options) {
            grouped.putIfAbsent(option.category, () => []).add(option);
          }
          return ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 130),
            children: [
              const _StepTopBar(title: 'Tedavi / Yönetim Planı', step: 5),
              const SizedBox(height: 18),
              _InputBlock(
                label: 'Tanınız',
                controller: _diagnosisController,
                hint: 'Tanınızı yazın',
                maxLines: 1,
              ),
              const SizedBox(height: 18),
              const Text(
                'Tedavi Planınızı Oluşturun',
                style: TextStyle(
                  color: PratiCaseColors.navy,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Hastaya yönelik uygun tedavi ve yönetim planınızı seçin.',
                style: TextStyle(
                  color: Color(0xFF66758A),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              if (grouped.isEmpty)
                const _CenteredState(
                  icon: Icons.assignment_outlined,
                  title: 'Tedavi seçeneği yok',
                  body:
                      'praticase.management_plan_options verisi eklendiğinde burada görünür.',
                )
              else
                for (final entry in grouped.entries) ...[
                  _ManagementGroupCard(
                    title: entry.key,
                    options: entry.value,
                    selected: _selected,
                    onChanged: (optionId, selected) {
                      setState(() {
                        if (selected) {
                          _selected.add(optionId);
                        } else {
                          _selected.remove(optionId);
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                ],
              _InputBlock(
                label: 'Planınızı kısaca açıklayın',
                controller: _noteController,
                hint: 'Yönetim planınızı klinik gerekçesiyle yazın.',
                maxLines: 5,
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MedicationInfoScreen(
                      repository: widget.repository,
                      caseId: widget.caseId,
                    ),
                  ),
                ),
                icon: const Icon(Icons.medication_outlined),
                label: const Text('İlaç / Tedavi Bilgisi'),
              ),
            ],
          );
        },
      ),
      bottom: _BottomAction(
        label: 'Planı Kaydet ve Devam Et',
        onPressed: _save,
      ),
    );
  }
}

class ResultScreen extends StatelessWidget {
  const ResultScreen({
    required this.repository,
    required this.sessionId,
    super.key,
  });

  final CasesRepository repository;
  final String sessionId;

  @override
  Widget build(BuildContext context) {
    return _FlowScaffold(
      body: FutureBuilder<ExamResultSummary>(
        future: repository.loadResult(sessionId),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _CenteredState(
              icon: Icons.emoji_events_outlined,
              title: 'Sonuç karnesi hazırlanıyor',
              body: 'Canlı puanlama verisi yükleniyor.',
            );
          }
          if (snapshot.hasError) {
            return _CenteredState(
              icon: Icons.cloud_off_rounded,
              title: 'Sonuç karnesi açılamadı',
              body: _errorText(snapshot.error),
            );
          }
          final result = snapshot.requireData;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 130),
            children: [
              _ResultHero(result: result),
              const SizedBox(height: 18),
              _ScoreGrid(scores: result.categoryScores),
              const SizedBox(height: 18),
              _FeedbackCard(
                title: 'Güçlü Yönlerin',
                icon: Icons.verified_rounded,
                color: const Color(0xFF2AA765),
                items: result.strongPoints,
              ),
              const SizedBox(height: 14),
              _FeedbackCard(
                title: 'Gelişim Alanların',
                icon: Icons.warning_amber_rounded,
                color: PratiCaseColors.gold,
                items: result.improvementPoints,
              ),
              const SizedBox(height: 18),
              _BottomAction(
                label: 'Vaka Raporunu İncele',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CaseReportScreen(result: result),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class CaseReportScreen extends StatelessWidget {
  const CaseReportScreen({required this.result, super.key});

  final ExamResultSummary result;

  @override
  Widget build(BuildContext context) {
    return _FlowScaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          const _StepTopBar(title: 'Vaka Raporu'),
          const SizedBox(height: 18),
          _SectionCard(
            title: result.caseTitle,
            child: Row(
              children: [
                Expanded(
                  child: _ReportMetric(
                    label: 'Performans Testi',
                    value: '${result.totalScore}/${result.maxScore}',
                  ),
                ),
                Expanded(
                  child: _ReportMetric(
                    label: 'Doğru Oranı',
                    value: '%${result.percentage}',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _ScoreGrid(scores: result.categoryScores),
          const SizedBox(height: 14),
          _FeedbackCard(
            title: 'Güçlü Yönlerin',
            icon: Icons.verified_rounded,
            color: const Color(0xFF2AA765),
            items: result.strongPoints,
          ),
          const SizedBox(height: 14),
          _FeedbackCard(
            title: 'Gelişim Alanların',
            icon: Icons.warning_amber_rounded,
            color: PratiCaseColors.gold,
            items: result.improvementPoints,
          ),
        ],
      ),
    );
  }
}

class LabResultScreen extends StatelessWidget {
  const LabResultScreen({
    required this.repository,
    required this.testOptionId,
    super.key,
  });

  final CasesRepository repository;
  final String testOptionId;

  @override
  Widget build(BuildContext context) {
    return _FlowScaffold(
      body: FutureBuilder<LabResultDetail?>(
        future: repository.loadLabResult(testOptionId),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _CenteredState(
              icon: Icons.biotech_outlined,
              title: 'Laboratuvar sonucu yükleniyor',
              body: 'Canlı tetkik detayı Supabase’den okunuyor.',
            );
          }
          if (snapshot.hasError) {
            return _CenteredState(
              icon: Icons.cloud_off_rounded,
              title: 'Laboratuvar sonucu açılamadı',
              body: _errorText(snapshot.error),
            );
          }
          final detail = snapshot.data;
          if (detail == null) {
            return const _CenteredState(
              icon: Icons.biotech_outlined,
              title: 'Laboratuvar detayı yok',
              body: 'Bu tetkik için canlı lab_result_details kaydı bulunamadı.',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              _StepTopBar(title: detail.title),
              const SizedBox(height: 18),
              _SectionCard(
                title: 'Parametreler',
                child: Column(
                  children: [
                    for (final item in detail.parameters)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.name),
                        subtitle: Text(item.referenceRange),
                        trailing: Text(
                          item.value,
                          style: TextStyle(
                            color: item.status.toLowerCase().contains('yük')
                                ? const Color(0xFFE04F5F)
                                : PratiCaseColors.navy,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _SectionCard(
                title: 'Değerlendirme',
                child: Text(detail.interpretation),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ImagingResultScreen extends StatelessWidget {
  const ImagingResultScreen({
    required this.repository,
    required this.testOptionId,
    super.key,
  });

  final CasesRepository repository;
  final String testOptionId;

  @override
  Widget build(BuildContext context) {
    return _FlowScaffold(
      body: FutureBuilder<ImagingResultDetail?>(
        future: repository.loadImagingResult(testOptionId),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _CenteredState(
              icon: Icons.image_search_rounded,
              title: 'Görüntüleme sonucu yükleniyor',
              body: 'Canlı görüntüleme raporu okunuyor.',
            );
          }
          if (snapshot.hasError) {
            return _CenteredState(
              icon: Icons.cloud_off_rounded,
              title: 'Görüntüleme açılamadı',
              body: _errorText(snapshot.error),
            );
          }
          final detail = snapshot.data;
          if (detail == null) {
            return const _CenteredState(
              icon: Icons.image_search_rounded,
              title: 'Görüntüleme detayı yok',
              body:
                  'Bu tetkik için canlı imaging_result_details kaydı bulunamadı.',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              _StepTopBar(title: detail.title),
              const SizedBox(height: 18),
              Container(
                height: 230,
                decoration: _cardDecoration(),
                clipBehavior: Clip.antiAlias,
                child: detail.imageUrl.isEmpty
                    ? const Center(child: Icon(Icons.image_outlined, size: 54))
                    : Image.network(detail.imageUrl, fit: BoxFit.cover),
              ),
              const SizedBox(height: 14),
              _SectionCard(title: 'Rapor', child: Text(detail.report)),
              const SizedBox(height: 14),
              _SectionCard(title: 'Sonuç', child: Text(detail.conclusion)),
            ],
          );
        },
      ),
    );
  }
}

class MedicationInfoScreen extends StatelessWidget {
  const MedicationInfoScreen({
    required this.repository,
    required this.caseId,
    super.key,
  });

  final CasesRepository repository;
  final String caseId;

  @override
  Widget build(BuildContext context) {
    return _FlowScaffold(
      body: FutureBuilder<List<MedicationInfo>>(
        future: repository.loadMedicationInfos(caseId),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _CenteredState(
              icon: Icons.medication_outlined,
              title: 'İlaç bilgisi yükleniyor',
              body: 'Canlı tedavi bilgisi Supabase’den okunuyor.',
            );
          }
          if (snapshot.hasError) {
            return _CenteredState(
              icon: Icons.cloud_off_rounded,
              title: 'İlaç bilgisi açılamadı',
              body: _errorText(snapshot.error),
            );
          }
          final items = snapshot.requireData;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              const _StepTopBar(title: 'İlaç Bilgisi'),
              const SizedBox(height: 18),
              if (items.isEmpty)
                const _CenteredState(
                  icon: Icons.medication_outlined,
                  title: 'İlaç bilgisi yok',
                  body: 'Bu vaka için canlı medication_infos kaydı bulunamadı.',
                )
              else
                for (final item in items) ...[
                  _SectionCard(
                    title: item.name,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _InfoLine(label: 'Doz', value: item.dosage),
                        _InfoLine(label: 'Yol', value: item.route),
                        _InfoLine(label: 'Endikasyon', value: item.indication),
                        _InfoLine(
                          label: 'Yan Etkiler',
                          value: item.sideEffects,
                        ),
                        _InfoLine(
                          label: 'Kontrendikasyon',
                          value: item.contraindications,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
            ],
          );
        },
      ),
    );
  }
}

class AddNoteScreen extends StatefulWidget {
  const AddNoteScreen({
    required this.repository,
    required this.caseId,
    super.key,
  });

  final CasesRepository repository;
  final String caseId;

  @override
  State<AddNoteScreen> createState() => _AddNoteScreenState();
}

class _AddNoteScreenState extends State<AddNoteScreen> {
  final _note = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.repository.saveNote(
        caseId: widget.caseId,
        body: _note.text,
        title: 'Vaka Notu',
        category: 'Vaka',
      );
      if (!mounted) return;
      Navigator.maybePop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _FlowScaffold(
      resizeToAvoidBottomInset: true,
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 130),
        children: [
          const _StepTopBar(title: 'Notlarım'),
          const SizedBox(height: 18),
          _InputBlock(
            label: 'Kişisel Not',
            controller: _note,
            hint: 'Notunuzu yazın...',
            maxLines: 10,
          ),
        ],
      ),
      bottom: _BottomAction(
        label: _saving ? 'Kaydediliyor...' : 'Kaydet',
        onPressed: _saving ? null : _save,
      ),
    );
  }
}

class CaseProgressScreen extends StatelessWidget {
  const CaseProgressScreen({
    required this.repository,
    required this.sessionId,
    super.key,
  });

  final CasesRepository repository;
  final String sessionId;

  @override
  Widget build(BuildContext context) {
    return _FlowScaffold(
      body: FutureBuilder<CaseProgressOverview>(
        future: repository.loadCaseProgress(sessionId),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _CenteredState(
              icon: Icons.timeline_rounded,
              title: 'Vaka ilerlemesi yükleniyor',
              body: 'Canlı session adımları okunuyor.',
            );
          }
          if (snapshot.hasError) {
            return _CenteredState(
              icon: Icons.cloud_off_rounded,
              title: 'Vaka ilerlemesi açılamadı',
              body: _errorText(snapshot.error),
            );
          }
          final progress = snapshot.requireData;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            children: [
              const _StepTopBar(title: 'Vaka İlerlemesi'),
              const SizedBox(height: 18),
              Text(
                progress.caseTitle,
                style: const TextStyle(
                  color: PratiCaseColors.navy,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 18),
              for (final step in progress.steps) _ProgressStepTile(step: step),
            ],
          );
        },
      ),
    );
  }
}

class _FlowScaffold extends StatelessWidget {
  const _FlowScaffold({
    required this.body,
    this.bottom,
    this.resizeToAvoidBottomInset,
  });

  final Widget body;
  final Widget? bottom;
  final bool? resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      backgroundColor: const Color(0xFFF7F9FB),
      body: SafeArea(bottom: false, child: body),
      bottomNavigationBar: bottom == null
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                child: bottom,
              ),
            ),
    );
  }
}

class _MobileHeader extends StatelessWidget {
  const _MobileHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.menu_rounded, color: PratiCaseColors.navy),
        ),
        const Spacer(),
        Image.asset('assets/branding/praticase.png', width: 34, height: 34),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: PratiCaseColors.navy,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: null,
          icon: const Icon(
            Icons.notifications_none_rounded,
            color: PratiCaseColors.navy,
          ),
        ),
      ],
    );
  }
}

class _StepTopBar extends StatelessWidget {
  const _StepTopBar({
    required this.title,
    this.step,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final int? step;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: PratiCaseColors.navy,
          ),
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: PratiCaseColors.navy,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: PratiCaseColors.teal,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              if (step != null) ...[
                const SizedBox(height: 8),
                _StepDots(active: step!),
              ],
            ],
          ),
        ),
        trailing ?? const SizedBox(width: 48),
      ],
    );
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.active});

  final int active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var index = 1; index <= 5; index++) ...[
          Container(
            width: index == active ? 18 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: index == active
                  ? PratiCaseColors.teal
                  : const Color(0xFFD8DFE8),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          if (index != 5) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _PageTitle extends StatelessWidget {
  const _PageTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: PratiCaseColors.navy,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF5F6E83),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: (_) => onChanged(),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Vaka ara...',
        prefixIcon: const Icon(Icons.search_rounded),
        filled: true,
        fillColor: PratiCaseColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: PratiCaseColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: PratiCaseColors.border),
        ),
      ),
    );
  }
}

class _FilterRail extends StatelessWidget {
  const _FilterRail();

  @override
  Widget build(BuildContext context) {
    const filters = ['Tümü', 'Acil', 'Dahiliye', 'Cerrahi'];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) =>
            _ChipTag(label: filters[index], active: index == 0),
      ),
    );
  }
}

class _CaseListCard extends StatelessWidget {
  const _CaseListCard({required this.item, required this.onTap});

  final OsceCaseSummary item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: _cardDecoration(),
        child: Row(
          children: [
            _SoftIcon(
              icon: _caseIcon(item.iconKey),
              color: _difficultyColor(item.difficulty),
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
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: PratiCaseColors.navy,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      _TinyPill(text: 'Zorluk: ${item.difficulty.label}'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF54647A),
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _ChipTag(label: item.setting),
                      _ChipTag(label: item.branch),
                      _ChipTag(label: '${item.points} Puan'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const _RoundArrow(),
          ],
        ),
      ),
    );
  }
}

class _DetailHero extends StatelessWidget {
  const _DetailHero({required this.detail});

  final OsceCaseDetail detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.summary.title,
                  style: const TextStyle(
                    color: PratiCaseColors.navy,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  detail.candidatePrompt,
                  style: const TextStyle(
                    color: Color(0xFF3E4E64),
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 14,
                  runSpacing: 10,
                  children: [
                    _Metric(
                      icon: Icons.schedule_rounded,
                      text: '${detail.summary.durationMinutes} dk',
                    ),
                    _Metric(
                      icon: Icons.bar_chart_rounded,
                      text: detail.summary.difficulty.label,
                    ),
                    _Metric(
                      icon: Icons.groups_rounded,
                      text: '${detail.summary.solvedCount} çözen',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          _SoftIcon(
            icon: _caseIcon(detail.summary.iconKey),
            color: _difficultyColor(detail.summary.difficulty),
            size: 72,
          ),
        ],
      ),
    );
  }
}

class _FlowCard extends StatelessWidget {
  const _FlowCard({required this.steps});

  final List<CaseFlowStep> steps;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Vaka Akışı',
      child: steps.isEmpty
          ? const Text('Canlı vaka akışı tanımlanmadı.')
          : Row(
              children: [
                for (var index = 0; index < steps.length; index++) ...[
                  Expanded(
                    child: Column(
                      children: [
                        _SoftIcon(
                          icon: _flowIcon(steps[index].iconKey),
                          color: PratiCaseColors.teal,
                          size: 42,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          steps[index].title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: PratiCaseColors.navy,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (index != steps.length - 1)
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF9AA8BA),
                    ),
                ],
              ],
            ),
    );
  }
}

class _PatientInfoCard extends StatelessWidget {
  const _PatientInfoCard({required this.patient});

  final PatientProfile patient;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Hasta Bilgileri',
      child: GridView.count(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        childAspectRatio: 0.86,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _InfoCell(
            icon: Icons.cake_outlined,
            title: 'Yaş',
            value: patient.age,
          ),
          _InfoCell(
            icon: Icons.favorite_border_rounded,
            title: 'Cinsiyet',
            value: patient.gender,
          ),
          _InfoCell(
            icon: Icons.local_hospital_outlined,
            title: 'Başvuru',
            value: patient.applicationSetting,
          ),
          _InfoCell(
            icon: Icons.schedule_rounded,
            title: 'Süre',
            value: patient.complaintDuration,
          ),
        ],
      ),
    );
  }
}

class _GoalsCard extends StatelessWidget {
  const _GoalsCard({required this.goals});

  final List<CaseGoal> goals;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Vaka Hedefleri',
      child: Column(
        children: [
          if (goals.isEmpty)
            const Text('Canlı hedef listesi tanımlanmadı.')
          else
            for (final goal in goals)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.check_box_rounded,
                  color: PratiCaseColors.teal,
                ),
                title: Text(goal.title),
                trailing: Text('${goal.points} puan'),
              ),
        ],
      ),
    );
  }
}

class _PatientBanner extends StatelessWidget {
  const _PatientBanner({required this.session});

  final ExamSessionOverview session;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: Color(0xFFDDEDEA),
            child: Icon(Icons.person_rounded, color: PratiCaseColors.navy),
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
                Text(
                  '${session.patient.age}, ${session.patient.gender}',
                  style: const TextStyle(
                    color: Color(0xFF5F6E83),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  session.patient.applicationSetting,
                  style: const TextStyle(
                    color: Color(0xFF5F6E83),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
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
            icon: const Icon(Icons.badge_outlined, size: 16),
            label: const Text('Hasta Bilgileri'),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message, required this.fromCandidate});

  final String message;
  final bool fromCandidate;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: fromCandidate ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.74,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: fromCandidate ? PratiCaseColors.teal : PratiCaseColors.white,
          borderRadius: BorderRadius.circular(14),
          border: fromCandidate
              ? null
              : Border.all(color: PratiCaseColors.border),
        ),
        child: Text(
          message,
          style: TextStyle(
            color: fromCandidate ? PratiCaseColors.white : PratiCaseColors.navy,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ChatComposer extends StatelessWidget {
  const _ChatComposer({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.onNext,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Sorunuzu yazın...',
                  filled: true,
                  fillColor: PratiCaseColors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: PratiCaseColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: PratiCaseColors.border),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filled(
              onPressed: sending ? null : onSend,
              icon: const Icon(Icons.send_rounded),
            ),
            const SizedBox(width: 6),
            IconButton.outlined(
              onPressed: onNext,
              icon: const Icon(Icons.arrow_forward_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentScroller extends StatelessWidget {
  const _SegmentScroller({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final activeIndex = selectedIndex < 0 ? 0 : selectedIndex;
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) => ChoiceChip(
          selected: index == activeIndex,
          onSelected: (_) => onSelected(index),
          label: Text(items[index]),
          selectedColor: PratiCaseColors.teal,
          labelStyle: TextStyle(
            color: index == activeIndex ? Colors.white : PratiCaseColors.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _BodyMapCard extends StatelessWidget {
  const _BodyMapCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 210,
      decoration: _cardDecoration(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.accessibility_new_rounded,
            size: 172,
            color: const Color(0xFFE9B190).withValues(alpha: 0.55),
          ),
          for (final alignment in const [
            Alignment(-0.35, -0.2),
            Alignment(0.0, -0.2),
            Alignment(0.35, -0.2),
            Alignment(-0.35, 0.12),
            Alignment(0.0, 0.12),
            Alignment(0.35, 0.12),
            Alignment(-0.35, 0.44),
            Alignment(0.0, 0.44),
            Alignment(0.35, 0.44),
          ])
            Align(
              alignment: alignment,
              child: Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: PratiCaseColors.teal,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FindingsCard extends StatelessWidget {
  const _FindingsCard({required this.options, required this.onSelect});

  final List<PhysicalExamOption> options;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Muayene Bulguları',
      child: Column(
        children: [
          if (options.isEmpty)
            const Text('Bu sistem için canlı bulgu tanımlanmadı.')
          else
            for (final item in options)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.title),
                subtitle: item.isSelected && item.finding.isNotEmpty
                    ? Text(item.finding)
                    : null,
                trailing: IconButton(
                  onPressed: () => onSelect(item.id),
                  icon: Icon(
                    item.isSelected
                        ? Icons.check_circle
                        : Icons.add_circle_outline,
                    color: PratiCaseColors.teal,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _TestOptionTile extends StatelessWidget {
  const _TestOptionTile({
    required this.item,
    required this.onTap,
    required this.onOpenDetail,
  });

  final TestOption item;
  final VoidCallback onTap;
  final VoidCallback onOpenDetail;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      child: ListTile(
        onTap: item.isSelected ? onOpenDetail : null,
        leading: _SoftIcon(
          icon: Icons.science_outlined,
          color: PratiCaseColors.teal,
          size: 42,
        ),
        title: Text(
          item.title,
          style: const TextStyle(
            color: PratiCaseColors.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: item.isSelected && item.result.isNotEmpty
            ? Text(item.result)
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${item.pointCost} puan'),
            IconButton(
              onPressed: onTap,
              icon: Icon(
                item.isSelected ? Icons.check_circle : Icons.add_box_outlined,
                color: PratiCaseColors.teal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiagnosisTile extends StatelessWidget {
  const _DiagnosisTile({
    required this.title,
    required this.selected,
    required this.onChanged,
  });

  final String title;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: selected,
      onChanged: (value) => onChanged(value ?? false),
      title: Text(title),
      activeColor: PratiCaseColors.teal,
      tileColor: selected
          ? PratiCaseColors.teal.withValues(alpha: 0.08)
          : PratiCaseColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: PratiCaseColors.border),
      ),
    );
  }
}

class _InputBlock extends StatelessWidget {
  const _InputBlock({
    required this.label,
    required this.controller,
    required this.hint,
    required this.maxLines,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FormLabel(label),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: PratiCaseColors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: PratiCaseColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: PratiCaseColors.border),
            ),
          ),
        ),
      ],
    );
  }
}

class _FormLabel extends StatelessWidget {
  const _FormLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: PratiCaseColors.navy,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _BottomAction extends StatelessWidget {
  const _BottomAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: FilledButton.icon(
        onPressed: onPressed,
        label: Text(label),
        icon: const Icon(Icons.arrow_forward_rounded),
        style: FilledButton.styleFrom(
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
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

class _InfoCell extends StatelessWidget {
  const _InfoCell({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: PratiCaseColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: PratiCaseColors.teal, size: 20),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF66758A),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: PratiCaseColors.navy,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFF65758D), size: 16),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF65758D),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ReportMetric extends StatelessWidget {
  const _ReportMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF66758A),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: PratiCaseColors.teal,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF66758A),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: PratiCaseColors.navy,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressStepTile extends StatelessWidget {
  const _ProgressStepTile({required this.step});

  final CaseProgressStep step;

  @override
  Widget build(BuildContext context) {
    final done = step.status == 'Tamamlandı';
    final active = step.status == 'Devam Ediyor';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Icon(
            done
                ? Icons.check_circle_rounded
                : active
                ? Icons.play_circle_fill_rounded
                : Icons.lock_outline_rounded,
            color: done || active
                ? PratiCaseColors.teal
                : const Color(0xFFB8C1CE),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              step.title,
              style: const TextStyle(
                color: PratiCaseColors.navy,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            step.status,
            style: TextStyle(
              color: active ? PratiCaseColors.teal : const Color(0xFF66758A),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterSummaryRow extends StatelessWidget {
  const _FilterSummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: Text(value, style: const TextStyle(color: Color(0xFF66758A))),
    );
  }
}

class _ChipTag extends StatelessWidget {
  const _ChipTag({required this.label, this.active = false, this.tone});

  final String label;
  final bool active;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final color = tone ?? PratiCaseColors.teal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: active ? PratiCaseColors.teal : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? PratiCaseColors.white : color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _TinyPill extends StatelessWidget {
  const _TinyPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: PratiCaseColors.gold.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFE18A00),
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SoftIcon extends StatelessWidget {
  const _SoftIcon({required this.icon, required this.color, this.size = 56});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color, size: size * 0.52),
    );
  }
}

class _RoundArrow extends StatelessWidget {
  const _RoundArrow();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [PratiCaseColors.teal, Color(0xFF005263)],
        ),
      ),
      child: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
    );
  }
}

class _SelectionSummary extends StatelessWidget {
  const _SelectionSummary({required this.text, required this.subtext});

  final String text;
  final String subtext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Text(
            text,
            style: const TextStyle(
              color: PratiCaseColors.teal,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          Text(
            subtext,
            style: const TextStyle(
              color: PratiCaseColors.navy,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CenteredState extends StatelessWidget {
  const _CenteredState({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          Icon(icon, color: PratiCaseColors.teal, size: 46),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: PratiCaseColors.navy,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF65758D),
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBundle {
  const _ChatBundle({required this.session, required this.messages});

  final ExamSessionOverview session;
  final List<ChatMessage> messages;
}

class _PhysicalBundle {
  const _PhysicalBundle({required this.groups, required this.options});

  final List<PhysicalExamGroup> groups;
  final List<PhysicalExamOption> options;
}

class _TestsBundle {
  const _TestsBundle({
    required this.session,
    required this.groups,
    required this.options,
  });

  final ExamSessionOverview session;
  final List<TestGroup> groups;
  final List<TestOption> options;
}

class _DiagnosisBundle {
  const _DiagnosisBundle({required this.session, required this.options});

  final ExamSessionOverview session;
  final List<DiagnosisOption> options;
}

class _ManagementBundle {
  const _ManagementBundle({required this.session, required this.options});

  final ExamSessionOverview session;
  final List<ManagementOption> options;
}

class _ManagementGroupCard extends StatelessWidget {
  const _ManagementGroupCard({
    required this.title,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final String title;
  final List<ManagementOption> options;
  final Set<String> selected;
  final void Function(String optionId, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: title,
      child: Column(
        children: [
          for (final option in options)
            CheckboxListTile(
              value: selected.contains(option.id),
              onChanged: (value) => onChanged(option.id, value ?? false),
              activeColor: PratiCaseColors.teal,
              contentPadding: EdgeInsets.zero,
              title: Text(
                option.title,
                style: const TextStyle(
                  color: PratiCaseColors.navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
              secondary: option.pointValue > 0
                  ? Text(
                      '${option.pointValue} p',
                      style: const TextStyle(
                        color: PratiCaseColors.teal,
                        fontWeight: FontWeight.w900,
                      ),
                    )
                  : null,
            ),
        ],
      ),
    );
  }
}

class _ResultHero extends StatelessWidget {
  const _ResultHero({required this.result});

  final ExamResultSummary result;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 46, 22, 30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF063443), Color(0xFF006A72)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const Text(
            'Tebrikler!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${result.caseTitle} başarıyla tamamlandı.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 26),
          Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: PratiCaseColors.gold.withValues(alpha: 0.18),
              border: Border.all(color: PratiCaseColors.gold, width: 8),
            ),
            child: const Icon(
              Icons.star_rounded,
              color: PratiCaseColors.gold,
              size: 74,
            ),
          ),
          const SizedBox(height: 26),
          const Text(
            'Toplam Puanınız',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '${result.totalScore}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                TextSpan(
                  text: ' / ${result.maxScore}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '%${result.percentage}',
            style: const TextStyle(
              color: Color(0xFF8AF07B),
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreGrid extends StatelessWidget {
  const _ScoreGrid({required this.scores});

  final List<ResultCategoryScore> scores;

  @override
  Widget build(BuildContext context) {
    if (scores.isEmpty) {
      return const _CenteredState(
        icon: Icons.query_stats_rounded,
        title: 'Puan dağılımı yok',
        body: 'Canlı rubric sonuçları oluştuğunda burada görünür.',
      );
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: GridView.count(
        crossAxisCount: 5,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 0.78,
        crossAxisSpacing: 6,
        children: [
          for (final score in scores)
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_scoreIcon(score.title), color: PratiCaseColors.teal),
                const SizedBox(height: 6),
                Text(
                  score.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PratiCaseColors.navy,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${score.score}/${score.maxScore}',
                  style: const TextStyle(
                    color: PratiCaseColors.teal,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: title,
      child: Column(
        children: [
          if (items.isEmpty)
            const Text('Canlı karne maddesi henüz oluşmadı.')
          else
            for (final item in items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(icon, color: color),
                title: Text(item),
              ),
        ],
      ),
    );
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: PratiCaseColors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: PratiCaseColors.border),
    boxShadow: [
      BoxShadow(
        color: PratiCaseColors.navy.withValues(alpha: 0.04),
        blurRadius: 16,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

Color _difficultyColor(OsceDifficulty difficulty) {
  switch (difficulty) {
    case OsceDifficulty.easy:
      return const Color(0xFF2AA765);
    case OsceDifficulty.medium:
      return PratiCaseColors.gold;
    case OsceDifficulty.hard:
      return const Color(0xFFE04F5F);
  }
}

IconData _caseIcon(String? key) {
  switch (key) {
    case 'heart':
      return Icons.favorite_rounded;
    case 'brain':
      return Icons.psychology_alt_rounded;
    case 'lung':
      return Icons.air_rounded;
    case 'abdomen':
      return Icons.medical_information_rounded;
    case 'uro':
      return Icons.water_drop_rounded;
    default:
      return Icons.local_hospital_rounded;
  }
}

IconData _flowIcon(String key) {
  switch (key) {
    case 'history':
      return Icons.chat_bubble_outline_rounded;
    case 'exam':
      return Icons.health_and_safety_outlined;
    case 'tests':
      return Icons.science_outlined;
    case 'diagnosis':
      return Icons.psychology_alt_rounded;
    case 'management':
      return Icons.assignment_turned_in_rounded;
    default:
      return Icons.radio_button_checked_rounded;
  }
}

IconData _scoreIcon(String title) {
  final lower = title.toLowerCase();
  if (lower.contains('anamnez')) return Icons.chat_bubble_outline_rounded;
  if (lower.contains('muayene')) return Icons.health_and_safety_outlined;
  if (lower.contains('tetkik')) return Icons.science_outlined;
  if (lower.contains('tan')) return Icons.psychology_alt_rounded;
  if (lower.contains('yönet')) return Icons.assignment_turned_in_rounded;
  return Icons.query_stats_rounded;
}

String _errorText(Object? error) {
  if (error is CasesDataUnavailable) return error.message;
  return 'Canlı veri alınamadı. Lütfen bağlantı ve yetkileri kontrol edin.';
}
