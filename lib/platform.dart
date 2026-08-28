import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 雨课堂服务器类型枚举。
///
/// 对应 course_helper 的 `RainClassroomServerType`：不同校区使用不同主域，
/// 登录鉴权与 Cookie 都绑定在该域下。
enum RainClassroomServerType {
  yuketang, // 雨课堂
  pro, // 荷塘.雨课堂
  changjiang, // 长江.雨课堂
  huanghe, // 黄河.雨课堂
}

/// 平台状态管理器。
///
/// 全局只有一个「当前服务器」，登录、拉课程、签到都走该服务器主域。
/// 每个账户记住自己的服务器，切换账户时会把全局服务器切到该账户的服务器，
/// 从而保证 Cookie 域匹配。
class PlatformManager {
  PlatformManager._();

  static final PlatformManager _instance = PlatformManager._();

  factory PlatformManager() => _instance;

  static const _serverKey = 'current_server';

  RainClassroomServerType _currentServer = RainClassroomServerType.yuketang;

  RainClassroomServerType get currentServer => _currentServer;

  /// 各服务器主域。
  static const Map<RainClassroomServerType, String> serverBaseUrlMap = {
    RainClassroomServerType.yuketang: 'https://www.yuketang.cn',
    RainClassroomServerType.pro: 'https://pro.yuketang.cn',
    RainClassroomServerType.changjiang: 'https://changjiang.yuketang.cn',
    RainClassroomServerType.huanghe: 'https://huanghe.yuketang.cn',
  };

  /// 当前服务器主域。
  String get baseUrl => serverBaseUrlMap[_currentServer]!;

  /// 启动时从本地读回上次选择的服务器。
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_serverKey);
      if (saved != null && saved.isNotEmpty) {
        for (final s in RainClassroomServerType.values) {
          if (s.name == saved) {
            _currentServer = s;
            break;
          }
        }
      }
    } catch (e) {
      debugPrint('加载服务器设置失败：$e');
    }
  }

  /// 切换服务器并持久化。
  Future<bool> setServer(RainClassroomServerType server) async {
    if (_currentServer == server) {
      return false;
    }
    _currentServer = server;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_serverKey, server.name);
    } catch (e) {
      debugPrint('保存服务器设置失败：$e');
    }
    return true;
  }

  /// 服务器展示名称。
  static String serverName(RainClassroomServerType server) {
    switch (server) {
      case RainClassroomServerType.yuketang:
        return '雨课堂';
      case RainClassroomServerType.pro:
        return '荷塘.雨课堂';
      case RainClassroomServerType.changjiang:
        return '长江.雨课堂';
      case RainClassroomServerType.huanghe:
        return '黄河.雨课堂';
    }
  }

  /// 从字符串解析（用于账户持久化），没有匹配则回退默认。
  static RainClassroomServerType parse(String? name) {
    for (final s in RainClassroomServerType.values) {
      if (s.name == name) {
        return s;
      }
    }
    return RainClassroomServerType.yuketang;
  }
}
