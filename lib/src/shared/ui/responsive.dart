import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../app/theme/praticase_performance.dart';
import '../../app/theme/praticase_tokens.dart';

abstract final class PratiCaseBreakpoints {
  static const double compactPhone = 380;
  static const double tablet = 600;
  static const double sideNavigation = 900;
  static const double desktop = 1180;

  /// iPad / tablet "shortest side" eşiği. iPad Mini portrait genişliği
  /// 768'dir; shortestSide >= 600 koşulu tüm iPad'leri (Mini dahil)
  /// telefon olarak değil tablet olarak işaretler. Telefon landscape'i
  /// (örn. iPhone 16 Pro Max landscape 932×430) shortestSide 430 olduğu
  /// için tablet sayılmaz; bu da yanlış side-navigation tetiklenmesini
  /// engeller.
  static const double tabletShortestSide = 600;

  static const double tabletContentMaxWidth = 760;
  static const double desktopContentMaxWidth = 1280;
  static const double flowContentMaxWidth = 960;
}

abstract final class PratiCaseResponsive {
  static bool isCompactPhone(BuildContext context) =>
      MediaQuery.sizeOf(context).width < PratiCaseBreakpoints.compactPhone;

  /// Tablet sınıfı cihazlar (genişlik >= 600 veya kısa kenar >= 600).
  /// Telefon landscape'i kısa kenarı küçük olduğu için tablet sayılmaz.
  static bool isTablet(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return size.width >= PratiCaseBreakpoints.tablet ||
        size.shortestSide >= PratiCaseBreakpoints.tabletShortestSide;
  }

  /// Side navigation: yatay genişlik >= 900 **veya** cihaz bir tablet
  /// (kısa kenar >= 600) ve mevcut genişlik 720'nin üzerinde. Bu sayede
  /// iPad portrait'te (768/810/834) artık side nav görünür; phone
  /// landscape'inde ise bottom nav korunur.
  static bool usesSideNavigation(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    if (size.width >= PratiCaseBreakpoints.sideNavigation) return true;
    if (size.shortestSide >= PratiCaseBreakpoints.tabletShortestSide &&
        size.width >= 720) {
      return true;
    }
    return false;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= PratiCaseBreakpoints.desktop;

  static double horizontalPaddingForWidth(double width) {
    if (width >= PratiCaseBreakpoints.desktop) return 32;
    if (width >= PratiCaseBreakpoints.tablet) return 28;
    if (width < PratiCaseBreakpoints.compactPhone) return 16;
    return PratiCaseSpacing.pageHorizontal;
  }

  static double bottomNavigationHeightForWidth(double width) {
    return width < PratiCaseBreakpoints.compactPhone ? 76 : 82;
  }

  static double bottomNavigationOuterPaddingForWidth(double width) {
    return width < PratiCaseBreakpoints.compactPhone ? 10 : 12;
  }

  static double bottomNavigationReserveForWidth(double width) {
    final navHeight = bottomNavigationHeightForWidth(width);
    final outerPadding = bottomNavigationOuterPaddingForWidth(width);
    return navHeight + outerPadding + 36;
  }

  static double maxContentWidthForWidth(
    double width, {
    double? tabletMaxWidth,
    double? desktopMaxWidth,
  }) {
    if (width >= PratiCaseBreakpoints.desktop) {
      return desktopMaxWidth ?? PratiCaseBreakpoints.desktopContentMaxWidth;
    }
    // Geniş tablet katmanı: iPad Pro 12.9" portrait (1024) ve iPad Pro
    // 11" landscape (1194 — desktop'a düşer) arası. 760 burada çok dar
    // kalıyor; 920'ye genişletirsek breathing room sağlanır.
    if (width >= 980) {
      return 920;
    }
    if (width >= PratiCaseBreakpoints.tablet) {
      return tabletMaxWidth ?? PratiCaseBreakpoints.tabletContentMaxWidth;
    }
    return double.infinity;
  }

  static EdgeInsets pagePadding(
    BuildContext context, {
    double top = PratiCaseSpacing.pageTop,
    double bottom = PratiCaseSpacing.bottomNavReserve,
    bool includeNavigationReserve = true,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    final defaultReserve = bottom == PratiCaseSpacing.bottomNavReserve
        ? bottomNavigationReserveForWidth(width)
        : bottom;
    final navigationReserve =
        includeNavigationReserve && !usesSideNavigation(context)
        ? defaultReserve
        : 24;
    return EdgeInsets.fromLTRB(
      horizontalPaddingForWidth(width),
      top,
      horizontalPaddingForWidth(width),
      MediaQuery.paddingOf(context).bottom + navigationReserve,
    );
  }

  static int columnsForWidth(
    double width, {
    int compact = 1,
    int tablet = 2,
    int desktop = 3,
  }) {
    if (width >= PratiCaseBreakpoints.desktop) return desktop;
    if (width >= PratiCaseBreakpoints.tablet) return tablet;
    return compact;
  }
}

class PratiCaseResponsiveFrame extends StatelessWidget {
  const PratiCaseResponsiveFrame({
    required this.child,
    this.maxWidth,
    this.expandHeight = false,
    super.key,
  });

  final Widget child;
  final double? maxWidth;
  final bool expandHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final effectiveMaxWidth =
            maxWidth ??
            PratiCaseResponsive.maxContentWidthForWidth(constraints.maxWidth);
        final width = math.min(effectiveMaxWidth, constraints.maxWidth);
        final height = expandHeight
            ? constraints.hasBoundedHeight
                  ? constraints.maxHeight
                  : MediaQuery.sizeOf(context).height -
                        MediaQuery.paddingOf(context).top -
                        MediaQuery.paddingOf(context).bottom
            : null;
        final framedChild = Align(
          alignment: Alignment.topCenter,
          heightFactor: expandHeight ? null : 1,
          child: SizedBox(
            width: width.isFinite ? width : constraints.maxWidth,
            height: height,
            child: child,
          ),
        );
        if (!expandHeight) {
          return framedChild;
        }
        if (!constraints.hasBoundedHeight) {
          return SizedBox(height: height, child: framedChild);
        }
        return SizedBox.expand(child: framedChild);
      },
    );
  }
}

class PratiCaseResponsiveListView extends StatelessWidget {
  const PratiCaseResponsiveListView({
    required this.children,
    this.padding,
    this.maxWidth,
    this.controller,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.onDrag,
    this.physics,
    super.key,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final double? maxWidth;
  final ScrollController? controller;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final effectivePadding =
            padding ?? PratiCaseResponsive.pagePadding(context);
        final resolvedPadding = effectivePadding.resolve(
          Directionality.of(context),
        );
        final effectiveMaxWidth =
            maxWidth ??
            PratiCaseResponsive.maxContentWidthForWidth(constraints.maxWidth);
        final width = math.min(effectiveMaxWidth, constraints.maxWidth);
        return ListView(
          controller: controller,
          keyboardDismissBehavior: keyboardDismissBehavior,
          physics: physics,
          scrollCacheExtent: PratiCasePerformance.web
              ? const ScrollCacheExtent.pixels(900)
              : null,
          padding: EdgeInsets.only(
            top: resolvedPadding.top,
            bottom: resolvedPadding.bottom,
          ),
          children: [
            for (final child in children)
              Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: width.isFinite ? width : constraints.maxWidth,
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: resolvedPadding.left,
                      right: resolvedPadding.right,
                    ),
                    child: child,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
