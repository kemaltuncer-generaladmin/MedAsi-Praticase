import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/praticase_colors.dart';
import '../../../app/theme/praticase_motion.dart';
import '../../../app/theme/praticase_tokens.dart';
import '../../../shared/data/user_facing_error.dart';
import '../../../shared/ui/ui.dart';
import '../data/cases_repository.dart';
import '../data/voice_exam_adapter.dart';
import '../domain/osce_case.dart';

part 'widgets/cases_chat.dart';
part 'widgets/cases_lab.dart';
part 'widgets/cases_imaging.dart';
part 'widgets/cases_result.dart';

enum CasesScreenMode { library, singleStation, miniOsce }

const _miniOsceStationCount = 3;

class MiniOscePlan {
  const MiniOscePlan({
    required this.caseIds,
    this.currentIndex = 0,
    this.completedSessionIds = const <String>[],
  });

  final List<String> caseIds;
  final int currentIndex;
  final List<String> completedSessionIds;

  int get stationNumber => currentIndex + 1;
  int get totalStations => caseIds.length;
  String get currentCaseId => caseIds[currentIndex];
  bool get hasNext => currentIndex + 1 < caseIds.length;
  String? get nextCaseId => hasNext ? caseIds[currentIndex + 1] : null;

  MiniOscePlan completeCurrent(String sessionId) {
    final completed = <String>[...completedSessionIds];
    if (!completed.contains(sessionId)) completed.add(sessionId);
    return MiniOscePlan(
      caseIds: caseIds,
      currentIndex: currentIndex,
      completedSessionIds: completed,
    );
  }

  MiniOscePlan advance() {
    return MiniOscePlan(
      caseIds: caseIds,
      currentIndex: currentIndex + 1,
      completedSessionIds: completedSessionIds,
    );
  }
}

class CasesScreen extends StatefulWidget {
  const CasesScreen({
    required this.repository,
    this.onOpenNotifications,
    this.onOpenProfile,
    this.onOpenHome,
    this.mode = CasesScreenMode.library,
    this.unreadNotificationCount = 0,
    super.key,
  });

  final CasesRepository repository;
  final VoidCallback? onOpenNotifications;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenHome;
  final CasesScreenMode mode;
  final int unreadNotificationCount;

  @override
  State<CasesScreen> createState() => _CasesScreenState();
}

class _CasesScreenState extends State<CasesScreen> {
  final _searchController = TextEditingController();
  final _miniSelection = <String>[];
  Timer? _searchDebounce;
  String? _branch;
  String? _difficulty;
  String? _setting;
  late Future<List<OsceCaseSummary>> _casesFuture;
  bool _startingMiniOsce = false;

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
    return Scaffold(
      backgroundColor: PratiCaseColors.softSurface,
      bottomNavigationBar: _isMiniOsce
          ? _MiniOsceStartBar(
              selectedCount: _miniSelection.length,
              requiredCount: _miniOsceStationCount,
              starting: _startingMiniOsce,
              onStart: _startMiniOsce,
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<List<OsceCaseSummary>>(
          future: _casesFuture,
          builder: (context, snapshot) {
            final allCases = snapshot.data ?? const <OsceCaseSummary>[];
            final visibleCases = _visibleCases(allCases);
            return RefreshIndicator(
              onRefresh: _refresh,
              child: PratiCaseResponsiveListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: PratiCaseResponsive.pagePadding(context),
                children: [
                  _MobileHeader(
                    onOpenNotifications: widget.onOpenNotifications,
                    onOpenProfile: widget.onOpenProfile,
                    unreadNotificationCount: widget.unreadNotificationCount,
                  ),
                  const SizedBox(height: 34),
                  _PageTitle(title: _pageTitle, subtitle: _pageSubtitle),
                  if (_isMiniOsce) ...[
                    const SizedBox(height: 18),
                    _MiniOsceSelectionNotice(
                      selectedCount: _miniSelection.length,
                      requiredCount: _miniOsceStationCount,
                    ),
                  ],
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
                      child: PratiCaseInlineSkeleton(
                        heroHeight: 132,
                        cardCount: 3,
                      ),
                    )
                  else if (snapshot.hasError)
                    Padding(
                      padding: const EdgeInsets.only(top: 22),
                      child: _CenteredState(
                        icon: Icons.cloud_off_rounded,
                        title: 'Vakalar yüklenemedi',
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
                        setState(() {
                          _branch = value == 'Tümü' ? null : value;
                          _difficulty = null;
                          _setting = null;
                        });
                      },
                    ),
                    if (_branch != null) ...[
                      const SizedBox(height: 18),
                      _FilterStrip(
                        label: 'Zorluk',
                        items: const ['Tümü', 'Kolay', 'Orta', 'Zor'],
                        selected: _difficulty ?? 'Tümü',
                        counts: _counts(
                          snapshot.requireData
                              .where((item) => item.branch == _branch)
                              .map((item) => item.difficulty.label),
                        ),
                        onSelected: (value) {
                          setState(() {
                            _difficulty = value == 'Tümü' ? null : value;
                            _setting = null;
                          });
                        },
                      ),
                    ],
                    if (_branch != null && _difficulty != null) ...[
                      const SizedBox(height: 18),
                      _FilterStrip(
                        label: 'Klinik Ortam',
                        items: [
                          'Tümü',
                          ...{
                            for (final item in snapshot.requireData)
                              if (item.branch == _branch &&
                                  item.difficulty.label == _difficulty &&
                                  item.setting.trim().isNotEmpty)
                                item.setting,
                          },
                        ],
                        selected: _setting ?? 'Tümü',
                        counts: _counts(
                          snapshot.requireData
                              .where(
                                (item) =>
                                    item.branch == _branch &&
                                    item.difficulty.label == _difficulty,
                              )
                              .map((item) => item.setting),
                        ),
                        onSelected: (value) {
                          setState(
                            () => _setting = value == 'Tümü' ? null : value,
                          );
                        },
                      ),
                    ],
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
                      _CaseResultsGrid(
                        cases: visibleCases,
                        onOpenCase: _isMiniOsce
                            ? _toggleMiniSelection
                            : (item) => _openDetail(context, item.id),
                        selectionMode: _isMiniOsce,
                        selectionOrderFor: _isMiniOsce
                            ? (item) => _selectionOrderFor(item.id)
                            : null,
                        selectionLimitReached:
                            _isMiniOsce &&
                            _miniSelection.length >= _miniOsceStationCount,
                      ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  bool get _isMiniOsce => widget.mode == CasesScreenMode.miniOsce;

  void _toggleMiniSelection(OsceCaseSummary item) {
    setState(() {
      if (_miniSelection.remove(item.id)) return;
      if (_miniSelection.length < _miniOsceStationCount) {
        _miniSelection.add(item.id);
        return;
      }
    });
    if (!_miniSelection.contains(item.id) &&
        _miniSelection.length >= _miniOsceStationCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mini OSCE için 3 istasyon seçildi.')),
      );
    }
  }

  int _selectionOrderFor(String caseId) {
    final index = _miniSelection.indexOf(caseId);
    return index < 0 ? 0 : index + 1;
  }

  Future<void> _startMiniOsce() async {
    if (_startingMiniOsce || _miniSelection.length != _miniOsceStationCount) {
      return;
    }
    setState(() => _startingMiniOsce = true);
    try {
      final plan = MiniOscePlan(caseIds: List<String>.of(_miniSelection));
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CaseDetailScreen(
            repository: widget.repository,
            caseId: plan.currentCaseId,
            mode: CasesScreenMode.miniOsce,
            miniPlan: plan,
            onOpenHome: widget.onOpenHome,
          ),
        ),
      );
    } on CasesDataUnavailable catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _startingMiniOsce = false);
    }
  }

  void _openDetail(BuildContext context, String caseId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CaseDetailScreen(
          repository: widget.repository,
          caseId: caseId,
          mode: widget.mode,
          onOpenHome: widget.onOpenHome,
        ),
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
    });
  }

  int get _activeFilterCount {
    return [_branch, _difficulty, _setting].whereType<String>().length;
  }

  String get _pageTitle {
    return switch (widget.mode) {
      CasesScreenMode.singleStation => 'Tek İstasyon Seç',
      CasesScreenMode.miniOsce => 'Mini OSCE Seç',
      CasesScreenMode.library => 'OSCE İstasyonları',
    };
  }

  String get _pageSubtitle {
    return switch (widget.mode) {
      CasesScreenMode.singleStation =>
        'Bir vaka seç, yönergeyi oku ve süreli hasta görüşmesine başla.',
      CasesScreenMode.miniOsce =>
        '3 istasyon seç; istasyonlar arka arkaya açılır, değerlendirme en sonda gösterilir.',
      CasesScreenMode.library =>
        'Başlamak için bir istasyon seçin ve pratiğe hemen başlayın.',
    };
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
      return true;
    }).toList();
    filtered.sort(_caseSorter);
    return filtered;
  }

  int _caseSorter(OsceCaseSummary a, OsceCaseSummary b) {
    final solvedOrder = _solved(a).compareTo(_solved(b));
    if (solvedOrder != 0) return solvedOrder;
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  }

  int _solved(OsceCaseSummary item) =>
      item.lastScore != null || item.progressPercent == 100 ? 1 : 0;

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
        padding: _flowListPadding(context),
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
                  label: '1. Branş',
                  value: 'Önce klinik dal seçilir',
                ),
                _FilterSummaryRow(
                  label: '2. Zorluk',
                  value: 'Branşa uygun zorluk açılır',
                ),
                _FilterSummaryRow(
                  label: '3. Klinik Ortam',
                  value: 'Son adımda ortam daraltılır',
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
    this.mode = CasesScreenMode.library,
    this.miniPlan,
    this.onOpenHome,
    super.key,
  });

  final CasesRepository repository;
  final String caseId;
  final CasesScreenMode mode;
  final MiniOscePlan? miniPlan;
  final VoidCallback? onOpenHome;

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
            miniPlan: widget.miniPlan,
            onOpenHome: widget.onOpenHome,
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
            return const _CaseDetailSkeleton();
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
            padding: _flowListPadding(context, top: 14, bottom: 110),
            children: [
              _StepTopBar(
                title: _topBarTitle,
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
              _PatientInfoCard(
                patient: detail.patient,
                durationMinutes: detail.summary.durationMinutes,
              ),
              const SizedBox(height: 18),
              const _ExamModeNotice(),
            ],
          );
        },
      ),
      bottom: _BottomAction(
        identifier: 'cta.start-case',
        label: _starting ? 'Başlatılıyor...' : _startLabel,
        onPressed: _starting ? null : _start,
      ),
    );
  }

  String get _topBarTitle {
    return switch (widget.mode) {
      CasesScreenMode.singleStation => 'Tek İstasyon',
      CasesScreenMode.miniOsce => 'Mini OSCE',
      CasesScreenMode.library => 'Vaka Detay',
    };
  }

  String get _startLabel {
    return switch (widget.mode) {
      CasesScreenMode.singleStation => 'Sınava Başla',
      CasesScreenMode.miniOsce => 'Mini OSCE’ye Başla',
      CasesScreenMode.library => 'Vaka Çözümüne Başla',
    };
  }
}

class PatientChatScreen extends StatefulWidget {
  const PatientChatScreen({
    required this.repository,
    required this.sessionId,
    this.voiceAdapter,
    this.miniPlan,
    this.onOpenHome,
    super.key,
  });

  final CasesRepository repository;
  final String sessionId;
  final VoiceExamAdapter? voiceAdapter;
  final MiniOscePlan? miniPlan;
  final VoidCallback? onOpenHome;

  @override
  State<PatientChatScreen> createState() => _PatientChatScreenState();
}

