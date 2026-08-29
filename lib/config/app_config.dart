import '../platform.dart';

/// 应用全局配置。
///
/// 雨课堂接口属于第三方逆向接口，可能随平台升级而变化，所有地址统一收敛到这里，
/// 方便一键调整。
class AppConfig {
  AppConfig._();

  /// 腾讯验证码 AppId（雨课堂密码/验证码登录需 ticket+rand，仿 course_helper）。
  static const String tCaptchaAppId = '2091064951';

  /// 应用版本（「关于」页展示，与 pubspec.yaml 对齐）。
  static const String appVersion = '1.0.0+1';

  /// 开发者名称（「关于」页展示）。
  static const String developerName = 'surface-user';

  /// 开发者主页（「关于」页点击跳转）。
  static const String developerUrl = 'https://github.com/surface-user';

  /// 应用一句话简介。
  static const String appDescription = '一款用于雨课堂多账号管理与签到的工具。';

  /// 当前服务器主域（跟随 [PlatformManager] 的当前服务器，支持多服务器）。
  static String get baseUrl => PlatformManager().baseUrl;

  /// 统一用作 User-Agent，模拟常见的移动端浏览器 / 客户端。
  static const String userAgent =
      'Mozilla/5.0 (Linux; Android 12; SM-G998B) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  /// 登录接口（账号密码 / 验证码登录）。
  /// 注意：雨课堂密码登录需腾讯验证码 ticket/rand，纯脚本较难通过；
  /// 故 App 提供了「手动粘贴 Cookie」兜底登录。
  static const String loginPath = '/api/v3/user/login/app';

  /// 发送短信验证码接口。
  static const String smsCodeSendPath = '/api/v3/user/code/send';

  /// 校验短信验证码接口。
  static const String smsCodeVerifyPath = '/api/v3/user/code/verify';

  /// 获取二维码登录信息接口（返回 token + qrImage）。
  static const String qrPreInfoPath = '/api/v3/user/login/pre-info';

  /// 二维码登录轮询接口（body 带 token）。
  static const String qrLoginPath = '/api/v3/user/login';

  /// 获取当前用户信息接口。
  static const String userInfoPath = '/v/course_meta/user_info';

  /// 获取课程（上课中）接口。
  static const String courseListPath = '/api/v3/classroom/on-lesson';

  /// 获取课件（幻灯片）接口，需要 presentation_id 参数。
  static const String courseSlidesPath = '/api/v3/lesson/presentation/fetch';

  /// 二维码扫码接口（扫码签到第一步）。
  static const String scanPath = '/api/v3/app/scan';

  /// 签到上报接口。
  static const String checkinPath = '/api/v3/lesson/checkin';

  /// 登录后在本地存储会话时使用的名称前缀。
  static const String cookieStorePrefix = 'cookie_';

  /// 手动粘贴 Cookie 时的最大会话有效时间（天），仅用于展示。
  static const int cookieExpireDays = 7;

  /// 网络请求超时（秒）。
  static const int networkTimeoutSeconds = 15;

  /// 完整拼装 URL。
  static String url(String path) {
    if (path.startsWith('http')) {
      return path;
    }
    return '$baseUrl$path';
  }
}
