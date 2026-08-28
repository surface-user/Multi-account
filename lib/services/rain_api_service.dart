import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../models/course.dart';
import '../models/slide.dart';

/// 登录结果。
class LoginResult {
  LoginResult({
    required this.success,
    this.cookie,
    this.message = '',
    this.userId,
    this.nickname,
  });

  final bool success;
  final String? cookie;
  final String message;
  final String? userId;
  final String? nickname;

  static LoginResult fail(String message) =>
      LoginResult(success: false, message: message);

  static LoginResult ok(String cookie,
          {String? userId, String? nickname, String message = '登录成功'}) =>
      LoginResult(
          success: true, cookie: cookie, message: message, userId: userId, nickname: nickname);
}

/// 简单 Cookie 容器：从响应 Set-Cookie 提取并维护会话。
class CookieJar {
  final Map<String, String> _cookies = {};

  /// 从响应头提取 Set-Cookie。
  void absorb(http.Response response) {
    final setCookies = response.headers['set-cookie'];
    if (setCookies == null) {
      return;
    }
    // 可能有多条（用逗号连接，但值里可能含逗号，这里做保守拆分）。
    for (final raw in setCookies.split(',')) {
      final first = raw.split(';').first.trim();
      final idx = first.indexOf('=');
      if (idx <= 0) {
        continue;
      }
      final name = first.substring(0, idx).trim();
      final value = first.substring(idx + 1).trim();
      if (name.isNotEmpty) {
        _cookies[name] = value;
      }
    }
  }

  /// 手动设置整条 Cookie 字符串。
  void setFromString(String cookie) {
    _cookies.clear();
    for (final item in cookie.split(';')) {
      final idx = item.indexOf('=');
      if (idx <= 0) {
        continue;
      }
      final name = item.substring(0, idx).trim();
      final value = item.substring(idx + 1).trim();
      if (name.isNotEmpty) {
        _cookies[name] = value;
      }
    }
  }

  void clear() => _cookies.clear();

  /// 取某个 Cookie 的值（如 csrftoken / sessionid），没有则 null。
  String? value(String name) => _cookies[name];

  String? get header {
    if (_cookies.isEmpty) {
      return null;
    }
    return _cookies.entries
        .map((e) => '${e.key}=${e.value}')
        .join('; ');
  }

  bool get isEmpty => _cookies.isEmpty;
}

/// 雨课堂 HTTP API 服务。
///
/// 负责登录、携带会话 Cookie 的鉴权请求，以及课程/课件拉取。所有可调整的接口
/// 路径集中在 [AppConfig]。凡涉及加密登录、验证码的，通常需要按平台最新实现调整。
class RainApiService {
  RainApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final CookieJar _jar = CookieJar();
  final Duration _timeout =
      const Duration(seconds: AppConfig.networkTimeoutSeconds);

  /// 雨课堂登录后由响应头 `set-auth` 返回的 Bearer Token。
  /// 后续请求带 `Authorization: Bearer <token>`。
  String? _bearerToken;

  String? get bearerToken => _bearerToken;

  /// 用户 ID（用于 `x-uid` 头，手动 Cookie 登录时可能未知）。
  String? _uid;

  String? get uid => _uid;

  /// 最近一次登录（密码/验证码/二维码）响应捕获到的会话 Cookie，用于持久化。
  String? _lastLoginCookie;

  String? get lastLoginCookie => _lastLoginCookie;

  /// 登录链路共用的 Cookie Jar（send → verify → login 贯穿携带 csrftoken，
  /// 对齐 course_helper 的临时 tempCookieJar，避免登录接口因缺失 CSRF Cookie 被拒）。
  final CookieJar _loginJar = CookieJar();

  /// 开始一次全新的登录链路前清空登录 Cookie Jar。
  void resetLoginJar() => _loginJar.clear();

  Map<String, String> _baseHeaders() {
    // 雨课堂 App 身份头（对齐 course_helper 的 HeadersManager.rainClassroomHeaders）。
    // 缺少这些头时，/api/v3/user/login/app 等接口会拒绝登录（发验证码等宽松接口则不校验）。
    return {
      'user-agent': 'Android',
      'brand': 'google Pixel 9 Pro',
      'uuid': '',
      'buildnumber': '1610',
      'xtua': 'client=app&tag=1.3.3&platform=Android',
      'systemversion': '16',
      'incremental': '14624737',
      'accept': 'application/json',
      'isphysicaldevice': 'true',
      'xtbz': 'ykt',
      'x-client': 'app',
      'Content-Type': 'application/json; charset=utf-8',
    };
  }