class _PatientChatScreenState extends State<PatientChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  late final VoiceExamAdapter _voiceAdapter;
  StreamSubscription<VoiceExamState>? _voiceSubscription;
  Timer? _autoResumeTimer;
  late Future<_ChatBundle> _bundleFuture;
  bool _sending = false;
  bool _navigating = false;
  bool _voiceExamMode = false;
  String? _pendingCandidateMessage;
  VoiceExamState _voiceState = const VoiceExamState();
  bool _wasSpeaking = false;
  String? _shownVoiceError;
  static const _autoResumeDelay = Duration(milliseconds: 450);

  @override
  void initState() {
    super.initState();
    _voiceAdapter = widget.voiceAdapter ?? NativeVoiceExamAdapter();
    _voiceState = _voiceAdapter.state;
    _voiceSubscription = _voiceAdapter.states.listen((state) {
      if (!mounted) return;
      // Detect the moment the patient finishes speaking so a hands-free voice
      // exam can reopen the microphone automatically (the user just keeps
      // talking, no tap required).
      final finishedSpeaking = _wasSpeaking && !state.speaking;
      _wasSpeaking = state.speaking;
      setState(() => _voiceState = state);
      _surfaceVoiceError(state);
      if (finishedSpeaking) _scheduleAutoResumeListening();
    });
    _bundleFuture = _load();
  }

  /// Surfaces a voice error (mic unavailable, speech synthesis failed, …) once,
  /// so spoken-mode failures are never silent. Re-arms when the error clears.
  void _surfaceVoiceError(VoiceExamState state) {
    final error = state.errorMessage?.trim();
    if (error == null || error.isEmpty) {
      _shownVoiceError = null;
      return;
    }
    if (error == _shownVoiceError || !mounted) return;
    _shownVoiceError = error;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  /// Reopens the microphone after the patient's reply finishes playing so the
  /// candidate can continue the anamnesis entirely by voice.
  void _scheduleAutoResumeListening() {
    _autoResumeTimer?.cancel();
    _autoResumeTimer = Timer(_autoResumeDelay, () {
      if (!mounted) return;
      _maybeAutoResumeListening();
    });
  }

  void _maybeAutoResumeListening() {
    final voiceState = _voiceAdapter.state;
    if (!_voiceExamMode || voiceState.muted || !voiceState.available) return;
    if (_sending || voiceState.listening || voiceState.speaking) return;
    if (_messageController.text.trim().isNotEmpty) return;
    unawaited(_beginListening());
  }

  @override
  void dispose() {
    _autoResumeTimer?.cancel();
    _voiceSubscription?.cancel();
    _voiceAdapter.dispose();
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
    FocusManager.instance.primaryFocus?.unfocus();
    final currentBundle = await _bundleFuture;
    final previousPatientReplies = _patientReplyCount(currentBundle.messages);
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
      final messages = await widget.repository.loadMessages(widget.sessionId);
      final sortedMessages = _chronologicalMessages(messages);
      setState(
        () => _bundleFuture = Future.value(
          currentBundle.copyWith(messages: sortedMessages),
        ),
      );
      await _bundleFuture;
      unawaited(
        _speakLatestPatient(currentBundle.copyWith(messages: sortedMessages)),
      );
      _scheduleScrollToBottom();
    } on Object catch (error) {
      // A long AI patient turn can complete on the server even when the HTTP
      // call fails client-side (slow/dropped connection). Re-fetch before
      // surfacing an error so a slow-but-successful reply is never lost and the
      // question is not duplicated on retry.
      final recovered = await _recoverAfterFailedSend(
        currentBundle,
        previousPatientReplies,
      );
      if (recovered || !mounted) return;
      _restoreFailedMessage(text);
      if (!mounted) return;
      final message = error is CasesDataUnavailable
          ? error.message
          : 'Hasta yanıtı alınamadı. Bağlantını kontrol edip tekrar dene.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
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

  int _patientReplyCount(List<ChatMessage> messages) =>
      messages.where((message) => !message.fromCandidate).length;

  /// After a failed send, the server may still have recorded the patient reply.
  /// Re-fetch (with one short delayed retry for replies that land moments later)
  /// and adopt the conversation if a new patient turn appeared. Returns true
  /// when recovery succeeded, so the caller can skip the error path.
  Future<bool> _recoverAfterFailedSend(
    _ChatBundle base,
    int previousPatientReplies,
  ) async {
    for (var attempt = 0; attempt < 2 && mounted; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(const Duration(seconds: 3));
        if (!mounted) return false;
      }
      try {
        final messages = await widget.repository.loadMessages(widget.sessionId);
        final sortedMessages = _chronologicalMessages(messages);
        if (_patientReplyCount(sortedMessages) <= previousPatientReplies) {
          continue;
        }
        if (!mounted) return true;
        setState(
          () => _bundleFuture = Future.value(
            base.copyWith(messages: sortedMessages),
          ),
        );
        await _bundleFuture;
        unawaited(_speakLatestPatient(base.copyWith(messages: sortedMessages)));
        _scheduleScrollToBottom();
        return true;
      } on Object {
        // Reload failed too; fall through to retry or give up.
      }
    }
    return false;
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
            miniPlan: widget.miniPlan,
            onOpenHome: widget.onOpenHome,
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

  Future<void> _toggleVoiceExamMode() async {
    final enabled = !_voiceExamMode;
    setState(() => _voiceExamMode = enabled);
    if (enabled) {
      await _voiceAdapter.initialize();
      final bundle = await _bundleFuture;
      unawaited(_speakLatestPatient(bundle));
    } else {
      _autoResumeTimer?.cancel();
      await _voiceAdapter.stopListening();
      await _voiceAdapter.stopSpeaking();
    }
  }

  Future<void> _toggleListening() async {
    if (_voiceState.listening) {
      await _voiceAdapter.stopListening();
      return;
    }
    // Tapping the mic while the patient is still speaking interrupts playback
    // (barge-in) so the candidate can jump straight back in.
    if (_voiceState.speaking) await _voiceAdapter.stopSpeaking();
    await _beginListening();
  }

  Future<void> _beginListening() async {
    _autoResumeTimer?.cancel();
    final voiceState = _voiceAdapter.state;
    if (_sending || voiceState.listening || voiceState.speaking) return;
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
        if (_voiceExamMode) unawaited(_send());
      },
    );
  }

  Future<void> _toggleMute() async {
    await _voiceAdapter.setMuted(!_voiceState.muted);
  }

  Future<void> _speakLatestPatient(_ChatBundle bundle) async {
    if (!_voiceExamMode || _voiceState.muted) return;
    final text = _latestPatientText(bundle);
    if (text.trim().isEmpty) return;
    _autoResumeTimer?.cancel();
    await _voiceAdapter.speak(text);
  }

  String _latestPatientText(_ChatBundle bundle) {
    for (final message in bundle.messages.reversed) {
      if (!message.fromCandidate && message.message.trim().isNotEmpty) {
        return message.message;
      }
    }
    return bundle.session.patient.openingLine;
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
            return const _PhaseLoadingSkeleton(activeStep: 1);
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
                phase: _miniPhaseLabel('Anamnez', widget.miniPlan),
                repository: widget.repository,
                sessionId: widget.sessionId,
                onOpenHome: widget.onOpenHome,
                onFinish: widget.miniPlan == null
                    ? null
                    : () => _finishMiniOsceStation(
                        context: context,
                        repository: widget.repository,
                        miniPlan: widget.miniPlan!,
                        sessionId: widget.sessionId,
                        onOpenHome: widget.onOpenHome,
                      ),
              ),
              Expanded(
                child: _AnamnesisWorkspace(
                  bundle: bundle,
                  scrollController: _scrollController,
                  pendingCandidateMessage: _pendingCandidateMessage,
                  patientTyping: _sending,
                  voiceState: _voiceState,
                  voiceExamMode: _voiceExamMode,
                  onReplayPatient: () => _speakLatestPatient(bundle),
                  onStopSpeaking: _voiceAdapter.stopSpeaking,
                  onToggleMute: _toggleMute,
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
                voiceState: _voiceState,
                voiceExamMode: _voiceExamMode,
                onSend: _send,
                onNext: _navigating ? null : _next,
                onToggleVoiceMode: _toggleVoiceExamMode,
                onToggleListening: _toggleListening,
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

String _miniPhaseLabel(String phase, MiniOscePlan? plan) {
  if (plan == null) return phase;
  return 'Mini OSCE ${plan.stationNumber}/${plan.totalStations} · $phase';
}

Future<void> _finishMiniOsceStation({
  required BuildContext context,
  required CasesRepository repository,
  required MiniOscePlan miniPlan,
  required String sessionId,
  VoidCallback? onOpenHome,
}) async {
  final shouldFinish = await _confirmIncompleteFinish(context);
  if (!shouldFinish || !context.mounted) return;
  await repository.advanceSession(sessionId: sessionId, step: 'completed');
  if (!context.mounted) return;
  await _continueMiniOsceOrShowResult(
    context: context,
    repository: repository,
    miniPlan: miniPlan,
    completedSessionId: sessionId,
    onOpenHome: onOpenHome,
  );
}

Future<void> _continueMiniOsceOrShowResult({
  required BuildContext context,
  required CasesRepository repository,
  required MiniOscePlan miniPlan,
  required String completedSessionId,
  VoidCallback? onOpenHome,
}) async {
  final completedPlan = miniPlan.completeCurrent(completedSessionId);
  if (!completedPlan.hasNext) {
    if (!context.mounted) return;
    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => MiniOsceResultScreen(
          repository: repository,
          plan: completedPlan,
          onOpenHome: onOpenHome,
        ),
      ),
      (route) => route.isFirst,
    );
    return;
  }

  final nextCaseId = completedPlan.nextCaseId;
  if (nextCaseId == null) return;
  if (!context.mounted) return;
  await Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute<void>(
      builder: (_) => CaseDetailScreen(
        repository: repository,
        caseId: nextCaseId,
        mode: CasesScreenMode.miniOsce,
        miniPlan: completedPlan.advance(),
        onOpenHome: onOpenHome,
      ),
    ),
    (route) => route.isFirst,
  );
}

class PhysicalExamScreen extends StatefulWidget {
  const PhysicalExamScreen({
    required this.repository,
    required this.sessionId,
    required this.caseId,
    this.miniPlan,
    this.onOpenHome,
    super.key,
  });

  final CasesRepository repository;
  final String sessionId;
  final String caseId;
  final MiniOscePlan? miniPlan;
  final VoidCallback? onOpenHome;

  @override
  State<PhysicalExamScreen> createState() => _PhysicalExamScreenState();
}

