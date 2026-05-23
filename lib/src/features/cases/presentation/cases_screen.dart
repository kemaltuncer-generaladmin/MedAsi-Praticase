import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/praticase_colors.dart';
import '../data/cases_repository.dart';
import '../domain/osce_case.dart';

class CasesScreen extends StatefulWidget {
  const CasesScreen({
    required this.repository,
    this.onOpenNotifications,
    this.onOpenProfile,
    this.unreadNotificationCount = 0,
    super.key,
  });

  final CasesRepository repository;
  final VoidCallback? onOpenNotifications;
  final VoidCallback? onOpenProfile;
  final int unreadNotificationCount;

  @override
  State<CasesScreen> createState() => _CasesScreenState();
}

class _CasesScreenState extends State<CasesScreen> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  String? _branch;
  String? _difficulty;
  String? _setting;
  String? _duration;
  String? _status;
  String _sort = 'Önerilen';
  late Future<List<OsceCaseSummary>> _casesFuture;

  @override
  void initState() {
    super.initState();
    _casesFuture = widget.repository.loadCases();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _scheduleSearch() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _search);
  }

  void _search() {
    setState(() {});
  }

  Future<void> _refresh() async {
    setState(() {
      _casesFuture = widget.repository.loadCases();
    });
    await _casesFuture;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<OsceCaseSummary>>(
      future: _casesFuture,
      builder: (context, snapshot) {
        final bottom = MediaQuery.paddingOf(context).bottom + 106;
        final allCases = snapshot.data ?? const <OsceCaseSummary>[];
        final visibleCases = _visibleCases(allCases);
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(20, 20, 20, bottom),
            children: [
              _MobileHeader(
                onOpenNotifications: widget.onOpenNotifications,
                onOpenProfile: widget.onOpenProfile,
                unreadNotificationCount: widget.unreadNotificationCount,
              ),
              const SizedBox(height: 34),
              const _PageTitle(
                title: 'Vaka Kütüphanesi',
                subtitle:
                    'Semptom, branş veya zorluk seçerek OSCE istasyonu başlat.',
              ),
              const SizedBox(height: 22),
              _SearchBox(
                controller: _searchController,
                onChanged: _scheduleSearch,
                onSubmitted: _search,
                onClear: _clearSearch,
              ),
              if (snapshot.connectionState != ConnectionState.done)
                const Padding(
                  padding: EdgeInsets.only(top: 22),
                  child: _CenteredState(
                    icon: Icons.hourglass_empty_rounded,
                    title: 'Canlı vakalar yükleniyor',
                    body: 'PratiCase vaka kütüphanesi Supabase’den okunuyor.',
                  ),
                )
              else if (snapshot.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 22),
                  child: _CenteredState(
                    icon: Icons.cloud_off_rounded,
                    title: 'Canlı veri bağlantısı gerekli',
                    body: _errorText(snapshot.error),
                  ),
                )
              else if (snapshot.requireData.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 22),
                  child: _CenteredState(
                    icon: Icons.assignment_outlined,
                    title: 'Yayınlanmış vaka yok',
                    body: 'Yayınlanan OSCE vakaları burada listelenecek.',
                  ),
                )
              else ...[
                const SizedBox(height: 28),
                _CaseFilterOverview(
                  totalCount: snapshot.requireData.length,
                  visibleCount: visibleCases.length,
                  activeCount: _activeFilterCount,
                  onClear: _activeFilterCount == 0 ? null : _clearFilters,
                ),
                const SizedBox(height: 18),
                _FilterStrip(
                  label: 'Branşlar',
                  items: [
                    'Tümü',
                    ...{
                      for (final item in snapshot.requireData)
                        if (item.branch.trim().isNotEmpty) item.branch,
                    },
                  ],
                  selected: _branch ?? 'Tümü',
                  counts: _counts(
                    snapshot.requireData.map((item) => item.branch),
                  ),
                  onSelected: (value) {
                    setState(() => _branch = value == 'Tümü' ? null : value);
                  },
                ),
                const SizedBox(height: 18),
                _FilterStrip(
                  label: 'Zorluk',
                  items: const ['Tümü', 'Kolay', 'Orta', 'Zor'],
                  selected: _difficulty ?? 'Tümü',
                  counts: _counts(
                    snapshot.requireData.map((item) => item.difficulty.label),
                  ),
                  onSelected: (value) {
                    setState(
                      () => _difficulty = value == 'Tümü' ? null : value,
                    );
                  },
                ),
                const SizedBox(height: 18),
                _FilterStrip(
                  label: 'Klinik Ortam',
                  items: [
                    'Tümü',
                    ...{
                      for (final item in snapshot.requireData)
                        if (item.setting.trim().isNotEmpty) item.setting,
                    },
                  ],
                  selected: _setting ?? 'Tümü',
                  counts: _counts(
                    snapshot.requireData.map((item) => item.setting),
                  ),
                  onSelected: (value) {
                    setState(() => _setting = value == 'Tümü' ? null : value);
                  },
                ),
                const SizedBox(height: 18),
                _FilterStrip(
                  label: 'Süre',
                  items: const ['Tümü', '≤7 dk', '8-10 dk', '10+ dk'],
                  selected: _duration ?? 'Tümü',
                  counts: _durationCounts(snapshot.requireData),
                  onSelected: (value) {
                    setState(() => _duration = value == 'Tümü' ? null : value);
                  },
                ),
                const SizedBox(height: 18),
                _FilterStrip(
                  label: 'Durum',
                  items: const [
                    'Tümü',
                    'Favoriler',
                    'Devam Eden',
                    'Tamamlanan',
                    'Düşük Skor',
                  ],
                  selected: _status ?? 'Tümü',
                  counts: _statusCounts(snapshot.requireData),
                  onSelected: (value) {
                    setState(() => _status = value == 'Tümü' ? null : value);
                  },
                ),
                const SizedBox(height: 18),
                _FilterStrip(
                  label: 'Sıralama',
                  items: const ['Önerilen', 'Süre', 'Puan', 'Son Skor'],
                  selected: _sort,
                  onSelected: (value) => setState(() => _sort = value),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${visibleCases.length} vaka bulundu',
                        style: const TextStyle(
                          color: PratiCaseColors.navy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _TinyPill(
                      text: _activeFilterCount == 0 ? 'Tümü' : 'Filtreli',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (visibleCases.isEmpty)
                  const _CenteredState(
                    icon: Icons.search_off_rounded,
                    title: 'Bu filtreye uygun vaka yok',
                    body: 'Arama veya filtreleri değiştirerek tekrar dene.',
                  )
                else
                  for (final item in visibleCases) ...[
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

  void _clearSearch() {
    _searchController.clear();
    _searchDebounce?.cancel();
    setState(() {});
  }

  void _clearFilters() {
    setState(() {
      _branch = null;
      _difficulty = null;
      _setting = null;
      _duration = null;
      _status = null;
      _sort = 'Önerilen';
    });
  }

  int get _activeFilterCount {
    return [
      _branch,
      _difficulty,
      _setting,
      _duration,
      _status,
      _sort == 'Önerilen' ? null : _sort,
    ].whereType<String>().length;
  }

  List<OsceCaseSummary> _visibleCases(List<OsceCaseSummary> cases) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = cases.where((item) {
      if (query.isNotEmpty) {
        final haystack = [
          item.title,
          item.branch,
          item.setting,
          item.difficulty.label,
          item.summary,
        ].join(' ').toLowerCase();
        if (!haystack.contains(query)) return false;
      }
      if (_branch != null && item.branch != _branch) return false;
      if (_difficulty != null && item.difficulty.label != _difficulty) {
        return false;
      }
      if (_setting != null && item.setting != _setting) return false;
      if (!_matchesDuration(item)) return false;
      if (!_matchesStatus(item)) return false;
      return true;
    }).toList();
    filtered.sort(_caseSorter);
    return filtered;
  }

  bool _matchesDuration(OsceCaseSummary item) {
    return switch (_duration) {
      '≤7 dk' => item.durationMinutes <= 7,
      '8-10 dk' => item.durationMinutes >= 8 && item.durationMinutes <= 10,
      '10+ dk' => item.durationMinutes > 10,
      _ => true,
    };
  }

  bool _matchesStatus(OsceCaseSummary item) {
    return switch (_status) {
      'Favoriler' => item.isBookmarked,
      'Devam Eden' =>
        item.progressPercent != null && (item.progressPercent ?? 0) < 100,
      'Tamamlanan' =>
        item.progressPercent != null && (item.progressPercent ?? 0) >= 100,
      'Düşük Skor' => item.lastScore != null && (item.lastScore ?? 100) < 75,
      _ => true,
    };
  }

  int _caseSorter(OsceCaseSummary a, OsceCaseSummary b) {
    return switch (_sort) {
      'Süre' => a.durationMinutes.compareTo(b.durationMinutes),
      'Puan' => b.points.compareTo(a.points),
      'Son Skor' => (b.lastScore ?? -1).compareTo(a.lastScore ?? -1),
      _ => a.title.compareTo(b.title),
    };
  }

  Map<String, int> _counts(Iterable<String> values) {
    final counts = <String, int>{'Tümü': 0};
    for (final raw in values) {
      final value = raw.trim();
      if (value.isEmpty) continue;
      counts['Tümü'] = (counts['Tümü'] ?? 0) + 1;
      counts[value] = (counts[value] ?? 0) + 1;
    }
    return counts;
  }

  Map<String, int> _durationCounts(List<OsceCaseSummary> cases) {
    return {
      'Tümü': cases.length,
      '≤7 dk': cases.where((item) => item.durationMinutes <= 7).length,
      '8-10 dk': cases
          .where(
            (item) => item.durationMinutes >= 8 && item.durationMinutes <= 10,
          )
          .length,
      '10+ dk': cases.where((item) => item.durationMinutes > 10).length,
    };
  }

  Map<String, int> _statusCounts(List<OsceCaseSummary> cases) {
    return {
      'Tümü': cases.length,
      'Favoriler': cases.where((item) => item.isBookmarked).length,
      'Devam Eden': cases
          .where(
            (item) =>
                item.progressPercent != null &&
                (item.progressPercent ?? 0) < 100,
          )
          .length,
      'Tamamlanan': cases
          .where(
            (item) =>
                item.progressPercent != null &&
                (item.progressPercent ?? 0) >= 100,
          )
          .length,
      'Düşük Skor': cases
          .where(
            (item) => item.lastScore != null && (item.lastScore ?? 100) < 75,
          )
          .length,
    };
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
              onPressed: () => Navigator.pop(context, ''),
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
  bool _bookmarking = false;

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

  Future<void> _toggleBookmark(OsceCaseDetail detail) async {
    if (_bookmarking) return;
    setState(() => _bookmarking = true);
    try {
      await widget.repository.setBookmark(
        caseId: widget.caseId,
        bookmarked: !detail.summary.isBookmarked,
      );
      setState(
        () => _detailFuture = widget.repository.loadCaseDetail(widget.caseId),
      );
    } on CasesDataUnavailable catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _bookmarking = false);
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
                  onPressed: _bookmarking
                      ? null
                      : () => _toggleBookmark(detail),
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
  final _scrollController = ScrollController();
  late Future<_ChatBundle> _bundleFuture;
  bool _sending = false;
  bool _navigating = false;
  String? _pendingCandidateMessage;

  @override
  void initState() {
    super.initState();
    _bundleFuture = _load();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<_ChatBundle> _load() async {
    final session = await widget.repository.loadSession(widget.sessionId);
    final detail = await widget.repository.loadCaseDetail(session.caseId);
    final messages = await widget.repository.loadMessages(widget.sessionId);
    return _ChatBundle(
      session: session,
      detail: detail,
      messages: _chronologicalMessages(messages),
    );
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _sending = true;
      _pendingCandidateMessage = text;
    });
    _messageController.clear();
    _scheduleScrollToBottom();
    try {
      await widget.repository.sendPatientQuestion(
        sessionId: widget.sessionId,
        message: text,
      );
      final bundle = await _bundleFuture;
      final messages = await widget.repository.loadMessages(widget.sessionId);
      setState(
        () => _bundleFuture = Future.value(
          bundle.copyWith(messages: _chronologicalMessages(messages)),
        ),
      );
      await _bundleFuture;
      _scheduleScrollToBottom();
    } on CasesDataUnavailable catch (error) {
      _restoreFailedMessage(text);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } on Object {
      _restoreFailedMessage(text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Hasta yanıtı alınamadı. Bağlantını kontrol edip tekrar dene.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          _pendingCandidateMessage = null;
        });
        _scheduleScrollToBottom();
      }
    }
  }

  Future<void> _next() async {
    if (_navigating) return;
    setState(() => _navigating = true);
    final session = (await _bundleFuture).session;
    try {
      await widget.repository.advanceSession(
        sessionId: widget.sessionId,
        step: 'physical_exam',
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PhysicalExamScreen(
            repository: widget.repository,
            sessionId: widget.sessionId,
            caseId: session.caseId,
          ),
        ),
      );
    } on CasesDataUnavailable catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _navigating = false);
    }
  }

  void _restoreFailedMessage(String text) {
    if (!mounted) return;
    setState(() {
      _messageController.text = text;
      _messageController.selection = TextSelection.collapsed(
        offset: _messageController.text.length,
      );
    });
  }

  void _scheduleScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return _FlowScaffold(
      backgroundColor: PratiCaseColors.softSurface,
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
          _scheduleScrollToBottom();
          return Column(
            children: [
              _ExamTopBar(
                session: bundle.session,
                phase: 'Anamnez',
                repository: widget.repository,
                sessionId: widget.sessionId,
              ),
              Expanded(
                child: _AnamnesisWorkspace(
                  bundle: bundle,
                  scrollController: _scrollController,
                  pendingCandidateMessage: _pendingCandidateMessage,
                  patientTyping: _sending,
                  onOpenProgress: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CaseProgressScreen(
                        repository: widget.repository,
                        sessionId: widget.sessionId,
                      ),
                    ),
                  ),
                  onAddNote: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AddNoteScreen(
                        repository: widget.repository,
                        caseId: bundle.session.caseId,
                      ),
                    ),
                  ),
                ),
              ),
              _ChatComposer(
                controller: _messageController,
                sending: _sending,
                onSend: _send,
                onNext: _navigating ? null : _next,
              ),
            ],
          );
        },
      ),
    );
  }
}

