import 'package:flutter/material.dart';

import '../../../app/theme/praticase_colors.dart';

class PratiCaseShell extends StatefulWidget {
  const PratiCaseShell({super.key});

  @override
  State<PratiCaseShell> createState() => _PratiCaseShellState();
}

class _PratiCaseShellState extends State<PratiCaseShell> {
  int _selectedIndex = 0;

  static const _pages = <_ShellPage>[
    _ShellPage(
      title: 'Ana Sayfa',
      icon: Icons.home_rounded,
      headline: 'Bugünün OSCE istasyonu hazır',
      body:
          'Sanal hasta, süreli istasyon ve rubrik karnesi için PratiCase temeli kuruldu.',
      action: 'Hızlı başlat',
    ),
    _ShellPage(
      title: 'Vakalar',
      icon: Icons.assignment_rounded,
      headline: 'Vaka kütüphanesi',
      body:
          'Kadın doğum, üroloji ve genel cerrahi istasyonları için model alanı ayrıldı.',
      action: 'Vakaları gör',
    ),
    _ShellPage(
      title: 'Sınavlar',
      icon: Icons.timer_rounded,
      headline: 'Süreli sınav odası',
      body:
          'Tek istasyon, mini OSCE ve zayıf konulardan sınav akışları burada yaşayacak.',
      action: 'Sınav planla',
    ),
    _ShellPage(
      title: 'Gelişim',
      icon: Icons.trending_up_rounded,
      headline: 'Performans karnesi',
      body:
          'Anamnez, muayene, tetkik, tanı ve yönetim skorları için gelişim zemini hazır.',
      action: 'Gelişimi incele',
    ),
    _ShellPage(
      title: 'Profil',
      icon: Icons.person_rounded,
      headline: 'Profil ve hedefler',
      body:
          'Auth planı geldiğinde kullanıcı hedefleri ve Medasi hesabı bağlantısı buraya eklenecek.',
      action: 'Profil kurulumu',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final page = _pages[_selectedIndex];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/branding/praticase.png',
                width: 36,
                height: 36,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            const Text('PratiCase'),
          ],
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            _HeroPanel(page: page),
            const SizedBox(height: 16),
            const _StatusGrid(),
            const SizedBox(height: 16),
            const _AuthNotice(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() => _selectedIndex = index);
          },
          destinations: [
            for (final item in _pages)
              NavigationDestination(icon: Icon(item.icon), label: item.title),
          ],
        ),
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.page});

  final _ShellPage page;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: PratiCaseColors.teal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Text(
                  'OSCE pratik platformu',
                  style: textTheme.labelLarge?.copyWith(
                    color: PratiCaseColors.teal,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(page.headline, style: textTheme.headlineMedium),
            const SizedBox(height: 10),
            Text(page.body, style: textTheme.bodyMedium),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(page.action),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusGrid extends StatelessWidget {
  const _StatusGrid();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 680;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isWide ? 3 : 1,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: isWide ? 1.55 : 3.2,
          children: const [
            _StatusCard(
              icon: Icons.verified_user_rounded,
              title: 'Bağımsız ürün',
              body: 'Qlinik ve SourceBase akışlarına dokunmadan ayrı gelişir.',
            ),
            _StatusCard(
              icon: Icons.storage_rounded,
              title: 'Ortak veri zemini',
              body: 'Medasi hesabı ve Supabase entegrasyonu için hazır kapı.',
            ),
            _StatusCard(
              icon: Icons.terminal_rounded,
              title: 'Docker hazır',
              body: 'Flutter web build çıktısı nginx ile servis edilecek.',
            ),
          ],
        );
      },
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    body,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall,
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

class _AuthNotice extends StatelessWidget {
  const _AuthNotice();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lock_outline_rounded, color: PratiCaseColors.gold),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Auth akışı, gelecek plan dosyasına göre ayrı feature altında kurulacak.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShellPage {
  const _ShellPage({
    required this.title,
    required this.icon,
    required this.headline,
    required this.body,
    required this.action,
  });

  final String title;
  final IconData icon;
  final String headline;
  final String body;
  final String action;
}
