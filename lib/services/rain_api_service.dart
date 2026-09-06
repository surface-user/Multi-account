import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../models/course.dart';
import '../models/slide.dart';
import '../platform.dart';

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
          success: true,
          cookie: cookie,
          message: message,
          userId: userId,
          nickname: nickname);
}

/// Cookie 会话的服务器验证结果。
///
/// [unavailable] 与 [expired] 必须分开：断网、超时或服务器故障时
/// 不能据此删除用户的 Cookie。
enum SessionValidationStatus { valid, expired, unavailable }

class SessionValidationResult {
  const SessionValidationResult._(this.status, {this.profile});

  final SessionValidationStatus status;
  final Map<String, dynamic>? profile;

  static SessionValidationResult valid(Map<String, dynamic> profile) =>
      SessionValidationResult._(
        SessionValidationStatus.valid,
        profile: profile,
      );

  static const expired =
      SessionValidationResult._(SessionValidationStatus.expired);

  static const unavailable =
      SessionValidationResult._(SessionValidationStatus.unavailable);
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
    return _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
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

  /// 持久化的设备 UUID，用作请求头 `uuid`（空串会被雨课堂视为非官方客户端）。
  String _uuid = '';

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
      'uuid': _uuid,
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

  Map<String, String> _authHeaders({
    String? cookie,
    String? uid,
    bool includeInternalSession = true,
  }) {
    final headers = _baseHeaders();
    final effective = cookie ?? (includeInternalSession ? _jar.header : null);
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
    // 优先用传入的账号 uid（重启后 *_uid 可能为空），保证多账号请求头 x-uid 正确。
    final effectiveUid = uid ?? (includeInternalSession ? _uid : null);
    if (effectiveUid != null && effectiveUid.isNotEmpty) {
      headers['x-uid'] = effectiveUid;
    }
    // 雨课堂鉴权优先用 Bearer Token（来自登录响应头 set-auth）。
    if (includeInternalSession &&
        _bearerToken != null &&
        _bearerToken!.isNotEmpty) {
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

  /// 加载并持久化设备 UUID（请求头 `uuid`），启动时调用一次即可。
  Future<String> ensureDeviceUuid() async {
    if (_uuid.isNotEmpty) {
      return _uuid;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      const key = 'rain_device_uuid';
      var saved = prefs.getString(key);
      if (saved == null || saved.isEmpty) {
        saved = const Uuid().v4();
        await prefs.setString(key, saved);
      }
      _uuid = saved;
    } catch (_) {
      // 读不到本地存储也生成一个，避免请求头 uuid 为空串。
      _uuid = const Uuid().v4();
    }
    return _uuid;
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
    var response =
        await _client.get(uri, headers: _loginHeaders()).timeout(_timeout);
    _logLogin('GET', AppConfig.qrPreInfoPath, null, response.statusCode,
        utf8.decode(response.bodyBytes, allowMalformed: true));
    if (_isAbnormalResponse(response)) {
      response =
          await _client.get(uri, headers: _loginHeaders()).timeout(_timeout);
      _logLogin(
          'GET(retry)',
          AppConfig.qrPreInfoPath,
          null,
          response.statusCode,
          utf8.decode(response.bodyBytes, allowMalformed: true));
    }
    if (_isAbnormalResponse(response)) {
      return _abnormalBody(response);
    }
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
    var response = await _client
        .post(uri, headers: _loginHeaders(), body: jsonEncode(jsonBody))
        .timeout(_timeout);
    _logLogin('POST', path, jsonBody, response.statusCode,
        utf8.decode(response.bodyBytes, allowMalformed: true));
    // 服务器偶发 404/5xx 空响应：重试一次；仍异常则返回明确错误信息（不再吞成空 map）。
    if (_isAbnormalResponse(response)) {
      response = await _client
          .post(uri, headers: _loginHeaders(), body: jsonEncode(jsonBody))
          .timeout(_timeout);
      _logLogin('POST(retry)', path, jsonBody, response.statusCode,
          utf8.decode(response.bodyBytes, allowMalformed: true));
    }
    final setAuth = response.headers['set-auth'];
    if (setAuth != null && setAuth.isNotEmpty) {
      _bearerToken = setAuth;
    }
    _loginJar.absorb(response);
    final cookie = _loginJar.header;
    if (cookie != null && cookie.isNotEmpty) {
      _lastLoginCookie = cookie;
    }
    if (_isAbnormalResponse(response)) {
      return _abnormalBody(response);
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

  // ---- 登录调试日志（采集各主域「已注册 / 未注册」响应，按时间裁剪，分析后可移除） ----
  static final List<_LoginLogEntry> _loginLogs = [];

  /// 日志仅保留最近 [kLogMaxAge] 内的条目，避免无限累积。
  static const Duration _logMaxAge = Duration(minutes: 10);

  /// 已收集的登录日志（供 UI「导出日志」复制到剪贴板）。
  String get loginLog {
    final b = StringBuffer();
    for (final e in _loginLogs) {
      b
        ..writeln(
            '[${e.time.toIso8601String()}] [${e.server}] ${e.method} ${e.path}')
        ..writeln('  req: ${e.reqBody ?? ''}')
        ..writeln('  http:${e.status}  resp: ${e.respBody}');
    }
    return b.toString();
  }

  /// 清空登录日志。
  void clearLoginLog() => _loginLogs.clear();

  /// 追加一条登录请求/响应日志，并剔除超过时间范围的旧日志。
  void _logLogin(String method, String path, Object? reqBody, int status,
      String respBody) {
    final now = DateTime.now();
    _loginLogs.add(_LoginLogEntry(now, PlatformManager().currentServer.name,
        method, path, reqBody, status, respBody));
    _loginLogs.removeWhere((e) => now.difference(e.time) > _logMaxAge);
  }

  /// 响应是否「异常」（非 2xx 或 200 但空 body）——用于识别服务器 404/5xx 空响应。
  bool _isAbnormalResponse(http.Response r) {
    if (r.statusCode < 200 || r.statusCode >= 300) {
      return true;
    }
    return utf8.decode(r.bodyBytes, allowMalformed: true).trim().isEmpty;
  }

  /// 读取响应体的「异常」提示。
  Map<String, dynamic> _abnormalBody(http.Response r) => {
        'code': -1,
        'msg': '服务器响应异常（HTTP ${r.statusCode}），请重试或切换服务器',
      };

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

  /// 登录态 GET 请求；服务器 404/5xx/空体时重试一次，仍异常返回 null。
  Future<http.Response?> _getWithRetry(Uri uri,
      {String? cookie, String? uid}) async {
    final headers = _authHeaders(cookie: cookie, uid: uid);
    var response = await _client.get(uri, headers: headers).timeout(_timeout);
    _logLogin('GET', uri.path, null, response.statusCode,
        utf8.decode(response.bodyBytes, allowMalformed: true));
    if (_isAbnormalResponse(response)) {
      response = await _client.get(uri, headers: headers).timeout(_timeout);
      _logLogin('GET(retry)', uri.path, null, response.statusCode,
          utf8.decode(response.bodyBytes, allowMalformed: true));
    }
    return _isAbnormalResponse(response) ? null : response;
  }

  /// 获取当前用户信息。 [cookie] 若提供则以它作为会话，否则用内部会话。
  ///
  /// 雨课堂返回结构: `{ data: { user_profile: { user_id, name, school,
  /// phone_number, avatar } } }`。
  Future<Map<String, dynamic>?> fetchUserInfo(
      {String? cookie, String? uid}) async {
    final uri = Uri.parse(AppConfig.url(AppConfig.userInfoPath));
    final response = await _getWithRetry(uri, cookie: cookie, uid: uid);
    if (response == null) {
      return null;
    }
    final data = _decodeBody(response);
    final profile = _extractUserProfile(data);
    final userId = profile['user_id']?.toString();
    if (userId != null && userId.isNotEmpty) {
      _uid = userId;
    }
    return profile;
  }

  /// 向用户信息接口发起一次轻量请求，验证指定 Cookie 是否仍有效。
  ///
  /// 只有服务器明确拒绝鉴权时才返回 [SessionValidationStatus.expired]；
  /// 网络异常、5xx 和无法识别的响应都返回 [SessionValidationStatus.unavailable]。
  Future<SessionValidationResult> validateSession({
    required String cookie,
    String? uid,
    RainClassroomServerType? server,
  }) async {
    if (cookie.trim().isEmpty) {
      return SessionValidationResult.expired;
    }

    final baseUrl = server == null
        ? AppConfig.baseUrl
        : PlatformManager.serverBaseUrlMap[server]!;
    final uri = Uri.parse('$baseUrl${AppConfig.userInfoPath}');

    try {
      final response = await _client
          .get(
            uri,
            headers: _authHeaders(
              cookie: cookie,
              uid: uid,
              includeInternalSession: false,
            ),
          )
          .timeout(_timeout);
      _logLogin(
        'GET(session-check)',
        uri.path,
        null,
        response.statusCode,
        utf8.decode(response.bodyBytes, allowMalformed: true),
      );

      if (response.statusCode == 401 || response.statusCode == 403) {
        return SessionValidationResult.expired;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return SessionValidationResult.unavailable;
      }

      final responseText =
          utf8.decode(response.bodyBytes, allowMalformed: true).trim();
      final contentType = response.headers['content-type']?.toLowerCase() ?? '';
      // 会话过期时，某些部署会跟随重定向并最终返回登录页 HTML。
      if (contentType.contains('text/html') || responseText.startsWith('<')) {
        return SessionValidationResult.expired;
      }

      final data = _decodeBody(response);
      if (_isAuthenticationFailure(data)) {
        return SessionValidationResult.expired;
      }
      if (_isAuthenticatedUserPayload(data)) {
        return SessionValidationResult.valid(_extractUserProfile(data));
      }
      return SessionValidationResult.unavailable;
    } catch (_) {
      return SessionValidationResult.unavailable;
    }
  }

  /// 拉取完整课程列表（learning_list），用于与 on-lesson 合并（仿 course_helper）。
  Future<List<Map<String, dynamic>>> _fetchLearningList(
      {String? cookie, String? uid}) async {
    final uri = Uri.parse(AppConfig.url(AppConfig.courseLearningListPath));
    final response = await _getWithRetry(uri, cookie: cookie, uid: uid);
    if (response == null) {
      return [];
    }
    final list = _extractList(_decodeBody(response));
    return [
      for (final e in list)
        if (e is Map<String, dynamic>) e
    ];
  }

  /// 获取课程列表。 [cookie] 为当前账户会话。
  ///
  /// 仿 course_helper：`learning_list` 给完整课程信息，`on-lesson` 给「上课中课程」
  /// 的 courseId + lessonId，二者按 courseId 合并，得到带 lesson_id 的当前课程。
  Future<List<Course>> fetchCourses({String? cookie, String? uid}) async {
    final fullCourses = await _fetchLearningList(cookie: cookie, uid: uid);
    final onLessonUri = Uri.parse(AppConfig.url(AppConfig.courseListPath));
    final onLessonResp =
        await _getWithRetry(onLessonUri, cookie: cookie, uid: uid);
    final onLessonItems = <Map<String, dynamic>>[];
    if (onLessonResp != null) {
      final list = _extractList(_decodeBody(onLessonResp));
      onLessonItems.addAll([
        for (final e in list)
          if (e is Map<String, dynamic>) e
      ]);
    }

    final coursesMap = {
      for (final c in fullCourses) '${c['course_id'] ?? c['id'] ?? ''}': c,
    };

    final result = <Course>[];
    for (final item in onLessonItems) {
      final courseId = '${item['courseId'] ?? item['course_id'] ?? ''}';
      final full = coursesMap[courseId];
      if (full == null) {
        continue;
      }
      // 把 on-lesson 的 lessonId 合并进完整课程信息，再解析。
      final merged = Map<String, dynamic>.from(full);
      final lessonId = item['lessonId'] ?? item['lesson_id'];
      if (lessonId != null) {
        merged['lesson_id'] = lessonId;
      }
      result.add(Course.fromJson(merged));
    }
    return result;
  }

  /// 获取某个课程的课件（幻灯片）列表。
  Future<List<Slide>> fetchSlides(Course course,
      {String? cookie, String? uid}) async {
    final presentationId = course.presentationId ?? course.id;
    final uri = Uri.parse(AppConfig.url(AppConfig.courseSlidesPath)).replace(
      queryParameters: {'presentation_id': presentationId},
    );
    final response = await _getWithRetry(uri, cookie: cookie, uid: uid);
    if (response == null) {
      return [];
    }
    final list = _extractList(_decodeBody(response));
    return [for (var i = 0; i < list.length; i++) Slide.fromJson(list[i], i)];
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

  Map<String, dynamic> _extractUserProfile(Map<String, dynamic> data) {
    final responseData = data['data'];
    if (responseData is Map<String, dynamic>) {
      final userProfile = responseData['user_profile'];
      if (userProfile is Map<String, dynamic>) {
        return userProfile;
      }
      return responseData;
    }
    return data;
  }

  bool _isAuthenticatedUserPayload(Map<String, dynamic> data) {
    final responseData = data['data'];
    if (responseData is Map<String, dynamic> &&
        responseData.containsKey('user_profile')) {
      // 未绑定高校的新账号可能返回 user_profile: null，
      // 但能返回该鉴权结构本身就说明会话仍有效。
      return true;
    }
    final profile = _extractUserProfile(data);
    return _pickString(profile, ['user_id', 'userId', 'uid']) != null;
  }

  bool _isAuthenticationFailure(Map<String, dynamic> data) {
    final code = _code(data);
    if (code == 401 || code == 403) {
      return true;
    }
    if (code == 0) {
      return false;
    }
    final message = '${data['message'] ?? data['msg'] ?? data['detail'] ?? ''}'
        .toLowerCase();
    return message.contains('未登录') ||
        message.contains('登录过期') ||
        message.contains('身份认证') ||
        message.contains('认证失败') ||
        message.contains('unauthorized') ||
        message.contains('not logged') ||
        message.contains('login required') ||
        message.contains('invalid session');
  }
}

/// 单条登录调试日志。
class _LoginLogEntry {
  _LoginLogEntry(this.time, this.server, this.method, this.path, this.reqBody,
      this.status, this.respBody);

  final DateTime time;
  final String server;
  final String method;
  final String path;
  final Object? reqBody;
  final int status;
  final String respBody;
}
