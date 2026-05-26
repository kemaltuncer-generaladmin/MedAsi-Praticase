import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/praticase_colors.dart';
import '../../../app/theme/praticase_motion.dart';
import '../../../app/theme/praticase_tokens.dart';
import '../../../shared/data/user_facing_error.dart';
import '../../../shared/ui/ui.dart';
import '../../cases/data/voice_exam_adapter.dart';
import '../data/oral_exam_repository.dart';
import '../domain/oral_exam_models.dart';

/// Sözlü sınav kurulum ekranı: persona + branş + süre seçimi.
class OralExamSetupScreen extends StatefulWidget {
  const OralExamSetupScreen({
    required this.repository,
    this.initialFormat = OralExamFormat.solo,
    super.key,
  });

  final OralExamRepository repository;
  final OralExamFormat initialFormat;

  @override
  State<OralExamSetupScreen> createState() => _OralExamSetupScreenState();
}

class _OralExamSetupScreenState extends State<OralExamSetupScreen> {
  late Future<OralExamCatalog> _catalogFuture;
  OralExamPersona? _persona;
  OralExamBranch? _branch;
  OralExamScenario? _scenario;
  int _durationMinutes = 15;
  bool _starting = false;
  late OralExamFormat _format = widget.initialFormat;

  @override
  void initState() {
    super.initState();
    _catalogFuture = widget.repository.loadCatalog();
  }

  void _onBranchChanged(OralExamBranch branch) {
    setState(() {
      _branch = branch;
      _scenario = null;
    });
  }

