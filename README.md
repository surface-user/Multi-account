# 雨课堂助手 (Rain Classroom Helper)

> 一个基于 **Flutter** 开发的 **Android** 雨课堂统一管理工具：多服务器、多账户、多种登录方式、
> 二维码签到、课件 PPT 查看。
>
> 雨课堂接口为**逆向整理的第三方非官方接口**，可能随平台升级而失效或变更，本项目已把它们统一收敛到
> [`lib/config/app_config.dart`](lib/config/app_config.dart) 以便一键调整。

## 功能特性

- **多服务器**：雨课堂 `www` / 荷塘 `pro` / 长江 `changjiang` / 黄河 `huanghe` 四主域，可独立登录、独立鉴权。
- **多账户管理**：添加、保存、切换、删除多个账号，每个账号记住自己的服务器，切换账号自动切到对应主域。
- **多种登录方式**：
  - 账号密码登录（需腾讯验证码 `ticket+rand`）
  - 手机短信验证码登录（发送 / 校验）
  - 二维码登录（微信扫码，轮询拉取登录态）
  - **手动粘贴浏览器 Cookie** 兜底（跳过验证码，最稳定）
- **未注册识别**：某主域下账号无资料（未绑定高校）时弹窗提示，可选择「仍然登录」并打上「未注册」标签。
- **学校标签**：主界面每个账户条目与「当前账户」卡片会显示所属高校名称（取自登录后拉取的真实用户资料；
  已有账户需重新登录一次以回填学校字段）。
- **登录日志**：登录请求日志可复制 / 清空，便于排查接口问题。
- **动态二维码签到**：调用摄像头扫描教师端二维码，解析后上报（源码 `/api/v3/app/scan` + `/api/v3/lesson/checkin` 两步）。
- **课程列表**：拉取「上课中」的课程。
- **PPT / 课件查看**：获取课件（幻灯片）列表，整页翻页浏览；复杂动态课件用内置 WebView 兜底。
- **本地持久化**：账户元数据与会话 Cookie 均本地保存，重启可直接使用。

## 多服务器架构

不同校区（主域）的登录鉴权与 Cookie 相互独立、绑定在该域下。因此项目把「**当前服务器**」作为全局状态，
登录、拉课程、签到全部走该主域。

- `lib/platform.dart` 中的 `RainClassroomServerType` 定义四种主域：
  `yuketang`(www) / `pro`(荷塘) / `changjiang`(长江) / `huanghe`(黄河)，并给出各自主域地址与展示名。
- `PlatformManager`（单例）持有全局「当前服务器」，启动时从本地读回上次选择，并持久化切换。
- 每个账户带上自己的 `server` 字段；切换账户时会同步把全局服务器切到该账户的主域，保证 Cookie 域匹配。

```dart
RainClassroomServerType.yuketang   // https://www.yuketang.cn
RainClassroomServerType.pro        // https://pro.yuketang.cn
RainClassroomServerType.changjiang // https://changjiang.yuketang.cn
RainClassroomServerType.huanghe    // https://huanghe.yuketang.cn
```

## 目录结构

