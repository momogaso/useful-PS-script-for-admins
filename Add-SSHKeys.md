# Add-SSHKeys.ps1

ssh-agentに秘密鍵を登録するスクリプト

## 概要

`~/.ssh/` 配下の秘密鍵をssh-agentに登録する。既に登録済みの鍵はスキップする。

## 使い方

```powershell
& "C:\Users\masa\OneDrive\00bin\script\Add-SSHKeys.ps1"
```

- 管理者権限不要（ssh-agentサービスが起動済みであること）
- パスフレーズ付き鍵は入力を求められる

## 対象鍵

- id_ecdsa
- id_rsa
- id_dsa
- id_ed25519
- id_rsa-vsp

## 修正履歴

| 日付 | 内容 |
|---|---|
| 2026-03-11 | 初版作成 |
