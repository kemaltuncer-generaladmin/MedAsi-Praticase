/// Kullanıcının PratiCase + Qlinik ortak cüzdanındaki canlı durumunu temsil
/// eder. Veriler `praticase-storekit-verify` edge fonksiyonunun döndürdüğü
/// `entitlement` paketinden ve Supabase `wallet_entitlements` görünümünden
/// gelir.
class SubscriptionState {
  const SubscriptionState({
    required this.hasActiveSubscription,
    required this.productCode,
    required this.productName,
    required this.expiresAt,
    required this.periodStartedAt,
    required this.willAutoRenew,
    required this.environment,
    required this.transactionId,
    required this.originalTransactionId,
    this.walletCoinBalance = 0,
    this.questionQuota = 0,
    this.remainingCoinAmount = 0,
    this.remainingQuestionAmount = 0,
    this.warnings = const <String>[],
  });

  final bool hasActiveSubscription;
  final String productCode;
  final String productName;
  final DateTime? expiresAt;
  final DateTime? periodStartedAt;
  final bool willAutoRenew;

  /// `production` veya `sandbox` (App Store ortamı).
  final String environment;
  final String transactionId;
  final String originalTransactionId;

  final double walletCoinBalance;
  final int questionQuota;
  final double remainingCoinAmount;
  final int remainingQuestionAmount;
  final List<String> warnings;

  static const SubscriptionState empty = SubscriptionState(
    hasActiveSubscription: false,
    productCode: '',
    productName: '',
    expiresAt: null,
    periodStartedAt: null,
    willAutoRenew: false,
    environment: '',
    transactionId: '',
    originalTransactionId: '',
  );

  bool get isExpired =>
      expiresAt != null && DateTime.now().toUtc().isAfter(expiresAt!.toUtc());

  Duration? get remainingDuration {
    final expires = expiresAt;
    if (expires == null) return null;
    final now = DateTime.now().toUtc();
    final delta = expires.toUtc().difference(now);
    return delta.isNegative ? Duration.zero : delta;
  }

  factory SubscriptionState.fromVerificationResponse(
    Map<String, dynamic> data,
  ) {
    final entitlement = data['entitlement'] is Map
        ? Map<String, dynamic>.from(data['entitlement'] as Map)
        : const <String, dynamic>{};
    final profile = data['profile'] is Map
        ? Map<String, dynamic>.from(data['profile'] as Map)
        : const <String, dynamic>{};
    final warningsValue = data['warnings'];
    return SubscriptionState(
      hasActiveSubscription: entitlement['active'] == true,
      productCode: (entitlement['product_code'] ?? '').toString(),
      productName: (entitlement['product_name'] ?? '').toString(),
      expiresAt: _parseDate(entitlement['expires_at']),
      periodStartedAt: _parseDate(entitlement['period_started_at']),
      willAutoRenew: entitlement['will_auto_renew'] == true,
      environment: (entitlement['environment'] ?? '').toString(),
      transactionId: (entitlement['transaction_id'] ?? '').toString(),
      originalTransactionId: (entitlement['original_transaction_id'] ?? '')
          .toString(),
      walletCoinBalance: _doubleValue(profile['wallet_balance']),
      questionQuota: _intValue(profile['question_quota']),
      remainingCoinAmount: _doubleValue(entitlement['remaining_coin_amount']),
      remainingQuestionAmount: _intValue(
        entitlement['remaining_question_amount'],
      ),
      warnings: warningsValue is List
          ? [
              for (final item in warningsValue)
                if (item != null && item.toString().trim().isNotEmpty)
                  item.toString().trim(),
            ]
          : const <String>[],
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}

double _doubleValue(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().trim() ?? '') ?? 0;
}

int _intValue(Object? value) => _doubleValue(value).round();

class StorePurchaseException implements Exception {
  const StorePurchaseException(this.message, {this.code = ''});

  final String message;
  final String code;

  @override
  String toString() => 'StorePurchaseException($code): $message';
}
