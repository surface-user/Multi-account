import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/account.dart';
import '../state/app_state.dart';
import '../utils/string_utils.dart';
import '../widgets/account_tile.dart';
import 'about_page.dart';
import 'account_login_page.dart';
import 'course_list_page.dart';
import 'qr_checkin_page.dart';

/// 应用主页面：管理多账户，并提供进入「签到 / 课件」等功能的入口。
class AccountListPage extends StatelessWidget {
  const AccountListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final current = state.currentAccount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('雨课堂助手'),
        actions: [
          IconButton(
            tooltip: '添加账户',
            icon: const Icon(Icons.add),
            onPressed: () => _openLogin(context),
          ),
          PopupMenuButton<String>(
            tooltip: '更多',
            onSelected: (value) {
              if (value == 'about') {
                showAboutInfo(context);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'about',
                child: Text('关于'),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => state.load(),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            if (current != null) _CurrentAccountCard(account: current),
            if (state.accounts.isEmpty)
              const _EmptyState()
            else ...[
              const _SectionHeader(title: '全部账户'),
              for (final account in state.accounts)
                AccountTile(
                  account: account,
                  isCurrent: account.id == state.currentAccountId,
                  onTap: () => state.switchAccount(account.id),
                  onEdit: () => _editCookie(context, account),
                  onDelete: () =>
                      _confirmDelete(context, state, account),
                ),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openLogin(context),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('添加账户'),
      ),
    );
  }

  void _openLogin(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AccountLoginPage()),
    );
  }

  void _editCookie(BuildContext context, Account account) {
    // 复用登录页的逻辑：只要编辑 Cookie，就跳转到登录页并传入账户。
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AccountLoginPage(editAccount: account),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, AppState state, Account account) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除账户'),
        content: Text('确定删除「${account.displayName}」吗？其登录态也会一并移除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await state.deleteAccount(account.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已删除 ${account.displayName}')),
        );
      }
    }
  }
}

class _CurrentAccountCard extends StatelessWidget {
  const _CurrentAccountCard({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.primary.withValues(alpha: 0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '当前账户',
            style: TextStyle(
              color: scheme.onPrimary.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white.withValues(alpha: 0.25),
                child: Text(
                  StringUtils.initialOf(account.displayName),
                  style: TextStyle(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.displayName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      account.username,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onPrimary.withValues(alpha: 0.85),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.dns_outlined,
                              size: 13, color: scheme.onPrimary),
                          const SizedBox(width: 4),
                          Text(
                            account.serverName,
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onPrimary,
                            ),
                          ),
                          if (!account.isRegistered) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '未注册',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (account.school.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.school_outlined,
                              size: 14,
                              color: scheme.onPrimary.withValues(alpha: 0.9)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              account.school,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onPrimary.withValues(alpha: 0.9),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                account.hasLogin
                    ? Icons.verified_user
                    : Icons.help_outline,
                color: scheme.onPrimary,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.qr_code_scanner,
                  label: '扫码签到',
                  onTap: () {
                    if (!account.hasLogin) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('请先登录该账户')),
                      );
                      return;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const QRCheckinPage()),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  icon: Icons.slideshow,
                  label: '课件 & PPT',
                  onTap: () {
                    if (!account.hasLogin) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('请先登录该账户')),
                      );
                      return;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CourseListPage()),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: scheme.onPrimary),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: scheme.onPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: [
          Icon(Icons.account_circle_outlined,
              size: 72, color: scheme.outline),
          const SizedBox(height: 12),
          Text(
            '还没有账户',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '点击右下角添加你的雨课堂账号',
            style: TextStyle(color: scheme.outline),
          ),
        ],
      ),
    );
  }
}