List<ChatMessage> _chronologicalMessages(List<ChatMessage> messages) {
  final sorted = [...messages];
  sorted.sort((a, b) {
    final byTime = a.createdAt.compareTo(b.createdAt);
    if (byTime != 0) return byTime;
    if (a.fromCandidate != b.fromCandidate) {
      return a.fromCandidate ? -1 : 1;
    }
    return a.id.compareTo(b.id);
  });
  return sorted;
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
    final session = await widget.repository.loadSession(widget.sessionId);
    final groups = await widget.repository.loadPhysicalExamGroups(
      widget.caseId,
    );
    final options = await widget.repository.loadPhysicalExamOptions(
      sessionId: widget.sessionId,
      caseId: widget.caseId,
    );
    return _PhysicalBundle(session: session, groups: groups, options: options);
  }

  Future<void> _select(String optionId) async {
    await widget.repository.selectPhysicalExam(
      sessionId: widget.sessionId,
      optionId: optionId,
    );
    setState(() {
      _bundleFuture = _load();
    });
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
          return Column(
            children: [
              _ExamTopBar(
                session: bundle.session,
                phase: 'Fizik Muayene',
                repository: widget.repository,
                sessionId: widget.sessionId,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                  children: [
                    const _PhaseTabs(activeStep: 2),
                    const SizedBox(height: 16),
                    _PatientBanner(session: bundle.session),
                    const SizedBox(height: 18),
                    const Text(
                      'Sistem seçerek muayene edin.',
                      style: TextStyle(
                        color: Color(0xFF4F5E72),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _SegmentScroller(
                      items: bundle.groups.map((item) => item.title).toList(),
                      selectedIndex: bundle.groups.indexWhere(
                        (item) => item.id == groupId,
                      ),
                      onSelected: (index) {
                        setState(
                          () => _selectedGroupId = bundle.groups[index].id,
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    const _BodyMapCard(),
                    const SizedBox(height: 18),
                    _FindingsCard(options: visible, onSelect: _select),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottom: _BottomAction(label: 'Tetkiklere Geç', onPressed: _next),
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
    setState(() {
      _bundleFuture = _load();
    });
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
          return Column(
            children: [
              _ExamTopBar(
                session: bundle.session,
                phase: 'Tetkikler',
                repository: widget.repository,
                sessionId: widget.sessionId,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                  children: [
                    const _PhaseTabs(activeStep: 3),
                    const SizedBox(height: 18),
                    _SelectionSummary(
                      text: 'İstem Listem ($selectedCount)',
                      subtext: '$selectedCost puan',
                    ),
                    const SizedBox(height: 18),
                    _SegmentScroller(
                      items: bundle.groups.map((item) => item.title).toList(),
                      selectedIndex: bundle.groups.indexWhere(
                        (item) => item.id == groupId,
                      ),
                      onSelected: (index) {
                        setState(
                          () => _selectedGroupId = bundle.groups[index].id,
                        );
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
                        body:
                            'Canlı tetkik seçenekleri eklendiğinde burada görünür.',
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottom: _BottomAction(label: 'Tanıya Geç', onPressed: _next),
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
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _bundleFuture = _load();
    _primaryController.addListener(() => setState(() {}));
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
    if (_primaryController.text.trim().isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await widget.repository.saveDiagnosisAnswer(
        sessionId: widget.sessionId,
        primaryDiagnosis: _primaryController.text.trim(),
        selectedOptionIds: _selected.toList(),
        reasoning: _reasoningController.text.trim(),
      );
      await widget.repository.advanceSession(
        sessionId: widget.sessionId,
        step: 'management',
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ManagementPlanScreen(
            repository: widget.repository,
            sessionId: widget.sessionId,
            caseId: widget.caseId,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
          return Column(
            children: [
              _ExamTopBar(
                session: bundle.session,
                phase: 'Tanı ve Yönetim',
                repository: widget.repository,
                sessionId: widget.sessionId,
              ),
              Expanded(
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 130),
                  children: [
                    const _PhaseTabs(activeStep: 4),
                    const SizedBox(height: 18),
                    _InputBlock(
                      label: 'Ön Tanı',
                      controller: _primaryController,
                      hint: 'Kesinleşen veya en olası ön tanınızı yazın.',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    const _FormLabel('Ayırıcı Tanılar'),
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
                            'Ayırıcı tanı seçenekleri yayınlandığında görünür.',
                      ),
                    const SizedBox(height: 14),
                    _InputBlock(
                      label: 'Tanı Gerekçesi',
                      controller: _reasoningController,
                      hint:
                          'Dışlanması gereken tanıları, klinik bulguları ve tetkik sonuçlarını özetleyin.',
                      maxLines: 6,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottom: _BottomAction(
        label: _saving ? 'Kaydediliyor...' : 'Yönetim Planına Geç',
        onPressed: _primaryController.text.trim().isEmpty || _saving
            ? null
            : _save,
      ),
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
    final diagnosisAnswer = await widget.repository.loadDiagnosisAnswer(
      widget.sessionId,
    );
    final options = await widget.repository.loadManagementOptions(
      sessionId: widget.sessionId,
      caseId: widget.caseId,
    );
    _diagnosisController.text = (answer?.diagnosis.trim().isNotEmpty ?? false)
        ? answer!.diagnosis
        : diagnosisAnswer?.primaryDiagnosis ?? '';
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
          return Column(
            children: [
              _ExamTopBar(
                session: bundle.session,
                phase: 'Tanı ve Yönetim',
                repository: widget.repository,
                sessionId: widget.sessionId,
              ),
              Expanded(
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 130),
                  children: [
                    const _PhaseTabs(activeStep: 5),
                    const SizedBox(height: 18),
                    _InputBlock(
                      label: 'Ön Tanı',
                      controller: _diagnosisController,
                      hint: 'Kesinleşen veya en olası ön tanınızı yazın.',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Yönetim Planı',
                      style: TextStyle(
                        color: PratiCaseColors.navy,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Tedavi, konsültasyon ve acil müdahale kararlarını eksiksiz işaretleyin.',
                      style: TextStyle(
                        color: Color(0xFF66758A),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (grouped.isEmpty)
                      const _CenteredState(
                        icon: Icons.assignment_outlined,
                        title: 'Tedavi seçeneği yok',
                        body:
                            'Yönetim planı seçenekleri yayınlandığında görünür.',
                      )
                    else
                      for (final entry in grouped.entries) ...[
                        _ManagementGroupCard(
                          title: _managementCategoryTitle(entry.key),
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
                      label: 'Acil Müdahaleler ve Ek Tetkikler',
                      controller: _noteController,
                      hint:
                          'Acil prosedür, ileri görüntüleme veya ek laboratuvar taleplerini klinik gerekçesiyle yazın.',
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
                ),
              ),
            ],
          );
        },
      ),
      bottom: _BottomAction(
        label: 'Sınavı Bitir ve Değerlendir',
        icon: Icons.check_circle_rounded,
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
              const SizedBox(height: 14),
              _FeedbackCard(
                title: 'Kritik Hatalar',
                icon: Icons.error_outline_rounded,
                color: const Color(0xFFE15B5B),
                items: result.criticalMistakes,
              ),
              const SizedBox(height: 14),
              _FeedbackCard(
                title: 'Gereksiz Tetkikler',
                icon: Icons.science_outlined,
                color: const Color(0xFF8B6F47),
                items: result.unnecessaryTests,
              ),
              const SizedBox(height: 14),
              _FeedbackCard(
                title: 'Eksik Anamnez',
                icon: Icons.chat_bubble_outline_rounded,
                color: const Color(0xFF506178),
                items: result.missedHistory,
              ),
              const SizedBox(height: 14),
              _FeedbackCard(
                title: 'Kaçırılan Muayeneler',
                icon: Icons.health_and_safety_outlined,
                color: PratiCaseColors.teal,
                items: result.missedPhysicalExam,
              ),
              const SizedBox(height: 14),
              _IdealApproachCard(text: result.idealApproach),
              const SizedBox(height: 18),
              _ResultActions(
                onRetry: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                onReport: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CaseReportScreen(result: result),
                    ),
                  );
                },
                onSuggestedCases: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CasesScreen(repository: repository),
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
          const SizedBox(height: 14),
          _FeedbackCard(
            title: 'Kritik Hatalar',
            icon: Icons.error_outline_rounded,
            color: const Color(0xFFE15B5B),
            items: result.criticalMistakes,
          ),
          const SizedBox(height: 14),
          _FeedbackCard(
            title: 'Gereksiz Tetkikler',
            icon: Icons.science_outlined,
            color: const Color(0xFF8B6F47),
            items: result.unnecessaryTests,
          ),
          const SizedBox(height: 14),
          _FeedbackCard(
            title: 'Eksik Anamnez',
            icon: Icons.chat_bubble_outline_rounded,
            color: const Color(0xFF506178),
            items: result.missedHistory,
          ),
          const SizedBox(height: 14),
          _FeedbackCard(
            title: 'Kaçırılan Muayeneler',
            icon: Icons.health_and_safety_outlined,
            color: PratiCaseColors.teal,
            items: result.missedPhysicalExam,
          ),
          const SizedBox(height: 14),
          _IdealApproachCard(text: result.idealApproach),
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
                    : Image.network(
                        detail.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.broken_image_outlined, size: 54),
                                SizedBox(height: 8),
                                Text('Görüntü yüklenemedi'),
                              ],
                            ),
                          );
                        },
                      ),
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
    if (_note.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not kaydetmek için içerik gir.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.repository.saveNote(
        caseId: widget.caseId,
        body: _note.text,
        title: 'Vaka Notu',
        category: 'Vaka',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Not kaydedildi.')));
      Navigator.maybePop(context);
    } on CasesDataUnavailable catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
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
    this.backgroundColor = const Color(0xFFF7F9FB),
  });

  final Widget body;
  final Widget? bottom;
  final bool? resizeToAvoidBottomInset;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final overlayStyle =
        ThemeData.estimateBrightnessForColor(backgroundColor) == Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        backgroundColor: backgroundColor,
        body: SafeArea(bottom: false, child: body),
        bottomNavigationBar: bottom == null
            ? null
            : SafeArea(
                top: false,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: PratiCaseColors.white,
                    border: Border(
                      top: BorderSide(
                        color: PratiCaseColors.navy.withValues(alpha: 0.06),
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: PratiCaseColors.navy.withValues(alpha: 0.08),
                        blurRadius: 18,
                        offset: const Offset(0, -8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                    child: bottom,
                  ),
                ),
              ),
      ),
    );
  }
}

class _MobileHeader extends StatelessWidget {
  const _MobileHeader({
    required this.unreadNotificationCount,
    this.onOpenNotifications,
    this.onOpenProfile,
  });

  final VoidCallback? onOpenNotifications;
  final VoidCallback? onOpenProfile;
  final int unreadNotificationCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            'assets/branding/praticase.png',
            width: 44,
            height: 44,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: RichText(
            maxLines: 1,
            text: const TextSpan(
              style: TextStyle(
                color: PratiCaseColors.navy,
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
              children: [
                TextSpan(text: 'Prati'),
                TextSpan(
                  text: 'Case',
                  style: TextStyle(color: PratiCaseColors.teal),
                ),
              ],
            ),
          ),
        ),
        _CasesHeaderBell(
          unreadCount: unreadNotificationCount,
          onTap: onOpenNotifications,
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Profilim',
          onPressed: onOpenProfile,
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFE2F1F0),
            fixedSize: const Size(44, 44),
          ),
          icon: const Icon(
            Icons.person_outline_rounded,
            color: PratiCaseColors.teal,
          ),
        ),
      ],
    );
  }
}

class _CasesHeaderBell extends StatelessWidget {
  const _CasesHeaderBell({required this.unreadCount, this.onTap});

  final int unreadCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'Bildirimler',
          onPressed: onTap,
          icon: const Icon(
            Icons.notifications_none_rounded,
            color: PratiCaseColors.navy,
            size: 30,
          ),
        ),
        if (unreadCount > 0)
          Positioned(
            right: 2,
            top: 2,
            child: Container(
              constraints: const BoxConstraints(minHeight: 18, minWidth: 18),
              padding: const EdgeInsets.symmetric(horizontal: 5),
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: PratiCaseColors.gold,
              ),
              child: Text(
                unreadCount > 9 ? '9+' : '$unreadCount',
                style: const TextStyle(
                  color: PratiCaseColors.navy,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _StepTopBar extends StatelessWidget {
  const _StepTopBar({required this.title, this.trailing});

  final String title;
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
          child: Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: PratiCaseColors.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        trailing ?? const SizedBox(width: 48),
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
            fontSize: 32,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF5F6E83),
            fontSize: 15,
            height: 1.45,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;
  final VoidCallback onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: (_) => onChanged(),
      onSubmitted: (_) => onSubmitted(),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Vaka ara...',
        prefixIcon: const Padding(
          padding: EdgeInsets.only(left: 8, right: 4),
          child: Icon(Icons.search_rounded, color: PratiCaseColors.navy),
        ),
        suffixIcon: controller.text.trim().isEmpty
            ? null
            : IconButton(
                tooltip: 'Aramayı temizle',
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
              ),
        prefixIconConstraints: const BoxConstraints(minWidth: 50),
        filled: true,
        fillColor: PratiCaseColors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: PratiCaseColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: PratiCaseColors.border),
        ),
      ),
    );
  }
}

class _CaseFilterOverview extends StatelessWidget {
  const _CaseFilterOverview({
    required this.totalCount,
    required this.visibleCount,
    required this.activeCount,
    required this.onClear,
  });

  final int totalCount;
  final int visibleCount;
  final int activeCount;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final ratio = totalCount == 0
        ? 0.0
        : (visibleCount / totalCount).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PratiCaseColors.navy,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: PratiCaseColors.navy.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: PratiCaseColors.tealBright,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Canlı Filtreler',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      activeCount == 0
                          ? 'Tüm yayınlanmış istasyonlar gösteriliyor.'
                          : '$activeCount filtre aktif.',
                      style: const TextStyle(
                        color: Color(0xFFDDE8EA),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(onPressed: onClear, child: const Text('Temizle')),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 8,
                    backgroundColor: Colors.white24,
                    color: PratiCaseColors.tealBright,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$visibleCount/$totalCount',
                style: const TextStyle(
                  color: Colors.white,
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

class _FilterStrip extends StatelessWidget {
  const _FilterStrip({
    required this.label,
    required this.items,
    required this.selected,
    required this.onSelected,
    this.counts = const {},
  });

  final String label;
  final List<String> items;
  final String selected;
  final ValueChanged<String> onSelected;
  final Map<String, int> counts;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: PratiCaseColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 46,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final item = items[index];
              final active = item == selected;
              final count = counts[item];
              return ChoiceChip(
                selected: active,
                onSelected: (_) => onSelected(item),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(item),
                    if (count != null) ...[
                      const SizedBox(width: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? Colors.white.withValues(alpha: 0.20)
                              : PratiCaseColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            color: active ? Colors.white : PratiCaseColors.teal,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                selectedColor: PratiCaseColors.teal,
                backgroundColor: Colors.transparent,
                side: BorderSide(
                  color: active ? PratiCaseColors.teal : PratiCaseColors.border,
                ),
                labelStyle: TextStyle(
                  color: active ? Colors.white : PratiCaseColors.slateBlue,
                  fontWeight: FontWeight.w800,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CaseListCard extends StatelessWidget {
  const _CaseListCard({required this.item, required this.onTap});

  final OsceCaseSummary item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress = item.progressPercent;
    final score = item.lastScore;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(radius: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: PratiCaseColors.navy,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _ChipTag(label: item.branch),
                          _ChipTag(
                            label: item.difficulty.label,
                            tone: _difficultyColor(item.difficulty),
                          ),
                          _ChipTag(label: '${item.durationMinutes} dk'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const _RoundArrow(),
              ],
            ),
            const SizedBox(height: 14),
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
            const SizedBox(height: 12),
            Row(
              children: [
                _Metric(
                  icon: Icons.local_hospital_outlined,
                  text: item.setting,
                ),
                const SizedBox(width: 14),
                _Metric(
                  icon: Icons.groups_rounded,
                  text: '${item.solvedCount} çözen',
                ),
                const Spacer(),
                if (score != null)
                  _TinyPill(text: 'Son skor $score')
                else if (progress != null)
                  _TinyPill(text: '%$progress devam')
                else
                  _TinyPill(text: '${item.points} puan'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExamTopBar extends StatelessWidget {
  const _ExamTopBar({
    required this.session,
    required this.phase,
    required this.repository,
    required this.sessionId,
  });

  final ExamSessionOverview session;
  final String phase;
  final CasesRepository repository;
  final String sessionId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: PratiCaseColors.navy,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            PratiCaseColors.navy,
            Color(0xFF0A3440),
            PratiCaseColors.gradientEnd,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: PratiCaseColors.navy.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.maybePop(context),
                tooltip: 'Geri',
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.10),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      phase.toUpperCase(),
                      style: const TextStyle(
                        color: PratiCaseColors.gold,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      session.caseTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _FinishExamButton(repository: repository, sessionId: sessionId),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _TimerBadge(session: session)),
              const SizedBox(width: 8),
              Expanded(
                child: _ExamHeaderPill(
                  icon: Icons.flag_outlined,
                  text: '${session.durationMinutes} dk',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ExamHeaderPill(
                  icon: Icons.assessment_outlined,
                  text: '${session.remainingPoints}/${session.budgetPoints} p',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExamHeaderPill extends StatelessWidget {
  const _ExamHeaderPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.78), size: 16),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimerBadge extends StatefulWidget {
  const _TimerBadge({required this.session});

  final ExamSessionOverview session;

  @override
  State<_TimerBadge> createState() => _TimerBadgeState();
}

class _TimerBadgeState extends State<_TimerBadge>
    with SingleTickerProviderStateMixin {
  late Timer _timer;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _remainingParts(widget.session);
    final urgent = remaining.startsWith('00:');
    if (urgent && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!urgent && _pulseController.isAnimating) {
      _pulseController.stop();
    }
    final color = urgent ? PratiCaseColors.errorRed : PratiCaseColors.gold;
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulse = urgent ? 0.18 + (_pulseController.value * 0.16) : 0.12;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: color.withValues(alpha: pulse),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.58)),
          ),
          child: child,
        );
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.timer_rounded, color: color, size: 17),
          const SizedBox(width: 5),
          Text(
            remaining,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhaseTabs extends StatelessWidget {
  const _PhaseTabs({required this.activeStep});

  final int activeStep;

  @override
  Widget build(BuildContext context) {
    const labels = ['Anamnez', 'Muayene', 'Tetkik', 'Tanı', 'Plan'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: PratiCaseColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PratiCaseColors.border),
        boxShadow: [
          BoxShadow(
            color: PratiCaseColors.navy.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          for (var index = 0; index < labels.length; index++) ...[
            Expanded(
              child: _PhaseStep(
                icon: _phaseIcon(index),
                label: labels[index],
                active: index + 1 == activeStep,
                complete: index + 1 < activeStep,
              ),
            ),
            if (index != labels.length - 1)
              Container(
                width: 10,
                height: 2,
                decoration: BoxDecoration(
                  color: index + 1 < activeStep
                      ? PratiCaseColors.teal
                      : PratiCaseColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _PhaseStep extends StatelessWidget {
  const _PhaseStep({
    required this.icon,
    required this.label,
    required this.active,
    required this.complete,
  });

  final IconData icon;
  final String label;
  final bool active;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final color = active || complete
        ? PratiCaseColors.teal
        : const Color(0xFF8A96A6);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: active ? 34 : 30,
          height: active ? 34 : 30,
          decoration: BoxDecoration(
            color: active
                ? PratiCaseColors.teal
                : complete
                ? PratiCaseColors.teal.withValues(alpha: 0.12)
                : const Color(0xFFF1F4F7),
            shape: BoxShape.circle,
            border: Border.all(
              color: active || complete
                  ? PratiCaseColors.teal
                  : PratiCaseColors.border,
            ),
          ),
          child: Icon(
            complete ? Icons.check_rounded : icon,
            size: 16,
            color: active
                ? PratiCaseColors.white
                : complete
                ? PratiCaseColors.teal
                : const Color(0xFF8A96A6),
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: active ? FontWeight.w900 : FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

IconData _phaseIcon(int index) {
  return switch (index) {
    0 => Icons.record_voice_over_outlined,
    1 => Icons.health_and_safety_outlined,
    2 => Icons.science_outlined,
    3 => Icons.fact_check_outlined,
    _ => Icons.assignment_turned_in_outlined,
  };
}

String _remainingParts(ExamSessionOverview session) {
  final endAt = session.startedAt.add(
    Duration(minutes: session.durationMinutes),
  );
  final remaining = endAt.difference(DateTime.now());
  final safeRemaining = remaining.isNegative ? Duration.zero : remaining;
  final minutes = safeRemaining.inMinutes
      .remainder(60)
      .toString()
      .padLeft(2, '0');
  final seconds = safeRemaining.inSeconds
      .remainder(60)
      .toString()
      .padLeft(2, '0');
  return '$minutes:$seconds';
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
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.45,
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

class _AnamnesisWorkspace extends StatelessWidget {
  const _AnamnesisWorkspace({
    required this.bundle,
    required this.scrollController,
    required this.patientTyping,
    required this.onOpenProgress,
    required this.onAddNote,
    this.pendingCandidateMessage,
  });

  final _ChatBundle bundle;
  final ScrollController scrollController;
  final bool patientTyping;
  final String? pendingCandidateMessage;
  final VoidCallback onOpenProgress;
  final VoidCallback onAddNote;

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20, keyboardOpen ? 8 : 12, 20, 8),
          child: Column(
            children: [
              if (keyboardOpen)
                _AnamnesisPatientStrip(session: bundle.session)
              else ...[
                const _PhaseTabs(activeStep: 1),
                const SizedBox(height: 12),
                _AnamnesisBriefCard(
                  session: bundle.session,
                  detail: bundle.detail,
                ),
                const SizedBox(height: 10),
                _AnamnesisActionRow(
                  onOpenProgress: onOpenProgress,
                  onAddNote: onAddNote,
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: _ConversationPanel(
            session: bundle.session,
            messages: bundle.messages,
            scrollController: scrollController,
            pendingCandidateMessage: pendingCandidateMessage,
            patientTyping: patientTyping,
          ),
        ),
      ],
    );
  }
}

class _AnamnesisBriefCard extends StatelessWidget {
  const _AnamnesisBriefCard({required this.session, required this.detail});

  final ExamSessionOverview session;
  final OsceCaseDetail detail;

  @override
  Widget build(BuildContext context) {
    final patient = session.patient;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
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
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: PratiCaseColors.navy,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 7,
                      runSpacing: 6,
                      children: [
                        _PatientMiniPill(
                          icon: Icons.cake_outlined,
                          text: '${patient.age}, ${patient.gender}',
                        ),
                        _PatientMiniPill(
                          icon: Icons.local_hospital_outlined,
                          text: patient.applicationSetting,
                        ),
                        _PatientMiniPill(
                          icon: Icons.schedule_rounded,
                          text: patient.complaintDuration,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F7F7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: PratiCaseColors.teal.withValues(alpha: 0.12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Aday Yönergesi',
                  style: TextStyle(
                    color: PratiCaseColors.teal,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  detail.candidatePrompt,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PratiCaseColors.navy,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
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

class _AnamnesisPatientStrip extends StatelessWidget {
  const _AnamnesisPatientStrip({required this.session});

  final ExamSessionOverview session;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: PratiCaseColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PratiCaseColors.border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.record_voice_over_outlined,
            color: PratiCaseColors.teal,
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: Text(
              '${session.patient.name} ile anamnez',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: PratiCaseColors.navy,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 2,
            child: Text(
              session.patient.mainComplaint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: PratiCaseColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnamnesisActionRow extends StatelessWidget {
  const _AnamnesisActionRow({
    required this.onOpenProgress,
    required this.onAddNote,
  });

  final VoidCallback onOpenProgress;
  final VoidCallback onAddNote;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onOpenProgress,
            icon: const Icon(Icons.timeline_rounded),
            label: const FittedBox(child: Text('Vaka İlerlemesi')),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onAddNote,
            icon: const Icon(Icons.note_add_outlined),
            label: const Text('Not Ekle'),
          ),
        ),
      ],
    );
  }
}

class _ConversationPanel extends StatelessWidget {
  const _ConversationPanel({
    required this.session,
    required this.messages,
    required this.scrollController,
    required this.patientTyping,
    this.pendingCandidateMessage,
  });

  final ExamSessionOverview session;
  final List<ChatMessage> messages;
  final ScrollController scrollController;
  final bool patientTyping;
  final String? pendingCandidateMessage;

  @override
  Widget build(BuildContext context) {
    final pending = pendingCandidateMessage?.trim();
    final conversationCount =
        messages.length + (pending == null || pending.isEmpty ? 0 : 1) + 1;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      decoration: BoxDecoration(
        color: PratiCaseColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PratiCaseColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: PratiCaseColors.teal,
                  size: 19,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Görüşme Kaydı',
                    style: TextStyle(
                      color: PratiCaseColors.navy,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _TinyPill(text: '$conversationCount mesaj'),
              ],
            ),
          ),
          const Divider(height: 1, color: PratiCaseColors.border),
          Expanded(
            child: ListView(
              controller: scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              children: [
                _ChatBubble(
                  message: session.patient.openingLine,
                  fromCandidate: false,
                  isOpening: true,
                ),
                for (final message in messages)
                  _ChatBubble(
                    message: message.message,
                    fromCandidate: message.fromCandidate,
                  ),
                if (pending != null && pending.isNotEmpty)
                  _ChatBubble(
                    message: pending,
                    fromCandidate: true,
                    isPending: true,
                  ),
                if (patientTyping) const _TypingBubble(),
              ],
            ),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PratiCaseColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PratiCaseColors.border),
        boxShadow: [
          BoxShadow(
            color: PratiCaseColors.navy.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
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
        color: const Color(0xFFF1F5F8),
        borderRadius: BorderRadius.circular(999),
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
          color: fromCandidate ? PratiCaseColors.teal : PratiCaseColors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(fromCandidate ? 16 : 5),
            bottomRight: Radius.circular(fromCandidate ? 5 : 16),
          ),
          border: fromCandidate
              ? null
              : Border.all(color: PratiCaseColors.border),
          boxShadow: [
            BoxShadow(
              color: PratiCaseColors.navy.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
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

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF6FAFA),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(5),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: PratiCaseColors.border),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: PratiCaseColors.teal,
              ),
            ),
            SizedBox(width: 8),
            Text(
              'Hasta yanıtlıyor...',
              style: TextStyle(
                color: PratiCaseColors.teal,
                fontWeight: FontWeight.w800,
              ),
            ),
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
    required this.onSend,
    required this.onNext,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: PratiCaseColors.white,
          border: const Border(top: BorderSide(color: PratiCaseColors.border)),
          boxShadow: [
            BoxShadow(
              color: PratiCaseColors.navy.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                      decoration: const InputDecoration(
                        hintText: 'Hastaya sorunuzu yazın...',
                        prefixIcon: Icon(Icons.record_voice_over_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: IconButton.filled(
                      onPressed: sending ? null : onSend,
                      tooltip: 'Gönder',
                      style: IconButton.styleFrom(
                        backgroundColor: PratiCaseColors.teal,
                        foregroundColor: PratiCaseColors.white,
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
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: onNext,
                  icon: const Icon(Icons.health_and_safety_outlined),
                  label: const Text('Muayeneye Geç'),
                ),
              ),
            ],
          ),
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
            for (final item in options) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: item.isSelected
                      ? PratiCaseColors.teal.withValues(alpha: 0.08)
                      : PratiCaseColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: item.isSelected
                        ? PratiCaseColors.teal
                        : PratiCaseColors.border,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  title: Text(
                    item.title,
                    style: const TextStyle(
                      color: PratiCaseColors.navy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
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
              ),
            ],
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
      decoration: BoxDecoration(
        color: item.isSelected
            ? PratiCaseColors.teal.withValues(alpha: 0.08)
            : PratiCaseColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isSelected
              ? PratiCaseColors.teal
              : PratiCaseColors.border,
          width: item.isSelected ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: PratiCaseColors.navy.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
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
            Text(
              '${item.pointCost} p',
              style: const TextStyle(
                color: PratiCaseColors.muted,
                fontWeight: FontWeight.w800,
              ),
            ),
            IconButton(
              onPressed: onTap,
              icon: Icon(
                item.isSelected ? Icons.check_circle : Icons.add_circle_outline,
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
  const _BottomAction({
    required this.label,
    required this.onPressed,
    this.icon = Icons.arrow_forward_rounded,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: onPressed == null ? 0.55 : 1,
      child: SizedBox(
        height: 58,
        child: FilledButton.icon(
          onPressed: onPressed,
          label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          icon: Icon(icon),
          style: FilledButton.styleFrom(
            backgroundColor: PratiCaseColors.teal,
            foregroundColor: PratiCaseColors.white,
            textStyle: const TextStyle(fontWeight: FontWeight.w900),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
        ),
      ),
    );
  }
}

class _FinishExamButton extends StatelessWidget {
  const _FinishExamButton({required this.repository, required this.sessionId});

  final CasesRepository repository;
  final String sessionId;

  Future<void> _finish(BuildContext context) async {
    await repository.advanceSession(sessionId: sessionId, step: 'completed');
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ResultScreen(repository: repository, sessionId: sessionId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Sınavı Bitir',
      child: IconButton.filled(
        onPressed: () => _finish(context),
        icon: const Icon(Icons.stop_circle_outlined, size: 21),
        style: IconButton.styleFrom(
          backgroundColor: PratiCaseColors.errorRed,
          foregroundColor: PratiCaseColors.white,
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
      child: Row(
        children: [
          Icon(icon, color: PratiCaseColors.teal, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PratiCaseColors.navy,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
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
  const _ChipTag({required this.label, this.tone});

  final String label;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final color = tone ?? PratiCaseColors.teal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: PratiCaseColors.gold.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFE18A00),
          fontSize: 12,
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
  const _ChatBundle({
    required this.session,
    required this.detail,
    required this.messages,
  });

  final ExamSessionOverview session;
  final OsceCaseDetail detail;
  final List<ChatMessage> messages;

  _ChatBundle copyWith({List<ChatMessage>? messages}) {
    return _ChatBundle(
      session: session,
      detail: detail,
      messages: messages ?? this.messages,
    );
  }
}

class _PhysicalBundle {
  const _PhysicalBundle({
    required this.session,
    required this.groups,
    required this.options,
  });

  final ExamSessionOverview session;
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

String _managementCategoryTitle(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.contains('kons') || normalized.contains('consult')) {
    return 'Konsültasyon İstemleri';
  }
  if (normalized.contains('acil') ||
      normalized.contains('emergency') ||
      normalized.contains('tetkik')) {
    return 'Acil Müdahaleler ve Ek Tetkikler';
  }
  if (normalized.contains('tedavi') ||
      normalized.contains('treatment') ||
      normalized.contains('ilaç')) {
    return 'Tedavi Planı';
  }
  return value.trim().isEmpty ? 'Tedavi Planı' : value;
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
            'Klinik Başarı Puanı',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '${result.totalScore}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 44,
                    height: 42 / 44,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(
                  text: '/${result.maxScore}',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            result.percentage >= 80
                ? 'Mükemmel bir teşhis süreci yönettiniz.'
                : '${result.caseTitle} için gelişim alanların hazır.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'Kategori Performansı',
            style: TextStyle(
              color: PratiCaseColors.navy,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.55,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [for (final score in scores) _ScoreCard(score: score)],
        ),
      ],
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.score});

  final ResultCategoryScore score;

  @override
  Widget build(BuildContext context) {
    final percent = score.maxScore == 0 ? 0.0 : score.score / score.maxScore;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PratiCaseColors.teal.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PratiCaseColors.teal.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_outlined, color: PratiCaseColors.teal),
          const Spacer(),
          Text(
            score.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: PratiCaseColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '${score.score}',
                style: const TextStyle(
                  color: PratiCaseColors.navy,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '/${score.maxScore}',
                style: const TextStyle(
                  color: PratiCaseColors.muted,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '%${(percent * 100).round()}',
                style: const TextStyle(
                  color: PratiCaseColors.teal,
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

class _ResultActions extends StatelessWidget {
  const _ResultActions({
    required this.onRetry,
    required this.onReport,
    required this.onSuggestedCases,
  });

  final VoidCallback onRetry;
  final VoidCallback onReport;
  final VoidCallback onSuggestedCases;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Tekrar Çöz'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: onReport,
            icon: const Icon(Icons.description_outlined),
            label: const Text('Detaylı Rapor'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: onSuggestedCases,
            icon: const Icon(Icons.library_books_outlined),
            label: const Text('Benzer Vaka Önerileri'),
          ),
        ),
      ],
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

class _IdealApproachCard extends StatelessWidget {
  const _IdealApproachCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'İdeal Yaklaşım Özeti',
      child: Text(
        text.isEmpty ? 'Canlı karne özeti henüz oluşmadı.' : text,
        style: const TextStyle(
          color: Color(0xFF405168),
          fontWeight: FontWeight.w700,
          height: 1.45,
        ),
      ),
    );
  }
}

BoxDecoration _cardDecoration({double radius = 16}) {
  return BoxDecoration(
    color: PratiCaseColors.white,
    borderRadius: BorderRadius.circular(radius),
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
      return Icons.monitor_heart_outlined;
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
    case 'chat':
      return Icons.chat_bubble_outline_rounded;
    case 'exam':
    case 'stethoscope':
      return Icons.health_and_safety_outlined;
    case 'tests':
    case 'tube':
      return Icons.science_outlined;
    case 'diagnosis':
    case 'clipboard':
      return Icons.fact_check_outlined;
    case 'management':
      return Icons.assignment_turned_in_rounded;
    default:
      return Icons.radio_button_checked_rounded;
  }
}

String _errorText(Object? error) {
  if (error is CasesDataUnavailable) return error.message;
  return 'Canlı veri alınamadı. Lütfen bağlantı ve yetkileri kontrol edin.';
}
