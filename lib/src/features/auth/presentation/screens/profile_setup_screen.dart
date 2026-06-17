import 'package:flutter/material.dart';

import '../../../../app/theme/praticase_colors.dart';
import '../../../../app/theme/praticase_tokens.dart';
import '../../../ecosystem_setup/data/turkish_universities.dart';
import '../../data/auth_repository.dart';
import '../../domain/auth_user.dart';
import '../../domain/profile_setup.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_status_card.dart';

const _pratiStart = Color(0xFF1D67D2);
const _pratiEnd = Color(0xFF56A4F4);
const _muted = Color(0xFF6B7396);

List<String> _targetOptionsForDiscipline(String discipline) {
  return switch (discipline) {
    'tip' => const [
      'OSCE Sınavı',
      'USMLE Step 2 CS',
      'Klinik Stajlar',
      'İntörnlük Hazırlığı',
    ],
    'dis' => const [
      'Klinik Beceri Sınavı',
      'DUS Klinik Hazırlık',
      'Klinik Stajlar',
    ],
    'hemsirelik' ||
    'ebelik' => const ['Klinik Uygulama', 'OSCE Sınavı', 'Staj Hazırlığı'],
    _ => const ['OSCE Sınavı', 'Klinik Stajlar'],
  };
}

String _targetForDiscipline(String current, String discipline) {
  final options = _targetOptionsForDiscipline(discipline);
  return options.contains(current) ? current : options.first;
}

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({
    required this.repository,
    required this.fullName,
    required this.onBack,
    required this.onCompleted,
    super.key,
  });

  final AuthRepository repository;
  final String fullName;
  final VoidCallback onBack;
  final ValueChanged<AuthUser> onCompleted;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  static const _stepTitles = [
    'Hedef & Takvim',
    'Çalışma Ritmi',
    'Anlatım Tercihi',
    'Mağaza',
  ];

  int _step = 0;
  UniversityOption? _university;
  String _discipline = 'tip';
  String _targetExam = 'OSCE Sınavı';
  String _grade = '5. Sınıf';
  int _dailyGoal = 2;
  int _weeklyGoalDays = 5;
  String _helpStyle = 'hint';
  String _learningPace = 'balanced';
  String _feedbackTone = 'friendly';
  bool _notifyMorning = true;
  bool _notifyEvening = false;
  bool _notifyCritical = true;
  String _storeAction = 'skip';
  String? _storePackageLabel;
  DateTime? _examDate;
  final _otherUniversityController = TextEditingController();
  final _syllabusController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _otherUniversityController.dispose();
    _syllabusController.dispose();
    super.dispose();
  }

  bool get _canContinue {
    if (_step != 0) return true;
    final selected = _university;
    if (selected == null) return true;
    if (selected.isOther) {
      return _otherUniversityController.text.trim().length >= 2;
    }
    return true;
  }

  Future<void> _complete() async {
    if (!_canContinue) {
      setState(() => _error = 'Diğer seçtiysen üniversite adını tamamla.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final selected = _university;
    final otherUniversity = _otherUniversityController.text.trim();
    try {
      final user = await widget.repository.completeProfile(
        ProfileSetup(
          discipline: _discipline,
          grade: _grade,
          targetExam: _targetExam,
          targetBranches: const [],
          dailyGoal: _dailyGoal,
          fullName: widget.fullName,
          universityName: selected == null
              ? 'MedAsi Ekosistem'
              : selected.isOther
              ? otherUniversity
              : selected.name,
          universityCity: selected == null || selected.isOther
              ? null
              : selected.city,
          universityType: selected?.type ?? 'Diğer',
          universityOther: selected == null
              ? 'MedAsi Ekosistem'
              : selected.isOther
              ? otherUniversity
              : null,
          weeklyGoalDays: _weeklyGoalDays,
          helpStyle: _helpStyle,
          learningPace: _learningPace,
          feedbackTone: _feedbackTone,
          notifyMorning: _notifyMorning,
          notifyEvening: _notifyEvening,
          notifyCritical: _notifyCritical,
          syllabusFileName: _syllabusController.text.trim().isEmpty
              ? null
              : _syllabusController.text.trim(),
          storeAction: _storeAction,
          storePackageLabel: _storePackageLabel,
          examDate: _examDate,
        ),
      );
      if (!mounted) return;
      widget.onCompleted(user);
    } on AuthFailure catch (failure) {
      setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _next() {
    if (!_canContinue) {
      setState(() => _error = 'Diğer seçtiysen üniversite adını tamamla.');
      return;
    }
    setState(() {
      _error = null;
      _step = (_step + 1).clamp(0, 3);
    });
  }

  Future<void> _pickUniversity() async {
    final selected = await showModalBottomSheet<UniversityOption>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: PratiCaseColors.white,
      builder: (_) => const _UniversityPickerSheet(),
    );
    if (selected == null) return;
    setState(() {
      _university = selected;
      if (!selected.isOther) _otherUniversityController.clear();
    });
  }

  Future<void> _pickExamDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _examDate ?? DateTime.now(),
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 8),
    );
    if (date != null) setState(() => _examDate = date);
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width < 340;
    return AuthScaffold(
      onBack: _step == 0
          ? widget.onBack
          : () => setState(() => _step = (_step - 1).clamp(0, 3)),
      showFooterText: false,
      topPadding: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProgressHeader(step: _step, titles: _stepTitles),
          const SizedBox(height: 18),
          Text(
            'MedAsi Ekosistem Kurulumu',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              fontSize: isNarrow ? 26 : 32,
              fontWeight: FontWeight.w900,
              height: 1.16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _subtitleForStep(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: PratiCaseColors.muted,
              fontSize: isNarrow ? 13.5 : 14,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: KeyedSubtree(key: ValueKey(_step), child: _stepBody()),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              TextButton.icon(
                onPressed: _step == 0
                    ? widget.onBack
                    : () => setState(() => _step = (_step - 1).clamp(0, 3)),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Geri'),
              ),
              const Spacer(),
              SizedBox(
                width: isNarrow ? 148 : 180,
                child: AuthPrimaryButton(
                  identifier: 'cta.complete-profile',
                  label: _step == 3 ? 'Bitir' : 'Devam',
                  loading: _loading,
                  showArrow: _step != 3,
                  onPressed: _loading
                      ? null
                      : _step == 3
                      ? _complete
                      : _next,
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: _error != null
                ? Padding(
                    padding: const EdgeInsets.only(top: PratiCaseSpacing.md),
                    child: AuthStatusCard(
                      message: _error!,
                      tone: AuthStatusTone.error,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  String _subtitleForStep() {
    return switch (_step) {
      0 => 'OSCE yolculuğun ne zaman zirveye çıkıyor?',
      1 => 'Günde kaç vakayla nöbet tutalım?',
      2 => 'Zor bir vakada başhekimin nasıl konuşsun?',
      _ => 'Cüzdanın hazırsa, klinik kapılarını açalım.',
    };
  }

  Widget _stepBody() {
    return switch (_step) {
      0 => _Step1GoalCalendar(
        discipline: _discipline,
        university: _university,
        otherUniversityController: _otherUniversityController,
        syllabusController: _syllabusController,
        targetExam: _targetExam,
        grade: _grade,
        examDate: _examDate,
        onDisciplineChanged: (value) => setState(() {
          _discipline = value;
          _targetExam = _targetForDiscipline(_targetExam, value);
        }),
        onPickUniversity: _pickUniversity,
        onPickExamDate: _pickExamDate,
        onTargetChanged: (value) => setState(() => _targetExam = value),
        onGradeChanged: (value) => setState(() => _grade = value),
        onChanged: () => setState(() {}),
      ),
      1 => _Step2StudyRhythm(
        dailyGoal: _dailyGoal,
        weeklyGoalDays: _weeklyGoalDays,
        notifyMorning: _notifyMorning,
        notifyEvening: _notifyEvening,
        notifyCritical: _notifyCritical,
        onDailyGoalChanged: (value) => setState(() => _dailyGoal = value),
        onWeeklyDaysChanged: (value) => setState(() => _weeklyGoalDays = value),
        onMorningChanged: (value) => setState(() => _notifyMorning = value),
        onEveningChanged: (value) => setState(() => _notifyEvening = value),
        onCriticalChanged: (value) => setState(() => _notifyCritical = value),
      ),
      2 => _Step3TeachingPrefs(
        helpStyle: _helpStyle,
        learningPace: _learningPace,
        feedbackTone: _feedbackTone,
        onHelpStyleChanged: (value) => setState(() => _helpStyle = value),
        onPaceChanged: (value) => setState(() => _learningPace = value),
        onToneChanged: (value) => setState(() => _feedbackTone = value),
      ),
      _ => _Step4Store(
        selectedLabel: _storePackageLabel,
        onSkip: () => setState(() {
          _storeAction = 'skip';
          _storePackageLabel = null;
        }),
        onPackage: (label) => setState(() {
          _storeAction = label == 'coin-100' ? 'coin' : 'package';
          _storePackageLabel = label;
        }),
      ),
    };
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.step, required this.titles});

  final int step;
  final List<String> titles;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            for (var index = 0; index < titles.length; index++) ...[
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: SizedBox(
                    height: 6,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const ColoredBox(color: PratiCaseColors.border),
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(end: index <= step ? 1 : 0),
                          duration: const Duration(milliseconds: 300),
                          builder: (context, value, child) {
                            return FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: value,
                              child: child,
                            );
                          },
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [_pratiStart, _pratiEnd],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (index != titles.length - 1) const SizedBox(width: 6),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          alignment: WrapAlignment.spaceBetween,
          children: [
            Text(
              'ADIM ${step + 1} / 4 · ${titles[step]}',
              style: const TextStyle(
                color: _muted,
                fontSize: 10.5,
                letterSpacing: 0.4,
              ),
            ),
            const Text(
              'Önce seni tanıyalım.',
              style: TextStyle(
                color: PratiCaseColors.teal,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Step1GoalCalendar extends StatelessWidget {
  const _Step1GoalCalendar({
    required this.discipline,
    required this.university,
    required this.otherUniversityController,
    required this.syllabusController,
    required this.targetExam,
    required this.grade,
    required this.examDate,
    required this.onDisciplineChanged,
    required this.onPickUniversity,
    required this.onPickExamDate,
    required this.onTargetChanged,
    required this.onGradeChanged,
    required this.onChanged,
  });

  final String discipline;
  final UniversityOption? university;
  final TextEditingController otherUniversityController;
  final TextEditingController syllabusController;
  final String targetExam;
  final String grade;
  final DateTime? examDate;
  final ValueChanged<String> onDisciplineChanged;
  final VoidCallback onPickUniversity;
  final VoidCallback onPickExamDate;
  final ValueChanged<String> onTargetChanged;
  final ValueChanged<String> onGradeChanged;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return _StepColumn(
      children: [
        const _GradientIntro(
          title: 'PRATICASE · ADIM 1',
          body: 'Önce hedef, sonra hasta odası.',
        ),
        _SetupSection(
          icon: Icons.monitor_heart_outlined,
          title: 'Alan / Branş',
          child: _ChoiceWrap(
            selected: discipline,
            values: const [
              'tip',
              'dis',
              'hemsirelik',
              'ebelik',
              'saglik_bilimleri',
            ],
            labelFor: (value) => switch (value) {
              'tip' => 'Tıp',
              'dis' => 'Diş Hekimliği',
              'hemsirelik' => 'Hemşirelik',
              'ebelik' => 'Ebelik',
              _ => 'Diğer Klinik',
            },
            onSelected: onDisciplineChanged,
          ),
        ),
        _SetupSection(
          icon: Icons.school_rounded,
          title: 'Üniversite',
          child: Column(
            children: [
              _PickerTile(
                title: university?.name ?? 'Üniversiteni seç',
                subtitle: university == null
                    ? 'Opsiyonel · tam liste + Diğer seçeneği'
                    : university!.isOther
                    ? 'Kendi üniversiteni yaz'
                    : '${university!.city} · ${university!.type}',
                onTap: onPickUniversity,
              ),
              if (university?.isOther == true) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: otherUniversityController,
                  decoration: const InputDecoration(
                    labelText: 'Üniversite adın',
                    prefixIcon: Icon(Icons.edit_location_alt_rounded),
                  ),
                  onChanged: (_) => onChanged(),
                ),
              ],
            ],
          ),
        ),
        _SetupSection(
          icon: Icons.track_changes_rounded,
          title: 'Hedef Sınav',
          child: _ChoiceWrap(
            selected: targetExam,
            values: _targetOptionsForDiscipline(discipline),
            onSelected: onTargetChanged,
          ),
        ),
        _SetupSection(
          icon: Icons.badge_outlined,
          title: 'Sınıf / Dönem',
          child: _ChoiceWrap(
            selected: grade,
            values: const [
              '1. Sınıf',
              '2. Sınıf',
              '3. Sınıf',
              '4. Sınıf',
              '5. Sınıf',
              '6. Sınıf',
              'Mezun',
            ],
            onSelected: onGradeChanged,
          ),
        ),
        _SetupSection(
          icon: Icons.calendar_month_rounded,
          title: 'Sınav Tarihi',
          child: _PickerTile(
            title: examDate == null ? 'Tarih seç' : _dateLabel(examDate!),
            subtitle: 'Opsiyonel · sonra değiştirebilirsin',
            onTap: onPickExamDate,
          ),
        ),
        _SetupSection(
          icon: Icons.picture_as_pdf_outlined,
          title: 'Ders Programı (PDF)',
          child: TextField(
            controller: syllabusController,
            decoration: const InputDecoration(
              labelText: 'PDF dosya adı / notu',
              hintText: 'staj-programim.pdf',
              prefixIcon: Icon(Icons.file_upload_outlined),
            ),
          ),
        ),
      ],
    );
  }
}

class _Step2StudyRhythm extends StatelessWidget {
  const _Step2StudyRhythm({
    required this.dailyGoal,
    required this.weeklyGoalDays,
    required this.notifyMorning,
    required this.notifyEvening,
    required this.notifyCritical,
    required this.onDailyGoalChanged,
    required this.onWeeklyDaysChanged,
    required this.onMorningChanged,
    required this.onEveningChanged,
    required this.onCriticalChanged,
  });

  final int dailyGoal;
  final int weeklyGoalDays;
  final bool notifyMorning;
  final bool notifyEvening;
  final bool notifyCritical;
  final ValueChanged<int> onDailyGoalChanged;
  final ValueChanged<int> onWeeklyDaysChanged;
  final ValueChanged<bool> onMorningChanged;
  final ValueChanged<bool> onEveningChanged;
  final ValueChanged<bool> onCriticalChanged;

  @override
  Widget build(BuildContext context) {
    return _StepColumn(
      children: [
        const _RhythmIntro(),
        _SetupSection(
          icon: Icons.local_fire_department_rounded,
          title: 'Günlük Hedef',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$dailyGoal',
                style: const TextStyle(
                  color: PratiCaseColors.teal,
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const Text(
                'vaka / gün',
                style: TextStyle(
                  color: PratiCaseColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Slider(
                min: 1,
                max: 8,
                divisions: 7,
                value: dailyGoal.toDouble().clamp(1, 8),
                onChanged: (value) => onDailyGoalChanged(value.round()),
              ),
            ],
          ),
        ),
        _SetupSection(
          icon: Icons.event_repeat_rounded,
          title: 'Haftalık Ritim',
          child: _ChoiceWrap(
            selected: '$weeklyGoalDays',
            values: const ['3', '5', '7'],
            labelFor: (value) => '$value gün/hafta',
            onSelected: (value) => onWeeklyDaysChanged(int.parse(value)),
          ),
        ),
        _SetupSection(
          icon: Icons.notifications_active_outlined,
          title: 'Bildirimler',
          child: Column(
            children: [
              _SwitchRow(
                title: 'Sabah dürtmesi',
                subtitle: 'Kahveden önce bir hatırlatma',
                value: notifyMorning,
                onChanged: onMorningChanged,
              ),
              _SwitchRow(
                title: 'Akşam toparlama',
                subtitle: 'Günün özeti, yarının planı',
                value: notifyEvening,
                onChanged: onEveningChanged,
              ),
              _SwitchRow(
                title: 'Kritik anlar',
                subtitle: 'OSCE’ye 30/15/7 gün kala',
                value: notifyCritical,
                onChanged: onCriticalChanged,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Step3TeachingPrefs extends StatelessWidget {
  const _Step3TeachingPrefs({
    required this.helpStyle,
    required this.learningPace,
    required this.feedbackTone,
    required this.onHelpStyleChanged,
    required this.onPaceChanged,
    required this.onToneChanged,
  });

  final String helpStyle;
  final String learningPace;
  final String feedbackTone;
  final ValueChanged<String> onHelpStyleChanged;
  final ValueChanged<String> onPaceChanged;
  final ValueChanged<String> onToneChanged;

  @override
  Widget build(BuildContext context) {
    return _StepColumn(
      children: [
        const _GradientIntro(
          title: 'Seni tanıyalım',
          body: 'Kişilik kartın · sonra profilden değiştirebilirsin.',
        ),
        _SetupSection(
          icon: Icons.lightbulb_outline_rounded,
          title: 'Zorlandığında...',
          child: _ChoiceWrap(
            selected: helpStyle,
            values: const ['hint', 'answer', 'socratic'],
            labelFor: (value) => switch (value) {
              'answer' => 'Direkt cevabı ver',
              'socratic' => 'Beni sorularla terlet',
              _ => 'Fısılda ipucunu',
            },
            onSelected: onHelpStyleChanged,
          ),
        ),
        _SetupSection(
          icon: Icons.speed_rounded,
          title: 'Öğrenme tempon',
          child: _ChoiceWrap(
            selected: learningPace,
            values: const ['calm', 'balanced', 'sprint'],
            labelFor: (value) => switch (value) {
              'calm' => 'Sakin',
              'sprint' => 'Sprint',
              _ => 'Dengeli',
            },
            onSelected: onPaceChanged,
          ),
        ),
        _SetupSection(
          icon: Icons.chat_bubble_outline_rounded,
          title: 'Geri bildirim tonu',
          child: _ChoiceWrap(
            selected: feedbackTone,
            values: const ['formal', 'friendly', 'witty'],
            labelFor: (value) => switch (value) {
              'formal' => 'Resmi',
              'witty' => 'Esprili',
              _ => 'Samimi',
            },
            onSelected: onToneChanged,
          ),
        ),
      ],
    );
  }
}

class _Step4Store extends StatelessWidget {
  const _Step4Store({
    required this.selectedLabel,
    required this.onSkip,
    required this.onPackage,
  });

  final String? selectedLabel;
  final VoidCallback onSkip;
  final ValueChanged<String> onPackage;

  @override
  Widget build(BuildContext context) {
    const packages = [
      ('20 vaka', '199 TL', ['Sözlü +60 dk']),
      ('60 vaka', '499 TL', ['Sözlü +200 dk', 'Detaylı karne']),
      ('Sınırsız', '999 TL', ['6 ay sınırsız', 'Birebir koç']),
    ];
    return _StepColumn(
      children: [
        const _GradientIntro(
          title: 'PRATICASE MAĞAZA',
          body: 'Vaka & Sözlü Sınav Kredisi',
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final item in packages)
              _StorePackageCard(
                label: item.$1,
                price: item.$2,
                perks: item.$3,
                popular: item.$1 == '60 vaka',
                selected: selectedLabel == item.$1,
                onTap: () => onPackage(item.$1),
              ),
          ],
        ),
        _CoinCard(
          selected: selectedLabel == 'coin-100',
          onTap: () => onPackage('coin-100'),
        ),
        const Row(
          children: [
            Expanded(child: _BenefitTile(text: '60 vaka kredisi')),
            SizedBox(width: 8),
            Expanded(child: _BenefitTile(text: '200dk sözlü sınav')),
            SizedBox(width: 8),
            Expanded(child: _BenefitTile(text: 'Detaylı karne')),
          ],
        ),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onSkip,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text(
              'Şimdilik ana ekrana geç',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}

class _StepColumn extends StatelessWidget {
  const _StepColumn({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final child in children) ...[child, const SizedBox(height: 14)],
      ],
    );
  }
}

class _GradientIntro extends StatelessWidget {
  const _GradientIntro({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_pratiStart, _pratiEnd]),
        borderRadius: BorderRadius.circular(PratiCaseRadius.xl),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.medical_services_outlined,
            color: Colors.white,
            size: 36,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    letterSpacing: 1.1,
                  ),
                ),
                Text(
                  body,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
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

class _RhythmIntro extends StatelessWidget {
  const _RhythmIntro();

  @override
  Widget build(BuildContext context) {
    return _SetupSection(
      icon: Icons.trending_up_rounded,
      title: 'Ritmini bul, sürdür.',
      subtitle:
          'Çok az çalışan dağılır, çok çalışan tükenir. Tatlı orta noktayı arıyoruz.',
      child: const SizedBox.shrink(),
    );
  }
}

class _SetupSection extends StatelessWidget {
  const _SetupSection({
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(PratiCaseSpacing.xl),
      decoration: BoxDecoration(
        color: PratiCaseColors.white,
        borderRadius: BorderRadius.circular(PratiCaseRadius.xl),
        border: Border.all(
          color: PratiCaseColors.border.withValues(alpha: 0.78),
        ),
        boxShadow: PratiCaseShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: PratiCaseColors.teal),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: PratiCaseColors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: PratiCaseColors.muted,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (child is! SizedBox) ...[const SizedBox(height: 14), child],
        ],
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(PratiCaseRadius.md),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: PratiCaseColors.softSurface,
          borderRadius: BorderRadius.circular(PratiCaseRadius.md),
          border: Border.all(color: PratiCaseColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: PratiCaseColors.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: PratiCaseColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: PratiCaseColors.teal,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceWrap extends StatelessWidget {
  const _ChoiceWrap({
    required this.selected,
    required this.values,
    required this.onSelected,
    this.labelFor,
  });

  final String selected;
  final List<String> values;
  final ValueChanged<String> onSelected;
  final String Function(String value)? labelFor;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final value in values)
          ChoiceChip(
            label: Text(labelFor?.call(value) ?? value),
            selected: selected == value,
            onSelected: (_) => onSelected(value),
          ),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(PratiCaseRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: PratiCaseColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: PratiCaseColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _StorePackageCard extends StatelessWidget {
  const _StorePackageCard({
    required this.label,
    required this.price,
    required this.perks,
    required this.popular,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String price;
  final List<String> perks;
  final bool popular;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PratiCaseRadius.xl),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: PratiCaseColors.white,
            borderRadius: BorderRadius.circular(PratiCaseRadius.xl),
            border: Border.all(
              color: selected || popular
                  ? PratiCaseColors.teal
                  : PratiCaseColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (popular)
                const Text(
                  'EN POPÜLER',
                  style: TextStyle(
                    color: PratiCaseColors.teal,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              Text(
                label,
                style: const TextStyle(
                  color: PratiCaseColors.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                price,
                style: const TextStyle(
                  color: PratiCaseColors.teal,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              for (final perk in perks)
                Text(
                  '· $perk',
                  style: const TextStyle(
                    color: PratiCaseColors.muted,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoinCard extends StatelessWidget {
  const _CoinCard({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(PratiCaseRadius.xl),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: PratiCaseColors.softSurface,
          borderRadius: BorderRadius.circular(PratiCaseRadius.xl),
          border: Border.all(
            color: selected ? PratiCaseColors.teal : PratiCaseColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: const Row(
          children: [
            Icon(Icons.toll_rounded, color: PratiCaseColors.teal, size: 30),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'MedAsi Coin - bir yükle, üç üründe harca\nQlinik · SourceBase · PratiCase arasında tek cüzdan. 100 Coin 49 TL.',
                style: TextStyle(color: PratiCaseColors.ink, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BenefitTile extends StatelessWidget {
  const _BenefitTile({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: PratiCaseColors.white,
        borderRadius: BorderRadius.circular(PratiCaseRadius.md),
        border: Border.all(color: PratiCaseColors.border),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: PratiCaseColors.ink,
          fontSize: 11,
          height: 1.3,
        ),
      ),
    );
  }
}

class _UniversityPickerSheet extends StatefulWidget {
  const _UniversityPickerSheet();

  @override
  State<_UniversityPickerSheet> createState() => _UniversityPickerSheetState();
}

class _UniversityPickerSheetState extends State<_UniversityPickerSheet> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final results = query.isEmpty
        ? turkishUniversities
        : turkishUniversities
              .where((item) => item.searchText.contains(query))
              .toList(growable: false);
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        minChildSize: 0.5,
        maxChildSize: 0.94,
        builder: (context, controller) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Üniversite ara',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final item = results[index];
                    return Material(
                      color: Colors.transparent,
                      child: ListTile(
                        title: Text(item.name),
                        subtitle: item.isOther
                            ? const Text('Listede yoksa kendi üniversiteni yaz')
                            : Text('${item.city} · ${item.type}'),
                        trailing: item.isOther
                            ? const Icon(Icons.edit_rounded)
                            : const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.of(context).pop(item),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _dateLabel(DateTime value) {
  return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
}
