# Setup-SSHAgent.ps1

SSH秘密鍵のパーミッション修正・パスフレーズ設定・ssh-agent登録を行うスクリプト

## 概要

初回セットアップ用スクリプト。以下を順に実行する：

1. ssh-agentサービスの状態確認
2. 秘密鍵のパーミッション修正（LogonSessionId等の不要なACLを除去）
3. パスフレーズ未設定の鍵にパスフレーズを設定
4. パーミッションをRead-onlyに戻す
5. ssh-agentに全鍵を登録

## 使い方

```powershell
& "C:\Users\masa\OneDrive\00bin\script\Setup-SSHAgent.ps1"
```

- 管理者権限不要（ssh-agentサービスが起動済みであること）
- ssh-agentが停止中の場合は、管理者権限での起動手順を案内して終了

## 対象鍵

- id_ecdsa
- id_rsa
- id_dsa
- id_ed25519
- id_rsa-vsp

## パスフレーズ判定ロジック

- PEM形式: ヘッダの `ENCRYPTED` で判定
- OpenSSH新形式: base64内の暗号方式（`none` = 未設定）で判定

## 修正履歴

| 日付 | 内容 |
|---|---|
| 2026-03-11 | 初版作成。管理者権限不要に修正。パスフレーズ判定ロジック改善。 |
