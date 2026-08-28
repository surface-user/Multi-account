import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/checkin_info.dart';

/// 签到结果。
class CheckinResult {
  CheckinResult({required this.success, this.message = ''});

  final bool success;
  final String message;

  static CheckinResult ok([String message = '签到成功']) =>
      CheckinResult(success: true, message: message);

  static CheckinResult fail(String message) =>
      CheckinResult(success: false, message: message);
}

/// 雨课堂扫码签到服务。
///
/// 真实流程为两步（依据 course_helper 逆向）：
///   1) POST /api/v3/app/scan      body: { url: <二维码内容> } → data.value = lessonId
///   2) POST /api/v3/lesson/checkin body: { source:21, lessonId, joinIfNotIn:true }
///      返回 code==0 表示签到成功。
///
/// 鉴权：雨课堂需要 Cookie + x-csrftoken + sessionid 头（仅带 Cookie 会失败）。
class CheckinService {
  CheckinService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration _timeout =
      const Duration(seconds: AppConfig.networkTimeoutSeconds);

  /// 执行扫码签到。 [cookie] 为当前账户的会话 Cookie。
  /// [info.raw] 即二维码扫描得到的 URL，作为第一步 scan 的 `url`。
  Future<CheckinResult> checkin(CheckinInfo info, String cookie) async {
    if (cookie.isEmpty) {
      return CheckinResult.fail('当前账户未登录（缺少会话 Cookie）');
    }
    final qrUrl = info.raw.trim();
    if (qrUrl.isEmpty) {
      return CheckinResult.fail('扫码结果为空，请重新扫码');
    }

    try {
      // 第一步：扫描，拿 lessonId。
      final lessonId = await _scan(qrUrl, cookie);
      if (lessonId == null || lessonId.isEmpty) {
        return CheckinResult.fail('未能从二维码解析出签到任务（二维码可能无效或已过期）');
      }

      // 第二步：上报签到。
      return await _checkin(lessonId, cookie);
    } catch (e) {
      return CheckinResult.fail('签到异常: $e');
    }
  }

  /// 是否解析出可上报的有效结果（二维码内容非空即可）。
  CheckinResult validate(CheckinInfo info) {
    if (info.raw.trim().isEmpty) {
      return CheckinResult.fail('未从二维码中解析出有效内容');
    }
    return CheckinResult.ok();
  }

  Future<String?> _scan(String qrUrl, String cookie) async {
    final uri = Uri.parse(AppConfig.url(AppConfig.scanPath));
    final body = {'url': qrUrl};
    final response = await _client
        .post(uri, headers: _headers(cookie), body: jsonEncode(body))
        .timeout(_timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }
    final data = _decodeBody(response);
    if (_code(data) != 0) {
      return null;
    }
    final value = data['data'];
    if (value is Map<String, dynamic>) {
      return value['value']?.toString();
    }
    return null;
  }

  Future<CheckinResult> _checkin(String lessonId, String cookie) async {
    final uri = Uri.parse(AppConfig.url(AppConfig.checkinPath));
    final body = {'source': 21, 'lessonId': lessonId, 'joinIfNotIn': true};
    final response = await _client
        .post(uri, headers: _headers(cookie), body: jsonEncode(body))
        .timeout(_timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return CheckinResult.fail('签到失败（HTTP ${response.statusCode}）');
    }
    final data = _decodeBody(response);
    if (_code(data) == 0) {
      return CheckinResult.ok(_pickMessage(data) ?? '签到成功');
    }
    final msg = _pickMessage(data) ?? '签到失败（${_code(data)}）';
    return CheckinResult.fail(msg);
  }

  /// 构造雨课堂 API 所需请求头：Cookie + x-csrftoken + sessionid。
  Map<String, String> _headers(String cookie) {
    final headers = {
      'User-Agent': AppConfig.userAgent,
      'Accept': 'application/json, text/plain, */*',
      'Content-Type': 'application/json; charset=utf-8',
      'Cookie': cookie,
    };
    final csrf = _cookieValue(cookie, 'csrftoken');
    final sssid = _cookieValue(cookie, 'sessionid');
    if (csrf != null && csrf.isNotEmpty) {
      headers['x-csrftoken'] = csrf;
    }
    if (sssid != null && sssid.isNotEmpty) {
      headers['sessionid'] = sssid;
    }
    return headers;
  }

  String? _cookieValue(String cookie, String name) {
    for (final item in cookie.split(';')) {
      final idx = item.indexOf('=');
      if (idx <= 0) {
        continue;
      }
      if (item.substring(0, idx).trim() == name) {
        var v = item.substring(idx + 1).trim();
        final semi = v.indexOf(';');
        if (semi >= 0) {
          v = v.substring(0, semi).trim();
        }
        return v;
      }
    }
    return null;
  }

  Map<String, dynamic> _decodeBody(http.Response response) {
    try {
      final obj = jsonDecode(utf8.decode(response.bodyBytes));
      return obj is Map<String, dynamic> ? obj : {'data': obj};
    } catch (_) {
      return {};
    }
  }

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

  String? _pickMessage(Map<String, dynamic> data) {
    final msg = data['message'] ?? data['msg'] ?? data['errmsg'];
    return msg != null ? '$msg' : null;
  }
}
