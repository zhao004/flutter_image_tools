import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_image_tools/main.dart';

void main() {
  testWidgets('显示首页内容', (WidgetTester tester) async {
    // 通过根组件启动应用，覆盖路由绑定和默认页面渲染路径。
    await tester.pumpWidget(const ImageToolsApp());
    await tester.pumpAndSettle();

    expect(find.text('HomeView'), findsOneWidget);
    expect(find.text('HomeView is working'), findsOneWidget);
  });
}
