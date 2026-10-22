<#
  restore.ps1
  把 install.ps1 做的改动全部还原成安装之前的样子。

  用法（在本文件夹里打开终端）：
    powershell -ExecutionPolicy Bypass -File .\restore.ps1
#>

$scripts = Join-Path $PSScriptRoot 'scripts'
$backup  = Join-Path $PSScriptRoot 'backup'

Write-Host '== 还原任务栏和桌面 =='
if (Test-Path "$backup\look-backup.json") { & "$scripts\apply-look.ps1" -Undo } else { Write-Host '没有备份，跳过。' }

Write-Host "`n== 还原 Nexus Dock =="
if (Test-Path "$backup\nexus-backup.reg") { & "$scripts\apply-nexus.ps1" -Undo } else { Write-Host '没有备份，跳过。' }

Write-Host "`n== 还原 Wallpaper Engine 自启 =="
# 只删除 install.ps1 新建的计划任务；如果你原来就有，保持不动
if (Test-Path "$backup\wallpaper-task-created.txt") { & "$scripts\fix-wallpaper-autostart.ps1" -Remove } else { Write-Host '计划任务不是本工具新建的，保持不动。' }

Write-Host "`n还原完成。"
