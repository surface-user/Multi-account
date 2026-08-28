# 平台配置（Android / iOS）

由于本仓库未包含完整平台脚手架（`android/`、`ios/` 的 Xcode/Gradle 工程由
`flutter create .` 生成），这里提供本应用**功能所需**的平台权限与配置，供你在生成
脚手架之后应用。

## 1. 生成平台脚手架

在项目根目录执行（需要先安装 Flutter SDK）：

```bash
flutter create . --platforms=android,ios --org com.rainclassroom
```

> `flutter create .` 会创建缺失的平台工程文件，并保留已有的 `lib/` 与 `pubspec.yaml`。

## 2. Android 权限

打开 `android/app/src/main/AndroidManifest.xml`，把
[`AndroidManifest.permissions.xml`](./AndroidManifest.permissions.xml) 中的
`<uses-permission>` 与 `<uses-feature>` 粘贴到 `<manifest>` 内、`<application>` 之前。

其中必需的权限：

- `android.permission.INTERNET` —— 登录、课程、课件、签到；
- `android.permission.CAMERA` —— 动态二维码扫码签到。

`ACCESS_NETWORK_STATE` 与相机 `<uses-feature>` 为可选/友好声明。

## 3. iOS 权限

打开 `ios/Runner/Info.plist`，把
[`Info.plist.keys.xml`](./Info.plist.keys.xml) 中的键值粘贴到 `<dict>` 顶层。

必需的键：

- `NSCameraUsageDescription` —— 扫码签到需要。

如果需要从相册读取二维码图片或保存截图，再启用对应的照片权限键。
`NSAppTransportSecurity` 一般无需放开（雨课堂走 HTTPS）。

## 4. 低版本 / 依赖说明

- `mobile_scanner`（扫码）与 `webview_flutter`、`cached_network_image` 都会在
  `flutter create .` 之后自动纳入 iOS/Android 工程；若构建报错，执行
  `flutter pub get` 后重新 `flutter run` 即可。

## 5. 验证

```bash
flutter analyze          # 静态检查
flutter run              # 在真机/模拟器运行
```

在真机运行扫码功能时，需要在系统设置中允许相机权限。
