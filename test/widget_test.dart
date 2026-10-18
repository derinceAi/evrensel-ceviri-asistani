import 'package:flutter_test/flutter_test.dart';
import 'package:ceviri_asistani/main.dart';

void main() {
  testWidgets('Evrensel Ceviri App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const EvrenselCeviriApp());
    expect(find.text('Evrensel Sesli Çeviri Asistanı'), findsOneWidget);
  });
}
