import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tencent_captcha/flutter_tencent_captcha.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../models/account.dart';
import '../platform.dart';
import '../state/app_state.dart';
import '../widgets/cookie_paste_dialog.dart';

/// 登录方式。
enum _LoginTab { password, sms, qr }

/// 登录 / 添加账户页面。
///
/// 完全仿照 course_helper 的三种登录方式：
/// - 密码登录（需先通过腾讯验证码，拿到 ticket + randstr）；
/// - 短信验证码登录（发送验证码也需腾讯验证码）；
/// - 二维码登录（微信扫码，轮询登录状态）。
///
/// 顶部可切换「雨课堂 / 荷塘 / 长江 / 黄河」服务器，登录与会话都绑定该服务器。
/// 若传入 [editAccount]，则该账户的登录态会被更新而非新增。
class AccountLoginPage extends StatefulWidget {
  const AccountLoginPage({super.key, this.editAccount});

  final Account? editAccount;

  @override
  State<AccountLoginPage> createState() => _AccountLoginPageState();
}

class _AccountLoginPageState extends State<AccountLoginPage> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _smsCtrl = TextEditingController();

  _LoginTab _tab = _LoginTab.password;
  bool _loading = false;

  // 腾讯验证码凭证（密码登录 / 发验证码 / 短信登录共用）。
  String? _ticket;
  String? _randstr;

  // 二维码登录状态。
  String? _qrToken;
  String? _qrImageUrl;
  bool _qrLoading = false;
  bool _qrActive = false;
  Timer? _qrTimer;

  // 当前选择的服务器（登录与会话绑定该服务器）。
  RainClassroomServerType _server = RainClassroomServerType.yuketang;

  // 验证码倒计时。
  int _countdown = 0;
  Timer? _countdownTimer;

  bool get _isEdit => widget.editAccount != null;

  @override
  void initState() {
    super.initState();
    _server = PlatformManager().currentServer;
    if (_isEdit) {
      _usernameCtrl.text = widget.editAccount!.username;
      _server = widget.editAccount!.server;
    }
    // 初始化腾讯验证码 SDK。
    try {
      TencentCaptcha.init(AppConfig.tCaptchaAppId);
    } catch (_) {}
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _smsCtrl.dispose();
    _qrTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  /// 腾讯验证码：弹出并等待用户完成，成功后把 ticket/randstr 存到字段。
  Future<bool> _showTencentCaptcha() async {
    final config = TencentCaptchaConfig(
      bizState: 'tencent-captcha',
      enableDarkMode: Theme.of(context).brightness == Brightness.dark,
    );
    final completer = Completer<bool>();
    try {
      await TencentCaptcha.verify(
        config: config,
        onSuccess: (data) {
          _ticket = data?['ticket']?.toString();
          _randstr = data?['randstr']?.toString();
          if (_ticket != null && _randstr != null) {
            completer.complete(true);
          } else {
            completer.complete(false);
          }
        },
        onFail: (data) {
          _toast('验证失败：${data?['errorMessage'] ?? '请重试'}');
          completer.complete(false);
        },
      );
    } catch (e) {
      _toast('验证异常：$e');
      completer.complete(false);
    }
    return completer.future;
  }

  /// 确保腾讯验证码凭证有效。
  Future<bool> _ensureCaptcha() async {
    if (_ticket != null && _randstr != null) {
      return true;
    }
    return _showTencentCaptcha();
  }

  /// 密码登录.
  Future<void> _loginPassword() async {
    final account = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (account.isEmpty) {
      _toast('请输入账号');
      return;
    }
    if (password.isEmpty) {
      _toast('请输入密码');
      return;
    }
    final okCaptcha = await _ensureCaptcha();
    if (!okCaptcha) {
      return;
    }
    await _run(() async {
      final state = context.read<AppState>();
      final data = await state.api.loginPassword(
          account, password, _ticket!, _randstr!);
      if (data != null && data['code'] == 0) {
        final result = await state.persistLogin(
          username: account,
          server: _server,
          editAccountId: widget.editAccount?.id,
        );
        _finish(result.ok, result.message);
      } else {
        _toast(_msg(data) ?? '登录失败，请检查账号密码');
      }
    });
  }

  /// 短信验证码登录.
  Future<void> _loginSms() async {
    final phone = _usernameCtrl.text.trim();
    final code = _smsCtrl.text.trim();
    if (phone.isEmpty) {
      _toast('请输入手机号');
      return;
    }
    if (code.isEmpty) {
      _toast('请输入验证码');
      return;
    }
    await _run(() async {
      final state = context.read<AppState>();
      // 先校验短信验证码。
      final verify = await state.api.verifySmsCode(phone, code);
      if (verify == null || verify['code'] != 0) {
        _toast(_msg(verify) ?? '验证码验证失败');
        return;
      }
      final data = await state.api.loginCode(phone, code, _ticket ?? '', _randstr ?? '');
      if (data != null && data['code'] == 0) {
        final result = await state.persistLogin(
          username: phone,
          server: _server,
          editAccountId: widget.editAccount?.id,
        );
        _finish(result.ok, result.message);
      } else {
        _toast(_msg(data) ?? '登录失败，请检查验证码');
      }
    });
  }

  /// 发送短信验证码。
  Future<void> _sendSmsCode() async {
    final phone = _usernameCtrl.text.trim();
    if (phone.isEmpty) {
      _toast('请输入手机号');
      return;
    }
    final okCaptcha = await _ensureCaptcha();
    if (!okCaptcha) {
      return;
    }
    await _run(() async {
      final state = context.read<AppState>();
      final data =
          await state.api.sendSmsCode(phone, _ticket!, _randstr!);
      if (data != null && data['code'] == 0) {
        _toast('验证码已发送');
        _startCountdown();
      } else {
        _toast(_msg(data) ?? '发送验证码失败');
      }
    });
  }

  /// 二维码登录：获取二维码，开轮询，显示图片+刷新+取消。
  Future<void> _startQr() async {
    setState(() => _qrLoading = true);
    _qrActive = true;
    _qrToken = null;
    _qrImageUrl = null;
    _qrTimer?.cancel();
    try {
      final state = context.read<AppState>();
      final data = await state.api.getQRCodeData();
      if (!mounted) {
        return;
      }
      if (data == null) {
        _toast('获取二维码失败');
        setState(() => _qrLoading = false);
        return;
      }
      setState(() {
        _qrToken = data['token']?.toString();
        _qrImageUrl = data['qrImage']?.toString();
        _qrLoading = false;
      });
      _startQrPolling();
    } catch (e) {
      if (!mounted) {
        return;
      }
      _toast('获取二维码异常：$e');
      setState(() => _qrLoading = false);
    }
  }

  void _startQrPolling() {
    _qrTimer?.cancel();
    _qrTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _pollQr();
    });
  }

  Future<void> _pollQr() async {
    if (!_qrActive || _qrToken == null) {
      return;
    }
    try {
      final state = context.read<AppState>();
      final data = await state.api.loginQRCode(_qrToken!);
      if (!mounted) {
        return;
      }
      if (data != null) {
        // 扫码成功：持久化账户。
        _qrTimer?.cancel();
        _qrActive = false;
        final result = await state.persistLogin(
          username: null,
          server: _server,
          editAccountId: widget.editAccount?.id,
        );
        _finish(result.ok, result.message);
        return;
      }
      // 超时/未扫码，刷新二维码。
      await _refreshQr();
    } catch (e) {
      if (!mounted) {
        return;
      }
      debugPrint('二维码轮询失败: $e');
    }
  }

  Future<void> _refreshQr() async {
    if (!_qrActive) {
      return;
    }
    try {
      final state = context.read<AppState>();
      final data = await state.api.getQRCodeData();
      if (mounted && data != null) {
        setState(() {
          _qrToken = data['token']?.toString();
          _qrImageUrl = data['qrImage']?.toString();
        });
      }
    } catch (_) {}
  }

  void _cancelQr() {
    _qrActive = false;
    _qrTimer?.cancel();
  }

  /// 统一执行 + loading 管理。
  Future<void> _run(Future<void> Function() action) async {
    if (_loading) {
      return;
    }
    setState(() => _loading = true);
    try {
      await action();
    } catch (e) {
      _toast('操作失败：$e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _finish(bool ok, String message) {
    if (mounted) {
      _toast(message, ok: ok);
      if (ok) {
        Navigator.of(context).pop(true);
      }
    }
  }

  void _startCountdown() {
    _countdown = 60;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        t.cancel();
      }
    });
  }

  /// 粘贴 Cookie 兜底。仍走「手动 Cookie」路径。
  Future<void> _pasteCookie() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const CookiePasteDialog(),
    );
    if (result != null) {
      await _run(() async {
        final state = context.read<AppState>();
        final msg = await state.addWithCookie(
          result['username'] ?? '',
          result['cookie'] ?? '',
          server: _server,
        );
        _finish(msg.ok, msg.message);
      });
    }
  }

  void _toast(String message, {bool ok = false}) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: ok ? Colors.green.shade600 : null,
      ),
    );
  }

  String? _msg(Map<String, dynamic>? data) {
    for (final k in ['msg', 'message', 'error']) {
      final v = data?[k];
      if (v != null && '$v'.isNotEmpty && '$v' != 'null') {
        return '$v';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? '更新登录态' : '登录 / 添加账户'),
        actions: [
          IconButton(
            tooltip: '粘贴 Cookie 登录',
            icon: const Icon(Icons.content_paste),
            onPressed: _pasteCookie,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ServerSelector(
              current: _server,
              onChanged: (s) {
                setState(() => _server = s);
              },
            ),
            const SizedBox(height: 20),
            SegmentedButton<_LoginTab>(
              segments: const [
                ButtonSegment(value: _LoginTab.password, label: Text('密码登录')),
                ButtonSegment(value: _LoginTab.sms, label: Text('验证码登录')),
                ButtonSegment(value: _LoginTab.qr, label: Text('二维码登录')),
              ],
              selected: {_tab},
              onSelectionChanged: (s) {
                setState(() => _tab = s.first);
                if (s.first == _LoginTab.qr) {
                  _startQr();
                }
              },
            ),
            const SizedBox(height: 24),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _tab == _LoginTab.password
                  ? _buildPassword(scheme)
                  : _tab == _LoginTab.sms
                      ? _buildSms(scheme)
                      : _buildQr(scheme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPassword(ColorScheme scheme) {
    return Column(
      key: const ValueKey('pw'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _usernameCtrl,
          decoration: const InputDecoration(
            labelText: '手机号 / 邮箱 / 学号',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordCtrl,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: '密码',
            prefixIcon: Icon(Icons.lock_outline),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _loading ? null : _loginPassword,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: _loading
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('登录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 12),
        Text(
          '密码登录需先通过腾讯验证码；若服务器要求，可用下方「粘贴 Cookie」兜底。',
          style: TextStyle(fontSize: 12, color: scheme.outline),
        ),
      ],
    );
  }

  Widget _buildSms(ColorScheme scheme) {
    return Column(
      key: const ValueKey('sms'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _usernameCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: '手机号',
            prefixIcon: Icon(Icons.phone_iphone),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _smsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '验证码',
                  prefixIcon: Icon(Icons.sms_outlined),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 56,
              child: OutlinedButton(
                onPressed:
                    (_countdown > 0 || _loading) ? null : _sendSmsCode,
                child: Text(_countdown > 0 ? '$_countdown 秒' : '获取验证码'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _loading ? null : _loginSms,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: _loading
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('登录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildQr(ColorScheme scheme) {
    return Column(
      key: const ValueKey('qr'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 240,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: _qrLoading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 8),
                      Text('生成中...', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                )
              : (_qrImageUrl != null && _qrImageUrl!.isNotEmpty)
                  ? Center(
                      child: Image.network(_qrImageUrl!, fit: BoxFit.contain),
                    )
                  : const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.qr_code, size: 72),
                          SizedBox(height: 8),
                          Text('使用微信扫码登录', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
        ),
        const SizedBox(height: 12),
        Text(
          '请用微信「扫一扫」扫描上方二维码，并在手机上确认登录。',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: scheme.outline),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _qrLoading ? null : _refreshQr,
              icon: const Icon(Icons.refresh),
              label: const Text('刷新二维码'),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: _cancelQr,
              child: const Text('取消'),
            ),
          ],
        ),
      ],
    );
  }
}

/// 服务器选择器（雨课堂 / 荷塘 / 长江 / 黄河）。
class _ServerSelector extends StatelessWidget {
  const _ServerSelector({required this.current, required this.onChanged});

  final RainClassroomServerType current;
  final ValueChanged<RainClassroomServerType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '服务器：${PlatformManager.serverName(current)}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in RainClassroomServerType.values)
                ChoiceChip(
                  label: Text(PlatformManager.serverName(s)),
                  selected: current == s,
                  onSelected: (_) => onChanged(s),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
