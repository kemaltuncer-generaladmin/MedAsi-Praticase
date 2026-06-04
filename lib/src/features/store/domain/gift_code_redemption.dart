import 'wallet_snapshot.dart';

class GiftCodeRedemption {
  const GiftCodeRedemption({
    required this.title,
    required this.coinAmount,
    required this.questionAmount,
    required this.aiQuestionAmount,
    required this.walletSnapshot,
  });

  final String title;
  final double coinAmount;
  final int questionAmount;
  final int aiQuestionAmount;
  final WalletSnapshot walletSnapshot;

  bool get hasReward =>
      coinAmount > 0 || questionAmount > 0 || aiQuestionAmount > 0;

  factory GiftCodeRedemption.fromFunctionResponse(Map<String, dynamic> data) {
    final redemption = data['redemption'] is Map
        ? Map<String, dynamic>.from(data['redemption'] as Map)
        : data;
    final profile = redemption['profile'] is Map
        ? Map<String, dynamic>.from(redemption['profile'] as Map)
        : const <String, dynamic>{};
    final walletBalance =
        _doubleValue(redemption['wallet_balance']) ??
        _doubleValue(profile['wallet_balance']) ??
        0;
    final questionQuota =
        _intValue(redemption['question_quota']) ??
        _intValue(profile['question_quota']) ??
        0;
    final aiQuota =
        _intValue(redemption['ai_quota']) ??
        _intValue(profile['ai_quota']) ??
        0;

    return GiftCodeRedemption(
      title: (redemption['title'] ?? '').toString(),
      coinAmount: _doubleValue(redemption['coin_amount']) ?? 0,
      questionAmount: _intValue(redemption['question_amount']) ?? 0,
      aiQuestionAmount: _intValue(redemption['ai_question_amount']) ?? 0,
      walletSnapshot: WalletSnapshot(
        walletCoinBalance: walletBalance,
        questionQuota: questionQuota,
        aiQuota: aiQuota,
      ),
    );
  }
}

String normalizeGiftCode(String value) {
  final buffer = StringBuffer();
  for (final codeUnit in value.toUpperCase().codeUnits) {
    final isLetter = codeUnit >= 65 && codeUnit <= 90;
    final isDigit = codeUnit >= 48 && codeUnit <= 57;
    if (isLetter || isDigit) buffer.writeCharCode(codeUnit);
  }
  final normalized = buffer.toString();
  return normalized.length == 16 ? normalized : '';
}

String formatGiftCodeInput(String value) {
  final buffer = StringBuffer();
  for (final codeUnit in value.toUpperCase().codeUnits) {
    final isLetter = codeUnit >= 65 && codeUnit <= 90;
    final isDigit = codeUnit >= 48 && codeUnit <= 57;
    if (isLetter || isDigit) buffer.writeCharCode(codeUnit);
    if (buffer.length == 16) break;
  }
  final raw = buffer.toString();
  final chunks = <String>[];
  for (var index = 0; index < raw.length; index += 4) {
    final end = index + 4 > raw.length ? raw.length : index + 4;
    chunks.add(raw.substring(index, end));
  }
  return chunks.join('-');
}

double? _doubleValue(Object? value) {
  if (value is num) return value.toDouble();
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return double.tryParse(text);
}

int? _intValue(Object? value) => _doubleValue(value)?.round();
