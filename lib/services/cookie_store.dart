import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

/// Cookie / 会话令牌的本地存储。
///
/// 出于构建兼容性（本项目路径含空格，且 `flutter_secure_storage` 会引入
/// `objective_c` / native-assets 导致无法打包），这里使用 [shared_preferences]
/// 并以 Base64 编码保存 Cookie，避免明文落盘。若部署环境无空格路径且可启用
/// 加密存储，可换回 `flutter_secure_storage`，本类接口保持不变。
class CookieStore {
  CookieStore({SharedPreferences? prefs}) : _prefs = prefs;

  final SharedPreferences? _prefs;

  static const _prefix = AppConfig.cookieStorePrefix;

  Future<SharedPreferences> get _prefsAsync async =>
      _prefs ?? await SharedPreferences.getInstance();

  /// 保存某账户的会话 Cookie（Base64 编码后写入）。
  Future<void> save(String accountId, String cookie) async {
    if (cookie.isEmpty) {
      return;
    }
    final prefs = await _prefsAsync;
    // Base64 简单混淆，避免明文直接落盘。
    final encoded = base64Encode(utf8.encode(cookie));
    await prefs.setString('$_prefix$accountId', encoded);
  }

  /// 读取某账户的会话 Cookie。
  Future<String?> read(String accountId) async {
    final prefs = await _prefsAsync;
    final encoded = prefs.getString('$_prefix$accountId');
    if (encoded == null || encoded.isEmpty) {
      return null;
    }
    try {
      return utf8.decode(base64Decode(encoded));
    } catch (e) {
      debugPrint('CookieStore.read decode error: $e');
      return null;
    }
  }

  /// 删除某账户的会话 Cookie。
  Future<void> delete(String accountId) async {
    final prefs = await _prefsAsync;
    await prefs.remove('$_prefix$accountId');
  }

  /// 是否是有效的会话 Cookie 字符串（简单的非空 + 携带键值对判断）。
  static bool isValidCookie(String? cookie) {
    if (cookie == null || cookie.trim().isEmpty) {
      return false;
    }
    return cookie.contains('=');
  }
}
