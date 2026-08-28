import 'package:flutter/material.dart';

/// 手动粘贴 Cookie 的对话框。这是自动登录接口失效时的兜底方式。
class CookiePasteDialog extends StatefulWidget {
  const CookiePasteDialog({super.key});

  @override
  State<CookiePasteDialog> createState() => _CookiePasteDialogState();
}

class _CookiePasteDialogState extends State<CookiePasteDialog> {
  final _usernameCtrl = TextEditingController();
  final _cookieCtrl = TextEditingController();

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _cookieCtrl.dispose();
    super.dispose();
  }

  /// 返回 {username, cookie}，为空表示取消。
  Map<String, String>? _submit() {
    final username = _usernameCtrl.text.trim();
    final cookie = _cookieCtrl.text.trim();
    if (username.isEmpty || cookie.isEmpty) {
      return null;
    }
    return {'username': username, 'cookie': cookie};
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('手动粘贴 Cookie'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '在浏览器登录雨课堂后，从开发者工具中复制 Cookie 字符串粘贴到下面。',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _usernameCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '用户名 / 备注',
              hintText: '例如 13800138000',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _cookieCtrl,
            maxLines: 4,
            minLines: 3,
            decoration: const InputDecoration(
              labelText: 'Cookie',
              hintText: 'name=value; name2=value2',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.cookie_outlined),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
          ),
          onPressed: () {
            final result = _submit();
            if (result != null) {
              Navigator.pop(context, result);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('请填写用户名与 Cookie'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
