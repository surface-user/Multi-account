import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/account.dart';
import '../platform.dart';
import '../services/account_store.dart';
import '../services/checkin_service.dart';
import '../services/cookie_store.dart';
import '../services/rain_api_service.dart';

/// 全局应用状态：管理账户列表、当前账户、会话 Cookie 以及各服务实例。
class AppState extends ChangeNotifier {
  AppState({
    AccountStore? accountStore,
    CookieStore? cookieStore,
    RainApiService? api,
    CheckinService? checkin,
  })  : _accountStore = accountStore ?? AccountStore(),
        _cookieStore = cookieStore ?? CookieStore(),
        api = api ?? RainApiService(),
        checkin = checkin ?? CheckinService();

  final AccountStore _accountStore;
  final CookieStore _cookieStore;
  final RainApiService api;
  final CheckinService checkin;

  static final _uuid = Uuid();

  List<Account> _accounts = [];
  String? _currentAccountId;
  bool _loaded = false;

  List<Account> get accounts => List.unmodifiable(_accounts);
  String? get currentAccountId => _currentAccountId;
  bool get loaded => _loaded;

  Account? get currentAccount {
    if (_currentAccountId == null) {
      return _accounts.isEmpty ? null : _accounts.first;
    }
    for (final a in _accounts) {
      if (a.id == _currentAccountId) {
        return a;
      }
    }
    return null;
  }

  Account? byId(String id) {
    for (final a in _accounts) {
      if (a.id == id) {
        return a;
      }
    }
    return null;
  }

  /// 启动时从本地加载账户，并**回填**各自的会话 Cookie（Cookie 单独加密存储，
  /// 不在账户 JSON 里，因此加载后需要从 [CookieStore] 读回，保证登录态指示正确）。
  Future<void> load() async {
    final stored = await _accountStore.loadAll();
    final hydrated = <Account>[];
    for (final account in stored) {
      final cookie = await _cookieStore.read(account.id);
      hydrated.add(cookie != null ? account.copyWith(cookie: cookie) : account);
    }
    _accounts = hydrated;
    if (_accounts.isNotEmpty && _currentAccountId == null) {
      _currentAccountId = _accounts.first.id;
      // 让全局服务器跟随当前账户，保证后续请求的 Cookie 域匹配。
      await PlatformManager().setServer(_accounts.first.server);
    }
    _loaded = true;
    notifyListeners();
  }

  /// 读取某账户的会话 Cookie。
  Future<String?> cookieOf(String id) => _cookieStore.read(id);

  /// 用账号密码登录并保存为新账户。
  Future<({bool ok, String message})> loginAndAdd(
      String username, String password) async {
    final result = await api.login(username, password);
    if (!result.success) {
      return (ok: false, message: result.message);
    }
    return (ok: true, message: await _persist(username, result));
  }

  /// 用手动粘贴的 Cookie 添加账户。
  Future<({bool ok, String message})> addWithCookie(
      String username, String cookie,
      {RainClassroomServerType server = RainClassroomServerType.yuketang}) async {
    if (!CookieStore.isValidCookie(cookie)) {
      return (ok: false, message: 'Cookie 无效，请重新粘贴');
    }
    api.setCookie(cookie);

    // 用 Cookie 拉一次用户信息：既能验证登录态有效，也能拿到真实姓名/uid/学校。
    String nickname = username;
    String? uid;
    String school = '';
    try {
      final user = await api.fetchUserInfo();
      if (user != null) {
        final name = user['name']?.toString();
        if (name != null && name.isNotEmpty) {
          nickname = name;
        }
        uid = user['user_id']?.toString();
        api.setUid(uid);
        school = user['school']?.toString() ?? '';
      }
    } catch (_) {
      // 拉取失败不阻断添加；仅用输入的 username 作为显示名。
    }

    final account = Account(
      id: _uuid.v4(),
      username: username,
      nickname: nickname,
      cookie: cookie,
      server: server,
      school: school,
      lastLoginAt: DateTime.now(),
      createdAt: DateTime.now(),
    );
    _accounts.add(account);
    await _cookieStore.save(account.id, cookie);
    await _accountStore.saveAll(_accounts);
    _currentAccountId = account.id;
    await PlatformManager().setServer(server);
    notifyListeners();
    return (ok: true, message: '已添加账户：$nickname');
  }

