import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/praticase_colors.dart';

const _pratiBlue = Color(0xFF1D67D2);
const _pratiBlueLight = Color(0xFF56A4F4);
const _pratiIndigo = Color(0xFF244AC4);
const _pratiViolet = Color(0xFF744AF0);
const _authPanelStart = Color(0xFFF4FAFF);
const _authPanelEnd = Color(0xFFEAF4FF);
const _authInputBorder = Color(0xFFC7DCF3);
const _authTextBlue = Color(0xFF3E5E86);

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.child,
    this.onBack,
    this.bottom,
    this.showFooterText = true,
    this.topPadding = 22,
    this.bottomPadding = 28,
    super.key,
  });

  final Widget child;
  final VoidCallback? onBack;
  final Widget? bottom;
  final bool showFooterText;
  final double topPadding;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: _authPanelStart,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final useWideLayout =
              constraints.maxWidth >= 1024 && constraints.maxHeight >= 620;
          return DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_authPanelStart, _authPanelEnd],
              ),
            ),
            child: useWideLayout
                ? _AuthWideLayout(
                    bottom: bottom,
                    bottomPadding: bottomPadding,
                    onBack: onBack,
                    showFooterText: showFooterText,
                    topPadding: topPadding,
                    child: child,
                  )
                : _AuthCompactLayout(
                    bottom: bottom,
                    bottomPadding: bottomPadding,
                    onBack: onBack,
                    showFooterText: showFooterText,
                    topPadding: topPadding,
                    child: child,
                  ),
          );
        },
      ),
    );
  }
}

class AuthCard extends StatelessWidget {
  const AuthCard({
    required this.children,
    this.padding,
    this.maxWidth = 430,
    super.key,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 340;
          final radius = isNarrow ? 18.0 : 22.0;
          final effectivePadding =
              padding ??
              EdgeInsets.fromLTRB(
                isNarrow ? 20 : 28,
                isNarrow ? 26 : 30,
                isNarrow ? 20 : 28,
                isNarrow ? 24 : 28,
              );

          return DecoratedBox(
            decoration: BoxDecoration(
              color: PratiCaseColors.white,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: _authInputBorder.withValues(alpha: 0.72),
              ),
              boxShadow: [
                BoxShadow(
                  color: _pratiBlue.withValues(alpha: 0.12),
                  blurRadius: isNarrow ? 30 : 40,
                  spreadRadius: -16,
                  offset: Offset(0, isNarrow ? 18 : 22),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: Stack(
                children: [
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_pratiBlue, _pratiBlueLight],
                        ),
                      ),
                      child: SizedBox(height: 4),
                    ),
                  ),
                  Padding(
                    padding: effectivePadding,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: children,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class AuthScreenHeader extends StatelessWidget {
  const AuthScreenHeader({
    required this.title,
    required this.subtitle,
    this.center = false,
    super.key,
  });

  final String title;
  final String subtitle;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 320;
        return Column(
          crossAxisAlignment: center
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            Text(
              title,
              textAlign: center ? TextAlign.center : TextAlign.start,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: PratiCaseColors.navy,
                fontSize: isNarrow ? 22 : 24,
                fontWeight: FontWeight.w900,
                height: 1.14,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: center ? TextAlign.center : TextAlign.start,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: _authTextBlue,
                fontSize: isNarrow ? 13.5 : 14,
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
          ],
        );
      },
    );
  }
}

class AuthEcosystemCallout extends StatelessWidget {
  const AuthEcosystemCallout({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 300;
        final iconSize = isNarrow ? 36.0 : 42.0;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _authPanelEnd.withValues(alpha: 0.94),
                PratiCaseColors.white.withValues(alpha: 0.84),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _authInputBorder),
          ),
          child: Padding(
            padding: EdgeInsets.all(isNarrow ? 14 : 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    color: PratiCaseColors.white,
                    borderRadius: BorderRadius.circular(isNarrow ? 12 : 14),
                    boxShadow: [
                      BoxShadow(
                        color: _pratiBlue.withValues(alpha: 0.12),
                        blurRadius: 16,
                        spreadRadius: -8,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(isNarrow ? 6 : 7),
                    child: Image.asset('assets/auth/praticase_icon.png'),
                  ),
                ),
                SizedBox(width: isNarrow ? 10 : 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '✣ MEDASI AILESINE HOŞ GELDINIZ',
                        style: TextStyle(
                          color: _pratiBlue,
                          fontSize: isNarrow ? 10 : 11,
                          fontWeight: FontWeight.w900,
                          height: 1.25,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: 'Tek hesabınızla '),
                            _brandSpan('Qlinik', PratiCaseColors.teal),
                            const TextSpan(text: ', '),
                            _brandSpan('PratiCase', _pratiBlue),
                            const TextSpan(text: ' ve '),
                            _brandSpan('SourceBase', const Color(0xFF006FB6)),
                            const TextSpan(
                              text:
                                  '\'in tamamına saniyeler içinde ulaşırsınız.',
                            ),
                          ],
                        ),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _authTextBlue,
                          fontSize: isNarrow ? 12.5 : 13,
                          fontWeight: FontWeight.w600,
                          height: 1.55,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static TextSpan _brandSpan(String text, Color color) {
    return TextSpan(
      text: text,
      style: TextStyle(color: color, fontWeight: FontWeight.w900),
    );
  }
}

class AuthDivider extends StatelessWidget {
  const AuthDivider({this.label = 'veya', super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: _authInputBorder, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13),
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8AA7C7),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const Expanded(child: Divider(color: _authInputBorder, height: 1)),
      ],
    );
  }
}