  Map<String, String> _authHeaders({String? cookie}) {
    final headers = _baseHeaders();
    final effective = cookie ?? _jar.header;
    if (effective != null && effective.isNotEmpty) {
      headers['Cookie'] = effective;
      // 雨课堂需要额外几个头（取自 Cookie），否则只带 Cookie 可能校验失败。
      final csrf = _cookieValue(effective, 'csrftoken');
      final sssid = _cookieValue(effective, 'sessionid');
      if (csrf != null && csrf.isNotEmpty) {
        headers['x-csrftoken'] = csrf;
      }
      if (sssid != null && sssid.isNotEmpty) {
        headers['sessionid'] = sssid;
      }
    }
    if (_uid != null && _uid!.isNotEmpty) {
      headers['x-uid'] = _uid!;
    }
    // 雨课堂鉴权优先用 Bearer Token（来自登录响应头 set-auth）。
    if (_bearerToken != null && _bearerToken!.isNotEmpty) {
      headers['authorization'] = 'Bearer $_bearerToken';
    }
    return headers;
  }

  /// 从 Cookie 字符串里取某个键的值（如 csrftoken / sessionid）。
  String? _cookieValue(String cookie, String name) {
    for (final item in cookie.split(';')) {
      final idx = item.indexOf('=');
      if (idx <= 0) {
        continue;
      }
      if (item.substring(0, idx).trim() == name) {
        var v = item.substring(idx + 1).trim();
        // 去掉可能带的可选属性（如 path=/; ...），只保留第一个 token。
        final semi = v.indexOf(';');
        if (semi >= 0) {
          v = v.substring(0, semi).trim();
        }
        return v;
      }
    }
    return null;
  }

  /// 当前是否已持有会话（Cookie 或 Bearer Token）。
  bool get isLoggedIn => !_jar.isEmpty || (_bearerToken != null);

  /// 手动写入会话 Cookie（手动登录兜底）。
  void setCookie(String cookie) {
    _jar.setFromString(cookie);
    _bearerToken = null;
  }

  /// 手动写入 Bearer Token（手动登录兜底，若用户粘贴的是 token 而非 Cookie）。
  void setBearerToken(String token) => _bearerToken = token;

  /// 设置用户 ID（用于 `x-uid` 头；从用户信息里拿到后调用）。
  void setUid(String? uid) => _uid = uid;

  /// 清空会话。
  void clearCookie() {
    _jar.clear();
    _bearerToken = null;
  }

