import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/main.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('abre tela de login', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthViewModel()),
          ChangeNotifierProvider(create: (_) => FinanceViewModel()),
        ],
        child: const MyApp(),
      ),
    );

    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });
}
