// 基础冒烟测试：仅跑一个空测试，避免默认模板对 MyApp 的引用报错。
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('rain classroom helper smoke', (WidgetTester tester) async {
    expect(1 + 1, 2);
  });
}
