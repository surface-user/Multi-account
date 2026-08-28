import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'platform.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 读回上次选择的雨课堂服务器（多服务器：雨课堂/荷塘/长江/黄河）。
  await PlatformManager().initialize();

  // 状态栏透明，配合整体美观。
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const RainClassroomApp());
}
