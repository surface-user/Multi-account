import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rain_classroom_helper/models/account.dart';
import 'package:rain_classroom_helper/platform.dart';
import 'package:rain_classroom_helper/services/account_store.dart';
import 'package:rain_classroom_helper/services/cookie_store.dart';
import 'package:rain_classroom_helper/services/rain_api_service.dart';
import 'package:rain_classroom_helper/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RainApiService.validateSession', () {
    test('用户信息接口返回 profile 时会话有效', () async {
      final client = MockClient((request) async {
        expect(request.url.host, 'changjiang.yuketang.cn');
        expect(request.headers['cookie'], 'sessionid=valid');
        expect(request.headers.containsKey('authorization'), isFalse);
        expect(request.headers.containsKey('x-uid'), isFalse);
        return http.Response(
          jsonEncode({
            'code': 0,
            'data': {
              'user_profile': {
                'user_id': 'u-1',
                'name': '小明',
                'school': '测试大学',
              },
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final api = RainApiService(client: client);
      // 模拟请求层内存里残留了另一个账号的身份；启动验证不得借用它。
      api.setBearerToken('another-account-token');
      api.setUid('another-account-uid');

      final result = await api.validateSession(
        cookie: 'sessionid=valid',
        server: RainClassroomServerType.changjiang,
      );

      expect(result.status, SessionValidationStatus.valid);
      expect(result.profile?['user_id'], 'u-1');
    });

    test('401/403 明确视为会话过期', () async {
      final api = RainApiService(
        client: MockClient((_) async => http.Response('', 401)),
      );

      final result = await api.validateSession(cookie: 'sessionid=expired');

      expect(result.status, SessionValidationStatus.expired);
    });

    test('HTTP 200 中的鉴权错误码仍视为会话过期', () async {
      final api = RainApiService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'code': 401,
              'message': '登录过期',
              'data': {'user_profile': null},
            }),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );

      final result = await api.validateSession(cookie: 'sessionid=expired');

      expect(result.status, SessionValidationStatus.expired);
    });

    test('服务器故障时标记为暂时无法验证', () async {
      final api = RainApiService(
        client: MockClient((_) async => http.Response('', 503)),
      );

      final result = await api.validateSession(cookie: 'sessionid=keep-me');

      expect(result.status, SessionValidationStatus.unavailable);
    });

    test('被重定向到 HTML 登录页时视为会话过期', () async {
      final api = RainApiService(
        client: MockClient(
          (_) async => http.Response(
            '<html><title>login</title></html>',
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          ),
        ),
      );

      final result = await api.validateSession(cookie: 'sessionid=expired');

      expect(result.status, SessionValidationStatus.expired);
    });
  });

  test('AppState.load 启动验证后清除明确过期的 Cookie', () async {
    final account = Account(
      id: 'account-1',
      username: 'student',
      nickname: '学生',
      createdAt: DateTime(2026),
    );
    SharedPreferences.setMockInitialValues({
      'accounts': jsonEncode([account.toJson()]),
      'cookie_account-1': base64Encode(utf8.encode('sessionid=expired')),
    });
    final prefs = await SharedPreferences.getInstance();
    final cookieStore = CookieStore(prefs: prefs);
    final state = AppState(
      accountStore: AccountStore(prefs: prefs),
      cookieStore: cookieStore,
      api: RainApiService(
        client: MockClient((_) async => http.Response('', 403)),
      ),
    );

    await state.load();

    expect(state.loaded, isTrue);
    expect(state.accounts.single.sessionStatus, AccountSessionStatus.expired);
    expect(state.accounts.single.hasLogin, isFalse);
    expect(await cookieStore.read('account-1'), isNull);
  });

  test('AppState.load 无法验证时保留 Cookie', () async {
    final account = Account(
      id: 'account-2',
      username: 'student',
      nickname: '学生',
      createdAt: DateTime(2026),
    );
    const cookie = 'sessionid=keep-me';
    SharedPreferences.setMockInitialValues({
      'accounts': jsonEncode([account.toJson()]),
      'cookie_account-2': base64Encode(utf8.encode(cookie)),
    });
    final prefs = await SharedPreferences.getInstance();
    final cookieStore = CookieStore(prefs: prefs);
    final state = AppState(
      accountStore: AccountStore(prefs: prefs),
      cookieStore: cookieStore,
      api: RainApiService(
        client: MockClient((_) async => http.Response('', 503)),
      ),
    );

    await state.load();

    expect(
      state.accounts.single.sessionStatus,
      AccountSessionStatus.unavailable,
    );
    expect(state.accounts.single.hasLogin, isTrue);
    expect(await cookieStore.read('account-2'), cookie);
  });
}