class AuthLegalFooter extends StatelessWidget {
  const AuthLegalFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 320;
        return Text.rich(
          TextSpan(
            children: const [
              TextSpan(text: 'Giriş yaparak '),
              TextSpan(
                text: 'Kullanım Koşulları',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              TextSpan(text: ' ve '),
              TextSpan(
                text: 'Gizlilik Politikası',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              TextSpan(text: '\'nı kabul etmiş olursunuz.\n\n'),
              TextSpan(text: '© 2026 MedAsi Ekosistemi'),
            ],
          ),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: _authTextBlue.withValues(alpha: 0.74),
            fontSize: isNarrow ? 10.5 : 11,
            fontWeight: FontWeight.w600,
            height: 1.42,
          ),
        );
      },
    );
  }
}

class _AuthWideLayout extends StatelessWidget {
  const _AuthWideLayout({
    required this.child,
    required this.showFooterText,
    required this.topPadding,
    required this.bottomPadding,
    this.onBack,
    this.bottom,
  });

  final Widget child;
  final VoidCallback? onBack;
  final Widget? bottom;
  final bool showFooterText;
  final double topPadding;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(flex: 7, child: _AuthHeroPanel()),
        Expanded(
          flex: 3,
          child: _AuthFormPanel(
            bottom: bottom,
            bottomPadding: bottomPadding,
            onBack: onBack,
            showFooterText: showFooterText,
            topPadding: topPadding,
            child: child,
          ),
        ),
      ],
    );
  }
}

class _AuthCompactLayout extends StatelessWidget {
  const _AuthCompactLayout({
    required this.child,
    required this.showFooterText,
    required this.topPadding,
    required this.bottomPadding,
    this.onBack,
    this.bottom,
  });

