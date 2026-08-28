# Code Change Approval Rule

## 核心规则
所有代码文件的改动，必须先向用户说明修改方案，得到确切的确认回复后，才可以进行实际的代码修改。

## 适用范围
- 项目中所有 `.cs` 脚本文件
- `Packages/manifest.json`
- 任何 `.uxml` / `.uss` UI 文件
- Scene 文件 (`.unity`)

## 执行流程
1. 收到修改请求后，先分析需要改动的文件和内容
2. 向用户说明改动方案，包括：涉及哪些文件、开发逻辑和实现原理、怎么改
3. 等待用户明确同意后，再执行修改

## 例外
- 纯信息查询、解释说明类问题无需确认
- 创建新的 `.md` / 文档类文件无需确认
- 用户已明确说"开始吧"/"执行"等指令时无需重复确认

---

# 版本与产物保留规则

## APK 历史版本必须保留
- **原则**：`build\app\outputs\flutter-apk\` 下的 APK 会被每次 `flutter build` **覆盖**，绝不允许因此丢失历史版本。
- **归档位置**：`D:\computer_work\project\Multi account\apk_history\`。
- **每次打包前先归档**：执行 `.\tools\archive_apk.ps1 -Root 'D:\computer_work\project\Multi account'`（在本工具环境里，脚本内的 `Get-Location`/`$PSScriptRoot` 可能为空，**务必显式传 `-Root`**；普通终端下不传 `-Root` 也可，会用当前目录）。命名带时间戳（如 `app-release_20260826_155355.apk`），把当前产物备份过来再重新打包。
- **任意一次 build 之后**：都应当归档一次，确保每个可安装版本都有留存，便于回滚/比较（例如改登录接口前后）。

---
