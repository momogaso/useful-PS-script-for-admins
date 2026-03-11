
<#
.SYNOPSIS
Wi-Fi診断ログ収集スクリプト (Windows 11)
by Masafumi OE / masa@fumi.org
.DESCRIPTION
過去24時間のWi-Fiアソシエーション・切断・ローミング・DHCP・NCSI等のログを収集し、
ZIP圧縮して出力する。

SUpported by Masafumi OE
#>

# --- 管理者権限チェック ---
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    try {
        Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        exit
    } catch {
        Write-Host "管理者権限への昇格がキャンセルされました。一部機能を制限して続行します。" -ForegroundColor Yellow
    }
}

[Console]::OutputEncoding = [Text.Encoding]::UTF8
$OutputEncoding = [Text.Encoding]::UTF8

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName Microsoft.VisualBasic

# --- フォルダ選択ダイアログ ---
$dialog = New-Object System.Windows.Forms.FolderBrowserDialog
$dialog.Description = "WLANレポートの出力先フォルダを選択してください"
$dialog.RootFolder = [Environment+SpecialFolder]::Desktop
$dialog.ShowNewFolderButton = $true

if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
Write-Host "キャンセルされました。" -ForegroundColor Yellow
exit 0
}
$outputRoot = $dialog.SelectedPath

# --- フォルダ名生成 ---
$pcName = $env:COMPUTERNAME
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$folderName = "WLANreport-${pcName}-${timestamp}"
$reportDir = Join-Path $outputRoot $folderName
New-Item -Path $reportDir -ItemType Directory -Force | Out-Null

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Wi-Fi診断ログ収集" -ForegroundColor Cyan
Write-Host " 出力先: $reportDir" -ForegroundColor Cyan
if (-not $isAdmin) {
    Write-Host " ※管理者権限なし - 一部コマンドはスキップされます" -ForegroundColor Yellow
}
Write-Host "========================================" -ForegroundColor Cyan

$since = (Get-Date).AddHours(-24)
$sinceStr = $since.ToString("yyyy/MM/dd HH:mm:ss")

# ============================================================
# 1. WLAN AutoConfig イベント (アソシエーション/切断/ローミング)
# ============================================================
Write-Host "`n[1/7] WLAN AutoConfig イベント収集中..." -ForegroundColor Green

try {
$wlanEvents = Get-WinEvent -FilterHashtable @{
    LogName   = 'Microsoft-Windows-WLAN-AutoConfig/Operational'
    StartTime = $since
} -ErrorAction SilentlyContinue

if ($wlanEvents) {
    $wlanEvents | Format-List TimeCreated, Id, LevelDisplayName, Message |
        Out-File (Join-Path $reportDir "01_WLAN-AutoConfig-All.txt") -Encoding utf8

    # 主要イベントを分類
    $categories = @{
        "01a_Association"  = @(8001, 8002, 11001, 11002, 11003, 11010, 11011)
        "01b_Disconnect"   = @(8003, 8004, 11004, 11006)
        "01c_Roaming"      = @(11004, 11005, 11006, 12011, 12012, 12013)
    }

    foreach ($cat in $categories.GetEnumerator()) {
        $filtered = $wlanEvents | Where-Object { $_.Id -in $cat.Value }
        if ($filtered) {
            $filtered | Format-List TimeCreated, Id, LevelDisplayName, Message |
                Out-File (Join-Path $reportDir "$($cat.Key).txt") -Encoding utf8
        }
    }

    # 切断理由サマリ
    $disconnects = $wlanEvents | Where-Object { $_.Id -in @(8003, 8004) }
    if ($disconnects) {
        $summary = $disconnects | Select-Object TimeCreated, Id,
            @{N='Message'; E={ ($_.Message -split "`n")[0..4] -join ' | ' }} |
            Format-Table -AutoSize -Wrap
        $summary | Out-File (Join-Path $reportDir "01d_Disconnect-Summary.txt") -Encoding utf8
    }

    Write-Host "  -> $($wlanEvents.Count) イベント収集" -ForegroundColor White
} else {
    "過去24時間にWLAN AutoConfigイベントはありません。" |
        Out-File (Join-Path $reportDir "01_WLAN-AutoConfig-All.txt") -Encoding utf8
    Write-Host "  -> イベントなし" -ForegroundColor Yellow
}
} catch {
"エラー: $_" | Out-File (Join-Path $reportDir "01_WLAN-AutoConfig-Error.txt") -Encoding utf8
Write-Host "  -> エラー: $_" -ForegroundColor Red
}