  /// 生成并持久化一个稳定的设备 ID，用于登录体的 `pushDeviceId`。
  Future<String> _deviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const key = 'rain_push_device_id';
      final saved = prefs.getString(key);
      if (saved != null && saved.isNotEmpty) {
        return saved;
      }
      final id = const Uuid().v4();
      await prefs.setString(key, id);
      return id;
    } catch (_) {
      // 读不到本地存储时也生成一个，保证登录体字段非空。
      return const Uuid().v4();
    }
  }

  /// 账号密码登录。
  ///
  /// 真实接口说明（依据 course_helper / 线上 login.js 逆向）：
  ///  - 登录接口: POST /api/v3/user/login/app
  ///  - 请求体 JSON，字段含 type / phoneNumber(或 email) / password /
  ///    pushDeviceId / ticket / rand。其中 ticket + rand 是腾讯验证码凭证，
  ///    纯脚本难以自动获得，故这里默认传空，服务器会要求验证码。
  ///  - 登录成功后，服务器在响应头 `set-auth` 返回 Bearer Token，用于后续鉴权。
  Future<LoginResult> login(String username, String password) async {
    try {
      final uri = Uri.parse(AppConfig.url(AppConfig.loginPath));
      final deviceId = await _deviceId();
      final isEmail = username.contains('@');
      final body = jsonEncode({
        'type': isEmail ? 2 : 1,
        'phoneNumber': isEmail ? '' : username,
        'email': isEmail ? username : '',
        'password': _encodePassword(password),
        'code': '',
        'pushDeviceId': deviceId,
        // 腾讯验证码凭证：自动化脚本无法获取，留空以便服务器明确提示。
        'ticket': '',
        'rand': '',
      });

      final response = await _client
          .post(uri, headers: _baseHeaders(), body: body)
          .timeout(_timeout);

      // 捕获 Cookie 与 set-auth Bearer Token。
      _jar.absorb(response);
      final setAuth = response.headers['set-auth'];
      if (setAuth != null && setAuth.isNotEmpty) {
        _bearerToken = setAuth;
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = _decodeBody(response);
        final userId = _pickString(data, ['user_id', 'userId', 'uid']);
        final nickname = _pickString(data, ['name', 'nickname']);
        if (userId != null) {
          _uid = userId;
        }
        final cookie = _jar.header;
        final hasSession = (_bearerToken != null && _bearerToken!.isNotEmpty) ||
            (cookie != null && cookie.isNotEmpty);
        if (!hasSession) {
          return LoginResult.fail('登录响应未返回会话（Cookie/Bearer Token）');
        }
        return LoginResult.ok(
          cookie ?? '',
          userId: userId,
          nickname: nickname,
        );
      }

      // 优先展示服务器返回的具体错误信息（如要求验证码）。
      final data = _decodeBody(response);
      final msg = _pickString(data, ['msg', 'message', 'error']);
      final display = (msg != null && msg.isNotEmpty && msg != 'null');
      if (display) {
        return LoginResult.fail(msg);
      }
      return LoginResult.fail('登录失败（HTTP ${response.statusCode}）');
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('RainApiService.login error: $e');
      }
      return LoginResult.fail('登录异常: $e');
    }
  }

  /// 发送短信验证码（需腾讯验证码的 ticket/rand，仿 course_helper）。
  Future<Map<String, dynamic>?> sendSmsCode(
      String phone, String ticket, String rand) async {
    return _postLogin(AppConfig.smsCodeSendPath, {
      'phoneNumber': phone,
      'email': '',
      'ticket': ticket,
      'rand': rand,
    });
  }

  /// 校验短信验证码（发送后，登录前）。
  Future<Map<String, dynamic>?> verifySmsCode(String phone, String code) async {
    return _postLogin(AppConfig.smsCodeVerifyPath, {
      'phoneNumber': phone,
      'email': '',
      'code': code,
    });
  }

  /// 密码登录（需腾讯验证码 ticket/rand）。account 可为手机号或邮箱。
  Future<Map<String, dynamic>?> loginPassword(
      String account, String password, String ticket, String rand) async {
    final isEmail = account.contains('@');
    return _postLogin(AppConfig.loginPath, {
      'type': isEmail ? 2 : 1,
      'phoneNumber': isEmail ? '' : account,
      'password': _encodePassword(password),
      'email': isEmail ? account : '',
      'code': '',
      'pushDeviceId': await _deviceId(),
      'ticket': ticket,
      'rand': rand,
    });
  }

  /// 短信验证码登录（type=3）。
  Future<Map<String, dynamic>?> loginCode(
      String phone, String code, String ticket, String rand) async {
    return _postLogin(AppConfig.loginPath, {
      'type': 3,
      'phoneNumber': phone,
      'password': '',
      'email': '',
      'code': code,
      'pushDeviceId': await _deviceId(),
      'ticket': ticket,
      'rand': rand,
    });
  }

  /// 获取二维码登录信息（返回 { token, qrImage }）。pre-info 为 GET。
  Future<Map<String, dynamic>?> getQRCodeData() async {
    final uri = Uri.parse(AppConfig.url(AppConfig.qrPreInfoPath));
    final response = await _client.get(uri, headers: _loginHeaders()).timeout(_timeout);
    _loginJar.absorb(response);
    final data = _decodeBody(response);
    if (_code(data) == 0 && data['data'] is Map<String, dynamic>) {
      return data['data'] as Map<String, dynamic>;
    }
    return null;
  }

  /// 二维码登录轮询（带 token）。code==0 表示扫码成功，返回 data。
  Future<Map<String, dynamic>?> loginQRCode(String token) async {
    return _postLogin(AppConfig.qrLoginPath, {
      'token': token,
    });
  }

  /// 统一处理登录链路 POST。
  ///
  /// 登录阶段共用 [_loginJar]：请求会带上该 Jar 已有的 Cookie 与 x-csrftoken，
  /// 响应再把它新设置的 Cookie 写回 Jar。这样 send → verify → login 全程携带
  /// csrftoken，避免登录接口因 CSRF 校验失败返回非预期结构。
  Future<Map<String, dynamic>?> _postLogin(
      String path, Map<String, dynamic> jsonBody) async {
    final uri = Uri.parse(AppConfig.url(path));
    final response = await _client
        .post(uri, headers: _loginHeaders(), body: jsonEncode(jsonBody))
        .timeout(_timeout);
    final setAuth = response.headers['set-auth'];
    if (setAuth != null && setAuth.isNotEmpty) {
      _bearerToken = setAuth;
    }
    _loginJar.absorb(response);
    final cookie = _loginJar.header;
    if (cookie != null && cookie.isNotEmpty) {
      _lastLoginCookie = cookie;
    }
    return _decodeBody(response);
  }

  /// 登录链路请求头：App 身份头 + 登录 Jar 里的 Cookie 与 x-csrftoken。
  Map<String, String> _loginHeaders() {
    final headers = _baseHeaders();
    final cookie = _loginJar.header;
    if (cookie != null && cookie.isNotEmpty) {
      headers['Cookie'] = cookie;
      final csrf = _loginJar.value('csrftoken');
      if (csrf != null && csrf.isNotEmpty) {
        headers['x-csrftoken'] = csrf;
      }
      final session = _loginJar.value('sessionid');
      if (session != null && session.isNotEmpty) {
        headers['sessionid'] = session;
      }
    }
    return headers;
  }

  /// 取响应体里的 code（兼容 num / String）。
  int _code(Map<String, dynamic> data) {
    final c = data['code'];
    if (c is num) {
      return c.toInt();
    }
    if (c is String) {
      return int.tryParse(c) ?? -1;
    }
    return -1;
  }

  /// 获取当前用户信息。 [cookie] 若提供则以它作为会话，否则用内部会话。
  ///
  /// 雨课堂返回结构: `{ data: { user_profile: { user_id, name, school,
  /// phone_number, avatar } } }`。
  Future<Map<String, dynamic>?> fetchUserInfo({String? cookie}) async {
    final uri = Uri.parse(AppConfig.url(AppConfig.userInfoPath));
    final response = await _client
        .get(uri, headers: _authHeaders(cookie: cookie))
        .timeout(_timeout);
    if (response.statusCode != 200) {
      return null;
    }
    final data = _decodeBody(response);
    final userProfile = data['data'];
    final profile = userProfile is Map<String, dynamic>
        ? (userProfile['user_profile'] is Map<String, dynamic>
            ? userProfile['user_profile'] as Map<String, dynamic>
            : userProfile)
        : data;
    final uid = profile['user_id']?.toString();
    if (uid != null && uid.isNotEmpty) {
      _uid = uid;
    }
    return profile;
  }

  /// 获取课程列表。 [cookie] 为当前账户会话；提供则用它。
  Future<List<Course>> fetchCourses({String? cookie}) async {
    final uri = Uri.parse(AppConfig.url(AppConfig.courseListPath));
    final response = await _client
        .get(uri, headers: _authHeaders(cookie: cookie))
        .timeout(_timeout);
    final data = _decodeBody(response);
    final list = _extractList(data);
    return list.map((e) => Course.fromJson(e)).toList();
  }

  /// 获取某个课程的课件（幻灯片）列表。
  Future<List<Slide>> fetchSlides(Course course, {String? cookie}) async {
    final presentationId = course.presentationId ?? course.id;
    final uri = Uri.parse(AppConfig.url(AppConfig.courseSlidesPath)).replace(
      queryParameters: {'presentation_id': presentationId},
    );
    final response = await _client
        .get(uri, headers: _authHeaders(cookie: cookie))
        .timeout(_timeout);
    final data = _decodeBody(response);
    final list = _extractList(data);
    return [
      for (var i = 0; i < list.length; i++) Slide.fromJson(list[i], i)
    ];
  }

  // ---- 工具方法 ----

  /// 密码在发送前的预处理占位。真实平台可能需要 hash / RSA 等。
  String _encodePassword(String password) {
    // 目前按明文发送，按平台实际实现替换。
    return password;
  }

  Map<String, dynamic> _decodeBody(http.Response response) {
    try {
      final text = utf8.decode(response.bodyBytes);
      final obj = jsonDecode(text);
      if (obj is Map<String, dynamic>) {
        return obj;
      }
      return {'data': obj};
    } catch (_) {
      return {};
    }
  }

  List<dynamic> _extractList(Map<String, dynamic> data) {
    // 兼容 {data: [...]} 或 {data: {list: [...]}} 等结构。
    final d = data['data'];
    if (d is List) {
      return d;
    }
    if (d is Map<String, dynamic>) {
      // 雨课堂课程接口: { data: { onLessonClassrooms: [...] } }
      final inner = d['onLessonClassrooms'] ??
          d['list'] ??
          d['courses'] ??
          d['slides'] ??
          d['course_list'];
      if (inner is List) {
        return inner;
      }
    }
    final list = data['list'] ?? data['courses'] ?? data['slides'];
    if (list is List) {
      return list;
    }
    return [];
  }

  String? _pickString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final v = map[key];
      if (v != null && '$v'.isNotEmpty) {
        return '$v';
      }
      // 也查找嵌套 data。
      final d = map['data'];
      if (d is Map<String, dynamic>) {
        final v2 = d[key];
        if (v2 != null && '$v2'.isNotEmpty) {
          return '$v2';
        }
      }
    }
    return null;
  }
}
