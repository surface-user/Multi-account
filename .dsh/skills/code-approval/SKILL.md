---
name: code-approval
description: 代码改动需先向用户说明修改方案并经确认后才执行；禁止代提交 git commit，commit 信息需符合规范且全部中文
---

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

# Git 提交与版本管理规则

## 禁止代提交
- **AI / 脚本不得代替用户执行 `git commit`**，也**不要询问是否帮用户 `git add` / 暂存**。所有 commit 一律由用户**手动编写并提交**。
- AI 负责**说明改动内容**（改了哪些文件、为什么改），并**必须给出对应的 commit description**（标题 + 正文，中文、遵循 Conventional Commits），供用户直接使用。绝不代劳提交、暂存或修改 commit 历史。
- **无需就用户自己会做的事反复询问**（如是否需要帮 `git add` / 是否需要连带处理某项、是否需要等设备等）：除非用户确实没把握或明确说「要不要」，否则**只完成用户下达的命令/任务本身**，不再多问一句。

## commit 信息规范（用户手动提交时遵循）
- **整体使用中文**（标题、正文均为中文）。
- 遵循 **Conventional Commits** 规范，标题格式：`<类型>(<范围>): <中文描述>`，其中类型保留规范英文关键字（`feat`/`fix`/`docs`/`refactor`/`style`/`test`/`chore` 等），范围和描述用中文。
  - 例：`fix(登录): 修复多主域登录请求未随选中服务器切换`
  - 例：`feat(登录): 登录成功后识别未注册账号并提示`
- 正文简要写清楚改动内容与原因，便于回溯。

---

# 版本与产物保留规则

## APK 历史版本必须保留
- **原则**：`build\app\outputs\flutter-apk\` 下的 APK 会被每次 `flutter build` **覆盖**，绝不允许因此丢失历史版本。
- **归档位置**：`D:\computer_work\project\Multi account\apk_history\`。
- **每次打包前先归档**：执行 `.\tools\archive_apk.ps1 -Root 'D:\computer_work\project\Multi account'`（在本工具环境里，脚本内的 `Get-Location`/`$PSScriptRoot` 可能为空，**务必显式传 `-Root`**；普通终端下不传 `-Root` 也可，会用当前目录）。命名带时间戳（如 `app-release_20260826_155355.apk`），把当前产物备份过来再重新打包。
- **任意一次 build 之后**：都应当归档一次，确保每个可安装版本都有留存，便于回滚/比较（例如改登录接口前后）。

## 构建与设备边界
- **本项目只需编译出可执行文件**（`flutter build apk` 产物）即可，交付到「build 成功、产物存在」即算完成。
- **无需检查 / 连接设备，无需安装到真机**。连接设备、`adb` 安装、真机调试、设备 bug 的排查均由用户自行处理。
- 除非用户**明确要求**帮忙安装 / 连接设备，否则不要执行 `adb`、安装、启动等与设备相关的命令，也不要提示「等设备接上」之类的话。

---

# 在雨课堂网页版找到 Cookie（手动登录兜底）

> 适用于"自动密码登录被腾讯验证码挡住"时，改用浏览器真人登录后复制 Cookie 给 App。

## 步骤
1. 用电脑浏览器（Edge/Chrome）打开你学校对应的雨课堂主域：
   - `https://changjiang.yuketang.cn`（长江，最常见）
   - 其它：`www.yuketang.cn` / `pro.yuketang.cn` / `huanghe.yuketang.cn`
2. **正常登录**：输入账号密码，**顺手把腾讯验证码/滑块过掉**。
3. 登录成功后，按 **F12** 打开开发者工具（DevTools）。
4. 两个方法任选其一复制 Cookie：

   **方法 A：Network 面板（推荐，最完整）**
   - 切到 **Network（网络）** 标签，按 F5 刷新页面。
   - 点任意一个发往 `changjiang.yuketang.cn` 的请求（比如课程列表接口）。
   - 在右侧 **Headers** 里往下找 **Request Headers → Cookie**，那是一整行 `name=value; name2=value2; ...`。
   - 选中并**整段复制**。

   **方法 B：Application 面板**
   - 切到 **Application（应用）** 标签 → 左侧 **Cookies** → 点开 `https://changjiang.yuketang.cn` 域名。
   - 这里以表格列出所有 Cookie 名/值；需要手拼成 `name1=value1; name2=value2; ...`（用 `; ` 连接）。
   - 注意：即使 Cookie 标为 `httpOnly`，也能从面板里看到并复制其取值（httpOnly 只是不让网页脚本读取，不是不给用户看）。

