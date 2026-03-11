# useful-PS-script-for-admins

Windows管理者向けPowerShellユーティリティスクリプト集
PowerShell utility scripts for Windows administrators

by Masafumi OE / masa@fumi.org

## Scripts

| Script | 概要 / Description |
|---|---|
| Collect-WLANReport.ps1 | 過去24時間のWi-Fi診断ログを収集しZIP出力 / Collects Wi-Fi diagnostic logs from the past 24 hours and outputs as ZIP |
| Add-SSHKeys.ps1 | 未登録のSSH秘密鍵をssh-agentに追加 / Registers unloaded SSH private keys into ssh-agent |
| Remove-SSHKeys.ps1 | ssh-agentから全鍵を一括削除 / Removes all keys from ssh-agent |

## Requirements

- Windows 11
- PowerShell 5.1+

## License

MIT