class _PhysicalExamScreenState extends State<PhysicalExamScreen> {
  late Future<_PhysicalBundle> _bundleFuture;
  String? _selectedGroupId;
  var _phaseReady = false;
  var _navigating = false;

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
    _phaseReady = true;
    scheduleMicrotask(() {
      if (mounted) setState(() {});
    });
    return _PhysicalBundle(session: session, groups: groups, options: options);
  }

  Future<void> _select(String optionId) async {
    try {
      await widget.repository.selectPhysicalExam(
        sessionId: widget.sessionId,
        optionId: optionId,
      );
      setState(() {
        _bundleFuture = _load();
      });
    } on CasesDataUnavailable catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _next() async {
    if (!_phaseReady || _navigating) return;
    setState(() => _navigating = true);
    try {
      await widget.repository.advanceSession(
        sessionId: widget.sessionId,
        step: 'tests',
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TestsScreen(
            repository: widget.repository,
            sessionId: widget.sessionId,
            caseId: widget.caseId,
            miniPlan: widget.miniPlan,
            onOpenHome: widget.onOpenHome,
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

  @override
  Widget build(BuildContext context) {
    return _FlowScaffold(
      body: FutureBuilder<_PhysicalBundle>(
        future: _bundleFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _PhaseLoadingSkeleton(activeStep: 2);
          }
          if (snapshot.hasError) {
            return _CenteredState(
              icon: Icons.cloud_off_rounded,
              title: 'Muayene açılamadı',
              body: _errorText(snapshot.error),
            );
          }
          final bundle = snapshot.requireData;
          final groupId = _selectedGroupId;
          PhysicalExamGroup? selectedGroup;
          if (groupId != null) {
            for (final group in bundle.groups) {
              if (group.id == groupId) {
                selectedGroup = group;
                break;
              }
            }
          }
          final visible = bundle.options
              .where((item) => item.groupId == groupId)
              .toList();
          final selectedCount = bundle.options
              .where((item) => item.isSelected)
              .length;
          return Column(
            children: [
              _ExamTopBar(
                session: bundle.session,
                phase: _miniPhaseLabel('Fizik Muayene', widget.miniPlan),
                repository: widget.repository,
                sessionId: widget.sessionId,
                onOpenHome: widget.onOpenHome,
                onFinish: widget.miniPlan == null
                    ? null
                    : () => _finishMiniOsceStation(
                        context: context,
                        repository: widget.repository,
                        miniPlan: widget.miniPlan!,
                        sessionId: widget.sessionId,
                        onOpenHome: widget.onOpenHome,
                      ),
              ),
              Expanded(
                child: ListView(
                  padding: _flowListPadding(context, top: 16),
                  children: [
                    _PhaseTabs(
                      activeStep: 2,
                      onStepSelected: (step) => _popBackToExamPhase(
                        context,
                        activeStep: 2,
                        step: step,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _PatientBanner(session: bundle.session),
                    const SizedBox(height: 18),
                    _SelectionSummary(
                      text: selectedGroup == null
                          ? 'Muayene Sistemi Seç'
                          : selectedGroup.title,
                      subtext: selectedCount == 0
                          ? 'Henüz muayene seçilmedi'
                          : '$selectedCount muayene seçildi',
                    ),
                    const SizedBox(height: 18),
                    if (bundle.groups.isEmpty)
                      const _CenteredState(
                        icon: Icons.health_and_safety_outlined,
                        title: 'Muayene sistemi yok',
                        body:
                            'Bu vaka için fizik muayene sistemi tanımlanmadı.',
                      )
                    else if (selectedGroup == null)
                      _PhysicalSystemPicker(
                        groups: bundle.groups,
                        options: bundle.options,
                        onSelected: (groupId) {
                          setState(() {
                            _selectedGroupId = groupId;
                          });
                        },
                      )
                    else ...[
                      OutlinedButton.icon(
                        onPressed: () => setState(() {
                          _selectedGroupId = null;
                        }),
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: const Text('Sistem Değiştir'),
                      ),
                      const SizedBox(height: 14),
                      _FindingsCard(
                        title: '${selectedGroup.title} Bulguları',
                        options: visible,
                        onSelect: _select,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottom: _BottomAction(
        label: _navigating ? 'Geçiliyor...' : 'Tetkiklere Geç',
        onPressed: !_phaseReady || _navigating ? null : _next,
      ),
    );
  }
}

class TestsScreen extends StatefulWidget {
  const TestsScreen({
    required this.repository,
    required this.sessionId,
    required this.caseId,
    this.miniPlan,
    this.onOpenHome,
    super.key,
  });

  final CasesRepository repository;
  final String sessionId;
  final String caseId;
  final MiniOscePlan? miniPlan;
  final VoidCallback? onOpenHome;

  @override
  State<TestsScreen> createState() => _TestsScreenState();
}

class _TestsScreenState extends State<TestsScreen> {
  late Future<_TestsBundle> _bundleFuture;
  String? _selectedGroupId;
  TestOption? _activeResult;
  final Set<String> _basket = <String>{};
  List<TestOption> _fetchedResults = const <TestOption>[];
  var _phaseReady = false;
  var _requesting = false;
  var _navigating = false;

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
    _phaseReady = true;
    scheduleMicrotask(() {
      if (mounted) setState(() {});
    });
    return _TestsBundle(session: session, groups: groups, options: options);
  }

  void _toggleBasket(String optionId) {
    setState(() {
      if (!_basket.remove(optionId)) _basket.add(optionId);
    });
  }

  /// Requests every test queued in the basket in one go, then reveals all of
  /// the freshly returned results together (a "sepet" checkout for tetkikler).
  Future<void> _fetchBasket() async {
    if (_requesting || _basket.isEmpty) return;
    setState(() => _requesting = true);
    final ids = _basket.toList();
    final failed = <String>{};
    try {
      final bundle = await _bundleFuture;
      final fetched = <TestOption>[];
      for (final id in ids) {
        try {
          await widget.repository.requestTest(
            sessionId: widget.sessionId,
            optionId: id,
          );
          fetched.add(bundle.options.firstWhere((item) => item.id == id));
        } on CasesDataUnavailable {
          failed.add(id);
        }
      }
      if (!mounted) return;
      setState(() {
        _basket
          ..clear()
          ..addAll(failed);
        _fetchedResults = fetched;
        _activeResult = null;
        _bundleFuture = _load();
      });
      if (failed.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bazı tetkikler getirilemedi. Tekrar dene.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  Future<void> _next() async {
    if (!_phaseReady || _navigating) return;
    setState(() => _navigating = true);
    try {
      await widget.repository.advanceSession(
        sessionId: widget.sessionId,
        step: 'diagnosis',
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DiagnosisScreen(
            repository: widget.repository,
            sessionId: widget.sessionId,
            caseId: widget.caseId,
            miniPlan: widget.miniPlan,
            onOpenHome: widget.onOpenHome,
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

  @override
  Widget build(BuildContext context) {
    return _FlowScaffold(
      body: FutureBuilder<_TestsBundle>(
        future: _bundleFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _PhaseLoadingSkeleton(activeStep: 3);
          }
          if (snapshot.hasError) {
            return _CenteredState(
              icon: Icons.cloud_off_rounded,
              title: 'Tetkik ekranı açılamadı',
              body: _errorText(snapshot.error),
            );
          }
          final bundle = snapshot.requireData;
          final groupId = _selectedGroupId;
          TestGroup? selectedGroup;
          if (groupId != null) {
            for (final group in bundle.groups) {
              if (group.id == groupId) {
                selectedGroup = group;
                break;
              }
            }
          }
          final visible = bundle.options
              .where((item) => item.groupId == groupId)
              .toList();
          final selectedCount = bundle.options
              .where((item) => item.isSelected)
              .length;
          final basketOptions = bundle.options
              .where((item) => _basket.contains(item.id))
              .toList();
          return Column(
            children: [
              _ExamTopBar(
                session: bundle.session,
                phase: _miniPhaseLabel('Tetkikler', widget.miniPlan),
                repository: widget.repository,
                sessionId: widget.sessionId,
                onOpenHome: widget.onOpenHome,
                onFinish: widget.miniPlan == null
                    ? null
                    : () => _finishMiniOsceStation(
                        context: context,
                        repository: widget.repository,
                        miniPlan: widget.miniPlan!,
                        sessionId: widget.sessionId,
                        onOpenHome: widget.onOpenHome,
                      ),
              ),
              Expanded(
                child: ListView(
                  padding: _flowListPadding(context, top: 16),
                  children: [
                    _PhaseTabs(
                      activeStep: 3,
                      onStepSelected: (step) => _popBackToExamPhase(
                        context,
                        activeStep: 3,
                        step: step,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _SelectionSummary(
                      text: 'İstem Listem ($selectedCount)',
                      subtext: selectedCount == 0
                          ? 'Henüz tetkik getirilmedi'
                          : '$selectedCount tetkik getirildi',
                    ),
                    if (basketOptions.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _TestBasketCard(
                        options: basketOptions,
                        requesting: _requesting,
                        onRemove: _toggleBasket,
                        onFetch: _fetchBasket,
                      ),
                    ],
                    const SizedBox(height: 18),
                    if (bundle.groups.isEmpty)
                      const _CenteredState(
                        icon: Icons.science_outlined,
                        title: 'Tetkik grubu yok',
                        body:
                            'Bu vaka için canlı tetkik kategorisi tanımlanmadı.',
                      )
                    else if (selectedGroup == null)
                      _TestGroupPicker(
                        groups: bundle.groups,
                        options: bundle.options,
                        onSelected: (groupId) {
                          setState(() {
                            _selectedGroupId = groupId;
                            _activeResult = null;
                          });
                        },
                      )
                    else ...[
                      OutlinedButton.icon(
                        onPressed: () => setState(() {
                          _selectedGroupId = null;
                          _activeResult = null;
                        }),
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: const Text('Tetkik Grubu Değiştir'),
                      ),
                      const SizedBox(height: 14),
                      _TestOptionsCard(
                        title: '${selectedGroup.title} Tetkikleri',
                        options: visible,
                        basket: _basket,
                        onToggleBasket: _toggleBasket,
                        onOpenDetail: (option) =>
                            setState(() => _activeResult = option),
                      ),
                    ],
                    if (_fetchedResults.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _FetchedResultsSection(results: _fetchedResults),
                    ],
                    if (_activeResult != null) ...[
                      const SizedBox(height: 14),
                      _InlineTestResultCard(option: _activeResult!),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottom: _BottomAction(
        label: _navigating ? 'Geçiliyor...' : 'Tanıya Geç',
        onPressed: !_phaseReady || _navigating ? null : _next,
      ),
    );
  }
}

class DiagnosisScreen extends StatefulWidget {
  const DiagnosisScreen({
    required this.repository,
    required this.sessionId,
    required this.caseId,
    this.miniPlan,
    this.onOpenHome,
    super.key,
  });

  final CasesRepository repository;
  final String sessionId;
  final String caseId;
  final MiniOscePlan? miniPlan;
  final VoidCallback? onOpenHome;

  @override
  State<DiagnosisScreen> createState() => _DiagnosisScreenState();
}

class _DiagnosisScreenState extends State<DiagnosisScreen> {
  final _primaryController = TextEditingController();
  final _differentialsController = TextEditingController();
  final _reasoningController = TextEditingController();
  late Future<_DiagnosisBundle> _bundleFuture;
  final _selected = <String>{};
  List<DiagnosisOption> _diagnosisOptions = const [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _bundleFuture = _load();
    _primaryController.addListener(() => setState(() {}));
    _differentialsController.addListener(() => setState(() {}));
    _reasoningController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _primaryController.dispose();
    _differentialsController.dispose();
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
    _diagnosisOptions = options;
    if (_differentialsController.text.trim().isEmpty && _selected.isNotEmpty) {
      final primary = _normalizeDiagnosisText(_primaryController.text);
      final selectedTitles = [
        for (final option in options)
          if (_selected.contains(option.id) &&
              _normalizeDiagnosisText(option.title) != primary)
            option.title,
      ];
      _differentialsController.text = selectedTitles.join(', ');
    }
    return _DiagnosisBundle(session: session, options: options);
  }

  Future<void> _save() async {
    if (!_canAdvanceDiagnosis) return;
    setState(() => _saving = true);
    try {
      await widget.repository.saveDiagnosisAnswer(
        sessionId: widget.sessionId,
        primaryDiagnosis: _primaryController.text.trim(),
        selectedOptionIds: _matchedDiagnosisOptionIds(),
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
            miniPlan: widget.miniPlan,
            onOpenHome: widget.onOpenHome,
          ),
        ),
      );
    } on CasesDataUnavailable catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _finishWithCurrentAnswer() async {
    if (_saving) return;
    final shouldFinish = await _confirmIncompleteFinish(context);
    if (!shouldFinish) return;
    if (!mounted) return;
    setState(() => _saving = true);
    try {
      if (_primaryController.text.trim().isNotEmpty ||
          _reasoningController.text.trim().isNotEmpty ||
          _selected.isNotEmpty) {
        await widget.repository.saveDiagnosisAnswer(
          sessionId: widget.sessionId,
          primaryDiagnosis: _primaryController.text.trim(),
          selectedOptionIds: _matchedDiagnosisOptionIds(),
          reasoning: _reasoningController.text.trim(),
        );
      }
      await widget.repository.advanceSession(
        sessionId: widget.sessionId,
        step: 'completed',
      );
      if (!mounted) return;
      final miniPlan = widget.miniPlan;
      if (miniPlan != null) {
        await _continueMiniOsceOrShowResult(
          context: context,
          repository: widget.repository,
          miniPlan: miniPlan,
          completedSessionId: widget.sessionId,
          onOpenHome: widget.onOpenHome,
        );
      } else {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => ResultScreen(
              repository: widget.repository,
              sessionId: widget.sessionId,
              onOpenHome: widget.onOpenHome,
            ),
          ),
        );
      }
    } on CasesDataUnavailable catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool get _canAdvanceDiagnosis {
    if (_saving || _primaryController.text.trim().isEmpty) return false;
    return true;
  }

  List<String> _matchedDiagnosisOptionIds() {
    final answerText = _normalizeDiagnosisText(
      '${_primaryController.text}\n${_differentialsController.text}',
    );
    final matched = <String>[];
    for (final option in _diagnosisOptions) {
      final title = _normalizeDiagnosisText(option.title);
      if (title.isEmpty) continue;
      if (_diagnosisTextMatches(answerText, title)) {
        matched.add(option.id);
      }
    }
    if (matched.isEmpty && _selected.isNotEmpty) return _selected.toList();
    return matched;
  }

  @override
  Widget build(BuildContext context) {
    return _FlowScaffold(
      resizeToAvoidBottomInset: true,
      body: FutureBuilder<_DiagnosisBundle>(
        future: _bundleFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _PhaseLoadingSkeleton(activeStep: 4);
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
                phase: _miniPhaseLabel('Tanı ve Yönetim', widget.miniPlan),
                repository: widget.repository,
                sessionId: widget.sessionId,
                onOpenHome: widget.onOpenHome,
                onFinish: _finishWithCurrentAnswer,
              ),
              Expanded(
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: _flowListPadding(context, top: 16, bottom: 130),
                  children: [
                    _PhaseTabs(
                      activeStep: 4,
                      onStepSelected: (step) => _popBackToExamPhase(
                        context,
                        activeStep: 4,
                        step: step,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _InputBlock(
                      label: 'Ön Tanı',
                      controller: _primaryController,
                      hint: 'Klinik olarak en olası ön tanınızı yazın.',
                      maxLines: 2,
                      semanticsIdentifier: 'input.primary-diagnosis',
                    ),
                    const SizedBox(height: 16),
                    _InputBlock(
                      label: 'Ayırıcı Tanılar',
                      controller: _differentialsController,
                      hint: 'Ayırıcı tanılarınızı virgülle ayırarak yazın.',
                      maxLines: 4,
                      semanticsIdentifier: 'input.differential-diagnoses',
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
        onPressed: _canAdvanceDiagnosis ? _save : null,
      ),
    );
  }
}

class ManagementPlanScreen extends StatefulWidget {
  const ManagementPlanScreen({
    required this.repository,
    required this.sessionId,
    required this.caseId,
    this.miniPlan,
    this.onOpenHome,
    super.key,
  });

  final CasesRepository repository;
  final String sessionId;
  final String caseId;
  final MiniOscePlan? miniPlan;
  final VoidCallback? onOpenHome;

  @override
  State<ManagementPlanScreen> createState() => _ManagementPlanScreenState();
}

class _ManagementPlanScreenState extends State<ManagementPlanScreen> {
  final _diagnosisController = TextEditingController();
  final _noteController = TextEditingController();
  final _consultationController = TextEditingController();
  late Future<_ManagementBundle> _bundleFuture;
  final _selected = <String>{};
  String? _selectedManagementCategory;
  var _managementReady = false;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _bundleFuture = _load();
    _diagnosisController.addListener(_onManagementInputChanged);
    _noteController.addListener(_onManagementInputChanged);
    _consultationController.addListener(_onConsultationChanged);
  }

  void _onConsultationChanged() => setState(() {});
  void _onManagementInputChanged() => setState(() {});

  @override
  void dispose() {
    _diagnosisController.dispose();
    _noteController.dispose();
    _consultationController.dispose();
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
    _consultationController.text = answer?.consultationDestination ?? '';
    _selected
      ..clear()
      ..addAll(answer?.selectedOptionIds ?? const []);
    if (_selectedManagementCategory == null && _selected.isNotEmpty) {
      for (final option in options) {
        if (_selected.contains(option.id)) {
          _selectedManagementCategory = option.category;
          break;
        }
      }
    }
    _managementReady = true;
    return _ManagementBundle(session: session, options: options);
  }

  Future<void> _save({bool allowIncomplete = false}) async {
    if (!allowIncomplete && !_canFinalizeManagement) return;
    if (_saving || !_managementReady) return;
    if (allowIncomplete) {
      final shouldFinish = await _confirmIncompleteFinish(context);
      if (!shouldFinish) return;
      if (!mounted) return;
    }
    setState(() => _saving = true);
    try {
      await widget.repository.saveManagementPlan(
        sessionId: widget.sessionId,
        diagnosis: _diagnosisController.text,
        selectedOptionIds: _selected.toList(),
        note: _noteController.text,
        consultationDestination: _consultationController.text,
      );
      await widget.repository.advanceSession(
        sessionId: widget.sessionId,
        step: 'completed',
      );
      if (!mounted) return;
      final miniPlan = widget.miniPlan;
      if (miniPlan != null) {
        await _continueMiniOsceOrShowResult(
          context: context,
          repository: widget.repository,
          miniPlan: miniPlan,
          completedSessionId: widget.sessionId,
          onOpenHome: widget.onOpenHome,
        );
      } else {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => ResultScreen(
              repository: widget.repository,
              sessionId: widget.sessionId,
              onOpenHome: widget.onOpenHome,
            ),
          ),
        );
      }
    } on CasesDataUnavailable catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool get _requiresConsultationDestination {
    return _selected.any(
      (id) => _visibleOptions.any(
        (option) =>
            option.id == id && option.category.toLowerCase().contains('kons'),
      ),
    );
  }

  bool get _hasManagementInput {
    return _noteController.text.trim().isNotEmpty;
  }

  bool get _canFinalizeManagement {
    if (!_managementReady || _saving || !_hasManagementInput) return false;
    if (_requiresConsultationDestination &&
        _consultationController.text.trim().isEmpty) {
      return false;
    }
    return true;
  }

  List<ManagementOption> _visibleOptions = const [];

  @override
  Widget build(BuildContext context) {
    return _FlowScaffold(
      resizeToAvoidBottomInset: true,
      body: FutureBuilder<_ManagementBundle>(
        future: _bundleFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _PhaseLoadingSkeleton(activeStep: 5);
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
          _visibleOptions = bundle.options;
          final selectedCategory = _selectedManagementCategory;
          final selectedCategoryOptions = selectedCategory == null
              ? const <ManagementOption>[]
              : grouped[selectedCategory] ?? const <ManagementOption>[];
          return Column(
            children: [
              _ExamTopBar(
                session: bundle.session,
                phase: _miniPhaseLabel('Tanı ve Yönetim', widget.miniPlan),
                repository: widget.repository,
                sessionId: widget.sessionId,
                onOpenHome: widget.onOpenHome,
                onFinish: () => _save(allowIncomplete: true),
              ),
              Expanded(
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: _flowListPadding(context, top: 16, bottom: 130),
                  children: [
                    _PhaseTabs(
                      activeStep: 5,
                      onStepSelected: (step) => _popBackToExamPhase(
                        context,
                        activeStep: 5,
                        step: step,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _InputBlock(
                      label: 'Ön Tanı',
                      controller: _diagnosisController,
                      hint: 'Klinik olarak en olası ön tanınızı yazın.',
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
                        color: PratiCaseColors.muted,
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
                    else if (selectedCategory == null)
                      for (final entry in grouped.entries) ...[
                        _ManagementCategoryTile(
                          title: _managementCategoryTitle(entry.key),
                          options: entry.value,
                          selected: _selected,
                          onTap: () => setState(
                            () => _selectedManagementCategory = entry.key,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ]
                    else ...[
                      OutlinedButton.icon(
                        onPressed: () =>
                            setState(() => _selectedManagementCategory = null),
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: const Text('Yönetim Başlığı Değiştir'),
                      ),
                      const SizedBox(height: 12),
                      _ManagementGroupCard(
                        title: _managementCategoryTitle(selectedCategory),
                        options: selectedCategoryOptions,
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
                    if (_requiresConsultationDestination) ...[
                      _InputBlock(
                        label: 'Konsültasyon Birimi',
                        controller: _consultationController,
                        hint:
                            'Hastayı hangi branşa veya birime yönlendireceksiniz?',
                        maxLines: 2,
                        semanticsIdentifier: 'input.consultation-destination',
                      ),
                      const SizedBox(height: 14),
                    ],
                    _InputBlock(
                      label: 'Acil Müdahaleler ve Ek Tetkikler',
                      controller: _noteController,
                      hint:
                          'Acil prosedür, ileri görüntüleme veya ek laboratuvar taleplerini klinik gerekçesiyle yazın.',
                      maxLines: 5,
                      semanticsIdentifier: 'input.management-plan',
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottom: _BottomAction(
        label: _saving ? 'Kaydediliyor...' : 'Sınavı Bitir ve Değerlendir',
        icon: Icons.check_circle_rounded,
        onPressed: _canFinalizeManagement ? () => _save() : null,
      ),
    );
  }
}

class MiniOsceResultScreen extends StatefulWidget {
  const MiniOsceResultScreen({
    required this.repository,
    required this.plan,
    this.onOpenHome,
    super.key,
  });

  final CasesRepository repository;
  final MiniOscePlan plan;
  final VoidCallback? onOpenHome;

  @override
  State<MiniOsceResultScreen> createState() => _MiniOsceResultScreenState();
}

class _MiniOsceResultScreenState extends State<MiniOsceResultScreen> {
  late Future<List<ExamResultSummary>> _resultsFuture;

  @override
  void initState() {
    super.initState();
    _resultsFuture = _loadResults();
  }

  Future<List<ExamResultSummary>> _loadResults() async {
    return Future.wait(
      widget.plan.completedSessionIds.map(widget.repository.loadResult),
    );
  }

  void _retry() {
    setState(() => _resultsFuture = _loadResults());
  }

  void _goHome() {
    final openHome = widget.onOpenHome;
    Navigator.of(context).popUntil((route) => route.isFirst);
    openHome?.call();
  }

  @override
  Widget build(BuildContext context) {
    return _FlowScaffold(
      body: FutureBuilder<List<ExamResultSummary>>(
        future: _resultsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _PhaseLoadingSkeleton(activeStep: 5);
          }
          if (snapshot.hasError) {
            return ListView(
              padding: _flowListPadding(context, top: 24),
              children: [
                const _StepTopBar(title: 'Mini OSCE Karnesi'),
                const SizedBox(height: 18),
                _CenteredState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Mini OSCE karnesi açılamadı',
                  body: _errorText(snapshot.error),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Tekrar Dene'),
                ),
              ],
            );
          }
          final results = snapshot.requireData;
          if (results.isEmpty) {
            return ListView(
              padding: _flowListPadding(context, top: 24),
              children: const [
                _StepTopBar(title: 'Mini OSCE Karnesi'),
                SizedBox(height: 18),
                _CenteredState(
                  icon: Icons.assignment_outlined,
                  title: 'Sonuç bulunamadı',
                  body: 'Mini OSCE istasyon sonuçları henüz hazırlanamadı.',
                ),
              ],
            );
          }
          return ListView(
            padding: _flowListPadding(context, bottom: 120),
            children: [
              const _StepTopBar(title: 'Mini OSCE Karnesi'),
              const SizedBox(height: 12),
              _MiniOsceHero(results: results),
              const SizedBox(height: 18),
              _ScoreGrid(scores: _aggregateCategoryScores(results)),
              const SizedBox(height: 18),
              _SectionCard(
                title: 'İstasyon Sonuçları',
                child: Column(
                  children: [
                    for (var index = 0; index < results.length; index++) ...[
                      _MiniOsceStationCard(
                        stationNumber: index + 1,
                        result: results[index],
                        onReport: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  CaseReportScreen(result: results[index]),
                            ),
                          );
                        },
                      ),
                      if (index != results.length - 1)
                        const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _FeedbackCard(
                title: 'Mini OSCE Güçlü Yönlerin',
                icon: Icons.verified_rounded,
                color: PratiCaseColors.successGreen,
                items: _aggregateFeedback(
                  results,
                  (result) => result.strongPoints,
                ),
              ),
              const SizedBox(height: 14),
              _FeedbackCard(
                title: 'Mini OSCE Gelişim Alanların',
                icon: Icons.warning_amber_rounded,
                color: PratiCaseColors.gold,
                items: _aggregateFeedback(
                  results,
                  (result) => result.improvementPoints,
                ),
              ),
              const SizedBox(height: 14),
              _FeedbackCard(
                title: 'Kritik Hatalar',
                icon: Icons.error_outline_rounded,
                color: PratiCaseColors.errorRed,
                items: _aggregateFeedback(
                  results,
                  (result) => result.criticalMistakes,
                ),
              ),
              const SizedBox(height: 14),
              _FeedbackCard(
                title: 'Eksik Anamnez',
                icon: Icons.chat_bubble_outline_rounded,
                color: PratiCaseColors.slateBlue,
                items: _aggregateFeedback(
                  results,
                  (result) => result.missedHistory,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 52,
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _goHome,
                  icon: const Icon(Icons.home_rounded),
                  label: const Text('Ana Sayfaya Dön'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MiniOsceHero extends StatelessWidget {
  const _MiniOsceHero({required this.results});

  final List<ExamResultSummary> results;

  @override
  Widget build(BuildContext context) {
    final totalScore = results.fold<int>(
      0,
      (sum, result) => sum + result.totalScore,
    );
    final maxScore = results.fold<int>(
      0,
      (sum, result) => sum + result.maxScore,
    );
    final percentage = maxScore == 0
        ? 0
        : ((totalScore / maxScore) * 100).round();
    final tone = percentage >= 80
        ? PratiCaseColors.successGreen
        : percentage >= 60
        ? PratiCaseColors.gold
        : PratiCaseColors.errorRed;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: PratiCaseGradients.hero,
        borderRadius: BorderRadius.circular(PratiCaseRadius.xxl),
        boxShadow: PratiCaseShadows.floating,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: PratiCaseColors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(PratiCaseRadius.md),
                  border: Border.all(
                    color: PratiCaseColors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: const Icon(
                  Icons.route_rounded,
                  color: PratiCaseColors.tealBright,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '3 istasyon tamamlandı',
                      style: TextStyle(
                        color: PratiCaseColors.tealBright,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Mini OSCE ortalama performansın',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: PratiCaseColors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        height: 1.16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
                  border: Border.all(color: tone.withValues(alpha: 0.48)),
                ),
                child: Text(
                  '%$percentage',
                  style: TextStyle(
                    color: tone,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _MiniOsceHeroMetric(
                  label: 'Toplam Puan',
                  value: '$totalScore/$maxScore',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniOsceHeroMetric(
                  label: 'İstasyon',
                  value: '${results.length}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniOsceHeroMetric extends StatelessWidget {
  const _MiniOsceHeroMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: PratiCaseColors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(PratiCaseRadius.md),
        border: Border.all(
          color: PratiCaseColors.white.withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: PratiCaseColors.tealBright,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: PratiCaseColors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniOsceStationCard extends StatelessWidget {
  const _MiniOsceStationCard({
    required this.stationNumber,
    required this.result,
    required this.onReport,
  });

  final int stationNumber;
  final ExamResultSummary result;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final tone = result.percentage >= 80
        ? PratiCaseColors.successGreen
        : result.percentage >= 60
        ? PratiCaseColors.gold
        : PratiCaseColors.errorRed;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PratiCaseColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(PratiCaseRadius.lg),
        border: Border.all(color: PratiCaseColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(PratiCaseRadius.md),
                ),
                child: Center(
                  child: Text(
                    '$stationNumber',
                    style: TextStyle(color: tone, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.caseTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: PratiCaseColors.navy,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${result.totalScore}/${result.maxScore} puan',
                      style: const TextStyle(
                        color: PratiCaseColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _TinyPill(text: '%${result.percentage}'),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onReport,
            icon: const Icon(Icons.description_outlined),
            label: const Text('Detaylı Rapor'),
          ),
        ],
      ),
    );
  }
}

List<ResultCategoryScore> _aggregateCategoryScores(
  List<ExamResultSummary> results,
) {
  final order = <String>[];
  final scores = <String, int>{};
  final maxScores = <String, int>{};
  for (final result in results) {
    for (final score in result.categoryScores) {
      if (!scores.containsKey(score.title)) order.add(score.title);
      scores[score.title] = (scores[score.title] ?? 0) + score.score;
      maxScores[score.title] = (maxScores[score.title] ?? 0) + score.maxScore;
    }
  }
  return [
    for (final title in order)
      ResultCategoryScore(
        title: title,
        score: scores[title] ?? 0,
        maxScore: maxScores[title] ?? 0,
      ),
  ];
}

List<String> _aggregateFeedback(
  List<ExamResultSummary> results,
  List<String> Function(ExamResultSummary result) select, {
  int limit = 8,
}) {
  final items = <String>[];
  for (final result in results) {
    for (final raw in select(result)) {
      final value = raw.trim();
      if (value.isEmpty) continue;
      final item = '${result.caseTitle}: $value';
      if (items.contains(item)) continue;
      items.add(item);
      if (items.length == limit) return items;
    }
  }
  return items;
}

class ResultScreen extends StatefulWidget {
  const ResultScreen({
    required this.repository,
    required this.sessionId,
    this.onOpenHome,
    super.key,
  });

  final CasesRepository repository;
  final String sessionId;
  final VoidCallback? onOpenHome;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late Future<ExamResultSummary> _resultFuture;
  bool _startingAgain = false;
  bool _feedbackRefreshScheduled = false;
  Timer? _feedbackRefreshTimer;

  @override
  void initState() {
    super.initState();
    _resultFuture = widget.repository.loadResult(widget.sessionId);
  }

  void _retry() {
    setState(() {
      _resultFuture = widget.repository.loadResult(widget.sessionId);
    });
  }

  void _goHome() {
    final openHome = widget.onOpenHome;
    Navigator.of(context).popUntil((route) => route.isFirst);
    openHome?.call();
  }

  @override
  void dispose() {
    _feedbackRefreshTimer?.cancel();
    super.dispose();
  }

  void _scheduleFeedbackRefresh(ExamResultSummary result) {
    if (_feedbackRefreshScheduled) {
      return;
    }
    final hasFallbackApproach = result.idealApproach.startsWith(
      'İstasyonu yapılandırılmış',
    );
    if (!hasFallbackApproach && result.checklistSections.isNotEmpty) {
      return;
    }
    _feedbackRefreshScheduled = true;
    _feedbackRefreshTimer = Timer(
      const Duration(seconds: 8),
      () => unawaited(_refreshFeedback()),
    );
  }

  Future<void> _refreshFeedback() async {
    try {
      final refreshed = await widget.repository.loadResult(widget.sessionId);
      if (!mounted) return;
      setState(() => _resultFuture = Future.value(refreshed));
    } on Object {
      // The deterministic card remains visible when enrichment is unavailable.
    }
  }

  Future<void> _startAgain() async {
    if (_startingAgain) return;
    setState(() => _startingAgain = true);
    try {
      final previous = await widget.repository.loadSession(widget.sessionId);
      final session = await widget.repository.startSession(previous.caseId);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => PatientChatScreen(
            repository: widget.repository,
            sessionId: session.id,
            onOpenHome: widget.onOpenHome,
          ),
        ),
      );
    } on CasesDataUnavailable catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _startingAgain = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _FlowScaffold(
      body: FutureBuilder<ExamResultSummary>(
        future: _resultFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _PhaseLoadingSkeleton(activeStep: 5);
          }
          if (snapshot.hasError) {
            return ListView(
              padding: _flowListPadding(context, top: 24),
              children: [
                const _StepTopBar(title: 'Sonuç Karnesi'),
                const SizedBox(height: 18),
                _CenteredState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Sonuç karnesi açılamadı',
                  body: _errorText(snapshot.error),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Tekrar Dene'),
                ),
              ],
            );
          }
          final result = snapshot.requireData;
          _scheduleFeedbackRefresh(result);
          return ListView(
            padding: _flowListPadding(context, bottom: 130),
            children: [
              const _StepTopBar(title: 'Sonuç Karnesi'),
              const SizedBox(height: 12),
              _ResultHero(result: result),
              const SizedBox(height: 18),
              FadeSlideIn(
                delay: const Duration(milliseconds: 120),
                child: _ScoreGrid(scores: result.categoryScores),
              ),
              const SizedBox(height: 18),
              FadeSlideIn(
                delay: const Duration(milliseconds: 200),
                child: _FeedbackCard(
                  title: 'Güçlü Yönlerin',
                  icon: Icons.verified_rounded,
                  color: PratiCaseColors.successGreen,
                  items: result.strongPoints,
                ),
              ),
              const SizedBox(height: 14),
              FadeSlideIn(
                delay: const Duration(milliseconds: 260),
                child: _FeedbackCard(
                  title: 'Gelişim Alanların',
                  icon: Icons.warning_amber_rounded,
                  color: PratiCaseColors.gold,
                  items: result.improvementPoints,
                ),
              ),
              const SizedBox(height: 14),
              FadeSlideIn(
                delay: const Duration(milliseconds: 320),
                child: _FeedbackCard(
                  title: 'Kritik Hatalar',
                  icon: Icons.error_outline_rounded,
                  color: PratiCaseColors.errorRed,
                  items: result.criticalMistakes,
                ),
              ),
              const SizedBox(height: 14),
              FadeSlideIn(
                delay: const Duration(milliseconds: 360),
                child: _FeedbackCard(
                  title: 'Gereksiz Tetkikler',
                  icon: Icons.science_outlined,
                  color: PratiCaseColors.slateBlue,
                  items: result.unnecessaryTests,
                ),
              ),
              const SizedBox(height: 14),
              FadeSlideIn(
                delay: const Duration(milliseconds: 400),
                child: _FeedbackCard(
                  title: 'İstemen Gereken Tetkikler',
                  icon: Icons.playlist_add_check_rounded,
                  color: PratiCaseColors.teal,
                  items: result.missedTests,
                ),
              ),
              const SizedBox(height: 14),
              FadeSlideIn(
                delay: const Duration(milliseconds: 440),
                child: _FeedbackCard(
                  title: 'Eksik Anamnez',
                  icon: Icons.chat_bubble_outline_rounded,
                  color: PratiCaseColors.slateBlue,
                  items: result.missedHistory,
                ),
              ),
              const SizedBox(height: 14),
              FadeSlideIn(
                delay: const Duration(milliseconds: 480),
                child: _FeedbackCard(
                  title: 'Kaçırılan Muayeneler',
                  icon: Icons.health_and_safety_outlined,
                  color: PratiCaseColors.teal,
                  items: result.missedPhysicalExam,
                ),
              ),
              const SizedBox(height: 14),
              FadeSlideIn(
                delay: const Duration(milliseconds: 520),
                child: _IdealApproachCard(text: result.idealApproach),
              ),
              const SizedBox(height: 18),
              FadeSlideIn(
                delay: const Duration(milliseconds: 560),
                child: _ResultActions(
                  onSupport: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ResultAiSupportScreen(result: result),
                      ),
                    );
                  },
                  onRetry: _startingAgain ? null : _startAgain,
                  retryLabel: _startingAgain ? 'Başlatılıyor...' : 'Tekrar Çöz',
                  onReport: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CaseReportScreen(result: result),
                      ),
                    );
                  },
                  onHome: _goHome,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ResultAiSupportScreen extends StatelessWidget {
  const ResultAiSupportScreen({required this.result, super.key});

  final ExamResultSummary result;

  @override
  Widget build(BuildContext context) {
    final priority = _priorityScore(result);
    final supportTopics = _supportTopics(result);
    final practicePlan = _practicePlan(result, priority);
    return _FlowScaffold(
      body: ListView(
        padding: _flowListPadding(context, bottom: 40),
        children: [
          const _StepTopBar(title: 'Recall Planı'),
          const SizedBox(height: 18),
          _AiSupportHero(result: result),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Öncelikli Çalışma Alanı',
            child: _PriorityFocus(priority: priority),
          ),
          const SizedBox(height: 14),
          _FeedbackCard(
            title: 'Hemen Çalışılacak Başlıklar',
            icon: Icons.history_edu_rounded,
            color: PratiCaseColors.teal,
            items: supportTopics,
          ),
          const SizedBox(height: 14),
          _FeedbackCard(
            title: 'Bir Sonraki Deneme Planı',
            icon: Icons.route_outlined,
            color: PratiCaseColors.slateBlue,
            items: practicePlan,
          ),
          const SizedBox(height: 14),
          _IdealApproachCard(text: result.idealApproach),
          const SizedBox(height: 18),
          SizedBox(
            height: 52,
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CaseReportScreen(result: result),
                ),
              ),
              icon: const Icon(Icons.description_outlined),
              label: const Text('Detaylı Raporu Aç'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Karneye Dön'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiSupportHero extends StatelessWidget {
  const _AiSupportHero({required this.result});

  final ExamResultSummary result;

  @override
  Widget build(BuildContext context) {
    final tone = result.percentage >= 80
        ? PratiCaseColors.successGreen
        : result.percentage >= 60
        ? PratiCaseColors.gold
        : PratiCaseColors.errorRed;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: PratiCaseGradients.hero,
        borderRadius: BorderRadius.circular(PratiCaseRadius.xl),
        boxShadow: PratiCaseShadows.floating,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: PratiCaseColors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(PratiCaseRadius.md),
                  border: Border.all(
                    color: PratiCaseColors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: const Icon(
                  Icons.history_edu_rounded,
                  color: PratiCaseColors.tealBright,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recall çalışma yönlendirmesi',
                      style: TextStyle(
                        color: PratiCaseColors.tealBright,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      result.caseTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: PratiCaseColors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        height: 1.18,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
                  border: Border.all(color: tone.withValues(alpha: 0.48)),
                ),
                child: Text(
                  '%${result.percentage}',
                  style: TextStyle(color: tone, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Bu ekran, sonuç karnendeki eksikleri sıraya koyar ve bir sonraki denemeye odaklı girmen için kısa bir çalışma planı çıkarır.',
            style: TextStyle(
              color: PratiCaseColors.white.withValues(alpha: 0.82),
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _PriorityFocus extends StatelessWidget {
  const _PriorityFocus({required this.priority});

  final ResultCategoryScore? priority;

  @override
  Widget build(BuildContext context) {
    if (priority == null) {
      return const Text(
        'Kategori puanları hazır olmadığında öncelik listesi gelişim başlıklarından oluşturulur.',
        style: TextStyle(
          color: PratiCaseColors.slateBlue,
          fontWeight: FontWeight.w700,
          height: 1.45,
        ),
      );
    }
    final percent = priority!.maxScore == 0
        ? 0
        : ((priority!.score / priority!.maxScore) * 100).round();
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: PratiCaseColors.teal.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(PratiCaseRadius.md),
          ),
          child: const Icon(
            Icons.track_changes_rounded,
            color: PratiCaseColors.teal,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                priority!.title,
                style: const TextStyle(
                  color: PratiCaseColors.navy,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$percent% performans · önce bu başlığı toparla.',
                style: const TextStyle(
                  color: PratiCaseColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

ResultCategoryScore? _priorityScore(ExamResultSummary result) {
  if (result.categoryScores.isEmpty) return null;
  final sorted = [...result.categoryScores]
    ..sort((a, b) {
      final aRatio = a.maxScore == 0 ? 1.0 : a.score / a.maxScore;
      final bRatio = b.maxScore == 0 ? 1.0 : b.score / b.maxScore;
      final ratioOrder = aRatio.compareTo(bRatio);
      if (ratioOrder != 0) return ratioOrder;
      return a.title.compareTo(b.title);
    });
  return sorted.first;
}

List<String> _supportTopics(ExamResultSummary result) {
  final topics = <String>[
    ...result.criticalMistakes,
    ...result.improvementPoints,
    ...result.missedHistory.map((item) => 'Anamnez: $item'),
    ...result.missedPhysicalExam.map((item) => 'Muayene: $item'),
    ...result.missedTests.map((item) => 'Tetkik: $item'),
  ];
  final compact = <String>[];
  for (final topic in topics) {
    final clean = topic.trim();
    if (clean.isEmpty || compact.contains(clean)) continue;
    compact.add(clean);
    if (compact.length == 5) break;
  }
  if (compact.isNotEmpty) return compact;
  return const [
    'Bir sonraki denemede anamnez, muayene, tetkik ve yönetim adımlarını sırayla tamamla.',
  ];
}

List<String> _practicePlan(
  ExamResultSummary result,
  ResultCategoryScore? priority,
) {
  final focus = priority?.title ?? 'en düşük puanlı klinik beceri';
  return [
    '$focus başlığı için 10 dakikalık hızlı tekrar yap.',
    'Vaka yönergesini okuyup kritik anamnez, muayene ve tetkik kontrol listesini zihinden kur.',
    '${result.caseTitle} istasyonunu tekrar çözmeden önce yönetim planını 3 net adımla yazmayı prova et.',
  ];
}

class CaseReportScreen extends StatelessWidget {
  const CaseReportScreen({required this.result, super.key});

  final ExamResultSummary result;

  @override
  Widget build(BuildContext context) {
    return _FlowScaffold(
      body: ListView(
        padding: _flowListPadding(context, bottom: 40),
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
          _ChecklistReportCard(sections: result.checklistSections),
          const SizedBox(height: 14),
          _FeedbackCard(
            title: 'Güçlü Yönlerin',
            icon: Icons.verified_rounded,
            color: PratiCaseColors.successGreen,
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
            color: PratiCaseColors.errorRed,
            items: result.criticalMistakes,
          ),
          const SizedBox(height: 14),
          _FeedbackCard(
            title: 'Gereksiz Tetkikler',
            icon: Icons.science_outlined,
            color: PratiCaseColors.slateBlue,
            items: result.unnecessaryTests,
          ),
          const SizedBox(height: 14),
          _FeedbackCard(
            title: 'İstemen Gereken Tetkikler',
            icon: Icons.playlist_add_check_rounded,
            color: PratiCaseColors.teal,
            items: result.missedTests,
          ),
          const SizedBox(height: 14),
          _FeedbackCard(
            title: 'Eksik Anamnez',
            icon: Icons.chat_bubble_outline_rounded,
            color: PratiCaseColors.slateBlue,
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
    this.fallbackTitle,
    this.fallbackResult,
    super.key,
  });

  final CasesRepository repository;
  final String testOptionId;
  final String? fallbackTitle;
  final String? fallbackResult;

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
              body: 'Tetkik sonucu hazırlanıyor.',
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
            return ListView(
              padding: _flowListPadding(context, bottom: 40),
              children: [
                _StepTopBar(title: fallbackTitle ?? 'Laboratuvar Sonucu'),
                const SizedBox(height: 18),
                _LabResultHero(
                  title: fallbackTitle ?? 'Laboratuvar Sonucu',
                  measuredAt: null,
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Sonuç',
                  child: Text(
                    (fallbackResult?.trim().isNotEmpty ?? false)
                        ? fallbackResult!.trim()
                        : 'Bu tetkik için canlı sonuç metni henüz tanımlanmadı.',
                    style: const TextStyle(
                      color: PratiCaseColors.navy,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            );
          }
          return ListView(
            padding: _flowListPadding(context, bottom: 40),
            children: [
              _StepTopBar(title: detail.title),
              const SizedBox(height: 18),
              _LabResultHero(
                title: detail.title,
                measuredAt: detail.measuredAt,
              ),
              const SizedBox(height: 14),
              _LabParametersCard(parameters: detail.parameters),
              const SizedBox(height: 14),
              _SectionCard(
                title: 'Değerlendirme',
                child: Text(
                  detail.interpretation.trim().isEmpty
                      ? 'Bu laboratuvar sonucu için değerlendirme metni henüz tanımlanmadı.'
                      : detail.interpretation,
                  style: const TextStyle(
                    color: PratiCaseColors.navy,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
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

class ImagingResultScreen extends StatelessWidget {
  const ImagingResultScreen({
    required this.repository,
    required this.testOptionId,
    this.fallbackTitle,
    this.fallbackResult,
    super.key,
  });

  final CasesRepository repository;
  final String testOptionId;
  final String? fallbackTitle;
  final String? fallbackResult;

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
              body: 'Görüntüleme raporu yükleniyor.',
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
            return ListView(
              padding: _flowListPadding(context, bottom: 40),
              children: [
                _StepTopBar(title: fallbackTitle ?? 'Görüntüleme Sonucu'),
                const SizedBox(height: 18),
                _ImagingHero(title: fallbackTitle ?? 'Görüntüleme Sonucu'),
                const SizedBox(height: 14),
                _ImagingPlaceholderCard(title: fallbackTitle),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Sonuç',
                  child: Text(
                    (fallbackResult?.trim().isNotEmpty ?? false)
                        ? fallbackResult!.trim()
                        : 'Bu görüntüleme için canlı sonuç metni henüz tanımlanmadı.',
                    style: const TextStyle(
                      color: PratiCaseColors.navy,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            );
          }
          return ListView(
            padding: _flowListPadding(context, bottom: 40),
            children: [
              _StepTopBar(title: detail.title),
              const SizedBox(height: 18),
              _ImagingHero(title: detail.title),
              const SizedBox(height: 14),
              _ImagingPreviewCard(
                imageUrl: detail.imageUrl,
                title: detail.title,
              ),
              const SizedBox(height: 14),
              _SectionCard(
                title: 'Rapor',
                child: Text(
                  detail.report.trim().isEmpty
                      ? 'Bu görüntüleme için rapor metni henüz tanımlanmadı.'
                      : detail.report,
                  style: const TextStyle(
                    color: PratiCaseColors.navy,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _SectionCard(
                title: 'Sonuç',
                child: Text(
                  detail.conclusion.trim().isEmpty
                      ? 'Bu görüntüleme için sonuç metni henüz tanımlanmadı.'
                      : detail.conclusion,
                  style: const TextStyle(
                    color: PratiCaseColors.navy,
                    fontWeight: FontWeight.w800,
                    height: 1.4,
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
              body: 'Tedavi bilgisi hazırlanıyor.',
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
            padding: _flowListPadding(context, bottom: 40),
            children: [
              const _StepTopBar(title: 'İlaç Bilgisi'),
              const SizedBox(height: 18),
              if (items.isEmpty)
                const _CenteredState(
                  icon: Icons.medication_outlined,
                  title: 'İlaç bilgisi yok',
                  body: 'Bu vaka için ilaç bilgisi tanımlanmadı.',
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
        padding: _flowListPadding(context, bottom: 130),
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
              body: 'Vaka adımların yükleniyor.',
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
            padding: _flowListPadding(context),
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
    this.backgroundColor = PratiCaseColors.softSurface,
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
        body: SafeArea(
          bottom: false,
          child: PratiCaseResponsiveFrame(
            maxWidth: PratiCaseBreakpoints.flowContentMaxWidth,
            expandHeight: true,
            child: body,
          ),
        ),
        bottomNavigationBar: bottom == null
            ? null
            : AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: SafeArea(
                  top: false,
                  minimum: const EdgeInsets.only(bottom: 6),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: PratiCaseColors.white,
                      border: Border(
                        top: BorderSide(
                          color: PratiCaseColors.navy.withValues(alpha: 0.06),
                        ),
                      ),
                    ),
                    child: PratiCaseResponsiveFrame(
                      maxWidth: PratiCaseBreakpoints.flowContentMaxWidth,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          PratiCaseResponsive.horizontalPaddingForWidth(
                            MediaQuery.sizeOf(context).width,
                          ),
                          10,
                          PratiCaseResponsive.horizontalPaddingForWidth(
                            MediaQuery.sizeOf(context).width,
                          ),
                          12,
                        ),
                        child: bottom,
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

EdgeInsets _flowListPadding(
  BuildContext context, {
  double top = 12,
  double bottom = 120,
}) {
  final horizontal = PratiCaseResponsive.horizontalPaddingForWidth(
    MediaQuery.sizeOf(context).width,
  );
  return EdgeInsets.fromLTRB(horizontal, top, horizontal, bottom);
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
          borderRadius: BorderRadius.circular(PratiCaseRadius.sm),
          child: Image.asset(
            'assets/auth/praticase_icon.png',
            width: 44,
            height: 44,
            fit: BoxFit.cover,
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
            backgroundColor: PratiCaseColors.teal.withValues(alpha: 0.10),
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
    return PageTitle(title: title, subtitle: subtitle);
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
    return PratiCaseSearchField(
      controller: controller,
      hintText: 'İstasyon ara...',
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      onClear: onClear,
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
        color: PratiCaseColors.teal.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(PratiCaseRadius.xl),
        border: Border.all(color: PratiCaseColors.teal.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: PratiCaseColors.navy.withValues(alpha: 0.05),
            blurRadius: 22,
            spreadRadius: -8,
            offset: const Offset(0, 14),
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
                  color: PratiCaseColors.white.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(PratiCaseRadius.md),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: PratiCaseColors.teal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Aktif Filtreler',
                      style: TextStyle(
                        color: PratiCaseColors.navy,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      activeCount == 0
                          ? 'Tüm istasyonlar gösteriliyor.'
                          : '$activeCount filtre aktif.',
                      style: TextStyle(
                        color: PratiCaseColors.muted,
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
                  borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 8,
                    backgroundColor: PratiCaseColors.white.withValues(
                      alpha: 0.58,
                    ),
                    color: PratiCaseColors.teal,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$visibleCount/$totalCount',
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
                          borderRadius: BorderRadius.circular(
                            PratiCaseRadius.pill,
                          ),
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

class _MiniOsceSelectionNotice extends StatelessWidget {
  const _MiniOsceSelectionNotice({
    required this.selectedCount,
    required this.requiredCount,
  });

  final int selectedCount;
  final int requiredCount;

  @override
  Widget build(BuildContext context) {
    final ready = selectedCount == requiredCount;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PratiCaseColors.white,
        borderRadius: BorderRadius.circular(PratiCaseRadius.xl),
        border: Border.all(
          color: ready
              ? PratiCaseColors.successGreen.withValues(alpha: 0.48)
              : PratiCaseColors.teal.withValues(alpha: 0.20),
        ),
        boxShadow: PratiCaseShadows.card,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color:
                  (ready ? PratiCaseColors.successGreen : PratiCaseColors.teal)
                      .withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(PratiCaseRadius.md),
            ),
            child: Icon(
              ready
                  ? Icons.check_circle_rounded
                  : Icons.format_list_numbered_rounded,
              color: ready
                  ? PratiCaseColors.successGreen
                  : PratiCaseColors.teal,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$selectedCount/$requiredCount istasyon seçildi',
                  style: const TextStyle(
                    color: PratiCaseColors.navy,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ready
                      ? 'Hazır. Başlatınca istasyonlar seçtiğin sırayla açılır.'
                      : 'Mini OSCE için toplam 3 istasyon seç.',
                  style: const TextStyle(
                    color: PratiCaseColors.muted,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
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

class _MiniOsceStartBar extends StatelessWidget {
  const _MiniOsceStartBar({
    required this.selectedCount,
    required this.requiredCount,
    required this.starting,
    required this.onStart,
  });

  final int selectedCount;
  final int requiredCount;
  final bool starting;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final canStart = selectedCount == requiredCount && !starting;
    final horizontal = PratiCaseResponsive.horizontalPaddingForWidth(
      MediaQuery.sizeOf(context).width,
    );
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(horizontal, 10, horizontal, 12),
        decoration: BoxDecoration(
          color: PratiCaseColors.softSurface.withValues(alpha: 0.96),
          border: Border(
            top: BorderSide(
              color: PratiCaseColors.border.withValues(alpha: 0.70),
            ),
          ),
        ),
        child: PratiCaseFlowActionButton(
          identifier: 'cta.start-mini-osce',
          label: starting
              ? 'Başlatılıyor...'
              : canStart
              ? 'Mini OSCE’yi Başlat'
              : '$requiredCount istasyon seç',
          icon: Icons.play_arrow_rounded,
          onPressed: canStart ? onStart : null,
        ),
      ),
    );
  }
}

class _CaseListCard extends StatelessWidget {
  const _CaseListCard({
    required this.item,
    required this.onTap,
    this.selectionMode = false,
    this.selectionOrder = 0,
    this.selectionLimitReached = false,
  });

  final OsceCaseSummary item;
  final VoidCallback onTap;
  final bool selectionMode;
  final int selectionOrder;
  final bool selectionLimitReached;

  @override
  Widget build(BuildContext context) {
    final progress = item.progressPercent;
    final score = item.lastScore;
    final selected = selectionOrder > 0;
    return Semantics(
      identifier: 'case-list-item',
      child: PressableScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: PratiCaseColors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected
                  ? PratiCaseColors.teal
                  : PratiCaseColors.border.withValues(alpha: 0.88),
              width: selected ? 1.6 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: PratiCaseColors.teal.withValues(alpha: 0.14),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ]
                : PratiCaseShadows.card,
          ),
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
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
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
                  if (selectionMode)
                    _CaseSelectionBadge(
                      selectionOrder: selectionOrder,
                      limitReached: selectionLimitReached,
                    )
                  else
                    const _RoundArrow(),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                item.summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: PratiCaseColors.slateBlue,
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
                    _TinyPill(text: 'Son skor: $score/100')
                  else if (progress != null)
                    _TinyPill(text: '%$progress devam')
                  else
                    _TinyPill(text: '${item.durationMinutes} dk'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaseResultsGrid extends StatelessWidget {
  const _CaseResultsGrid({
    required this.cases,
    required this.onOpenCase,
    this.selectionMode = false,
    this.selectionOrderFor,
    this.selectionLimitReached = false,
  });

  final List<OsceCaseSummary> cases;
  final ValueChanged<OsceCaseSummary> onOpenCase;
  final bool selectionMode;
  final int Function(OsceCaseSummary item)? selectionOrderFor;
  final bool selectionLimitReached;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = PratiCaseResponsive.columnsForWidth(
          constraints.maxWidth,
          desktop: 3,
        );
        final spacing = columns == 1 ? 0.0 : 14.0;
        final itemWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: 14,
          children: [
            for (var i = 0; i < cases.length; i++)
              SizedBox(
                width: itemWidth,
                child: FadeSlideIn(
                  delay: Duration(milliseconds: (i * 40).clamp(0, 400)),
                  child: _CaseListCard(
                    item: cases[i],
                    onTap: () => onOpenCase(cases[i]),
                    selectionMode: selectionMode,
                    selectionOrder: selectionOrderFor?.call(cases[i]) ?? 0,
                    selectionLimitReached: selectionLimitReached,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CaseSelectionBadge extends StatelessWidget {
  const _CaseSelectionBadge({
    required this.selectionOrder,
    required this.limitReached,
  });

  final int selectionOrder;
  final bool limitReached;

  @override
  Widget build(BuildContext context) {
    final selected = selectionOrder > 0;
    final text = selected
        ? '$selectionOrder. İstasyon'
        : limitReached
        ? 'Dolu'
        : 'Seç';
    final color = selected ? PratiCaseColors.teal : PratiCaseColors.muted;
    return Container(
      constraints: const BoxConstraints(minWidth: 58),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: selected
            ? PratiCaseColors.teal.withValues(alpha: 0.10)
            : PratiCaseColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
        border: Border.all(
          color: selected
              ? PratiCaseColors.teal.withValues(alpha: 0.48)
              : PratiCaseColors.border,
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
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
    this.onOpenHome,
    this.onFinish,
  });

  final ExamSessionOverview session;
  final String phase;
  final CasesRepository repository;
  final String sessionId;
  final VoidCallback? onOpenHome;
  final Future<void> Function()? onFinish;

  Future<void> _finish(BuildContext context) async {
    final customFinish = onFinish;
    if (customFinish != null) {
      await customFinish();
      return;
    }
    final shouldFinish = await _confirmIncompleteFinish(context);
    if (!shouldFinish || !context.mounted) return;
    await repository.advanceSession(sessionId: sessionId, step: 'completed');
    if (!context.mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ResultScreen(
          repository: repository,
          sessionId: sessionId,
          onOpenHome: onOpenHome,
        ),
      ),
    );
  }

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
            PratiCaseColors.gradientStart,
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
              _FinishExamButton(onFinish: () => _finish(context)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _TimerBadge(
                  session: session,
                  onExpired: () => _finish(context),
                ),
              ),
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
                  text: 'Süreli İstasyon',
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
        borderRadius: BorderRadius.circular(PratiCaseRadius.sm),
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
  const _TimerBadge({required this.session, required this.onExpired});

  final ExamSessionOverview session;
  final Future<void> Function() onExpired;

  @override
  State<_TimerBadge> createState() => _TimerBadgeState();
}

class _TimerBadgeState extends State<_TimerBadge>
    with SingleTickerProviderStateMixin {
  late Timer _timer;
  late final AnimationController _pulseController;
  bool _didExpire = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    WidgetsBinding.instance.addPostFrameCallback((_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    setState(() {});
    if (_remainingParts(widget.session) != '00:00' || _didExpire) return;
    _didExpire = true;
    unawaited(widget.onExpired());
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
            borderRadius: BorderRadius.circular(PratiCaseRadius.sm),
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
  const _PhaseTabs({required this.activeStep, this.onStepSelected});

  final int activeStep;

  /// When provided, already-completed (earlier) phases become tappable so the
  /// candidate can step back — e.g. return to Tetkik to request more labs.
  final ValueChanged<int>? onStepSelected;

  @override
  Widget build(BuildContext context) {
    const labels = ['Anamnez', 'Muayene', 'Tetkik', 'Tanı', 'Plan'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: PratiCaseColors.white,
        borderRadius: BorderRadius.circular(PratiCaseRadius.lg),
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
                onTap: (index + 1 < activeStep && onStepSelected != null)
                    ? () => onStepSelected!(index + 1)
                    : null,
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
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final bool complete;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = active || complete
        ? PratiCaseColors.teal
        : PratiCaseColors.muted;
    final content = Column(
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
                : PratiCaseColors.softSurface,
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
                : PratiCaseColors.muted,
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
    if (onTap == null) return content;
    return Semantics(
      button: true,
      enabled: true,
      label: '$label aşamasına dön',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PratiCaseRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: content,
        ),
      ),
    );
  }
}

void _popBackToExamPhase(
  BuildContext context, {
  required int activeStep,
  required int step,
}) {
  if (step >= activeStep) return;
  final navigator = Navigator.of(context);
  for (var popCount = activeStep - step; popCount > 0; popCount--) {
    if (!navigator.canPop()) return;
    navigator.pop();
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

String _shortDateTime(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day.$month.${local.year} $hour:$minute';
}

bool _labParameterAbnormal(String status) {
  final normalized = status.trim().toLowerCase();
  return normalized.contains('yük') ||
      normalized.contains('düş') ||
      normalized.contains('pozitif') ||
      normalized.contains('abnormal') ||
      normalized.contains('high') ||
      normalized.contains('low');
}

class _DetailHero extends StatelessWidget {
  const _DetailHero({required this.detail});

  final OsceCaseDetail detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(PratiCaseRadius.xl),
        boxShadow: PratiCaseShadows.floating,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(PratiCaseRadius.xl),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: PratiCaseGradients.hero,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          detail.summary.title,
                          style: const TextStyle(
                            color: PratiCaseColors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _HeroPill(
                              icon: Icons.schedule_rounded,
                              text: '${detail.summary.durationMinutes} dk',
                            ),
                            _HeroPill(
                              icon: Icons.bar_chart_rounded,
                              text: detail.summary.difficulty.label,
                            ),
                            _HeroPill(
                              icon: Icons.groups_rounded,
                              text: '${detail.summary.solvedCount} çözen',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: PratiCaseColors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(PratiCaseRadius.md),
                    ),
                    child: Icon(
                      _caseIcon(detail.summary.iconKey),
                      color: PratiCaseColors.white,
                      size: 36,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: PratiCaseColors.white,
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
                    style: const TextStyle(
                      color: PratiCaseColors.slateBlue,
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

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: PratiCaseColors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
        border: Border.all(
          color: PratiCaseColors.white.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: PratiCaseColors.tealBright, size: 13),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: PratiCaseColors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
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
          ? const Text('Vaka akışı henüz tanımlanmadı.')
          : LayoutBuilder(
              builder: (context, constraints) {
                final tight = constraints.maxWidth / steps.length < 64;
                if (tight) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var index = 0; index < steps.length; index++) ...[
                          SizedBox(
                            width: 72,
                            child: _FlowStepIcon(step: steps[index]),
                          ),
                          if (index != steps.length - 1)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 2),
                              child: Icon(
                                Icons.chevron_right_rounded,
                                color: PratiCaseColors.muted,
                              ),
                            ),
                        ],
                      ],
                    ),
                  );
                }
                return Row(
                  children: [
                    for (var index = 0; index < steps.length; index++) ...[
                      Expanded(child: _FlowStepIcon(step: steps[index])),
                      if (index != steps.length - 1)
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: PratiCaseColors.muted,
                        ),
                    ],
                  ],
                );
              },
            ),
    );
  }
}

class _FlowStepIcon extends StatelessWidget {
  const _FlowStepIcon({required this.step});

  final CaseFlowStep step;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SoftIcon(
          icon: _flowIcon(step.iconKey),
          color: PratiCaseColors.teal,
          size: 42,
        ),
        const SizedBox(height: 6),
        Text(
          step.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: PratiCaseColors.navy,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _PatientInfoCard extends StatelessWidget {
  const _PatientInfoCard({
    required this.patient,
    required this.durationMinutes,
  });

  final PatientProfile patient;
  final int durationMinutes;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Hasta Bilgileri',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 320;
          return GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: compact ? 1.9 : 2.3,
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
                value: patient.complaintDuration.trim().isNotEmpty
                    ? patient.complaintDuration
                    : '$durationMinutes dk',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ExamModeNotice extends StatelessWidget {
  const _ExamModeNotice();

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Sınav Modu',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline_rounded, color: PratiCaseColors.teal),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Hedefler, ideal yaklaşım ve puan kırılımları sınav bitince karnede açılır. Bu ekranda yalnız aday yönergesi ve istasyon bilgileri gösterilir.',
              style: TextStyle(
                color: PratiCaseColors.navy.withValues(alpha: 0.84),
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
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
    required this.voiceState,
    required this.voiceExamMode,
    required this.onReplayPatient,
    required this.onStopSpeaking,
    required this.onToggleMute,
    required this.onOpenProgress,
    required this.onAddNote,
    this.pendingCandidateMessage,
  });

  final _ChatBundle bundle;
  final ScrollController scrollController;
  final bool patientTyping;
  final VoiceExamState voiceState;
  final bool voiceExamMode;
  final String? pendingCandidateMessage;
  final VoidCallback onReplayPatient;
  final VoidCallback onStopSpeaking;
  final VoidCallback onToggleMute;
  final VoidCallback onOpenProgress;
  final VoidCallback onAddNote;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          child: _AnamnesisCompactHeader(
            session: bundle.session,
            detail: bundle.detail,
            voiceState: voiceState,
            voiceExamMode: voiceExamMode,
            onReplayPatient: onReplayPatient,
            onStopSpeaking: onStopSpeaking,
            onToggleMute: onToggleMute,
            onOpenProgress: onOpenProgress,
            onAddNote: onAddNote,
          ),
        ),
        Expanded(
          child: _ConversationPanel(
            session: bundle.session,
            messages: bundle.messages,
            scrollController: scrollController,
            pendingCandidateMessage: pendingCandidateMessage,
            patientTyping: patientTyping,
            voiceState: voiceState,
          ),
        ),
      ],
    );
  }
}

class _AnamnesisCompactHeader extends StatelessWidget {
  const _AnamnesisCompactHeader({
    required this.session,
    required this.detail,
    required this.voiceState,
    required this.voiceExamMode,
    required this.onReplayPatient,
    required this.onStopSpeaking,
    required this.onToggleMute,
    required this.onOpenProgress,
    required this.onAddNote,
  });

  final ExamSessionOverview session;
  final OsceCaseDetail detail;
  final VoiceExamState voiceState;
  final bool voiceExamMode;
  final VoidCallback onReplayPatient;
  final VoidCallback onStopSpeaking;
  final VoidCallback onToggleMute;
  final VoidCallback onOpenProgress;
  final VoidCallback onAddNote;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: PratiCaseColors.white,
        borderRadius: BorderRadius.circular(PratiCaseRadius.lg),
        border: Border.all(color: PratiCaseColors.border),
        boxShadow: PratiCaseShadows.card,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: PratiCaseColors.teal.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_rounded,
              color: PratiCaseColors.teal,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${session.patient.name} ile anamnez',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PratiCaseColors.navy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail.candidatePrompt,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PratiCaseColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          _CompactIconButton(
            tooltip: 'Hasta sesini yeniden oynat',
            icon: voiceState.speaking
                ? Icons.stop_circle_outlined
                : Icons.volume_up_outlined,
            onPressed: voiceState.speaking ? onStopSpeaking : onReplayPatient,
            active: voiceExamMode && voiceState.speaking,
          ),
          _CompactIconButton(
            tooltip: voiceState.muted ? 'Sesi aç' : 'Sesi kapat',
            icon: voiceState.muted
                ? Icons.volume_off_outlined
                : Icons.volume_down_outlined,
            onPressed: onToggleMute,
            active: voiceState.muted,
          ),
          _CompactIconButton(
            tooltip: 'Vaka ilerlemesi',
            icon: Icons.timeline_rounded,
            onPressed: onOpenProgress,
          ),
          _CompactIconButton(
            tooltip: 'Not ekle',
            icon: Icons.note_add_outlined,
            onPressed: onAddNote,
          ),
        ],
      ),
    );
  }
}

class _CompactIconButton extends StatelessWidget {
  const _CompactIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.active = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          backgroundColor: active
              ? PratiCaseColors.teal.withValues(alpha: 0.12)
              : Colors.transparent,
          foregroundColor: active
              ? PratiCaseColors.teal
              : PratiCaseColors.muted,
          fixedSize: const Size(38, 38),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: Icon(icon, size: 20),
      ),
    );
  }
}

class _ConversationPanel extends StatelessWidget {
  const _ConversationPanel({
    required this.session,
    required this.messages,
    required this.scrollController,
    required this.patientTyping,
    required this.voiceState,
    this.pendingCandidateMessage,
  });

  final ExamSessionOverview session;
  final List<ChatMessage> messages;
  final ScrollController scrollController;
  final bool patientTyping;
  final VoiceExamState voiceState;
  final String? pendingCandidateMessage;

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = PratiCaseResponsive.horizontalPaddingForWidth(
      MediaQuery.sizeOf(context).width,
    );
    final pending = pendingCandidateMessage?.trim();
    final conversationCount =
        messages.length + (pending == null || pending.isEmpty ? 0 : 1) + 1;
    return Container(
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: PratiCaseColors.softSurface,
        border: Border(
          top: BorderSide(color: PratiCaseColors.navy.withValues(alpha: 0.06)),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              10,
              horizontalPadding,
              8,
            ),
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
                if (voiceState.partialText.trim().isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: _TinyPill(
                      text: 'Dinleniyor: ${voiceState.partialText}',
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                12,
                horizontalPadding,
                18,
              ),
              children: [
                FadeSlideIn(
                  offset: const Offset(0, 0.04),
                  child: _ChatBubble(
                    message: session.patient.openingLine,
                    fromCandidate: false,
                    isOpening: true,
                  ),
                ),
                for (var i = 0; i < messages.length; i++)
                  FadeSlideIn(
                    delay: Duration(milliseconds: (i * 30).clamp(0, 300)),
                    offset: Offset(messages[i].fromCandidate ? 0.04 : -0.04, 0),
                    child: _ChatBubble(
                      message: messages[i].message,
                      fromCandidate: messages[i].fromCandidate,
                    ),
                  ),
                if (pending != null && pending.isNotEmpty)
                  FadeSlideIn(
                    offset: const Offset(0.04, 0),
                    child: _ChatBubble(
                      message: pending,
                      fromCandidate: true,
                      isPending: true,
                    ),
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

class _PhysicalSystemPicker extends StatelessWidget {
  const _PhysicalSystemPicker({
    required this.groups,
    required this.options,
    required this.onSelected,
  });

  final List<PhysicalExamGroup> groups;
  final List<PhysicalExamOption> options;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Önce muayene sistemini seç.',
          style: TextStyle(
            color: PratiCaseColors.slateBlue,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        for (final group in groups) ...[
          _PhysicalSystemTile(
            group: group,
            optionCount: options
                .where((option) => option.groupId == group.id)
                .length,
            selectedCount: options
                .where(
                  (option) => option.groupId == group.id && option.isSelected,
                )
                .length,
            onTap: () => onSelected(group.id),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _PhysicalSystemTile extends StatelessWidget {
  const _PhysicalSystemTile({
    required this.group,
    required this.optionCount,
    required this.selectedCount,
    required this.onTap,
  });

  final PhysicalExamGroup group;
  final int optionCount;
  final int selectedCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: _cardDecoration(radius: 16),
        child: Row(
          children: [
            _SoftIcon(
              icon: Icons.health_and_safety_outlined,
              color: selectedCount > 0
                  ? PratiCaseColors.successGreen
                  : PratiCaseColors.teal,
              size: 44,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.title,
                    style: const TextStyle(
                      color: PratiCaseColors.navy,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selectedCount == 0
                        ? '$optionCount muayene seçeneği'
                        : '$selectedCount/$optionCount seçildi',
                    style: const TextStyle(
                      color: PratiCaseColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: PratiCaseColors.teal,
            ),
          ],
        ),
      ),
    );
  }
}

class _FindingsCard extends StatelessWidget {
  const _FindingsCard({
    required this.title,
    required this.options,
    required this.onSelect,
  });

  final String title;
  final List<PhysicalExamOption> options;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: title,
      child: Column(
        children: [
          if (options.isEmpty)
            const Text('Bu sistem için canlı bulgu tanımlanmadı.')
          else
            for (final item in options) ...[
              Container(
                margin: const EdgeInsets.only(bottom: PratiCaseSpacing.sm),
                decoration: BoxDecoration(
                  color: item.isSelected
                      ? PratiCaseColors.teal.withValues(alpha: 0.06)
                      : PratiCaseColors.white,
                  borderRadius: BorderRadius.circular(PratiCaseRadius.sm),
                  border: item.isSelected
                      ? Border.all(color: PratiCaseColors.teal, width: 1.5)
                      : Border.all(color: PratiCaseColors.border),
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: PratiCaseSpacing.md,
                    ),
                    title: Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: PratiCaseColors.navy,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: item.isSelected && item.finding.isNotEmpty
                        ? Text(
                            item.finding,
                            style: const TextStyle(
                              color: PratiCaseColors.slateBlue,
                              height: 1.35,
                            ),
                          )
                        : null,
                    isThreeLine: item.isSelected && item.finding.isNotEmpty,
                    trailing: Icon(
                      item.isSelected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: item.isSelected
                          ? PratiCaseColors.teal
                          : PratiCaseColors.border,
                      size: 26,
                    ),
                    onTap: () => onSelect(item.id),
                  ),
                ),
              ),
            ],
        ],
      ),
    );
  }
}

class _TestGroupPicker extends StatelessWidget {
  const _TestGroupPicker({
    required this.groups,
    required this.options,
    required this.onSelected,
  });

  final List<TestGroup> groups;
  final List<TestOption> options;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Önce tetkik grubunu seç.',
          style: TextStyle(
            color: PratiCaseColors.slateBlue,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        for (final group in groups) ...[
          _TestGroupTile(
            group: group,
            optionCount: options
                .where((option) => option.groupId == group.id)
                .length,
            selectedCount: options
                .where(
                  (option) => option.groupId == group.id && option.isSelected,
                )
                .length,
            onTap: () => onSelected(group.id),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _TestGroupTile extends StatelessWidget {
  const _TestGroupTile({
    required this.group,
    required this.optionCount,
    required this.selectedCount,
    required this.onTap,
  });

  final TestGroup group;
  final int optionCount;
  final int selectedCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: _cardDecoration(radius: 16),
        child: Row(
          children: [
            _SoftIcon(
              icon: Icons.biotech_outlined,
              color: selectedCount > 0
                  ? PratiCaseColors.successGreen
                  : PratiCaseColors.teal,
              size: 44,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.title,
                    style: const TextStyle(
                      color: PratiCaseColors.navy,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selectedCount == 0
                        ? '$optionCount tetkik seçeneği'
                        : '$selectedCount/$optionCount istendi',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: PratiCaseColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: PratiCaseColors.teal,
            ),
          ],
        ),
      ),
    );
  }
}

class _TestOptionsCard extends StatelessWidget {
  const _TestOptionsCard({
    required this.title,
    required this.options,
    required this.basket,
    required this.onToggleBasket,
    required this.onOpenDetail,
  });

  final String title;
  final List<TestOption> options;
  final Set<String> basket;
  final ValueChanged<String> onToggleBasket;
  final ValueChanged<TestOption> onOpenDetail;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: title,
      child: Column(
        children: [
          if (options.isEmpty)
            const Text('Bu grupta canlı tetkik tanımlanmadı.')
          else
            for (final item in options) ...[
              _TestOptionTile(
                item: item,
                inBasket: basket.contains(item.id),
                onToggleBasket: () => onToggleBasket(item.id),
                onOpenDetail: () => onOpenDetail(item),
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _TestOptionTile extends StatelessWidget {
  const _TestOptionTile({
    required this.item,
    required this.inBasket,
    required this.onToggleBasket,
    required this.onOpenDetail,
  });

  final TestOption item;
  final bool inBasket;
  final VoidCallback onToggleBasket;
  final VoidCallback onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final requested = item.isSelected;
    final highlighted = requested || inBasket;
    final accent = requested
        ? PratiCaseColors.successGreen
        : PratiCaseColors.teal;
    return Container(
      decoration: BoxDecoration(
        color: highlighted
            ? accent.withValues(alpha: 0.06)
            : PratiCaseColors.white,
        borderRadius: BorderRadius.circular(PratiCaseRadius.lg),
        border: highlighted
            ? Border.all(color: accent.withValues(alpha: 0.45), width: 1.4)
            : Border.all(color: PratiCaseColors.border),
        boxShadow: PratiCaseShadows.card,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          onTap: requested ? onOpenDetail : onToggleBasket,
          leading: _SoftIcon(
            icon: Icons.science_outlined,
            color: accent,
            size: 42,
          ),
          title: Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: PratiCaseColors.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Text(
            requested
                ? 'Sonuç alttaki kutuda gösteriliyor.'
                : inBasket
                ? 'Sepette — Getir ile sonucu al.'
                : 'İstem sepetine ekle.',
            style: const TextStyle(
              color: PratiCaseColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          isThreeLine: false,
          trailing: Icon(
            requested
                ? Icons.visibility_outlined
                : inBasket
                ? Icons.check_circle_rounded
                : Icons.add_circle_outline_rounded,
            color: accent,
          ),
        ),
      ),
    );
  }
}

/// Cart-style summary of queued tetkikler with a single bulk "Getir" action.
class _TestBasketCard extends StatelessWidget {
  const _TestBasketCard({
    required this.options,
    required this.requesting,
    required this.onRemove,
    required this.onFetch,
  });

  final List<TestOption> options;
  final bool requesting;
  final ValueChanged<String> onRemove;
  final Future<void> Function() onFetch;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            PratiCaseColors.white,
            PratiCaseColors.teal.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(PratiCaseRadius.lg),
        border: Border.all(color: PratiCaseColors.teal.withValues(alpha: 0.30)),
        boxShadow: PratiCaseShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.shopping_basket_rounded,
                color: PratiCaseColors.teal,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'İstem Sepeti (${options.length})',
                style: const TextStyle(
                  color: PratiCaseColors.navy,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in options)
                _BasketChip(
                  label: option.title,
                  onRemove: () => onRemove(option.id),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: requesting ? null : () => onFetch(),
              icon: requesting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.download_rounded),
              label: Text(
                requesting
                    ? 'Getiriliyor...'
                    : 'Seçilenleri Getir (${options.length})',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BasketChip extends StatelessWidget {
  const _BasketChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
      decoration: BoxDecoration(
        color: PratiCaseColors.teal.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
        border: Border.all(color: PratiCaseColors.teal.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: PratiCaseColors.navy,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(20),
            child: const Icon(
              Icons.close_rounded,
              size: 16,
              color: PratiCaseColors.teal,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows every result returned by the latest basket fetch together.
class _FetchedResultsSection extends StatelessWidget {
  const _FetchedResultsSection({required this.results});

  final List<TestOption> results;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.fact_check_rounded,
              color: PratiCaseColors.teal,
              size: 19,
            ),
            const SizedBox(width: 8),
            Text(
              'Getirilen Sonuçlar (${results.length})',
              style: const TextStyle(
                color: PratiCaseColors.navy,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final option in results) ...[
          _InlineTestResultCard(option: option),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _InlineTestResultCard extends StatelessWidget {
  const _InlineTestResultCard({required this.option});

  final TestOption option;

  bool get _isImaging {
    final lower = option.title.toLowerCase();
    return lower.contains('usg') ||
        lower.contains('bt') ||
        lower.contains('mr') ||
        lower.contains('röntgen') ||
        lower.contains('grafi');
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Tetkik Sonucu',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SoftIcon(
                icon: _isImaging
                    ? Icons.monitor_heart_outlined
                    : Icons.biotech_outlined,
                color: PratiCaseColors.teal,
                size: 42,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  option.title,
                  style: const TextStyle(
                    color: PratiCaseColors.navy,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: PratiCaseColors.softSurface,
              borderRadius: BorderRadius.circular(PratiCaseRadius.md),
              border: Border.all(color: PratiCaseColors.border),
            ),
            child: Text(
              option.result.trim().isEmpty
                  ? 'Bu tetkik için yapılandırılmış sonuç tanımlı değil.'
                  : option.result,
              style: const TextStyle(
                color: PratiCaseColors.ink,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
    this.semanticsIdentifier,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final String? semanticsIdentifier;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final isFilled = value.text.trim().isNotEmpty;
        final activeColor = isFilled
            ? PratiCaseColors.successGreen
            : PratiCaseColors.teal;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FormLabel(label),
            const SizedBox(height: 8),
            Semantics(
              identifier: semanticsIdentifier ?? '',
              child: TextField(
                controller: controller,
                maxLines: maxLines,
                decoration: InputDecoration(
                  hintText: hint,
                  filled: true,
                  fillColor: isFilled
                      ? PratiCaseColors.successGreen.withValues(alpha: 0.04)
                      : PratiCaseColors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(PratiCaseRadius.md),
                    borderSide: const BorderSide(color: PratiCaseColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(PratiCaseRadius.md),
                    borderSide: BorderSide(
                      color: isFilled
                          ? PratiCaseColors.successGreen
                          : PratiCaseColors.border,
                      width: isFilled ? 1.5 : 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(PratiCaseRadius.md),
                    borderSide: BorderSide(color: activeColor, width: 1.5),
                  ),
                ),
              ),
            ),
          ],
        );
      },
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
    this.identifier = 'cta.bottom-action',
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  final String identifier;

  @override
  Widget build(BuildContext context) {
    return PratiCaseFlowActionButton(
      identifier: identifier,
      label: label,
      icon: icon,
      onPressed: onPressed,
    );
  }
}

class _FinishExamButton extends StatelessWidget {
  const _FinishExamButton({required this.onFinish});

  final Future<void> Function() onFinish;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Sınavı Bitir',
      child: IconButton.filled(
        onPressed: onFinish,
        icon: const Icon(Icons.stop_circle_outlined, size: 21),
        style: IconButton.styleFrom(
          backgroundColor: PratiCaseColors.errorRed,
          foregroundColor: PratiCaseColors.white,
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PratiCaseRadius.sm),
          ),
        ),
      ),
    );
  }
}

Future<bool> _confirmIncompleteFinish(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Sınavı bitir?'),
      content: const Text(
        'Eksik anamnez, muayene, tetkik, tanı veya yönetim adımları sonuç karnesine yansır.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Devam Et'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Bitir'),
        ),
      ],
    ),
  );
  return result ?? false;
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
        borderRadius: BorderRadius.circular(PratiCaseRadius.sm),
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
                    color: PratiCaseColors.muted,
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
        Icon(icon, color: PratiCaseColors.muted, size: 16),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            color: PratiCaseColors.muted,
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
            color: PratiCaseColors.muted,
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
                color: PratiCaseColors.muted,
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
                : PratiCaseColors.border,
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
              color: active ? PratiCaseColors.teal : PratiCaseColors.muted,
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
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        trailing: Text(
          value,
          style: const TextStyle(color: PratiCaseColors.muted),
        ),
      ),
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
      padding: const EdgeInsets.symmetric(
        horizontal: PratiCaseSpacing.sm,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
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
        borderRadius: BorderRadius.circular(PratiCaseRadius.sm),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: PratiCaseColors.gold,
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
    return SoftIconBadge(
      icon: icon,
      color: color,
      size: size,
      iconSize: size * 0.52,
      radius: 14,
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
          colors: [PratiCaseColors.teal, PratiCaseColors.gradientEnd],
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
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: PratiCaseColors.teal,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              subtext,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
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
              color: PratiCaseColors.muted,
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

class _CaseDetailSkeleton extends StatelessWidget {
  const _CaseDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: _flowListPadding(context, top: 14, bottom: 110),
      children: const [
        _StepTopBar(title: 'Vaka Detay'),
        SizedBox(height: 18),
        Row(
          children: [
            PratiCaseSkeletonBlock(width: 80, height: 28),
            SizedBox(width: 8),
            PratiCaseSkeletonBlock(width: 92, height: 28),
            SizedBox(width: 8),
            PratiCaseSkeletonBlock(width: 116, height: 28),
          ],
        ),
        SizedBox(height: 18),
        PratiCaseSkeletonBlock(height: 240, radius: PratiCaseRadius.xxl),
        SizedBox(height: 18),
        PratiCaseSkeletonCard(lines: 2, leading: false),
        SizedBox(height: 14),
        PratiCaseSkeletonCard(lines: 3),
      ],
    );
  }
}

class _PhaseLoadingSkeleton extends StatelessWidget {
  const _PhaseLoadingSkeleton({required this.activeStep});

  final int activeStep;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(
            PratiCaseResponsive.horizontalPaddingForWidth(
              MediaQuery.sizeOf(context).width,
            ),
            14,
            PratiCaseResponsive.horizontalPaddingForWidth(
              MediaQuery.sizeOf(context).width,
            ),
            14,
          ),
          decoration: const BoxDecoration(gradient: PratiCaseGradients.hero),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: PratiCaseColors.white.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PratiCaseSkeletonBlock(width: 96, height: 12),
                      SizedBox(height: 8),
                      PratiCaseSkeletonBlock(width: 148, height: 20),
                    ],
                  ),
                ),
                const PratiCaseSkeletonBlock(
                  width: 44,
                  height: 44,
                  radius: PratiCaseRadius.lg,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: _flowListPadding(context, top: 16),
            children: [
              _PhaseTabs(activeStep: activeStep),
              const SizedBox(height: 16),
              const PratiCaseSkeletonCard(lines: 2),
              const SizedBox(height: 14),
              const PratiCaseSkeletonCard(lines: 3, leading: false),
              const SizedBox(height: 14),
              const PratiCaseSkeletonCard(lines: 2),
            ],
          ),
        ),
      ],
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
  if (normalized.contains('gereksiz') ||
      normalized.contains('zararlı') ||
      normalized.contains('harm')) {
    return 'Diğer Yönetim Kararları';
  }
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

String _normalizeDiagnosisText(String value) {
  final lower = value.toLowerCase();
  final buffer = StringBuffer();
  for (final codeUnit in lower.codeUnits) {
    final char = String.fromCharCode(codeUnit);
    final normalized = switch (char) {
      'ç' => 'c',
      'ğ' => 'g',
      'ı' => 'i',
      'ö' => 'o',
      'ş' => 's',
      'ü' => 'u',
      _ => char,
    };
    buffer.write(RegExp(r'[a-z0-9]').hasMatch(normalized) ? normalized : ' ');
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

bool _diagnosisTextMatches(String answerText, String optionTitle) {
  if (answerText.isEmpty || optionTitle.isEmpty) return false;
  if (answerText.contains(optionTitle)) return true;
  final words = optionTitle
      .split(' ')
      .where((word) => word.length > 3)
      .toList(growable: false);
  if (words.isEmpty) return false;
  final matched = words.where(answerText.contains).length;
  return matched / words.length >= 0.65;
}

class _ManagementCategoryTile extends StatelessWidget {
  const _ManagementCategoryTile({
    required this.title,
    required this.options,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final List<ManagementOption> options;
  final Set<String> selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selectedCount = options
        .where((option) => selected.contains(option.id))
        .length;
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: _cardDecoration(radius: 16),
        child: Row(
          children: [
            _SoftIcon(
              icon: Icons.assignment_turned_in_outlined,
              color: selectedCount > 0
                  ? PratiCaseColors.successGreen
                  : PratiCaseColors.teal,
              size: 44,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: PratiCaseColors.navy,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selectedCount == 0
                        ? '${options.length} yönetim seçeneği'
                        : '$selectedCount/${options.length} seçildi',
                    style: const TextStyle(
                      color: PratiCaseColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: PratiCaseColors.teal,
            ),
          ],
        ),
      ),
    );
  }
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
              fontSize: 15,
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 12),
            height: 2,
            decoration: BoxDecoration(
              color: PratiCaseColors.teal,
              borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
            ),
          ),
          for (final option in options)
            _ManagementOptionTile(
              option: option,
              isSelected: selected.contains(option.id),
              onChanged: (value) => onChanged(option.id, value),
            ),
        ],
      ),
    );
  }
}

class _ManagementOptionTile extends StatelessWidget {
  const _ManagementOptionTile({
    required this.option,
    required this.isSelected,
    required this.onChanged,
  });

  final ManagementOption option;
  final bool isSelected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: PratiCaseSpacing.sm),
      decoration: BoxDecoration(
        color: isSelected
            ? PratiCaseColors.teal.withValues(alpha: 0.06)
            : PratiCaseColors.softSurface,
        borderRadius: BorderRadius.circular(PratiCaseRadius.sm),
        border: Border.all(
          color: isSelected ? PratiCaseColors.teal : PratiCaseColors.border,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: CheckboxListTile(
          value: isSelected,
          onChanged: (value) => onChanged(value ?? false),
          activeColor: PratiCaseColors.teal,
          checkColor: PratiCaseColors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: PratiCaseSpacing.md,
            vertical: 4,
          ),
          title: Text(
            option.title,
            style: const TextStyle(
              color: PratiCaseColors.navy,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

BoxDecoration _cardDecoration({double radius = PratiCaseRadius.xl}) {
  return PratiCaseCardDecorations.card(
    borderColor: PratiCaseColors.border.withValues(alpha: 0.88),
    radius: radius,
  );
}

Color _difficultyColor(OsceDifficulty difficulty) {
  switch (difficulty) {
    case OsceDifficulty.easy:
      return PratiCaseColors.successGreen;
    case OsceDifficulty.medium:
      return PratiCaseColors.gold;
    case OsceDifficulty.hard:
      return PratiCaseColors.errorRed;
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
  if (error is CasesDataUnavailable) {
    return PratiCaseUserMessage.safe(error.message);
  }
  return PratiCaseUserMessage.generalFailure;
}
