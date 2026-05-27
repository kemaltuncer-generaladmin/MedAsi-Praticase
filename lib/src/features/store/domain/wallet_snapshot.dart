import 'store_product.dart';

/// Qlinik ile ortak Medasi cüzdanının tek canlı okuma sonucudur.
///
/// `store` cevabındaki `profile`, sunucunun `sync_wallet_profile` sonucudur;
/// MC ve soru hakkı başka bir istemci isteğiyle birleştirilmez.
class WalletSnapshot {
  const WalletSnapshot({
    required this.walletCoinBalance,
    required this.questionQuota,
    this.aiQuota = 0,
  });

  final double walletCoinBalance;
  final int questionQuota;
  final int aiQuota;

  static const empty = WalletSnapshot(walletCoinBalance: 0, questionQuota: 0);

  factory WalletSnapshot.fromStoreResponse(Map<String, dynamic> data) {
    final profile = data['profile'] is Map
        ? Map<String, dynamic>.from(data['profile'] as Map)
        : const <String, dynamic>{};
    return WalletSnapshot(
      walletCoinBalance: _doubleValue(profile['wallet_balance']),
      questionQuota: _intValue(profile['question_quota']),
      aiQuota: _intValue(profile['ai_quota']),
    );
  }
}

class WalletCatalog {
  const WalletCatalog({required this.products, required this.snapshot});

  final List<PratiCaseStoreProduct> products;
  final WalletSnapshot snapshot;

  factory WalletCatalog.fromStoreResponse(Map<String, dynamic> data) {
    final rows = data['products'];
    return WalletCatalog(
      products: [
        for (final row in (rows is List ? rows : const <Object>[]))
          if (row is Map)
            PratiCaseStoreProduct.fromMap(Map<String, dynamic>.from(row)),
      ],
      snapshot: WalletSnapshot.fromStoreResponse(data),
    );
  }
}

double _doubleValue(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().trim() ?? '') ?? 0;
}

int _intValue(Object? value) => _doubleValue(value).round();
