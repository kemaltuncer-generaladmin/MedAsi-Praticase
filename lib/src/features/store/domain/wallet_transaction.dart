/// PratiCase cüzdan işlem geçmişinde gösterilen tek satır.
///
/// `praticase-storekit-verify` edge fonksiyonunun `wallet_transactions`
/// aksiyonundan gelir. Şu an her satır bir `wallet_entitlements` kaydına
/// karşılık gelir (satın alma veya yenileme).
class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.kind,
    required this.productCode,
    required this.productName,
    required this.coinAmount,
    required this.questionAmount,
    required this.remainingCoinAmount,
    required this.remainingQuestionAmount,
    required this.status,
    required this.expired,
    required this.occurredAt,
    this.expiresAt,
  });

  /// Edge fonksiyonu tarafından üretilen stabil kimlik.
  final String id;

  /// `subscription`, `one_time`, `purchase` vb. — entitlement tipi.
  final String kind;

  final String productCode;
  final String productName;

  /// Bu satın almayla yüklenen toplam MC.
  final double coinAmount;

  /// Bu satın almayla yüklenen soru hakkı.
  final int questionAmount;

  final double remainingCoinAmount;
  final int remainingQuestionAmount;

  /// `active`, `consumed`, `refunded` vb.
  final String status;

  /// Hak süresi dolmuş mu?
  final bool expired;

  /// Satın alma / yenileme zamanı.
  final DateTime? occurredAt;

  /// Hak bitiş zamanı (varsa).
  final DateTime? expiresAt;

  bool get isSubscription => kind == 'subscription';
  bool get isCredit => coinAmount > 0 || questionAmount > 0;
  bool get isActive => status == 'active' && !expired;

  factory WalletTransaction.fromMap(Map<String, dynamic> row) {
    return WalletTransaction(
      id: (row['id'] ?? '').toString(),
      kind: (row['kind'] ?? 'purchase').toString(),
      productCode: (row['product_code'] ?? '').toString(),
      productName: (row['product_name'] ?? '').toString(),
      coinAmount: (row['coin_amount'] as num?)?.toDouble() ?? 0,
      questionAmount: (row['question_amount'] as num?)?.round() ?? 0,
      remainingCoinAmount:
          (row['remaining_coin_amount'] as num?)?.toDouble() ?? 0,
      remainingQuestionAmount:
          (row['remaining_question_amount'] as num?)?.round() ?? 0,
      status: (row['status'] ?? 'active').toString(),
      expired: row['expired'] == true,
      occurredAt: _parseDate(row['occurred_at']),
      expiresAt: _parseDate(row['expires_at']),
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }
}
