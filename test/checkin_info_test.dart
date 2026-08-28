import 'package:flutter_test/flutter_test.dart';
import 'package:rain_classroom_helper/models/checkin_info.dart';

void main() {
  group('CheckinInfo.parse', () {
    test('解析 JSON 形式', () {
      const raw = '{"classId":"c1","checkinId":"100","code":"abc"}';
      final info = CheckinInfo.parse(raw);
      expect(info.classId, 'c1');
      expect(info.checkinId, '100');
      expect(info.checkinCode, 'abc');
      expect(info.isUsable, isTrue);
    });

    test('解析 URL 查询参数形式', () {
      const raw =
          'https://changjiang.yuketang.cn/checkin?class_id=9&checkin_code=xyz';
      final info = CheckinInfo.parse(raw);
      expect(info.classId, '9');
      expect(info.checkinCode, 'xyz');
      expect(info.isUsable, isTrue);
    });

    test('纯 token 形式', () {
      const raw = 'dyn-token-12345';
      final info = CheckinInfo.parse(raw);
      expect(info.checkinId, raw);
      expect(info.checkinCode, raw);
      expect(info.isEncrypted, isTrue);
    });

    test('空字符串', () {
      final info = CheckinInfo.parse('');
      expect(info.isUsable, isFalse);
    });

    test('无法解析时不可用', () {
      final info = CheckinInfo.parse('@@@');
      expect(info.isUsable, isFalse);
    });
  });
}
