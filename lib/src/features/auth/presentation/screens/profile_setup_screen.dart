import 'package:flutter/material.dart';

import '../../../../app/theme/praticase_colors.dart';
import '../../../../app/theme/praticase_tokens.dart';
import '../../data/auth_repository.dart';
import '../../domain/profile_setup.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_status_card.dart';

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
  final VoidCallback onCompleted;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  String _targetExam = 'TUS';
  String _grade = '5. Sınıf';
  int _dailyGoal = 2;
  final _branches = <String>{};
  DateTime? _examDate;
  bool _loading = false;
  String? _error;

  Future<void> _complete() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.repository.completeProfile(
        ProfileSetup(
          grade: _grade,
          targetExam: _targetExam,
          targetBranches: _branches.toList(),
          dailyGoal: _dailyGoal,
          examDate: _examDate,
        ),
      );
      widget.onCompleted();
    } on AuthFailure catch (failure) {
      setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final branches = [
      (Icons.pregnant_woman_rounded, 'Kadın Doğum'),
      (Icons.healing_rounded, 'Genel Cerrahi'),
      (Icons.water_drop_outlined, 'Üroloji'),
      (Icons.local_hospital_rounded, 'Dahiliye'),
      (Icons.emergency_rounded, 'Acil'),
    ];

    return AuthScaffold(
      onBack: widget.onBack,
      showFooterText: false,
      topPadding: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SetupProgressHeader(),
          const SizedBox(height: 24),
          Text(
            'Profilini Özelleştir',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: PratiCaseSpacing.sm),
          Text(
            'Klinik simülasyon deneyimini sana özel hale getirelim.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: PratiCaseColors.muted,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          _SetupSection(
            icon: Icons.track_changes_rounded,
            title: 'Hedef Sınav',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final exam in const ['TUS', 'OSCE', 'Komite', 'USMLE'])
                  _ChoicePill(
                    label: exam,
                    selected: _targetExam == exam,
                    onTap: () => setState(() => _targetExam = exam),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SetupSection(
            icon: Icons.school_rounded,
            title: 'Klinik Seviye',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final grade in const [
                  '4. Sınıf',
                  '5. Sınıf',
                  '6. Sınıf',
                  'Mezun',
                ])
                  _ChoicePill(
                    label: grade,
                    selected: _grade == grade,
                    onTap: () => setState(() => _grade = grade),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SetupSection(
            icon: Icons.favorite_rounded,
            title: 'İlgi Alanları',
            subtitle: 'Birden fazla seçebilirsiniz',
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final branch in branches)
                      _BranchChip(
                        width: (constraints.maxWidth - 10) / 2,
                        icon: branch.$1,
                        label: branch.$2,
                        selected: _branches.contains(branch.$2),
                        onTap: () {
                          setState(() {
                            if (_branches.contains(branch.$2)) {
                              _branches.remove(branch.$2);
                            } else if (_branches.length < 3) {
                              _branches.add(branch.$2);
                            }
                          });
                        },
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          _SetupSection(
            icon: Icons.flag_rounded,
            title: 'Günlük Hedef',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final goal in const [1, 2, 5])
                  _ChoicePill(
                    label: '$goal Vaka',
                    selected: _dailyGoal == goal,
                    onTap: () => setState(() => _dailyGoal = goal),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SetupSection(
            icon: Icons.calendar_month_rounded,
            title: 'OSCE Sınav Tarihi',
            child: OutlinedButton.icon(
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _examDate ?? DateTime.now(),
                  firstDate: DateTime(2026),
                  lastDate: DateTime(2030),
                );
                if (date != null) setState(() => _examDate = date);
              },
              icon: const Icon(
                Icons.calendar_today_rounded,
                size: 18,
                color: PratiCaseColors.teal,
              ),
              label: Text(
                _formatDate(_examDate),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                alignment: Alignment.centerLeft,
                foregroundColor: PratiCaseColors.ink,
                side: const BorderSide(color: PratiCaseColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(PratiCaseRadius.md),
                ),
              ),
            ),
          ),
          const SizedBox(height: PratiCaseSpacing.xxl),
          AuthPrimaryButton(
            identifier: 'cta.complete-profile',
            label: 'PratiCase’e Başla',
            loading: _loading,
            onPressed: _complete,
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

  String _formatDate(DateTime? date) {
    if (date == null) return 'Opsiyonel';
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}

class _SetupProgressHeader extends StatelessWidget {
  const _SetupProgressHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'ADIM 2 / 3',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: PratiCaseColors.teal,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                height: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: PratiCaseSpacing.md),
        ClipRRect(
          borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
          child: const LinearProgressIndicator(
            value: 0.66,
            minHeight: 6,
            backgroundColor: PratiCaseColors.surfaceContainerHighest,
            color: PratiCaseColors.teal,
          ),
        ),
      ],
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
        borderRadius: BorderRadius.circular(PratiCaseRadius.md),
        border: Border.all(color: PratiCaseColors.border),
        boxShadow: PratiCaseShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: PratiCaseColors.teal, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: PratiCaseColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: selected ? PratiCaseColors.teal : Colors.transparent,
          borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
          border: Border.all(
            color: selected ? PratiCaseColors.teal : PratiCaseColors.border,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? PratiCaseColors.white : PratiCaseColors.ink,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _BranchChip extends StatelessWidget {
  const _BranchChip({
    required this.width,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final double width;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
      child: Container(
        width: width.clamp(132, 190),
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? PratiCaseColors.teal : Colors.transparent,
          borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
          border: Border.all(
            color: selected ? PratiCaseColors.teal : PratiCaseColors.border,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (selected) ...[
              const Icon(
                Icons.check_rounded,
                color: PratiCaseColors.white,
                size: 16,
              ),
              const SizedBox(width: 4),
            ] else ...[
              Icon(icon, color: PratiCaseColors.muted, size: 16),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? PratiCaseColors.white : PratiCaseColors.ink,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