# ============================================================
# 2. WLAN MSM (メディア固有モジュール) イベント
# ============================================================
Write-Host "[2/7] WLAN MSM イベント収集中..." -ForegroundColor Green

try {
$msmEvents = Get-WinEvent -FilterHashtable @{
    LogName   = 'Microsoft-Windows-WLAN-AutoConfig/Operational'
    StartTime = $since
    Id        = @(12001, 12002, 12003, 12004, 12005, 12006,
                    12011, 12012, 12013, 12014, 12015, 12016)
} -ErrorAction SilentlyContinue

if ($msmEvents) {
    $msmEvents | Format-List TimeCreated, Id, LevelDisplayName, Message |
        Out-File (Join-Path $reportDir "02_WLAN-MSM.txt") -Encoding utf8
    Write-Host "  -> $($msmEvents.Count) イベント収集" -ForegroundColor White
} else {
    "過去24時間にWLAN MSMイベントはありません。" |
        Out-File (Join-Path $reportDir "02_WLAN-MSM.txt") -Encoding utf8
    Write-Host "  -> イベントなし" -ForegroundColor Yellow
}
} catch {
"イベントなし、またはログが無効です。" |
    Out-File (Join-Path $reportDir "02_WLAN-MSM.txt") -Encoding utf8
Write-Host "  -> スキップ" -ForegroundColor Yellow
}

# ============================================================
# 3. DHCP (IPv4) イベント
# ============================================================
Write-Host "[3/7] DHCPv4 イベント収集中..." -ForegroundColor Green

try {
# Dhcp-Client Admin + Operational
$dhcpEvents = @()

$dhcpAdmin = Get-WinEvent -FilterHashtable @{
    LogName   = 'Microsoft-Windows-Dhcp-Client/Admin'
    StartTime = $since
} -ErrorAction SilentlyContinue
if ($dhcpAdmin) { $dhcpEvents += $dhcpAdmin }

$dhcpOper = Get-WinEvent -FilterHashtable @{
    LogName   = 'Microsoft-Windows-Dhcp-Client/Operational'
    StartTime = $since
} -ErrorAction SilentlyContinue
if ($dhcpOper) { $dhcpEvents += $dhcpOper }

if ($dhcpEvents.Count -gt 0) {
    $dhcpEvents | Sort-Object TimeCreated |
        Format-List TimeCreated, Id, LevelDisplayName, Message |
        Out-File (Join-Path $reportDir "03_DHCPv4.txt") -Encoding utf8
    Write-Host "  -> $($dhcpEvents.Count) イベント収集" -ForegroundColor White
} else {
    "過去24時間にDHCPv4イベントはありません。" |
        Out-File (Join-Path $reportDir "03_DHCPv4.txt") -Encoding utf8
    Write-Host "  -> イベントなし" -ForegroundColor Yellow
}
} catch {
"エラー: $_" | Out-File (Join-Path $reportDir "03_DHCPv4-Error.txt") -Encoding utf8
Write-Host "  -> エラー: $_" -ForegroundColor Red
}

# ============================================================
# 4. DHCPv6 / IPv6 アドレス取得イベント
# ============================================================
Write-Host "[4/7] IPv6 / DHCPv6 イベント収集中..." -ForegroundColor Green

