import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'pages/account_list_page.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

/// 应用根组件。
class RainClassroomApp extends StatelessWidget {
  const RainClassroomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppState>(
      create: (_) {
        final state = AppState();
        state.load();
        return state;
      },
      child: MaterialApp(
        title: '雨课堂助手',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme(),
        darkTheme: AppTheme.darkTheme(),
        home: const AccountListPage(),
      ),
    );
  }
}
