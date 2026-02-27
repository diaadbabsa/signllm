import 'package:flutter_test/flutter_test.dart';
import 'package:sign_vision_app/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SignVisionApp());
    await tester.pump();
  });
}