```
rain_classroom_helper/
├── pubspec.yaml                     # 依赖与工程配置（含 dependency_overrides 构建兼容）
├── analysis_options.yaml            # lint 配置
├── assets/images/                   # 内置图片资源
├── platform-config/                 # Android / iOS 权限片段（供合并，见其 README）
├── tools/                           # 辅助脚本（APK 归档、Flutter SDK 下载提取等）
├── build_and_install.ps1            # 一键构建并安装 APK 到安卓真机
└── lib/
    ├── main.dart                    # 入口：初始化服务器、状态栏、挂载 App
    ├── app.dart                     # RainClassroomApp：Provider + MaterialApp + 首页
    ├── platform.dart                # 多服务器枚举 + PlatformManager（全局当前服务器）
    ├── config/
    │   └── app_config.dart          # 后端地址/常量（全部接口路径收敛于此）
    ├── models/
    │   ├── account.dart             # 账户模型（含 server、isRegistered 等）
    │   ├── course.dart              # 课程模型
    │   ├── checkin_info.dart        # 扫码签到信息模型（JSON/URL/token 解析）
    │   └── slide.dart               # 课件幻灯片模型
    ├── state/
    │   └── app_state.dart           # AppState（ChangeNotifier）：账户列表/当前账户/服务实例
    ├── services/
    │   ├── rain_api_service.dart    # 雨课堂 HTTP：登录/短信/二维码/用户信息/课程/课件
    │   ├── checkin_service.dart     # 扫码签到（scan + checkin 两步上报）
    │   ├── account_store.dart       # 账户列表本地持久化（shared_preferences JSON）
    │   └── cookie_store.dart        # 会话 Cookie 存储（shared_preferences + Base64）
    ├── theme/
    │   └── app_theme.dart           # Material3 主题（浅/深）
    ├── utils/
    │   └── string_utils.dart        # 通用字符串工具
    ├── pages/
    │   ├── account_list_page.dart   # 账户管理首页（当前账户卡片 + 操作）
    │   ├── account_login_page.dart  # 登录/添加账户（密码/短信/二维码/粘贴Cookie + 服务器选择）
    │   ├── course_list_page.dart    # 我的课程
    │   ├── qr_checkin_page.dart     # 扫码签到（mobile_scanner）
    │   └── ppt_viewer_page.dart     # PPT 整页查看（含 WebView 兜底）
    └── widgets/
        ├── account_tile.dart        # 账户条目（含当前/未注册 标签）
        └── cookie_paste_dialog.dart # 手动粘贴 Cookie 对话框
```

## 数据与存储

- **账户元数据**：`AccountStore` 以 JSON 数组存于 `shared_preferences`（key `accounts`），只保存非敏感字段
  （账号、昵称、用户 ID、服务器、是否注册、最后登录时间等）。
- **会话 Cookie**：`CookieStore` 保存在 `shared_preferences`（key 前缀 `cookie_`），用 **Base64 编码** 非明文落盘。
  > 说明：原计划用 `flutter_secure_storage`，但因本项目路径含空格、`flutter_secure_storage` 引入
  > `objective_c` / native-assets 导致无法打包，故改用 `shared_preferences` + Base64。若部署环境无空格路径，
  > 可换回加密存储，接口不变。
- **全局当前服务器**：`PlatformManager` 用 `shared_preferences` 持久化（key `current_server`）。

## 网络与接口

所有第三方接口地址集中在 `lib/config/app_config.dart`，修改一处即可：

| 用途 | 方法 | 路径 |
|---|---|---|
| 登录（账号密码 / 短信） | POST | `/api/v3/user/login/app` |
| 发送短信验证码 | POST | `/api/v3/user/code/send` |
| 校验短信验证码 | POST | `/api/v3/user/code/verify` |
| 二维码登录预取（拿 token + 二维码） | GET | `/api/v3/user/login/pre-info` |
| 二维码登录轮询 | POST | `/api/v3/user/login` |
| 用户信息 | GET | `/v/course_meta/user_info` |
| 课程（上课中） | GET | `/api/v3/classroom/on-lesson` |
| 课件（幻灯片） | GET | `/api/v3/lesson/presentation/fetch` |
| 扫码（签到第一步） | POST | `/api/v3/app/scan` |
| 签到上报 | POST | `/api/v3/lesson/checkin` |

**鉴权**：登录成功后从响应头 `set-auth` 取 Bearer Token（`authorization: Bearer ...`），并按账号持久化 Cookie。
签到等接口还需额外携带 `x-csrftoken`、`sessionid` 头（值取自 Cookie），仅带 Cookie 会失败。

## 环境要求

- **Flutter SDK**：`>=3.6.0`（Dart `>=3.6.0` 且 `<4.0.0`）。
- **Android**：需 Android SDK / Android Studio，联网下载 Gradle 与依赖。
- **设备**：Android 真机（需开启「开发者选项 → USB 调试」）。
- 本仓库为 **Android-only**（`flutter create . --platforms=android --org com.rainclassroom` 生成，
  `applicationId = com.rainclassroom.rain_classroom_helper`）。

### Android 权限

`build_and_install.ps1` 会在构建时幂等注入以下权限到 `android/app/src/main/AndroidManifest.xml`：
`INTERNET`、`ACCESS_NETWORK_STATE`、`CAMERA`。也可参考 [`platform-config/AndroidManifest.permissions.xml`](platform-config/AndroidManifest.permissions.xml)。

