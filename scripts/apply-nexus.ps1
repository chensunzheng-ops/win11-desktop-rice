<#
  apply-nexus.ps1
  把 config\nexus-dock.json 里的 Dock 外观导入你的 Nexus，
  并自动检测你电脑上装了哪些常用软件，把它们放到 Dock 上。

  用法：
    .\apply-nexus.ps1          导入（会先把你原来的 Nexus 配置备份到 backup\ 文件夹）
    .\apply-nexus.ps1 -Undo    恢复成导入之前的样子
#>
param([switch]$Undo)

$ErrorActionPreference = 'Stop'
$nexusExe   = 'C:\Program Files (x86)\Winstep\Nexus.exe'
$rootKey    = 'HKCU\Software\WinSTEP2000'
$nexusKey   = 'HKCU:\Software\WinSTEP2000\NeXuS'
$docksKey   = "$nexusKey\Docks"
$configFile = Join-Path $PSScriptRoot '..\config\nexus-dock.json'
$backupDir  = Join-Path $PSScriptRoot '..\backup'
$backupFile = Join-Path $backupDir 'nexus-backup.reg'

function Stop-Nexus {
    # 直接结束进程，避免 Nexus 退出时把旧设置写回注册表
    Get-Process -Name Nexus -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 1
}

function Start-Nexus {
    Start-Process $nexusExe
    Write-Host 'Nexus 已重新启动。'
}

if (-not (Test-Path $nexusExe)) {
    Write-Host '没有找到 Nexus，请先从 https://www.winstep.net/nexus.htm 下载安装。'
    exit 1
}

if ($Undo) {
    if (-not (Test-Path $backupFile)) { Write-Host '没有找到备份文件，无法恢复。'; exit 1 }
    Stop-Nexus
    # reg 会把"操作成功"写到错误输出，PowerShell 5.1 会误判成出错，所以交给 cmd 执行
    cmd /c "reg delete `"$rootKey`" /f >nul 2>&1 && reg import `"$backupFile`" >nul 2>&1"
    if ($LASTEXITCODE -ne 0) { Write-Host "恢复失败，备份文件还在：$backupFile"; exit 1 }
    Start-Nexus
    Remove-Item $backupFile
    Write-Host '已恢复原来的 Nexus 配置。'
    exit 0
}

if (-not (Test-Path $docksKey)) {
    Write-Host '还没有 Nexus 的配置。请先运行一次 Nexus，等 Dock 出现后再运行这个脚本。'
    exit 1
}

# 先备份；已经有备份就不覆盖，保证多次运行后还能还原到最初的样子
if (Test-Path $backupFile) {
    Write-Host "已有备份 $backupFile，保留不覆盖。"
} else {
    New-Item -ItemType Directory -Force $backupDir | Out-Null
    cmd /c "reg export `"$rootKey`" `"$backupFile`" /y >nul 2>&1"
    if ($LASTEXITCODE -ne 0) { Write-Host '备份 Nexus 配置失败，已停止，什么都没改。'; exit 1 }
    Write-Host "原来的 Nexus 配置已备份到 $backupFile"
}

# 要放到 Dock 上的软件：按顺序检测，装了的才加
function Find-Steam {
    $p = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamExe
    if ($p) { return $p -replace '/', '\' }
}
function Find-First($pattern) {
    Get-ChildItem $pattern -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
}
$candidates = @(
    @{ Label = '文件资源管理器'; Path = "$env:WINDIR\explorer.exe" }
    @{ Label = 'Edge';           Path = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe" }
    @{ Label = 'Chrome';         Path = "$env:ProgramFiles\Google\Chrome\Application\chrome.exe" }
    @{ Label = 'QQ';             Path = "$env:ProgramFiles\Tencent\QQNT\QQ.exe" }
    @{ Label = '微信';           Path = "$env:ProgramFiles\Tencent\Weixin\Weixin.exe" }
    @{ Label = 'Steam';          Path = (Find-Steam) }
    @{ Label = 'QQ音乐';         Path = (Find-First "${env:ProgramFiles(x86)}\Tencent\QQMusic\*\QQMusic.exe") }
    @{ Label = '网易云音乐';     Path = "$env:ProgramFiles\NetEase\CloudMusic\cloudmusic.exe" }
)
$apps = @($candidates | Where-Object { $_.Path -and (Test-Path $_.Path) })

$config = Get-Content $configFile -Raw -Encoding UTF8 | ConvertFrom-Json

Stop-Nexus

# 主题
foreach ($p in $config.theme.PSObject.Properties) {
    Set-ItemProperty -Path $nexusKey -Name $p.Name -Value ([string]$p.Value) -Type String
}

# Dock 外观
foreach ($p in $config.dock.PSObject.Properties) {
    Set-ItemProperty -Path $docksKey -Name $p.Name -Value ([string]$p.Value) -Type String
}

# Dock 上的软件：先清掉第 1 个 Dock 原有的图标，再按检测结果写入
$docks = Get-Item $docksKey
foreach ($name in $docks.GetValueNames()) {
    if ($name -match '^1[A-Za-z]+\d+$') { Remove-ItemProperty -Path $docksKey -Name $name }
}
for ($i = 0; $i -lt $apps.Count; $i++) {
    $a = $apps[$i]
    Set-ItemProperty -Path $docksKey -Name "1Path$i"      -Value $a.Path -Type String
    Set-ItemProperty -Path $docksKey -Name "1Label$i"     -Value $a.Label -Type String
    Set-ItemProperty -Path $docksKey -Name "1IconPath$i"  -Value $a.Path -Type String
    Set-ItemProperty -Path $docksKey -Name "1StartPath$i" -Value ((Split-Path $a.Path) + '\') -Type String
    Set-ItemProperty -Path $docksKey -Name "1Type$i"      -Value '1' -Type String
}
# Nexus 记的是最后一个图标的序号，不是图标个数
Set-ItemProperty -Path $docksKey -Name 'DockNoItems1' -Value ([string]($apps.Count - 1)) -Type String

Start-Nexus
Write-Host "Dock 外观已导入，放上了 $($apps.Count) 个软件：$(($apps | ForEach-Object Label) -join '、')"
Write-Host '其他软件可以直接拖到 Dock 上。想恢复原样，运行：.\apply-nexus.ps1 -Undo'
