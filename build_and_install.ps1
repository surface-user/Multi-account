# ============================================================
#  雨课堂助手 —— 一键打包并安装到安卓真机（数据线调试）
#
#  前置条件（必须满足）:
#   1. 已安装 Flutter SDK 并在 PATH 中（flutter --version 可用）
#   2. 已安装 Android SDK / Android Studio，且能联网（首次构建需下载依赖）
#   3. 手机已开启「开发者选项」->「USB 调试」，并用数据线连接电脑
#   4. 在手机上允许「始终允许这台电脑使用 USB 调试」
#
#  用法（在项目根目录）:
#    .\build_and_install.ps1                # debug 构建并安装
#    .\build_and_install.ps1 -Mode release  # release 构建并安装
# ============================================================
param(
    [ValidateSet('debug', 'release')]
    [string]$Mode = 'debug'
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = $PSScriptRoot
$Org = 'com.rainclassroom'

# ------------------------------------------------------------
# 在 AndroidManifest 中加入所需权限（幂等：已存在则跳过）
# ------------------------------------------------------------
function Apply-AndroidPermissions {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        Write-Host "[警告] 未找到 $Path，跳过权限注入。" -ForegroundColor Yellow
        return
    }
    $content = Get-Content $Path -Raw -Encoding UTF8
    $perms = @(
        '<uses-permission android:name="android.permission.INTERNET"/>',
        '<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>',
        '<uses-permission android:name="android.permission.CAMERA"/>'
    )
    $added = @()
    foreach ($p in $perms) {
        if ($content -notmatch [regex]::Escape($p)) {
            $content = $content -replace '(<application)', "    $p`r`n$1"
            $added += $p
        }
    }
    if ($added.Count -gt 0) {
        Set-Content -Path $Path -Value $content -Encoding UTF8 -NoNewline
        Write-Host "已注入权限:" -ForegroundColor Green
        $added | ForEach-Object { Write-Host "  $_" -ForegroundColor Green }
    } else {
        Write-Host "权限已存在，无需修改。" -ForegroundColor Green
    }
}

Write-Host "==> 检查 Flutter..." -ForegroundColor Cyan
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "[错误] 未找到 flutter 命令。请先安装 Flutter SDK 并加入 PATH。" -ForegroundColor Red
    Write-Host "       参考: https://docs.flutter.dev/get-started/install" -ForegroundColor Yellow
    exit 1
}
& flutter --version
Write-Host ""

Write-Host "==> 检查连接的安卓设备..." -ForegroundColor Cyan
& flutter devices
$deviceList = (& adb devices 2>$null) -join "`n"
if ($deviceList -notmatch 'device$') {
    Write-Host "[提示] 未检测到已授权的安卓设备。请确认手机已开启 USB 调试并授权。" -ForegroundColor Yellow
    Write-Host "       在手机上：设置 -> 关于手机 -> 连点版本号开启开发者选项；再打开“USB 调试”。" -ForegroundColor Yellow
    Write-Host "       连接后若弹出授权窗口，请勾选“允许”。" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "==> 生成/补全 android 平台脚手架（不会覆盖 lib 与 pubspec.yaml）..." -ForegroundColor Cyan
Push-Location $ProjectRoot
try {
    & flutter create . --platforms=android --org $Org
} finally {
    Pop-Location
}

Write-Host ""
Write-Host "==> 应用 Android 权限（INTERNET / CAMERA）..." -ForegroundColor Cyan
Apply-AndroidPermissions -Path (Join-Path $ProjectRoot 'android\app\src\main\AndroidManifest.xml')

Write-Host ""
Write-Host "==> 拉取依赖..." -ForegroundColor Cyan
Push-Location $ProjectRoot
try {
    & flutter pub get
} finally {
    Pop-Location
}

Write-Host ""
Write-Host "==> 构建 APK ($Mode) ..." -ForegroundColor Cyan
Push-Location $ProjectRoot
try {
    & flutter build apk --$Mode
} finally {
    Pop-Location
}

$apk = Join-Path $ProjectRoot "build\app\outputs\flutter-apk\app-$Mode.apk"
if (-not (Test-Path $apk)) {
    Write-Host "[错误] 未找到产物: $apk" -ForegroundColor Red
    exit 1
}
Write-Host "构建成功: $apk" -ForegroundColor Green

Write-Host ""
Write-Host "==> 安装到手机（adb install -r）..." -ForegroundColor Cyan
& adb install -r $apk
if ($LASTEXITCODE -ne 0) {
    Write-Host "[错误] 安装失败。请检查手机是否连接且已开启 USB 调试。" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "==> 启动应用..." -ForegroundColor Cyan
$pkg = "$Org.rain_classroom_helper"
& adb shell monkey -p $pkg -c android.intent.category.LAUNCHER 1
if ($LASTEXITCODE -ne 0) {
    Write-Host "[提示] 未能自动启动，请在手机上手动点开应用。" -ForegroundColor Yellow
} else {
    Write-Host "已启动应用。若需查看日志：flutter logs" -ForegroundColor Green
}
Write-Host "完成。" -ForegroundColor Green
