<#
  install.ps1
  一键复刻这个桌面。依次做三件事：
    1. 调整任务栏和桌面（深色、自动隐藏、隐藏桌面图标）
    2. 导入 Nexus Dock 的外观，并把你装了的常用软件放上 Dock
    3. 让 Wallpaper Engine 开机稳定自启

  每一步都会先备份，运行 restore.ps1 可以全部还原。

  用法（在本文件夹里打开终端）：
    powershell -ExecutionPolicy Bypass -File .\install.ps1
#>

$ErrorActionPreference = 'Stop'
$scripts = Join-Path $PSScriptRoot 'scripts'

function Test-WallpaperEngine {
    $steam = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath
    if (-not $steam) { return $false }
    $libs = @($steam)
    $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
    if (Test-Path $vdf) {
        $libs += Select-String -Path $vdf -Pattern '"path"\s+"(.+)"' |
            ForEach-Object { $_.Matches[0].Groups[1].Value -replace '\\\\', '\' }
    }
    foreach ($lib in $libs) {
        if (Test-Path (Join-Path $lib 'steamapps\common\wallpaper_engine\wallpaper32.exe')) { return $true }
    }
    return $false
}

Write-Host '== 检查需要的软件 =='
$hasWE    = Test-WallpaperEngine
$hasNexus = Test-Path 'C:\Program Files (x86)\Winstep\Nexus.exe'
Write-Host ("Wallpaper Engine：{0}" -f $(if ($hasWE) { '已安装' } else { '未安装（Steam 商店购买：https://store.steampowered.com/app/431960/）' }))
Write-Host ("Nexus Dock：      {0}" -f $(if ($hasNexus) { '已安装' } else { '未安装（免费下载：https://www.winstep.net/nexus.htm）' }))

$answer = Read-Host "`n接下来会修改任务栏、桌面和 Dock 设置（都会先备份）。继续吗？(Y/N)"
if ($answer -notmatch '^[Yy]') { Write-Host '已取消，什么都没改。'; exit 0 }

Write-Host "`n== 1/3 调整任务栏和桌面 =="
& "$scripts\apply-look.ps1"

Write-Host "`n== 2/3 导入 Nexus Dock =="
if ($hasNexus) { & "$scripts\apply-nexus.ps1" } else { Write-Host '跳过：没有安装 Nexus。装好并运行一次后，可以单独运行 scripts\apply-nexus.ps1。' }

Write-Host "`n== 3/3 Wallpaper Engine 开机自启 =="
if ($hasWE) { & "$scripts\fix-wallpaper-autostart.ps1" } else { Write-Host '跳过：没有安装 Wallpaper Engine。' }

Write-Host "`n全部完成！去 wallpapers.md 挑一张壁纸订阅吧。想还原，运行 restore.ps1。"
