import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticase/src/app/praticase_app.dart';
import 'package:praticase/src/features/auth/data/mock_auth_repository.dart';

void main() {
  testWidgets('PratiCase auth onboarding renders', (tester) async {
    await tester.pumpWidget(PratiCaseApp(authRepository: MockAuthRepository()));

    expect(find.byType(Image), findsWidgets);
    expect(find.text('OSCE’ye gerçek sınav gibi hazırlan.'), findsOneWidget);
    expect(find.text('Hesap Oluştur'), findsOneWidget);
    expect(find.text('Giriş Yap'), findsOneWidget);
  });
}
