import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';

/// 「关于」页：应用名、版本、开发者（可点击跳转 GitHub）、简介。
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  Future<void> _openDeveloperLink(BuildContext context) async {
    final uri = Uri.tryParse(AppConfig.developerUrl);
    if (uri == null) {
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法打开开发者主页')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        children: [
          const SizedBox(height: 16),
          Center(
            child: CircleAvatar(
              radius: 38,
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              child: const Icon(Icons.school_outlined, size: 40),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              '雨课堂助手',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              '版本 ${AppConfig.appVersion}',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 28),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow(context, label: '简介', value: AppConfig.appDescription),
                  const Divider(height: 26),
                  Row(
                    children: [
                      const SizedBox(width: 56, child: Text('开发者')),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => _openDeveloperLink(context),
                            icon: const Icon(Icons.open_in_new, size: 16),
                            label: const Text(
                              AppConfig.developerName,
                              style: TextStyle(
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 26),
                  _infoRow(context, tag: '本工具为个人学习用', value: '非官方应用，接口可能随平台升级而失效。'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
    BuildContext context, {
    String? label,
    String? tag,
    required String value,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final leading = label ?? tag;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 56,
          child: Text(
            leading!,
            style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }
}
