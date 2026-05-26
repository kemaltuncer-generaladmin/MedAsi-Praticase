/// PratiCase abonelik / tek seferlik satın alma ürün modeli.
///
/// Veri kaynakları:
/// - Supabase `public.store_products` tablosu (qlinik ile ortak)
/// - StoreKit `Product` (App Store Connect üzerinden gelen yerel fiyat ve
///   kullanıcı dilinde başlık)
class PratiCaseStoreProduct {
  const PratiCaseStoreProduct({
    required this.code,
    required this.name,
    required this.description,
    required this.priceCents,
    required this.currency,
    required this.appStoreProductId,
    required this.entitlementKind,
    required this.interval,
    required this.durationDays,
    this.originalPriceCents,
    this.coinAmount = 0,
    this.questionAmount = 0,
    this.features = const <String>[],
    this.isFeatured = false,
    this.badge = '',
    this.localizedPrice,
    this.localizedTitle,
    this.localizedDescription,
  });

  /// Supabase ürün kodu (`weekly_subscription`, `monthly_subscription`, vb.).
  final String code;

  /// Türkçe ürün adı (Supabase üzerinden).
  final String name;

  /// Türkçe açıklama (Supabase üzerinden).
  final String description;

  /// Kuruş cinsinden fiyat (Supabase üzerinden).
  final int priceCents;

  final int? originalPriceCents;

  /// Para birimi (varsayılan TRY).
  final String currency;

  /// App Store Connect ürün kimliği.
  ///
  /// Öncelik ortak Medasi/Qlinik katalog alanındadır; PratiCase'e özel
  /// StoreKit override tanımlandıysa edge function bu değeri onunla değiştirir.
  final String appStoreProductId;

  /// `one_time` veya `subscription`.
  final String entitlementKind;

  /// `week`, `month`, `year`, `lifetime` vb. (Supabase üzerinden).
  final String interval;

  /// Hak süresi (gün).
  final int durationDays;

  final double coinAmount;
  final int questionAmount;
  final List<String> features;
  final bool isFeatured;
  final String badge;

  /// StoreKit tarafından gelen yerelleştirilmiş fiyat metni.
  final String? localizedPrice;
  final String? localizedTitle;
  final String? localizedDescription;

  bool get isSubscription => entitlementKind == 'subscription';

  bool get canPurchaseInPratiCase => appStoreProductId.trim().isNotEmpty;

  bool get isLifetime =>
      interval.toLowerCase() == 'lifetime' || durationDays >= 365 * 50;

  String get periodLabel {
    switch (interval.toLowerCase()) {
      case 'week':
        return 'haftalık';
      case 'month':
        return 'aylık';
      case 'year':
        return 'yıllık';
      case 'lifetime':
        return 'sınırsız';
      default:
        return '';
    }
  }

  PratiCaseStoreProduct copyWith({
    String? localizedPrice,
    String? localizedTitle,
    String? localizedDescription,
  }) {
    return PratiCaseStoreProduct(
      code: code,
      name: name,
      description: description,
      priceCents: priceCents,
      originalPriceCents: originalPriceCents,
      currency: currency,
      appStoreProductId: appStoreProductId,
      entitlementKind: entitlementKind,
      interval: interval,
      durationDays: durationDays,
      coinAmount: coinAmount,
      questionAmount: questionAmount,
      features: features,
      isFeatured: isFeatured,
      badge: badge,
      localizedPrice: localizedPrice ?? this.localizedPrice,
      localizedTitle: localizedTitle ?? this.localizedTitle,
      localizedDescription: localizedDescription ?? this.localizedDescription,
    );
  }

  factory PratiCaseStoreProduct.fromMap(Map<String, dynamic> row) {
    final featuresValue = row['features'];
    return PratiCaseStoreProduct(
      code: (row['code'] ?? '').toString(),
      name: (row['name'] ?? '').toString(),
      description: (row['description'] ?? '').toString(),
      priceCents: (row['price_cents'] as num?)?.round() ?? 0,
      originalPriceCents: (row['original_price_cents'] as num?)?.round(),
      currency: (row['currency'] ?? 'TRY').toString(),
      appStoreProductId: (row['app_store_product_id'] ?? '').toString(),
      entitlementKind: (row['entitlement_kind'] ?? 'one_time').toString(),
      interval: (row['interval'] ?? '').toString(),
      durationDays: (row['duration_days'] as num?)?.round() ?? 30,
      coinAmount: (row['coin_amount'] as num?)?.toDouble() ?? 0,
      questionAmount: (row['question_amount'] as num?)?.round() ?? 0,
      features: featuresValue is List
          ? [
              for (final item in featuresValue)
                if (item != null && item.toString().trim().isNotEmpty)
                  item.toString().trim(),
            ]
          : const <String>[],
      isFeatured: row['is_featured'] == true,
      badge: (row['badge'] ?? '').toString(),
    );
  }
}
