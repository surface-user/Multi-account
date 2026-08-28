# 归档当前构建的 APK，避免因重新打包而覆盖历史版本。
# 用法：
#   .\tools\archive_apk.ps1                       # 用当前目录作为项目根
#   .\tools\archive_apk.ps1 -Root 'D:\...\项目'    # 显式指定项目根
# 作用：把 build\app\outputs\flutter-apk\ 里的 *.apk 复制到 apk_history\，
#       文件名追加时间戳，保留每次构建的产物。

param(
    [string]$Root = ''
)

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = (Get-Location).Path
}
$src  = Join-Path $Root 'build\app\outputs\flutter-apk'
$hist = Join-Path $Root 'apk_history'

if (-not (Test-Path $src)) {
    Write-Host "源目录不存在: $src"
    exit 1
}
if (-not (Test-Path $hist)) { New-Item -ItemType Directory -Path $hist -Force | Out-Null }

$ts = Get-Date -Format 'yyyyMMdd_HHmmss'
$copied = @()
Get-ChildItem -Path $src -Filter '*.apk' -File | ForEach-Object {
    $dest = Join-Path $hist ($_.BaseName + '_' + $ts + $_.Extension)
    Copy-Item -Path $_.FullName -Destination $dest -Force
    $copied += [PSCustomObject]@{
        File    = $_.Name
        Archive = (Split-Path -Leaf $dest)
        SizeMB  = [math]::Round($_.Length / 1MB, 1)
    }
}

if ($copied.Count -eq 0) {
    Write-Host "没有找到 APK（$src 为空）。"
} else {
    Write-Host "已归档到 apk_history\："
    $copied | Format-Table -AutoSize
}