  Future<void> _start() async {
    if (_branch == null || _starting) return;
    if (_format == OralExamFormat.solo && _persona == null) return;
    setState(() => _starting = true);
    try {
      final session = await widget.repository.startSession(
        personaId: _persona?.id ?? 'stern_professor',
        branchId: _branch!.id,
        durationSeconds: _durationMinutes * 60,
        scenarioId: _scenario?.id,
        format: _format,
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
                  FadeSlideIn(child: _IntroCard(format: _format)),
                  const SizedBox(height: 18),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 40),
                    child: _SectionTitle('Sınav Formatı'),
                  ),
                  const SizedBox(height: 10),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 50),
                    child: _FormatPicker(
                      value: _format,
                      onChanged: (value) => setState(() {
                        _format = value;
                        if (value == OralExamFormat.panel) {
                          _persona = null;
                        }
                      }),
                    ),
                  ),
                  if (_format == OralExamFormat.solo) ...[
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
                  ] else ...[
                    const SizedBox(height: 14),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 60),
                      child: _CommitteePreview(personas: catalog.personas),
                    ),
                  ],
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
                          onTap: () => _onBranchChanged(branch),
                        ),
                    ],
                  ),
                  if (_branch != null &&
                      catalog.scenariosFor(_branch!.id).isNotEmpty) ...[
                    const SizedBox(height: 20),
                    FadeSlideIn(child: _SectionTitle('Vaka')),
                    const SizedBox(height: 4),
                    const Text(
                      'Hazır senaryo seçebilir veya yeni bir rastgele vaka ile başlayabilirsin.',
                      style: TextStyle(
                        color: PratiCaseColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _ScenarioRandomTile(
                      selected: _scenario == null,
                      onTap: () => setState(() => _scenario = null),
                    ),
                    const SizedBox(height: 10),
                    for (final scenario in catalog.scenariosFor(_branch!.id))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ScenarioTile(
                          scenario: scenario,
                          selected: _scenario?.id == scenario.id,
                          onTap: () => setState(() => _scenario = scenario),
                        ),
                      ),
                  ],
                  const SizedBox(height: 20),
                  FadeSlideIn(child: _SectionTitle('Sınav Süresi')),
                  const SizedBox(height: 10),
                  _DurationPicker(
                    value: _durationMinutes,
                    onChanged: (value) =>
                        setState(() => _durationMinutes = value),
                  ),
                  const SizedBox(height: 20),
                  FadeSlideIn(child: _BranchDetailCard(branch: _branch)),
                ],
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: MediaQuery.paddingOf(context).bottom + 16,
                child: SafeArea(
                  top: false,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient:
                          _branch == null ||
                              _starting ||
                              (_format == OralExamFormat.solo &&
                                  _persona == null)
                          ? null
                          : PratiCaseGradients.action,
                      color:
                          _branch == null ||
                              _starting ||
                              (_format == OralExamFormat.solo &&
                                  _persona == null)
                          ? PratiCaseColors.border
                          : null,
                      borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
                      boxShadow:
                          _branch == null ||
                              _starting ||
                              (_format == OralExamFormat.solo &&
                                  _persona == null)
                          ? null
                          : [
                              BoxShadow(
                                color: PratiCaseColors.teal.withValues(
                                  alpha: 0.22,
                                ),
                                blurRadius: 22,
                                spreadRadius: -7,
                                offset: const Offset(0, 14),
                              ),
                            ],
                    ),
                    child: FilledButton.icon(
                      onPressed:
                          _branch == null ||
                              _starting ||
                              (_format == OralExamFormat.solo &&
                                  _persona == null)
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
                          : Icon(
                              _format == OralExamFormat.panel
                                  ? Icons.groups_2_rounded
                                  : Icons.record_voice_over_rounded,
                            ),
                      label: Text(
                        _starting
                            ? (_format == OralExamFormat.panel
                                  ? 'Komite hazırlanıyor...'
                                  : 'Hoca hazırlanıyor...')
                            : (_format == OralExamFormat.panel
                                  ? 'Komiteye Çık'
                                  : 'Sözlü Sınavı Başlat'),
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        backgroundColor: Colors.transparent,
                        disabledBackgroundColor: Colors.transparent,
                        foregroundColor: PratiCaseColors.white,
                        disabledForegroundColor: PratiCaseColors.muted,
                        shadowColor: Colors.transparent,
                        elevation: 0,
                      ),
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
  const _IntroCard({required this.format});
  final OralExamFormat format;

  @override
  Widget build(BuildContext context) {
    final isPanel = format == OralExamFormat.panel;
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
                child: Icon(
                  isPanel
                      ? Icons.groups_2_rounded
                      : Icons.record_voice_over_rounded,
                  color: PratiCaseColors.tealBright,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isPanel
                      ? 'Komite Önünde Sözlü Sınav'
                      : 'Sözlü Sınav Moderatörü',
                  style: const TextStyle(
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
          Text(
            isPanel
                ? 'Üç hoca karşında; cevapların klinik gerekçe, bilgi, tempo ve profesyonellik açısından ayrı ayrı değerlendirilir. '
                      'Karne sonunda her hocadan kısa ve resmi yorum alırsın.'
                : 'Moderatör vakayı sunar; cevabını gizli vaka hedefleriyle değerlendirip kısa takip sorusu sorar. '
                      'Klinik akıl yürütme, bilgi, iletişim, hız ve profesyonellik 100 puan üzerinden değerlendirilir. '
                      'Mikrofona izin verirsen cevaplarını sesli verebilirsin.',
            style: const TextStyle(
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

class _FormatPicker extends StatelessWidget {
  const _FormatPicker({required this.value, required this.onChanged});
  final OralExamFormat value;
  final ValueChanged<OralExamFormat> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _FormatOption(
            selected: value == OralExamFormat.solo,
            icon: Icons.record_voice_over_rounded,
            title: 'Tek Moderatör',
            subtitle:
                'Tek moderatör sınavı — kısa takip soruları ve resmi değerlendirme.',
            onTap: () => onChanged(OralExamFormat.solo),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _FormatOption(
            selected: value == OralExamFormat.panel,
            icon: Icons.groups_2_rounded,
            title: 'Komite (3 Hoca)',
            subtitle:
                'Komite sınavı — üç hocadan kısa soru ve ayrı karne yorumu.',
            badge: 'YENİ',
            onTap: () => onChanged(OralExamFormat.panel),
          ),
        ),
      ],
    );
  }
}

class _FormatOption extends StatelessWidget {
  const _FormatOption({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: PratiCaseDurations.fast,
        padding: const EdgeInsets.all(14),
        constraints: const BoxConstraints(minHeight: 138),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: PratiCaseColors.teal.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: PratiCaseColors.teal, size: 20),
                ),
                const Spacer(),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: PratiCaseColors.gold.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        color: PratiCaseColors.gold,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                color: PratiCaseColors.navy,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: PratiCaseColors.muted,
                fontSize: 11,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommitteePreview extends StatelessWidget {
  const _CommitteePreview({required this.personas});
  final List<OralExamPersona> personas;

  @override
  Widget build(BuildContext context) {
    final ordered = [...personas]
      ..sort((a, b) {
        const order = {'lead': 0, 'second': 1, 'observer': 2};
        return (order[a.panelRole] ?? 9).compareTo(order[b.panelRole] ?? 9);
      });
    return ClinicalCard(
      color: PratiCaseColors.navy,
      borderColor: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.groups_2_rounded, color: PratiCaseColors.tealBright),
              SizedBox(width: 6),
              Text(
                'Karşındaki Komite',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < ordered.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: PratiCaseColors.tealBright.withValues(
                    alpha: 0.20,
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: PratiCaseColors.tealBright,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              ordered[i].title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          _PanelRoleChip(role: ordered[i].panelRole),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ordered[i].description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 11.5,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (i != ordered.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _PanelRoleChip extends StatelessWidget {
  const _PanelRoleChip({required this.role});
  final String role;

  String get _label {
    switch (role) {
      case 'lead':
        return 'BAŞKAN';
      case 'second':
        return 'YARDIMCI';
      case 'observer':
        return 'GÖZLEMCİ';
      default:
        return role.toUpperCase();
    }
  }

  Color get _color {
    switch (role) {
      case 'lead':
        return PratiCaseColors.errorRed;
      case 'second':
        return PratiCaseColors.gold;
      case 'observer':
        return PratiCaseColors.successGreen;
      default:
        return PratiCaseColors.teal;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _label,
        style: TextStyle(
          color: _color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
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
                    _examSafePersonaDescription(persona),
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

class _ScenarioRandomTile extends StatelessWidget {
  const _ScenarioRandomTile({required this.selected, required this.onTap});
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: PratiCaseDurations.fast,
        padding: const EdgeInsets.all(14),
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
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: PratiCaseColors.teal.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.shuffle_rounded,
                color: PratiCaseColors.teal,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rastgele Vaka',
                    style: TextStyle(
                      color: PratiCaseColors.navy,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Moderatör branş bilgisiyle her seferinde özgün bir vaka üretir.',
                    style: TextStyle(
                      color: PratiCaseColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                color: PratiCaseColors.teal,
              ),
          ],
        ),
      ),
    );
  }
}

class _ScenarioTile extends StatelessWidget {
  const _ScenarioTile({
    required this.scenario,
    required this.selected,
    required this.onTap,
  });

  final OralExamScenario scenario;
  final bool selected;
  final VoidCallback onTap;

  Color get _accent {
    switch (scenario.difficultyFloor) {
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
        padding: const EdgeInsets.all(14),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.assignment_ind_rounded,
                    color: _accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    scenario.title,
                    style: const TextStyle(
                      color: PratiCaseColors.navy,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    scenario.difficultyFloor,
                    style: TextStyle(
                      color: _accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.check_circle_rounded,
                    color: PratiCaseColors.teal,
                    size: 20,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Vaka brifi sınav başladığında açılır. Bu ekranda yalnız konu ve zorluk seçilir.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: PratiCaseColors.slateBlue,
                fontSize: 12.5,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _examSafePersonaDescription(OralExamPersona persona) {
  switch (persona.id) {
    case 'patient_assistant':
      return 'Sakin sınav dili; kısa takip soruları ve resmi değerlendirme.';
    case 'socratic_associate':
      return 'Gerekçeni sınayan kısa sorular; ideal cevabı açıklamadan ilerler.';
    case 'stern_professor':
      return 'Daha zor tempo; kısa, doğrudan ve resmi sınav soruları.';
    default:
      return persona.description
          .replaceAll('ipucu verir', 'resmi takip soruları sorar')
          .replaceAll(
            'Yanlış cevap = sert takip.',
            'Yanlış cevap karneye yansır.',
          )
          .replaceAll('Sokratik', 'Gerekçe odaklı');
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
  late String _activePersonaId;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.session.durationSeconds;
    _activePersonaId = widget.session.activePersonaId.isNotEmpty
        ? widget.session.activePersonaId
        : widget.session.personaId;
    _voiceAdapter =
        widget.voiceAdapter ??
        NativeVoiceExamAdapter(voiceRole: VoiceSpeechRole.mentor);
    _voiceState = _voiceAdapter.state;
    _voiceSubscription = _voiceAdapter.states.listen((state) {
      if (!mounted) return;
      setState(() => _voiceState = state);
    });
    final opener = widget.session.personaById(_activePersonaId);
    _messages.add(
      OralExamMessage(
        speaker: 'mentor',
        message: widget.session.openingMessage,
        personaId: _activePersonaId,
        personaTitle: opener?.title ?? widget.session.personaTitle,
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

  void _showFailure(String message, {VoidCallback? onRetry}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        action: onRetry == null
            ? null
            : SnackBarAction(label: 'Tekrar Dene', onPressed: onRetry),
      ),
    );
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending || _finalizing) return;
    FocusManager.instance.primaryFocus?.unfocus();
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
      final mentorMessages = response.mentorMessages.isEmpty
          ? [
              OralExamMessage(
                speaker: 'mentor',
                message: response.mentorMessage,
                isFollowup: response.isFollowup,
                personaId: response.activePersonaId,
                personaTitle: response.activePersonaTitle,
              ),
            ]
          : response.mentorMessages;
      setState(() {
        _activePersonaId = response.activePersonaId.isNotEmpty
            ? response.activePersonaId
            : _activePersonaId;
        _messages.addAll(mentorMessages);
        if (response.remainingSeconds > 0) {
          _remainingSeconds = response.remainingSeconds;
        }
      });
      unawaited(PratiCaseHaptics.selection());
      unawaited(_speakMentorMessages(mentorMessages));
      unawaited(_scrollToBottom());
      if (response.shouldEnd) {
        await _finalize();
      }
    } on OralExamUnavailable catch (error) {
      if (!mounted) return;
      _showFailure(PratiCaseUserMessage.oralExam(error.message));
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
      final mentors = await widget.repository.skipQuestion(widget.session.id);
      if (!mounted) return;
      setState(() {
        _messages.addAll(mentors);
        if (mentors.isNotEmpty && mentors.last.personaId.isNotEmpty) {
          _activePersonaId = mentors.last.personaId;
        }
      });
      unawaited(_speakMentorMessages(mentors));
      unawaited(_scrollToBottom());
    } on OralExamUnavailable catch (error) {
      if (!mounted) return;
      _showFailure(PratiCaseUserMessage.oralExam(error.message));
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
            repository: widget.repository,
            result: result,
            session: widget.session,
          ),
        ),
      );
    } on OralExamUnavailable catch (error) {
      if (!mounted) return;
      setState(() => _finalizing = false);
      _showFailure(
        PratiCaseUserMessage.report(error.message),
        onRetry: _finalize,
      );
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

  Future<void> _speakMentorMessages(List<OralExamMessage> messages) async {
    if (!_voiceMode || _voiceState.muted || messages.isEmpty) return;
    final transcript = messages
        .where((message) => message.message.isNotEmpty)
        .map(
          (message) => message.personaTitle.isEmpty
              ? message.message
              : '${message.personaTitle}: ${message.message}',
        )
        .join(' ');
    if (transcript.isNotEmpty) await _voiceAdapter.speak(transcript);
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
          'Şu ana kadar verdiğin cevaplar değerlendirilip karnen hazırlanacak.',
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
          title: const Text('Sözlü Sınav Odası'),
          centerTitle: true,
          backgroundColor: PratiCaseColors.softSurface,
          scrolledUnderElevation: 0,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _timerColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _timerColor.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.timer_outlined, size: 16, color: _timerColor),
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
            widget.session.format == OralExamFormat.panel &&
                    widget.session.panel.length >= 2
                ? _PanelBanner(
                    panel: widget.session.panel,
                    activePersonaId: _activePersonaId,
                    caseBrief: widget.session.caseBrief,
                    voiceMode: _voiceMode,
                    onToggleVoice: _toggleVoiceMode,
                  )
                : _MentorBanner(
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
                  final msg = _messages[index];
                  return FadeSlideIn(
                    key: ValueKey('msg_$index'),
                    offset: Offset(
                      msg.speaker == 'candidate' ? 0.04 : -0.04,
                      0,
                    ),
                    child: _ExamBubble(message: msg),
                  );
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

class _PanelBanner extends StatelessWidget {
  const _PanelBanner({
    required this.panel,
    required this.activePersonaId,
    required this.caseBrief,
    required this.voiceMode,
    required this.onToggleVoice,
  });

  final List<OralExamPersona> panel;
  final String activePersonaId;
  final String caseBrief;
  final bool voiceMode;
  final VoidCallback onToggleVoice;

  @override
  Widget build(BuildContext context) {
    final ordered = [...panel]
      ..sort((a, b) {
        const order = {'lead': 0, 'second': 1, 'observer': 2};
        return (order[a.panelRole] ?? 9).compareTo(order[b.panelRole] ?? 9);
      });
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 12),
      decoration: const BoxDecoration(color: PratiCaseColors.navy),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: PratiCaseColors.tealBright.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Text(
                  'KOMİTE',
                  style: TextStyle(
                    color: PratiCaseColors.tealBright,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: onToggleVoice,
                icon: Icon(
                  voiceMode
                      ? Icons.volume_up_rounded
                      : Icons.volume_off_rounded,
                  color: voiceMode
                      ? PratiCaseColors.tealBright
                      : Colors.white.withValues(alpha: 0.7),
                ),
                tooltip: voiceMode ? 'Sesli mod açık' : 'Sesli mod kapalı',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Komite birlikte değerlendirir; yanıtını aktif hocaya ver.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < ordered.length; i++) ...[
                Expanded(
                  child: _PanelistAvatar(
                    persona: ordered[i],
                    active: ordered[i].id == activePersonaId,
                  ),
                ),
                if (i != ordered.length - 1) const SizedBox(width: 6),
              ],
            ],
          ),
          if (caseBrief.isNotEmpty) ...[
            const SizedBox(height: 10),
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

class _PanelistAvatar extends StatelessWidget {
  const _PanelistAvatar({required this.persona, required this.active});
  final OralExamPersona persona;
  final bool active;

  Color get _accent {
    switch (persona.panelRole) {
      case 'lead':
        return PratiCaseColors.errorRed;
      case 'second':
        return PratiCaseColors.gold;
      case 'observer':
        return PratiCaseColors.successGreen;
      default:
        return PratiCaseColors.teal;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: PratiCaseDurations.standard,
      curve: PratiCaseCurves.standard,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: active
            ? PratiCaseColors.tealBright.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active
              ? PratiCaseColors.tealBright
              : Colors.white.withValues(alpha: 0.06),
          width: active ? 1.4 : 0.5,
        ),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: active
                    ? PratiCaseColors.tealBright.withValues(alpha: 0.30)
                    : Colors.white.withValues(alpha: 0.10),
                child: Icon(
                  Icons.person_rounded,
                  color: active
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.66),
                  size: 22,
                ),
              ),
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: PratiCaseColors.navy, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            persona.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.7),
              fontSize: 10.5,
              fontWeight: active ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
          if (active) ...[
            const SizedBox(height: 2),
            const Text(
              'SORU SORUYOR',
              style: TextStyle(
                color: PratiCaseColors.tealBright,
                fontSize: 7,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ],
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
      decoration: const BoxDecoration(color: PratiCaseColors.navy),
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
                  voiceMode
                      ? Icons.volume_up_rounded
                      : Icons.volume_off_rounded,
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
        mainAxisAlignment: mentor
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
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
                    color: mentor ? PratiCaseColors.border : Colors.transparent,
                  ),
                  boxShadow: mentor ? PratiCaseShadows.card : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (mentor && message.personaTitle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              message.personaTitle,
                              style: const TextStyle(
                                color: PratiCaseColors.teal,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.2,
                              ),
                            ),
                            if (message.isFollowup) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: PratiCaseColors.gold.withValues(
                                    alpha: 0.18,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'TAKİP',
                                  style: TextStyle(
                                    color: PratiCaseColors.gold,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                    else if (message.isFollowup && mentor)
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
            child: const SizedBox(width: 24, height: 8, child: _TypingDots()),
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
          border: Border(top: BorderSide(color: PratiCaseColors.border)),
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
                        listening ? Icons.mic_rounded : Icons.mic_none_rounded,
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
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(PratiCaseRadius.xl),
                        borderSide: const BorderSide(
                          color: PratiCaseColors.border,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(PratiCaseRadius.xl),
                        borderSide: const BorderSide(
                          color: PratiCaseColors.border,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(PratiCaseRadius.xl),
                        borderSide: const BorderSide(
                          color: PratiCaseColors.teal,
                          width: 1.5,
                        ),
                      ),
                    ),
                    onSubmitted: (_) => onSend(),
                  ),
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) => PressableScale(
                    onTap: disabled || value.text.trim().isEmpty
                        ? null
                        : () => onSend(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: value.text.trim().isEmpty
                            ? PratiCaseColors.teal.withValues(alpha: 0.45)
                            : PratiCaseColors.teal,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                      ),
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
                    label: const Text('Pas Geç'),
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
                      finalizing ? 'Karne hazırlanıyor...' : 'Sınavı Bitir',
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
    required this.repository,
    required this.result,
    required this.session,
    super.key,
  });

  final OralExamRepository repository;
  final OralExamResult result;
  final OralExamSession session;

  @override
  State<OralExamResultScreen> createState() => _OralExamResultScreenState();
}

class _OralExamResultScreenState extends State<OralExamResultScreen> {
  bool _animated = false;
  bool _retrying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _animated = true);
      PratiCaseHaptics.success();
    });
  }

  Future<void> _restartExam() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      final session = await widget.repository.startSession(
        personaId: widget.session.personaId.isNotEmpty
            ? widget.session.personaId
            : 'stern_professor',
        branchId: widget.session.branchId,
        durationSeconds: widget.session.durationSeconds,
        format: widget.session.format,
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(PratiCaseUserMessage.oralExam(error.message))),
      );
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
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
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.18,
                                ),
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
                    widget.session.format.isPanel
                        ? 'KOMİSYON KURULU'
                        : widget.session.personaTitle.toUpperCase(),
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
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: scoreColor.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
                      border: Border.all(
                        color: scoreColor.withValues(alpha: 0.55),
                      ),
                    ),
                    child: Text(
                      r.scoreLevelLabel,
                      style: TextStyle(
                        color: scoreColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FadeSlideIn(
            delay: const Duration(milliseconds: 80),
            child: _RubricGrid(
              result: r,
              personaTitle: widget.session.personaTitle,
              isPanel: widget.session.format.isPanel,
            ),
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
                      children: [
                        const Icon(
                          Icons.format_quote_rounded,
                          color: PratiCaseColors.teal,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          r.format == OralExamFormat.panel
                              ? 'Komite Kararı'
                              : 'Moderatör Yorumu',
                          style: const TextStyle(
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
          if (r.format == OralExamFormat.panel &&
              r.panelVerdicts.isNotEmpty) ...[
            const SizedBox(height: 14),
            FadeSlideIn(
              delay: const Duration(milliseconds: 180),
              child: _PanelVerdictsCard(
                verdicts: r.panelVerdicts,
                panel: widget.session.panel,
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
          if (r.criticalErrors.isNotEmpty) ...[
            const SizedBox(height: 14),
            FadeSlideIn(
              delay: const Duration(milliseconds: 220),
              child: _FeedbackBlock(
                title: 'Kritik Hatalar',
                color: const Color(0xFFB91C1C),
                icon: Icons.warning_amber_rounded,
                items: r.criticalErrors,
              ),
            ),
          ],
          if (r.idealApproach.isNotEmpty) ...[
            const SizedBox(height: 14),
            FadeSlideIn(
              delay: const Duration(milliseconds: 260),
              child: ClinicalCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          color: PratiCaseColors.teal,
                          size: 18,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'İdeal Yaklaşım Özeti',
                          style: TextStyle(
                            color: PratiCaseColors.navy,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      r.idealApproach,
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
          if (r.nextAttemptPlan.isNotEmpty) ...[
            const SizedBox(height: 14),
            FadeSlideIn(
              delay: const Duration(milliseconds: 300),
              child: _FeedbackBlock(
                title: 'Bir Sonraki Deneme Planı',
                color: PratiCaseColors.teal,
                icon: Icons.flag_rounded,
                items: r.nextAttemptPlan,
              ),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _retrying ? null : _restartExam,
            icon: _retrying
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.replay_rounded),
            label: const Text('Tekrar Sözlü'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _retrying
                ? null
                : () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
            icon: const Icon(Icons.home_rounded),
            label: const Text('Ana Sayfaya Dön'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelVerdictsCard extends StatelessWidget {
  const _PanelVerdictsCard({required this.verdicts, required this.panel});

  final List<OralExamPanelVerdict> verdicts;
  final List<OralExamPersona> panel;

  Color _verdictColor(String verdict) {
    final lower = verdict.toLowerCase();
    if (lower.contains('geçer') || lower.contains('başarı')) {
      return PratiCaseColors.successGreen;
    }
    if (lower.contains('sınır')) return PratiCaseColors.gold;
    if (lower.contains('kal')) return PratiCaseColors.errorRed;
    return PratiCaseColors.teal;
  }

  String _personaTitle(String id) {
    for (final p in panel) {
      if (p.id == id) return p.title;
    }
    return id;
  }

  String _personaRole(String id) {
    for (final p in panel) {
      if (p.id == id) return p.panelRole;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return ClinicalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.groups_2_rounded, color: PratiCaseColors.teal),
              SizedBox(width: 6),
              Text(
                'Hocaların Notları',
                style: TextStyle(
                  color: PratiCaseColors.navy,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < verdicts.length; i++) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PratiCaseColors.softSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: PratiCaseColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: PratiCaseColors.teal.withValues(
                          alpha: 0.16,
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          color: PratiCaseColors.teal,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _personaTitle(verdicts[i].personaId),
                              style: const TextStyle(
                                color: PratiCaseColors.navy,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                            if (_personaRole(verdicts[i].personaId).isNotEmpty)
                              _PanelRoleChip(
                                role: _personaRole(verdicts[i].personaId),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _verdictColor(
                            verdicts[i].verdict,
                          ).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          verdicts[i].verdict.toUpperCase(),
                          style: TextStyle(
                            color: _verdictColor(verdicts[i].verdict),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (verdicts[i].note.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      verdicts[i].note,
                      style: const TextStyle(
                        color: PratiCaseColors.slateBlue,
                        fontSize: 12.5,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (i != verdicts.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _RubricGrid extends StatelessWidget {
  const _RubricGrid({
    required this.result,
    required this.personaTitle,
    required this.isPanel,
  });
  final OralExamResult result;
  final String personaTitle;
  final bool isPanel;

  String get _sectionHeader {
    if (isPanel) return 'Komisyon Değerlendirme Puanları';
    final t = personaTitle.toLowerCase();
    if (t.contains('sert') || t.contains('stern')) {
      return 'Kritik Performans Değerlendirmesi';
    }
    if (t.contains('sokratik') || t.contains('socratic')) {
      return 'Akıl Yürütme Zinciri Analizi';
    }
    if (t.contains('sabırlı') || t.contains('patient')) {
      return 'Cevap Yapılandırma Değerlendirmesi';
    }
    return 'Puan Dağılımı';
  }

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _sectionHeader,
            style: const TextStyle(
              color: PratiCaseColors.navy,
              fontWeight: FontWeight.w900,
              fontSize: 13,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 12),
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
