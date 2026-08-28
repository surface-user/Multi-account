import 'package:flutter_test/flutter_test.dart';
import 'package:rain_classroom_helper/models/account.dart';

void main() {
  group('Account', () {
    test('JSON 往返保持非敏感字段', () {
      final account = Account(
        id: 'id-1',
        username: '13800138000',
        nickname: '小明',
        userId: 'u-9',
        lastLoginAt: DateTime(2024, 1, 1, 12),
        createdAt: DateTime(2023, 1, 1),
      );

      final json = account.toJson();
      // Cookie 不进入 JSON。
      expect(json.containsKey('cookie'), isFalse);

      final restored = Account.fromJson(json);
      expect(restored.id, account.id);
      expect(restored.username, account.username);
      expect(restored.nickname, account.nickname);
      expect(restored.userId, account.userId);
    });

    test('displayName 使用昵称或用户名', () {
      final a = Account(
        id: '1',
        username: 'u',
        nickname: 'nick',
        createdAt: DateTime(2022),
      );
      expect(a.displayName, 'nick');

      final b = Account(
        id: '2',
        username: 'u',
        nickname: '',
        createdAt: DateTime(2022),
      );
      expect(b.displayName, 'u');
    });

    test('hasLogin 判断', () {
      final a = Account(id: '1', username: 'u', nickname: '', createdAt: DateTime(2022));
      expect(a.hasLogin, isFalse);

      final b = a.copyWith(cookie: 'a=1');
      expect(b.hasLogin, isTrue);
    });
  });
}