5. 回到 App，粘贴这段 Cookie（App 里对应"粘贴 Cookie 登录"入口），保存即可。
6. 以后每次请求 App 都把这个 Cookie 放在 `Cookie` 头里，服务器就能识别登录态。

## 你需要复制的到底是什么
- 是**整段 Cookie 字符串**（`name=value; name=value; ...`），**不是**某个单独的值，也不是请求体。
- 雨课堂登录态常包含 `sessionid`、`csrftoken` 等；剪贴板里通常是一长串，**整段复制最稳**。
- 复制时要**来自你实际登录的那个域名**（用 changjiang 登录就复制 changjiang 的，别拿别的校区）。
- Cookie 会**过期/失效**：若 App 提示登录失效，重新去浏览器登录再复制一次即可。

## 相关头（供排查）
course_helper 除了带 `Cookie`，还额外附加 `x-csrftoken`、`x-uid`、`sessionid` 头（值取自 Cookie）。若只粘 Cookie 仍校验失败，说明接口额外校验这些头，届时在 App 里从 Cookie 中提取同名值一并加上。

---

# 计算机网络基础知识（针对本项目雨课堂接口）

> 面向对网络不太熟悉的读者，尽量讲清"登录/接口/鉴权"到底在干什么。

## 1. 一次网络请求长什么样：请求 + 响应

手机上的 App 和服务器之间，"说话"的方式是 **HTTP 请求 / HTTP 响应**。

**一个请求（Request）由四部分组成：**
- **URL**：发给谁。例 `https://changjiang.yuketang.cn/api/v3/user/login/app`
- **方法（Method）**：想干什么。
  - `GET`：读取数据（如查课程列表）
  - `POST`：提交数据（如登录、签到）
  - `PUT`/`DELETE`：改/删，较少用
- **请求头（Headers）**：附加信息。常见：
  - `User-Agent`：我是谁（什么浏览器/手机）
  - `Content-Type`：请求体格式（`application/json` 表示发的是 JSON）
  - `Cookie`：把之前登录拿到的凭证带回去
  - `Authorization: Bearer <token>`：用 Token 鉴权
- **请求体（Body）**：真正的内容，登录时是 `{"phoneNumber":"138...","password":"..."}`。

**一个响应（Response）由三部分组成：**
- **状态码（Status Code）**：结果。常见：
  - `200` 成功；`201` 创建成功
  - `301/302` 重定向（跳到别处）
  - `400` 请求参数错误；`401` 未登录/凭证无效；`403` 没权限
  - `404` 路径不存在（**你之前碰到的就是它**：登录接口路径写错）
  - `500` 服务器内部错误
- **响应头（Headers）**：服务器回的信息，`Set-Cookie`（发 Cookie 给你）、`set-auth`（发 Token 给你）都在这。
- **响应体（Body）**：JSON 数据，如 `{"code":0,"data":{...}}`。

## 2. URL 的结构
```
https://changjiang.yuketang.cn / api/v3/user/login/app ?a=1#frag
  └─协议─┘  └────域名(服务器)────┘ └──路径(path)──┘ └查询参数┘
```
- **协议**：`http://` 明文，`https://` 走 **TLS 加密**（安全、防偷看/篡改），现在的网站基本都用 https。
- **域名**：`changjiang.yuketang.cn`，人好记的名字；实际由 DNS 服务器翻译成 **IP 地址**（一串数字，如 `123.45.67.89`）去找到那台服务器。域名其实是一个"名字地址"，IP 才是"真实地址"。
- **路径**：`/api/v3/user/login/app`，表示服务器上哪个"接口/功能"。
- **查询参数**：`?presentation_id=123`，跟随在路径后面传小数据。

## 3. 端口与 DNS
- 服务器通过 **端口** 开服务：`https` 默认 `443`，`http` 默认 `80`。通常 URL 里看不到，是默认值。
- **DNS**（域名系统）：把域名翻译成 IP。你改 hosts、换环境时常见到。

## 4. 登录后服务器怎么"记住你"：Cookie 与会话
登录本质：**提交凭证（账号/密码）→ 服务器核验 → 返回一个"通行证"**，之后每次请求都出示通行证。

