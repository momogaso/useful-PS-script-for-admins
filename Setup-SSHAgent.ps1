<#
.SYNOPSIS
SSH秘密鍵のパーミッション修正・パスフレーズ設定・ssh-agent登録を行うスクリプト
by Masafumi OE / masa@fumi.org
.DESCRIPTION
1. ssh-agentサービスの状態確認（停止中の場合はガイドを表示）
2. 秘密鍵のパーミッション修正（不要なACLを除去）
3. パスフレーズ未設定の鍵にパスフレーズを設定
4. ssh-agentに全鍵を登録
※管理者権限は不要（ssh-agentサービスが起動済みであること）
#>

$keyDir = "$env:USERPROFILE\.ssh"
$keys = @("id_ecdsa", "id_rsa", "id_dsa", "id_ed25519", "id_rsa-vsp")

# --- Step 1: ssh-agent サービス確認 ---
Write-Host "`n=== Step 1: ssh-agent サービス確認 ===" -ForegroundColor Cyan
$svc = Get-Service ssh-agent -ErrorAction SilentlyContinue
if (-not $svc) {
    Write-Host "ssh-agent サービスが見つかりません。OpenSSH がインストールされていません。" -ForegroundColor Red
    exit 1
}

if ($svc.Status -ne 'Running') {
    Write-Host "ssh-agent が停止中です。管理者権限のPowerShellで以下を1回だけ実行してください:" -ForegroundColor Yellow
    Write-Host "  Set-Service ssh-agent -StartupType Automatic; Start-Service ssh-agent" -ForegroundColor White
    Write-Host "その後、本スクリプトを再実行してください。" -ForegroundColor Yellow
    Write-Host "`n何かキーを押すと終了します..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
} else {
    Write-Host "ssh-agent: 起動済み" -ForegroundColor Green
}

# --- Step 2: パーミッション修正 ---
Write-Host "`n=== Step 2: 秘密鍵パーミッション修正 ===" -ForegroundColor Cyan
foreach ($key in $keys) {
    $path = Join-Path $keyDir $key
    if (-not (Test-Path $path)) {
        Write-Host "  $key : ファイルなし - スキップ" -ForegroundColor Yellow
        continue
    }

    # 現在のACLを確認し、不要なエントリを除去
    $acl = Get-Acl $path
    foreach ($ace in @($acl.Access)) {
        $id = $ace.IdentityReference.Value
        if ($id -match "LogonSessionId|BUILTIN\\Users|Everyone") {
            $acl.RemoveAccessRule($ace) | Out-Null
        }
    }

    # 自分自身のRead+Write権限を確保（パスフレーズ変更時に書き込みが必要）
    $userRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        $env:USERNAME, "Read,Write", "Allow")
    $acl.SetAccessRule($userRule)

    Set-Acl -Path $path -AclObject $acl
    Write-Host "  $key : パーミッション修正完了" -ForegroundColor Green
}

# --- Step 3: パスフレーズ設定 ---
Write-Host "`n=== Step 3: パスフレーズ設定 ===" -ForegroundColor Cyan
Write-Host "パスフレーズ未設定の鍵にパスフレーズを設定します。" -ForegroundColor White
Write-Host "既にパスフレーズが設定済みの鍵はそのままにします。" -ForegroundColor White

foreach ($key in $keys) {
    $path = Join-Path $keyDir $key
    if (-not (Test-Path $path)) { continue }

    # 鍵ファイルの先頭を読んでパスフレーズ有無を判定
    # OpenSSH新形式: base64の2行目に暗号方式が含まれる（"none"=パスフレーズなし）
    # PEM形式: "ENCRYPTED" ヘッダで判定
    $headBytes = Get-Content $path -Head 5 -ErrorAction SilentlyContinue
    $headStr = ($headBytes -join " ")
    $encrypted = ($headStr -match "ENCRYPTED") -or
                 ($headStr -match "b3BlbnNzaC1rZXktdjE" -and $headStr -notmatch "b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQ")

    if ($encrypted) {
        Write-Host "  $key : パスフレーズ設定済み - スキップ" -ForegroundColor Green
    } else {
        Write-Host "  $key : パスフレーズ未設定 - 設定します" -ForegroundColor Yellow
        Write-Host "    ssh-keygen が起動します。現在のパスフレーズは空Enterで進めてください。" -ForegroundColor White
        & ssh-keygen -p -f $path
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    -> 設定完了" -ForegroundColor Green
        } else {
            Write-Host "    -> 失敗 (手動で ssh-keygen -p -f $path を実行してください)" -ForegroundColor Red
        }
    }
}

# --- Step 3.5: パーミッションをRead-onlyに戻す ---
Write-Host "`n=== パーミッションをRead-onlyに戻します ===" -ForegroundColor Cyan
foreach ($key in $keys) {
    $path = Join-Path $keyDir $key
    if (-not (Test-Path $path)) { continue }
    $acl = Get-Acl $path
    foreach ($ace in @($acl.Access)) {
        if ($ace.IdentityReference.Value -match [regex]::Escape($env:USERNAME)) {
            $acl.RemoveAccessRule($ace) | Out-Null
        }
    }
    $userRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        $env:USERNAME, "Read", "Allow")
    $acl.SetAccessRule($userRule)
    Set-Acl -Path $path -AclObject $acl
}
Write-Host "  完了" -ForegroundColor Green

# --- Step 4: ssh-agent に鍵を登録 ---
Write-Host "`n=== Step 4: ssh-agent に鍵を登録 ===" -ForegroundColor Cyan
foreach ($key in $keys) {
    $path = Join-Path $keyDir $key
    if (-not (Test-Path $path)) { continue }

    # 既に登録済みか確認
    $loaded = & ssh-add -l 2>&1
    $pubkey = & ssh-keygen -l -f $path 2>&1
    if ($pubkey -and $loaded -match ($pubkey -replace '.*?(SHA256:\S+).*','$1')) {
        Write-Host "  $key : 登録済み - スキップ" -ForegroundColor Green
        continue
    }

    Write-Host "  $key : 登録中 (パスフレーズを入力してください)..." -ForegroundColor White
    & ssh-add $path
    if ($LASTEXITCODE -eq 0) {
        Write-Host "    -> 登録完了" -ForegroundColor Green
    } else {
        Write-Host "    -> 失敗" -ForegroundColor Red
    }
}

# --- 結果確認 ---
Write-Host "`n=== 登録済み鍵一覧 ===" -ForegroundColor Cyan
& ssh-add -l

Write-Host "`n完了しました。" -ForegroundColor Green
Write-Host "何かキーを押すと終了します..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
