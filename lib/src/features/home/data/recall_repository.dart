import '../domain/recall_summary.dart';

abstract interface class RecallRepository {
  Future<RecallSummary> loadSummary();
}

class RecallDataUnavailable implements Exception {
  const RecallDataUnavailable(this.message);

  final String message;

  @override
  String toString() => message;
}