try {
$ipv6Events = @()

$dhcpv6 = Get-WinEvent -FilterHashtable @{
    LogName   = 'Microsoft-Windows-DHCPv6-Client/Admin'
    StartTime = $since
} -ErrorAction SilentlyContinue
if ($dhcpv6) { $ipv6Events += $dhcpv6 }

# DHCPv6 Operational (may not exist on all systems)
try {
    $dhcpv6Op = Get-WinEvent -FilterHashtable @{
        LogName   = 'Microsoft-Windows-DHCPv6-Client/Operational'
        StartTime = $since
    } -ErrorAction SilentlyContinue
    if ($dhcpv6Op) { $ipv6Events += $dhcpv6Op }
} catch { }

if ($ipv6Events.Count -gt 0) {
    $ipv6Events | Sort-Object TimeCreated |
        Format-List TimeCreated, Id, LevelDisplayName, Message |
        Out-File (Join-Path $reportDir "04_IPv6-DHCPv6.txt") -Encoding utf8
    Write-Host "  -> $($ipv6Events.Count) イベント収集" -ForegroundColor White
} else {
    "過去24時間にIPv6/DHCPv6イベントはありません。" |
        Out-File (Join-Path $reportDir "04_IPv6-DHCPv6.txt") -Encoding utf8
    Write-Host "  -> イベントなし" -ForegroundColor Yellow
}
} catch {
"エラー: $_" | Out-File (Join-Path $reportDir "04_IPv6-Error.txt") -Encoding utf8
Write-Host "  -> エラー: $_" -ForegroundColor Red
}

# 現在のIPアドレス情報
Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
Where-Object { $_.InterfaceAlias -notmatch 'Loopback' } |
Format-Table InterfaceAlias, IPAddress, PrefixLength, AddressState -AutoSize |
Out-File (Join-Path $reportDir "04a_Current-IPv4.txt") -Encoding utf8

Get-NetIPAddress -AddressFamily IPv6 -ErrorAction SilentlyContinue |
Where-Object { $_.InterfaceAlias -notmatch 'Loopback' } |
Format-Table InterfaceAlias, IPAddress, PrefixLength, AddressState -AutoSize |
Out-File (Join-Path $reportDir "04b_Current-IPv6.txt") -Encoding utf8

# ============================================================
# 5. Wi-Fiドライバ情報
# ============================================================
Write-Host "[5/7] Wi-Fiドライバ情報収集中..." -ForegroundColor Green

$driverFile = Join-Path $reportDir "05_WiFi-Driver.txt"

# netsh wlan show drivers
$netshDrivers = & netsh wlan show drivers 2>&1
$netshDrivers | Out-File $driverFile -Encoding utf8

# 追加: Get-NetAdapter で Wi-Fi アダプタ情報
"`n--- Get-NetAdapter Wi-Fi ---`n" | Out-File $driverFile -Append -Encoding utf8
Get-NetAdapter -Name "Wi-Fi*" -ErrorAction SilentlyContinue |
Format-List Name, InterfaceDescription, DriverVersion, DriverDate,
            DriverProvider, NdisVersion, MacAddress, Status |
Out-File $driverFile -Append -Encoding utf8

Write-Host "  -> 完了" -ForegroundColor White

# ============================================================
# 6. NCSI (Network Connectivity Status Indicator)
# ============================================================
Write-Host "[6/7] NCSI 結果収集中..." -ForegroundColor Green

$ncsiFile = Join-Path $reportDir "06_NCSI.txt"

try {
$ncsiEvents = Get-WinEvent -FilterHashtable @{
    LogName   = 'Microsoft-Windows-NCSI/Operational'
    StartTime = $since
} -ErrorAction SilentlyContinue

if ($ncsiEvents) {
    $ncsiEvents | Format-List TimeCreated, Id, LevelDisplayName, Message |
        Out-File $ncsiFile -Encoding utf8
    Write-Host "  -> $($ncsiEvents.Count) イベント収集" -ForegroundColor White
} else {
    "過去24時間にNCSIイベントはありません。" | Out-File $ncsiFile -Encoding utf8
    Write-Host "  -> イベントなし" -ForegroundColor Yellow
}
} catch {
"NCSIログの取得に失敗: $_" | Out-File $ncsiFile -Encoding utf8
Write-Host "  -> エラー: $_" -ForegroundColor Red
}

