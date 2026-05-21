import '../domain/home_dashboard.dart';

abstract interface class HomeRepository {
  Future<HomeDashboard> loadDashboard();
}

class HomeDataUnavailable implements Exception {
  const HomeDataUnavailable(this.message);

  final String message;

  @override
  String toString() => message;
}
