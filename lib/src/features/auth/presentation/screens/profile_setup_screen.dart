import 'package:flutter/material.dart';

import '../../../../app/theme/praticase_colors.dart';
import '../../data/auth_repository.dart';
import '../../domain/profile_setup.dart';
import '../widgets/auth_brand.dart';
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AuthBrand(),
          const SizedBox(height: 30),
          Text(
            'Pratiğini kişiselleştirelim',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Sana özel bir deneyim sunmak için bazı bilgileri öğrenelim.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 22),
          Text('Sınıf / Dönem', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _grade,
            items: ['4. Sınıf', '5. Sınıf', '6. Sınıf', 'Mezun']
                .map(
                  (grade) => DropdownMenuItem(value: grade, child: Text(grade)),
                )
                .toList(),
            onChanged: (value) => setState(() => _grade = value ?? _grade),
            decoration: const InputDecoration(
              filled: true,
              fillColor: PratiCaseColors.white,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Hedef Branşlar',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'En fazla 3 seçim yapabilirsin.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
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
          const SizedBox(height: 22),
          Text(
            'Günlük Hedefin',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 1, label: Text('1 Vaka')),
              ButtonSegment(value: 2, label: Text('2 Vaka')),
              ButtonSegment(value: 5, label: Text('5 Vaka')),
            ],
            selected: {_dailyGoal},
            onSelectionChanged: (value) =>
                setState(() => _dailyGoal = value.first),
          ),
          const SizedBox(height: 22),
          Text(
            'OSCE Sınav Tarihin',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _examDate ?? DateTime.now(),
                firstDate: DateTime(2026),
                lastDate: DateTime(2030),
              );
              if (date != null) setState(() => _examDate = date);
            },
            icon: const Icon(Icons.calendar_today_rounded, size: 18),
            label: Text(_formatDate(_examDate)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              alignment: Alignment.centerLeft,
            ),
          ),
          const SizedBox(height: 24),
          AuthPrimaryButton(
            label: 'PratiCase’e Başla',
            loading: _loading,
            onPressed: _complete,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            AuthStatusCard(message: _error!, tone: AuthStatusTone.error),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Opsiyonel';
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
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
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: width.clamp(132, 190),
        height: 74,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected
              ? PratiCaseColors.teal.withValues(alpha: 0.09)
              : PratiCaseColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? PratiCaseColors.teal : PratiCaseColors.border,
          ),
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    color: selected
                        ? PratiCaseColors.teal
                        : PratiCaseColors.muted,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Align(
                alignment: Alignment.topRight,
                child: CircleAvatar(
                  radius: 9,
                  backgroundColor: PratiCaseColors.teal,
                  child: Icon(
                    Icons.check_rounded,
                    color: PratiCaseColors.white,
                    size: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
