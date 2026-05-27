import 'package:flutter_test/flutter_test.dart';

import 'package:lingxi/app.dart';

void main() {
  testWidgets('App renders login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const LingxiApp());

    expect(find.text('登录 / 注册'), findsOneWidget);
  });
}
