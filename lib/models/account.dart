import '../platform.dart';

/// 账户模型。
///
/// 一个账户代表一个雨课堂账号。为安全起见，**非敏感**的元数据（用户名、昵称、
/// 用户ID 等）保存在 `shared_preferences`，而**会话 Cookie** 单独加密保存在
/// [flutter_secure_storage]（见 [CookieStore]），这里仅持有 Cookie 的引用。
class Account {
  Account({
    required this.id,
    required this.username,
    required this.nickname,
    this.userId,
    this.avatarUrl,
    this.cookie,
    this.server = RainClassroomServerType.yuketang,
    this.isRegistered = true,
    this.lastLoginAt,
    required this.createdAt,
  });

  /// 本地唯一 ID（UUID）。
  final String id;

  /// 用户名 / 手机号 / 学号 / 邮箱。
  final String username;

  /// 昵称（登录后从平台解析，或由用户填写）。
  final String nickname;

  /// 雨课堂平台用户 ID（登录成功后才有）。
  final String? userId;

  /// 头像地址。
  final String? avatarUrl;

  /// 会话 Cookie 字符串。
  final String? cookie;

  /// 账户所属服务器（切换账户时会把全局服务器切到该服务器，保证 Cookie 域匹配）。
  final RainClassroomServerType server;

  /// 是否已注册 / 绑定高校。false 表示登录成功但资料为空（未绑定高校，无法正常签到）。
  final bool isRegistered;

  /// 最近一次登录时间。
  final DateTime? lastLoginAt;

  /// 创建时间。
  final DateTime createdAt;

  /// 是否已包含有效的会话 Cookie。
  bool get hasLogin => cookie != null && cookie!.isNotEmpty;

  /// 展示名称。
  String get displayName => nickname.isNotEmpty ? nickname : username;

  /// 所属服务器展示名。
  String get serverName => PlatformManager.serverName(server);

  Account copyWith({
    String? nickname,
    String? userId,
    String? avatarUrl,
    String? cookie,
    RainClassroomServerType? server,
    bool? isRegistered,
    DateTime? lastLoginAt,
  }) {
    return Account(
      id: id,
      username: username,
      nickname: nickname ?? this.nickname,
      userId: userId ?? this.userId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      cookie: cookie ?? this.cookie,
      server: server ?? this.server,
      isRegistered: isRegistered ?? this.isRegistered,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'nickname': nickname,
      'userId': userId,
      'avatarUrl': avatarUrl,
      'server': server.name,
      'isRegistered': isRegistered,
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      // 注意: Cookie 不写入 JSON，单独安全存储。
    };
  }

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] as String,
      username: json['username'] as String,
      nickname: json['nickname'] as String? ?? '',
      userId: json['userId'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      server: PlatformManager.parse(json['server'] as String?),
      isRegistered: json['isRegistered'] as bool? ?? true,
      lastLoginAt: json['lastLoginAt'] == null
          ? null
          : DateTime.tryParse(json['lastLoginAt'] as String),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
              DateTime.now(),
    );
  }

  @override
  String toString() => 'Account($username, $nickname)';
}
