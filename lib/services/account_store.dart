import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/account.dart';

/// 账户列表的本地持久化（仅保存非敏感元数据，Cookie 见 [CookieStore]）。
///
/// 以一个 JSON 数组的形式存储于 `shared_preferences`，key 为 `accounts`。
class AccountStore {
  AccountStore({SharedPreferences? prefs}) : _prefs = prefs;

  final SharedPreferences? _prefs;

  static const _key = 'accounts';

  Future<SharedPreferences> get _prefsAsync async =>
      _prefs ?? await SharedPreferences.getInstance();

  /// 读取全部账户元数据。
  Future<List<Account>> loadAll() async {
    final prefs = await _prefsAsync;
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => Account.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // 解析失败则返回空列表，避免崩溃。
      return [];
    }
  }

  /// 保存全部账户元数据。
  Future<void> saveAll(List<Account> accounts) async {
    final prefs = await _prefsAsync;
    final raw = jsonEncode(accounts.map((a) => a.toJson()).toList());
    await prefs.setString(_key, raw);
  }
}
