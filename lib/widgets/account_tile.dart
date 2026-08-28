import 'package:flutter/material.dart';

import '../models/account.dart';
import '../utils/string_utils.dart';

/// 账户列表条目。
class AccountTile extends StatelessWidget {
  const AccountTile({
    super.key,
    required this.account,
    required this.isCurrent,
    required this.onTap,
    required this.onDelete,
    required this.onEdit,
  });

  final Account account;
  final bool isCurrent;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final avatarBg =
        isCurrent ? scheme.primary : scheme.surfaceContainerHighest;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: avatarBg,
                foregroundColor: isCurrent ? scheme.onPrimary : scheme.onSurface,
                child: Text(
                  StringUtils.initialOf(account.displayName),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            account.displayName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (isCurrent) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '当前',
                              style: TextStyle(
                                fontSize: 11,
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      account.username,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (account.school.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.school_outlined,
                              size: 13, color: scheme.primary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              account.school,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          account.hasLogin
                              ? Icons.cloud_done_outlined
                              : Icons.cloud_off_outlined,
                          size: 14,
                          color: account.hasLogin
                              ? Colors.green
                              : scheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          account.hasLogin ? '已登录' : '未登录',
                          style: TextStyle(
                            fontSize: 12,
                            color: account.hasLogin
                                ? Colors.green
                                : scheme.outline,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(Icons.dns_outlined, size: 13, color: scheme.outline),
                        const SizedBox(width: 4),
                        Text(
                          account.serverName,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.outline,
                          ),
                        ),
                        if (!account.isRegistered) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: scheme.errorContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '未注册',
                              style: TextStyle(
                                fontSize: 11,
                                color: scheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '编辑',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: '删除',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, color: Colors.red),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
