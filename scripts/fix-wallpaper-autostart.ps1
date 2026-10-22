<#
  fix-wallpaper-autostart.ps1
  修复"开机后 Wallpaper Engine 壁纸不出来"的问题。

  原因：Wallpaper Engine 设置里勾选了"高优先级"后，它改成靠一个后台服务开机启动。
  如果这个服务被优化软件改成了"手动"，或原来的启动项被关掉，开机时就没人去启动它。

  做法：自动找到 Wallpaper Engine 的安装位置，建一个"登录后延迟 10 秒启动"的计划任务。
  不需要管理员权限。

  用法：
    .\fix-wallpaper-autostart.ps1           创建或更新计划任务
    .\fix-wallpaper-autostart.ps1 -Remove   删除这个计划任务
#>
param([switch]$Remove)

$ErrorActionPreference = 'Stop'
$taskName = 'WallpaperEngine_Logon'

$backupDir = Join-Path $PSScriptRoot '..\backup'
$marker    = Join-Path $backupDir 'wallpaper-task-created.txt'

if ($Remove) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Item $marker -ErrorAction SilentlyContinue
    Write-Host "已删除计划任务 $taskName"
    exit 0
}

# 从 Steam 的库文件夹列表里找 Wallpaper Engine
function Find-WallpaperEngine {
    $steam = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath
    if (-not $steam) { return $null }
    $libraries = @($steam)
    $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
    if (Test-Path $vdf) {
        $libraries += Select-String -Path $vdf -Pattern '"path"\s+"(.+)"' |
            ForEach-Object { $_.Matches[0].Groups[1].Value -replace '\\\\', '\' }
    }
    foreach ($lib in $libraries | Select-Object -Unique) {
        $exe = Join-Path $lib 'steamapps\common\wallpaper_engine\wallpaper32.exe'
        if (Test-Path $exe) { return $exe }
    }
    return $null
}

$exe = Find-WallpaperEngine
if (-not $exe) {
    Write-Host '没有找到 Wallpaper Engine，请确认已经通过 Steam 安装。'
    exit 1
}
Write-Host "找到 Wallpaper Engine：$exe"

$action    = New-ScheduledTaskAction -Execute $exe
$trigger   = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$trigger.Delay = 'PT10S'   # 等桌面加载完再启动，避免壁纸闪一下就没了
$settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit 0
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

# 记下这个任务是不是本脚本新建的，一键还原时只删自己建的
if (-not (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue)) {
    New-Item -ItemType Directory -Force $backupDir | Out-Null
    Set-Content $marker 'created by fix-wallpaper-autostart.ps1'
}

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
    -Settings $settings -Principal $principal -Force | Out-Null

Write-Host "已创建计划任务 $taskName，下次登录 10 秒后会自动启动壁纸。"
Write-Host '提醒：以后在 Wallpaper Engine 设置里不要勾选"高优先级"，否则会换回依赖后台服务的启动方式。'