## 构建与安装

### 1. 安装依赖

```bash
flutter pub get
```

### 2. 直接构建 APK

```bash
flutter build apk --release
# 产物: build/app/outputs/flutter-apk/app-release.apk
```

### 3. 一键构建并安装到安卓真机（数据线）

在已安装 Flutter、Android 工具链并连接好开启 USB 调试的手机后，于项目根目录执行：

```powershell
.\build_and_install.ps1                # debug 构建、安装、启动
.\build_and_install.ps1 -Mode release  # release 构建
```

脚本会：检查 Flutter 与设备 → `flutter create` 补全 android 平台脚手架（不覆盖 lib/pubspec）→ 注入权限
→ `flutter pub get` → `flutter build apk --<mode>` → `adb install -r` 安装 → 用 `monkey` 自动启动应用。

> 手机端必须开启「USB 调试」，并在弹窗中允许该电脑调试；首次构建需联网下载 Gradle 与依赖。

### 4. APK 归档（历史版本保留）

`flutter build` 会覆盖 `build/app/outputs/flutter-apk/` 下的 APK。为避免丢失历史版本，每次打包前先归档：

```powershell
.\tools\archive_apk.ps1 -Root 'D:\computer_work\project\Multi account'
```

脚本会把当前产物备份到 `apk_history/`（带时间戳命名），便于回滚/比较。

### 国内镜像（本机环境）

若网络无法直接访问 Flutter 官方源，可使用以下环境变量（与仓库当前构建环境一致）：

```powershell
$env:FLUTTER_STORAGE_BASE_URL='https://storage.flutter-io.cn'
$env:PUB_HOSTED_URL='https://pub.flutter-io.cn'
$env:PUB_CACHE="$PWD\.pub-cache"
$env:ANDROID_HOME="$PWD\.android-sdk"
$env:JAVA_HOME='C:\Program Files\Microsoft\jdk-17.0.11.9-hotspot'
```

Flutter SDK 本地路径：`<仓库>/flutter-sdk/flutter/bin/flutter.bat`。

## 登录与账号说明

- **密码登录**：雨课堂密码登录需腾讯验证码 `ticket+rand`，纯脚本难以通过（滑块/点选需真人交互）；
  因此 App 提供了「**手动粘贴 Cookie**」兜底。
- **短信登录**：先发送验证码再校验，同样走 `/api/v3/user/login/app`。
- **二维码登录**：App 获取二维码（`pre-info`）→ 用户微信扫码 → App 轮询 `login` 直到成功。
- **未注册识别**：登录后用真实用户资料（`fetchUserInfo`）判断该主域下账号是否已注册（未绑定高校则资料为空），
  空资料弹窗提示，用户仍可「仍然登录」并在主界面打上「未注册」标签。
- **服务器 404**：若某节点响应异常（HTTP 404/5xx），会弹窗提示「服务器节点 404，请稍后重试或改用二维码登录」，
  这是负载均衡节点问题，非应用可修复；应用会重试一次。

## 二维码签到流程

真实流程（依据 course_helper 逆向）分两步：

1. `POST /api/v3/app/scan`，body `{ "url": <二维码内容> }` → 从 `data.value` 取 `lessonId`。
2. `POST /api/v3/lesson/checkin`，body `{ "source": 21, "lessonId", "joinIfNotIn": true }` → `code==0` 即签到成功。

用 `mobile_scanner`（7.2.0，与 course_helper 同款）扫码；相机预览在 Android 16 上黑屏的问题已修复——
不自行处理权限状态分支，交由 `mobile_scanner` 启动时内部请求权限。

## 注意事项

- **接口合规**：雨课堂为第三方平台，逆向接口可能违反其服务条款，本项目仅供学习 / 个人用途，请勿用于商业或滥用。
- **接口易变**：路径、字段、加密、验证码可能随时变化，所有地址已收敛到 `AppConfig`，改一处即可。
- **调试技巧**：登录页可查看 / 复制 / 清空登录请求日志，便于对照浏览器 Network 面板排查；用状态码判断问题
  （`404` 路径错、`400` 参数错、`401/403` 未登录、`200` 成功）。

## License

仅供学习与交流使用。请勿用于任何违反平台规则或法律法规的用途。