# NCSI レジストリ設定
"`n--- NCSI Registry Settings ---`n" | Out-File $ncsiFile -Append -Encoding utf8
try {
Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters\Internet" -ErrorAction SilentlyContinue |
    Format-List | Out-File $ncsiFile -Append -Encoding utf8
} catch {
"レジストリ取得失敗" | Out-File $ncsiFile -Append -Encoding utf8
}

# 現在のネットワーク接続プロファイル
"`n--- Network Connection Profile ---`n" | Out-File $ncsiFile -Append -Encoding utf8
Get-NetConnectionProfile -ErrorAction SilentlyContinue |
Format-List Name, InterfaceAlias, NetworkCategory, IPv4Connectivity, IPv6Connectivity |
Out-File $ncsiFile -Append -Encoding utf8

# ============================================================
# 7. 追加情報 (netsh wlan show all, wlanreport)
# ============================================================
Write-Host "[7/7] 追加情報収集中..." -ForegroundColor Green

# netsh wlan show interfaces
& netsh wlan show interfaces 2>&1 |
Out-File (Join-Path $reportDir "07a_WLAN-Interfaces.txt") -Encoding utf8

# netsh wlan show wlanreport (HTML形式の公式レポート) - 管理者権限が必要
if ($isAdmin) {
    try {
        & netsh wlan show wlanreport duration=1 2>&1 | Out-Null
        $wlanReportPath = "$env:ProgramData\Microsoft\Windows\WlanReport\wlan-report-latest.html"
        if (Test-Path $wlanReportPath) {
            Copy-Item $wlanReportPath (Join-Path $reportDir "07b_WlanReport.html") -Force
        }
    } catch { }
} else {
    "管理者権限がないため、netsh wlan show wlanreport を実行できませんでした。" |
        Out-File (Join-Path $reportDir "07b_WlanReport-SKIPPED.txt") -Encoding utf8
    Write-Host "  -> wlanreport: 管理者権限なしのためスキップ" -ForegroundColor Yellow
}

# netsh wlan show profiles
& netsh wlan show profiles 2>&1 |
Out-File (Join-Path $reportDir "07c_WLAN-Profiles.txt") -Encoding utf8

# NetworkProfile Operational events
try {
$npEvents = Get-WinEvent -FilterHashtable @{
    LogName   = 'Microsoft-Windows-NetworkProfile/Operational'
    StartTime = $since
} -ErrorAction SilentlyContinue

if ($npEvents) {
    $npEvents | Format-List TimeCreated, Id, LevelDisplayName, Message |
        Out-File (Join-Path $reportDir "07d_NetworkProfile.txt") -Encoding utf8
}
} catch { }

# システム情報サマリ
$adminStatus = if ($isAdmin) { "Yes" } else { "No (wlanreport skipped)" }
$sysInfo = @"
Computer Name : $pcName
OS Version    : $((Get-CimInstance Win32_OperatingSystem).Caption) Build $((Get-CimInstance Win32_OperatingSystem).BuildNumber)
Admin Rights  : $adminStatus
Collection    : $timestamp
Period        : $sinceStr ~ $(Get-Date -Format "yyyy/MM/dd HH:mm:ss")
"@
$sysInfo | Out-File (Join-Path $reportDir "00_SystemInfo.txt") -Encoding utf8

Write-Host "  -> 完了" -ForegroundColor White

# ============================================================
# ZIP圧縮
# ============================================================
Write-Host "`n圧縮中..." -ForegroundColor Cyan
$zipPath = "${reportDir}.zip"
Compress-Archive -Path $reportDir -DestinationPath $zipPath -Force

# 元フォルダ削除
Remove-Item -Path $reportDir -Recurse -Force

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " 完了!" -ForegroundColor Green
Write-Host " 出力: $zipPath" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# 結果フォルダをエクスプローラーで開く
Start-Process explorer.exe "/select,`"$zipPath`""

Write-Host "`n何かキーを押すと終了します..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