两种主流通行证：
- **Cookie（会话）**：登录成功，服务器在响应头 **`Set-Cookie`** 里给一串，如 `sessionid=abc123`。之后请求带 `Cookie: sessionid=abc123`，服务器就认你。
- **Token（Bearer）**：登录成功，服务器在某个响应头/响应体里给一串 Token。之后请求带 `Authorization: Bearer <token>`。

雨课堂（course_helper 的实现）用的是 **set-auth Bearer Token**：`response.headers['set-auth']` 拿到 token，再放进 `authorization: Bearer ...`。

**核心记忆**：Cookie / Token 都是"你登录过的证明"，区别只在"放在哪个头里"。

## 5. 登录的几种方式
- **密码登录（纯 HTTP 可做）**：`POST` 账号+密码 → 核验 → 返回 Cookie/Token。App 自己就能发这个请求。
- **短信/验证码登录**：先 `POST` 申请发验证码，用户填码后再 `POST` 提交。本质也是纯 HTTP。
- **扫码/微信登录（OAuth 式，多个"参与者"）**：
  1. App 生成一个**二维码**（内容是"授权接口 + 一个随机 state"）。
  2. 用户用**微信**扫码，微信侧确认"是本人"。
  3. 微信回调通知雨课堂"已授权"。
  4. App **轮询**一个接口，直到发现授权成功，再领 Token。
  整个过程 App 仍然是发 HTTP 请求，只是"验证你身份"这一步交给了微信/第三方。

## 6. 验证码（captcha）为什么挡脚本
腾讯验证码（滑块/点选）是**专门防自动化**的：它需要真人进行"拖动滑块/按图点字"这类人机交互。只有真人操作后，前端才能拿到 `ticket` + `rand` 两个凭证，登录接口校验通过才放行。

所以：**纯代码、纯 HTTP、没有真人操作，就过不了验证码**。这就是密码登录"很难自动化"的根本原因。

## 7. 那本项目的正确做法是什么？
- **自动密码登录**：接口改成 `/api/v3/user/login/app`（已改对），但缺 `ticket/rand`，服务器会要验证码 → 仍登不进。
- **最可靠兜底 = 手动粘贴 Cookie**：
  1. 你在电脑浏览器里打开 `https://changjiang.yuketang.cn` 登录（真人过验证码）。
  2. 按 F12 → 应用/网络 里复制整段 `Cookie`。
  3. 粘到 App 的"粘贴 Cookie 登录"里，App 每次请求就带上它 → 能签到、看课件。
- 因为已持有真实登录态（浏览器验证过的 Cookie），App 无需再解验证码。

## 8. 对接第三方接口的注意事项
- 逆向第三方接口可能**违反其服务条款**，只建议学习/个人用途，勿用于商业或滥用（如批量刷课、攻击）。
- 接口可能**随时变**（路径、字段、加密、验证码），所以本项目把所有路径收敛到 `AppConfig`，改一处即可。
- **调试技巧**：
  - 看状态码判断问题：`404` 路径错、`400` 参数错、`401/403` 没登录、`200` 成功。
  - 用浏览器开发者工具（Network 面板）看真实请求，复制 Header/Body 对照。
  - 用 `curl` / Postman 先单独调通接口，再写进代码。
- **http vs https**：`http` 明文，密码会被看到，务必用 `https`；本项目全部走 https。

## 9. 本项目的雨课堂关键接口速查（依据 course_helper 逆向）
| 用途 | 方法 | 路径 |
|---|---|---|
| 登录 | POST | `/api/v3/user/login/app`（网页端 `/api/v3/user/login/app-web-login`）|
| 用户信息 | GET | `/v/course_meta/user_info` |
| 课程（上课中） | GET | `/api/v3/classroom/on-lesson` |
| 扫码（签到第一步） | POST | `/api/v3/app/scan` |
| 签到上报 | POST | `/api/v3/lesson/checkin` |
| 课件/PPT | GET | `/api/v3/lesson/presentation/fetch?presentation_id=...` |
| 直播/互动 | WS | `wss://<server>.yuketang.cn/wsapp/` |

主域（校区）：`www.yuketang.cn` / `pro.yuketang.cn` / `changjiang.yuketang.cn` / `huanghe.yuketang.cn`；本项目用 `changjiang`。
鉴权：登录后响应头 **`set-auth`** 取 Bearer Token，后续 `authorization: Bearer <token>`；同时按账号持久化 Cookie。