  final Widget child;
  final VoidCallback? onBack;
  final Widget? bottom;
  final bool showFooterText;
  final double topPadding;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(painter: _AuthSoftBackdropPainter()),
        ),
        SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: _AuthFormPanel(
                bottom: bottom,
                bottomPadding: bottomPadding,
                onBack: onBack,
                showFooterText: showFooterText,
                topPadding: topPadding,
                child: child,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AuthFormPanel extends StatelessWidget {
  const _AuthFormPanel({
    required this.child,
    required this.showFooterText,
    required this.topPadding,
    required this.bottomPadding,
    this.onBack,
    this.bottom,
  });

  final Widget child;
  final VoidCallback? onBack;
  final Widget? bottom;
  final bool showFooterText;
  final double topPadding;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final horizontalPadding = viewportWidth < 340
        ? 12.0
        : viewportWidth < 390
        ? 16.0
        : 20.0;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _authPanelStart.withValues(alpha: 0.96),
            _authPanelEnd.withValues(alpha: 0.96),
          ],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compactHeight = constraints.maxHeight < 700;
          final effectiveTopPadding = compactHeight
              ? math.min(topPadding, 14.0)
              : topPadding;
          final effectiveBottomPadding = compactHeight
              ? math.max(bottomPadding, 22.0)
              : bottomPadding;
          final minHeight = math.max(
            0.0,
            constraints.maxHeight -
                effectiveTopPadding -
                effectiveBottomPadding,
          );

          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              effectiveTopPadding,
              horizontalPadding,
              effectiveBottomPadding,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (onBack != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _AuthBackButton(onBack: onBack),
                    ),
                  if (onBack != null) SizedBox(height: compactHeight ? 8 : 12),
                  const _MedasiPratiCaseLockup(),
                  SizedBox(height: compactHeight ? 10 : 16),
                  const Center(child: _EcosystemBadge()),
                  SizedBox(height: compactHeight ? 20 : 30),
                  child,
                  if (bottom != null) ...[
                    SizedBox(height: compactHeight ? 14 : 18),
                    bottom!,
                  ],
                  if (showFooterText) ...[
                    SizedBox(height: compactHeight ? 20 : 28),
                    const AuthLegalFooter(),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AuthBackButton extends StatelessWidget {
  const _AuthBackButton({required this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PratiCaseColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _authInputBorder),
        boxShadow: [
          BoxShadow(
            color: _pratiBlue.withValues(alpha: 0.10),
            blurRadius: 18,
            spreadRadius: -8,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: IconButton(
        onPressed: onBack,
        icon: const Icon(
          Icons.arrow_back_rounded,
          color: PratiCaseColors.navy,
          size: 22,
        ),
      ),
    );
  }
}

class _MedasiPratiCaseLockup extends StatelessWidget {
  const _MedasiPratiCaseLockup();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const _LogoColumn(label: 'MEDASI', child: _MedasiMark()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: [
                Text(
                  '×',
                  style: TextStyle(
                    color: _authTextBlue.withValues(alpha: 0.54),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Container(width: 1, height: 28, color: _authInputBorder),
              ],
            ),
          ),
          _LogoColumn(
            label: 'PRATICASE',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Image.asset(
                'assets/auth/praticase_icon.png',
                width: 42,
                height: 42,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoColumn extends StatelessWidget {
  const _LogoColumn({required this.child, required this.label});

  final Widget child;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        child,
        const SizedBox(height: 7),
        Text(
          label,
          style: const TextStyle(
            color: _pratiBlue,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _MedasiMark extends StatelessWidget {
  const _MedasiMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 42,
      decoration: BoxDecoration(
        color: PratiCaseColors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: _pratiBlue.withValues(alpha: 0.11),
            blurRadius: 18,
            spreadRadius: -9,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: Image.asset(
          'assets/auth/medasi_company_logo.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _EcosystemBadge extends StatelessWidget {
  const _EcosystemBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _authPanelEnd,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _authInputBorder),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(radius: 4, backgroundColor: _pratiBlue),
            SizedBox(width: 6),
            Text(
              'MedAsi Ekosistemi',
              style: TextStyle(
                color: _pratiBlue,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthHeroPanel extends StatelessWidget {
  const _AuthHeroPanel();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compactHeight = constraints.maxHeight < 1120;
        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_pratiIndigo, _pratiBlue, _pratiViolet],
              stops: [0.0, 0.54, 1.0],
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _AuthHeroPainter())),
              Positioned(
                left: 64,
                top: compactHeight ? 72 : 108,
                child: Container(
                  width: 36,
                  height: 36,
                  color: PratiCaseColors.white.withValues(alpha: 0.92),
                ),
              ),
              Positioned(
                left: 64,
                top: compactHeight ? 238 : 352,
                child: _HeroLogoCard(),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  64,
                  compactHeight ? 352 : 470,
                  64,
                  compactHeight ? 40 : 64,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '✣ MEDASI EKOSISTEMI',
                      style: TextStyle(
                        color: PratiCaseColors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Tek hesap,\ntıbbın üç gücü.',
                      style: TextStyle(
                        color: PratiCaseColors.white,
                        fontSize: 44,
                        height: 1.08,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 18),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: Text(
                        'Gerçekçi vaka senaryoları ile klinik karar verme becerinizi güvenli ortamda pratik edin.',
                        style: TextStyle(
                          color: PratiCaseColors.white.withValues(alpha: 0.86),
                          fontSize: 17,
                          height: 1.45,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _HeroFeature(
                          icon: Icons.verified_user_outlined,
                          label: 'Güvenli',
                        ),
                        _HeroFeature(
                          icon: Icons.bolt_rounded,
                          label: 'Hızlı erişim',
                        ),
                        _HeroFeature(
                          icon: Icons.favorite_border_rounded,
                          label: 'Hekim odaklı',
                        ),
                      ],
                    ),
                    if (!compactHeight) ...[
                      const Spacer(),
                      const _HeroFamilyCard(),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeroLogoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PratiCaseColors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: PratiCaseColors.white.withValues(alpha: 0.34),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Container(
          width: 66,
          height: 66,
          decoration: BoxDecoration(
            color: PratiCaseColors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Image.asset('assets/auth/praticase_icon.png'),
          ),
        ),
      ),
    );
  }
}

class _HeroFeature extends StatelessWidget {
  const _HeroFeature({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 152,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PratiCaseColors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: PratiCaseColors.white.withValues(alpha: 0.20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: PratiCaseColors.white, size: 18),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              color: PratiCaseColors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroFamilyCard extends StatelessWidget {
  const _HeroFamilyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PratiCaseColors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: PratiCaseColors.white.withValues(alpha: 0.18),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AILENIZ',
            style: TextStyle(
              color: PratiCaseColors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          SizedBox(height: 12),
          _HeroFamilyRow(letter: 'Q', label: 'Qlinik'),
          _HeroFamilyRow(letter: 'P', label: 'PratiCase'),
          _HeroFamilyRow(letter: 'S', label: 'SourceBase'),
        ],
      ),
    );
  }
}

class _HeroFamilyRow extends StatelessWidget {
  const _HeroFamilyRow({required this.letter, required this.label});

  final String letter;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: PratiCaseColors.white,
            child: Text(
              letter,
              style: const TextStyle(
                color: _pratiBlue,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              color: PratiCaseColors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthSoftBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final topGlow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              _pratiBlueLight.withValues(alpha: 0.18),
              _pratiBlueLight.withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.78, size.height * 0.05),
              radius: size.width * 0.72,
            ),
          );
    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.05),
      size.width * 0.72,
      topGlow,
    );

    final lowerGlow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              _pratiViolet.withValues(alpha: 0.08),
              _pratiViolet.withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.20, size.height * 0.86),
              radius: size.width * 0.75,
            ),
          );
    canvas.drawCircle(
      Offset(size.width * 0.20, size.height * 0.86),
      size.width * 0.75,
      lowerGlow,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AuthHeroPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = PratiCaseColors.white.withValues(alpha: 0.055);
    for (var i = 0; i < 7; i++) {
      final x = size.width * (0.08 + i * 0.13);
      canvas.drawCircle(Offset(x, size.height * 0.18), 2.5, paint);
      canvas.drawCircle(Offset(x + 26, size.height * 0.82), 2.0, paint);
    }

    final glowPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              PratiCaseColors.white.withValues(alpha: 0.14),
              PratiCaseColors.white.withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.86, size.height * 0.18),
              radius: size.width * 0.38,
            ),
          );
    canvas.drawCircle(
      Offset(size.width * 0.86, size.height * 0.18),
      size.width * 0.38,
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
