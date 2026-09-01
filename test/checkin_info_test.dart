import 'package:flutter_test/flutter_test.dart';
import 'package:rain_classroom_helper/models/checkin_info.dart';

void main() {
  group('CheckinInfo.parse', () {
    test('解析雨课堂签到二维码 URL（dynamic-qr-code）', () {
      const raw = 'https://changjiang.yuketang.cn/api/v3/lesson/check-in/dynamic-qr-code'
          '?class_id=9&lessonId=100&checkin_code=xyz';
      final info = CheckinInfo.parse(raw);
      expect(info.classId, '9');
      expect(info.checkinId, '100');
      expect(info.checkinCode, 'xyz');
      expect(info.isUsable, isTrue);
    });

    test('普通 yuketang URL 不等于签到二维码，不可用', () {
      const raw =
          'https://changjiang.yuketang.cn/checkin?class_id=9&checkin_code=xyz';
      final info = CheckinInfo.parse(raw);
      expect(info.checkinId, isNull);
      expect(info.checkinCode, isNull);
      expect(info.isUsable, isFalse);
    });

    test('微信跳转链（非签到二维码）不可用且不误标', () {
      const raw = 'http://weixin.qq.com/q/02Qz_3VlCc92';
      final info = CheckinInfo.parse(raw);
      expect(info.checkinId, isNull);
      expect(info.checkinCode, isNull);
      expect(info.isUsable, isFalse);
    });

    test('纯 token 形式不可用且不误标', () {
      const raw = 'dyn-token-12345';
      final info = CheckinInfo.parse(raw);
      expect(info.checkinId, isNull);
      expect(info.checkinCode, isNull);
      expect(info.isUsable, isFalse);
    });

    test('JSON 形式不可用（雨课堂签到必须是 dynamic-qr-code URL）', () {
      const raw = '{"classId":"c1","checkinId":"100","code":"abc"}';
      final info = CheckinInfo.parse(raw);
      expect(info.isUsable, isFalse);
    });

    test('空字符串不可用', () {
      final info = CheckinInfo.parse('');
      expect(info.isUsable, isFalse);
    });

    test('无法解析时不可用', () {
      final info = CheckinInfo.parse('@@@');
      expect(info.isUsable, isFalse);
    });
  });
}