  /// 登录成功后持久化（复用已由 [RainApiService] 捕获的会话 Cookie）。
  ///
  /// [username] 为登录输入（手机号/邮箱/学号）；二维码登录时可为空，此时以
  /// 拉取到的用户昵称命名。[server] 为该账户所属服务器；[editAccountId] 若提供
  /// 则更新该账户的登录态而不是新增。
  Future<({bool ok, String message})> persistLogin({
    String? username,
    required RainClassroomServerType server,
    String? editAccountId,
    bool isRegistered = true,
  }) async {
    final cookie = api.lastLoginCookie;
    if (cookie == null || cookie.isEmpty) {
      return (ok: false, message: '登录未捕获到会话 Cookie');
    }
    api.setCookie(cookie);

    final fallback = (username != null && username.isNotEmpty) ? username : '扫码用户';
    String nickname = fallback;
    String? userId;
    String school = '';
    try {
      final profile = await api.fetchUserInfo();
      if (profile != null) {
        final name = profile['name']?.toString();
        if (name != null && name.isNotEmpty) {
          nickname = name;
        }
        userId = profile['user_id']?.toString();
        school = profile['school']?.toString() ?? '';
      }
    } catch (_) {
      // 拉取失败不阻断；仅用登录输入作为显示名。
    }

    // 二维码登录没有账号输入，不去重，每次都新增一个账户。
    final dedupKey = (username != null && username.isNotEmpty) ? username : null;

    Account target;
    if (editAccountId != null) {
      final idx = _accounts.indexWhere((a) => a.id == editAccountId);
      if (idx < 0) {
        return (ok: false, message: '未找到要更新的账户');
      }
      target = _accounts[idx].copyWith(
        nickname: nickname,
        userId: userId,
        cookie: cookie,
        server: server,
        isRegistered: isRegistered,
        school: school,
        lastLoginAt: DateTime.now(),
      );
      await _cookieStore.save(target.id, cookie);
    } else if (dedupKey != null) {
      final idx =
          _accounts.indexWhere((a) => a.username == dedupKey && a.server == server);
      if (idx >= 0) {
        target = _accounts[idx].copyWith(
          nickname: nickname,
          userId: userId,
          cookie: cookie,
          server: server,
          isRegistered: isRegistered,
          lastLoginAt: DateTime.now(),
        );
        await _cookieStore.save(target.id, cookie);
      } else {
        target = Account(
          id: _uuid.v4(),
          username: dedupKey,
          nickname: nickname,
          userId: userId,
          cookie: cookie,
          server: server,
          isRegistered: isRegistered,
          school: school,
          lastLoginAt: DateTime.now(),
          createdAt: DateTime.now(),
        );
        _accounts.add(target);
        await _cookieStore.save(target.id, cookie);
      }
    } else {
      target = Account(
        id: _uuid.v4(),
        username: nickname,
        nickname: nickname,
        userId: userId,
        cookie: cookie,
        server: server,
        isRegistered: isRegistered,
        school: school,
        lastLoginAt: DateTime.now(),
        createdAt: DateTime.now(),
      );
      _accounts.add(target);
      await _cookieStore.save(target.id, cookie);
    }
    _currentAccountId = target.id;
    await PlatformManager().setServer(server);
    await _accountStore.saveAll(_accounts);
    notifyListeners();
    return (ok: true, message: '登录成功：${target.displayName}');
  }

  /// 更新某账户的会话 Cookie。
  Future<void> updateCookie(String id, String cookie) async {
    final idx = _accounts.indexWhere((a) => a.id == id);
    if (idx < 0) {
      return;
    }
    _accounts[idx] = _accounts[idx].copyWith(
      cookie: cookie,
      lastLoginAt: DateTime.now(),
    );
    await _cookieStore.save(id, cookie);
    await _accountStore.saveAll(_accounts);
    notifyListeners();
  }

  /// 切换当前账户。
  Future<void> switchAccount(String id) async {
    final acc = byId(id);
    if (acc == null) {
      return;
    }
    _currentAccountId = id;
    // 切到该账户所属服务器，保证后续请求的 Cookie 域匹配。
    await PlatformManager().setServer(acc.server);
    notifyListeners();
  }

  /// 删除账户（连同其 Cookie）。
  Future<void> deleteAccount(String id) async {
    _accounts.removeWhere((a) => a.id == id);
    await _cookieStore.delete(id);
    if (_currentAccountId == id) {
      _currentAccountId = _accounts.isEmpty ? null : _accounts.first.id;
    }
    await _accountStore.saveAll(_accounts);
    notifyListeners();
  }

  /// 内部：把登录结果持久化为新账户。
  Future<String> _persist(String username, LoginResult result) async {
    // 存在同名账户则只更新 Cookie。
    final idx = _accounts.indexWhere((a) => a.username == username);
    if (idx >= 0) {
      _accounts[idx] = _accounts[idx].copyWith(
        cookie: result.cookie,
        userId: result.userId ?? _accounts[idx].userId,
        lastLoginAt: DateTime.now(),
      );
      await _cookieStore.save(_accounts[idx].id, result.cookie!);
      _currentAccountId = _accounts[idx].id;
      await _accountStore.saveAll(_accounts);
      notifyListeners();
      return '已更新账户 ${_accounts[idx].displayName} 的登录态';
    }

    final account = Account(
      id: _uuid.v4(),
      username: username,
      nickname: result.nickname ?? username,
      userId: result.userId,
      cookie: result.cookie,
      lastLoginAt: DateTime.now(),
      createdAt: DateTime.now(),
    );
    _accounts.add(account);
    await _cookieStore.save(account.id, result.cookie!);
    _currentAccountId = account.id;
    await _accountStore.saveAll(_accounts);
    notifyListeners();
    return '已添加账户 ${account.displayName}';
  }
}
