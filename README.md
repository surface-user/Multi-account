# 雨课堂助手 (Rain Classroom Helper)

一个基于 **Flutter** 开发、同时支持 **Android** 与 **iOS** 的雨课堂（雨课堂 / 学堂在线）统一管理工具。

## 功能

- **多账户管理**：添加、保存、切换、删除多个雨课堂账号。
- **Cookie 登录态本地持久化**：登录成功后捕获并（加密）本地保存会话 Cookie，下一次可直接使用；
  也支持手动粘贴浏览器 Cookie 作为兜底登录方式。
- **动态二维码签到**：调用摄像头扫描教师端动态二维码，解析签到信息并上报到雨课堂云端平台。
- **PPT / 课件整页查看**：拉取课程课件（幻灯片）列表，以整页可翻页方式浏览全部 PPT。

## 目录结构

```
rain_classroom_helper/
├── pubspec.yaml                  # 依赖与工程配置
├── analysis_options.yaml         # lint 配置
├── assets/images/                # 应用内置图片资源
├── platform-config/              # Android / iOS 权限与平台配置（见其 README）
└── lib/
    ├── main.dart                 # 应用入口
    ├── app.dart                  # MaterialApp / 主题 / 路由
    ├── config/
    │   └── app_config.dart       # 后端接口配置
    ├── models/
    │   ├── account.dart          # 账户模型
    │   ├── course.dart           # 课程模型
    │   ├── checkin_info.dart     # 签到信息模型
    │   └── slide.dart            # 课件幻灯片模型
    ├── state/
    │   └── app_state.dart        # 全局 Provider 状态
    ├── services/
    │   ├── cookie_store.dart     # Cookie / 会话安全存储
    │   ├── account_store.dart    # 账户列表本地持久化
    │   ├── rain_api_service.dart # 雨课堂 HTTP API（登录 / 课程 / 课件）
    │   └── checkin_service.dart  # 二维码签到上报
    ├── pages/
    │   ├── account_list_page.dart # 账户管理首页
    │   ├── account_login_page.dart# 登录 / 添加账户页
    │   ├── home_page.dart         # 登录后主页面
    │   ├── course_list_page.dart  # 课程列表页
    │   ├── qr_checkin_page.dart   # 二维码签到页
    │   └── ppt_viewer_page.dart   # PPT 整页查看页
    └── widgets/
        ├── account_tile.dart      # 账户条目
        └── cookie_paste_dialog.dart # 手动粘贴 Cookie 对话框
```

## 快速开始

### 1. 安装 Flutter SDK（如果你尚未安装）

到 <https://docs.flutter.dev/get-started/install> 下载并安装 Flutter
（建议 3.27+，Dart 3.6+），并安装好 Android Studio / Xcode 及对应平台的工具链。

### 2. 补全平台脚手架（本仓库只包含与功能相关的平台配置）

在项目根目录执行以下命令，让 Flutter 自动生成缺失的 `android/`、`ios/` 运行时工程骨架：

```bash
flutter create . --platforms=android,ios --org com.rainclassroom
```

> `flutter create .` 只会创建缺失的平台文件，**不会**覆盖 `lib/`、`pubspec.yaml` 中已有的内容。
> 执行后请按照 [`platform-config/README.md`](platform-config/README.md) 把 Android 权限
> 与 iOS 权限配置（相机、网络）合并到生成的清单 / Info.plist 中。

### 3. 应用平台权限配置

参见 [`platform-config/`](platform-config/)：
- Android：`android/app/src/main/AndroidManifest.xml` 中加入 `INTERNET` / `CAMERA` 权限。
- iOS：`ios/Runner/Info.plist` 中加入 `NSCameraUsageDescription`。

### 4. 安装依赖

```bash
flutter pub get
```

### 5. 运行

```bash
flutter run          # 在有连接的真机 / 模拟器上运行
```

### 6. 一键打包并安装到安卓真机（数据线）

在已安装 Flutter、Android 工具链并**连接好开启 USB 调试的手机**后，在项目根目录执行：

```powershell
.\build_and_install.ps1                # debug 构建、安装、启动
.\build_and_install.ps1 -Mode release  # release 构建
```

脚本会：检查 Flutter 与设备 -> `flutter create` 补全 android 平台脚手架 ->
注入 `INTERNET` / `CAMERA` 权限 -> `flutter pub get` -> `flutter build apk` ->
`adb install -r` 安装 -> 自动启动应用。

> 手机端必须开启「开发者选项」->「USB 调试」，并在弹窗中允许该电脑调试。
> 首次构建需联网下载 Gradle 与依赖，请保持网络畅通。

## 关于雨课堂 API

雨课堂属于第三方平台，其接口为逆向整理的、非官方接口，**可能随平台升级而失效或变更**。
本项目将后端地址统一收敛到 `lib/config/app_config.dart`，所有接口路径均可一键修改。

- **自动登录**尝试调用平台登录接口并捕获 `Set-Cookie`；若接口变更导致失败，可使用
  **手动粘贴 Cookie** 的方式登录（见登录页）。
- **二维码签到**解析扫码结果，并将解析出的签到信息连同当前账户 Cookie 上报到签到接口。
- 请遵守平台的使用条款与学校相关规定，仅用于个人学习用途。

## License

仅供学习与交流使用。请勿用于任何违反平台规则或法律法规的用途。
