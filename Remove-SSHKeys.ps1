<#
.SYNOPSIS
ssh-agentから全鍵を削除するスクリプト
by Masafumi OE / masa@fumi.org
#>

Write-Host "=== 現在の登録鍵 ===" -ForegroundColor Cyan
& ssh-add -l

Write-Host "`n全鍵を削除します..." -ForegroundColor Yellow
& ssh-add -D

if ($LASTEXITCODE -eq 0) {
    Write-Host "完了 - 全鍵を削除しました。" -ForegroundColor Green
} else {
    Write-Host "失敗" -ForegroundColor Red
}
