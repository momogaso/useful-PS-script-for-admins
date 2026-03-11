<#
.SYNOPSIS
ssh-agentに秘密鍵を登録するスクリプト
by Masafumi OE / masa@fumi.org
.DESCRIPTION
未登録の秘密鍵のみをssh-agentに追加する。管理者権限不要。
#>

$keyDir = "$env:USERPROFILE\.ssh"
$keys = @("id_ecdsa", "id_rsa", "id_dsa", "id_ed25519", "id_rsa-vsp")

# ssh-agent 確認
$svc = Get-Service ssh-agent -ErrorAction SilentlyContinue
if (-not $svc -or $svc.Status -ne 'Running') {
    Write-Host "ssh-agent が起動していません。" -ForegroundColor Red
    exit 1
}

# 登録済み鍵の一覧を取得
$loaded = & ssh-add -l 2>&1

foreach ($key in $keys) {
    $path = Join-Path $keyDir $key
    if (-not (Test-Path $path)) { continue }

    # 既に登録済みか確認
    $fingerprint = & ssh-keygen -l -f $path 2>&1
    if ($fingerprint -match '(SHA256:\S+)') {
        $fp = $Matches[1]
        if ($loaded -match [regex]::Escape($fp)) {
            Write-Host "  $key : 登録済み" -ForegroundColor Green
            continue
        }
    }

    Write-Host "  $key : 登録中..." -ForegroundColor Yellow
    & ssh-add $path
    if ($LASTEXITCODE -eq 0) {
        Write-Host "    -> 完了" -ForegroundColor Green
    } else {
        Write-Host "    -> 失敗" -ForegroundColor Red
    }
}

Write-Host "`n=== 登録済み鍵一覧 ===" -ForegroundColor Cyan
& ssh-add -l
