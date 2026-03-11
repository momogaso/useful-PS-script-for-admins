# Collect-WLANReport.ps1

Wi-Fi診断ログ収集スクリプト (Windows 11)

## 概要

過去24時間のWi-Fi関連イベントログ（アソシエーション・切断・ローミング・DHCP・NCSI等）を収集し、ZIP圧縮して出力する。

## 使い方

1. `Collect-WLANReport.ps1` を右クリック →「PowerShellで実行」
2. UAC昇格ダイアログが表示される → 「はい」で管理者権限で実行（「いいえ」でも一部制限付きで続行可能）
3. フォルダ選択ダイアログで出力先を選択
4. 自動的にログ収集・ZIP圧縮が行われ、エクスプローラーで結果が表示される

## 管理者権限について

- UAC昇格を試行し、キャンセルされた場合は一般権限で続行する
- 管理者権限が必要なコマンド（`netsh wlan show wlanreport`）は、権限がない場合スキップされ、`07b_WlanReport-SKIPPED.txt` にその旨が記録される
- `00_SystemInfo.txt` の `Admin Rights` 行で権限状態を確認可能

## 出力ファイル一覧

| ファイル名 | 内容 |
|---|---|
| `00_SystemInfo.txt` | PC名・OS・収集日時・管理者権限状態 |
| `01_WLAN-AutoConfig-All.txt` | WLAN AutoConfig全イベント |
| `01a_Association.txt` | アソシエーションイベント |
| `01b_Disconnect.txt` | 切断イベント |
| `01c_Roaming.txt` | ローミングイベント |
| `01d_Disconnect-Summary.txt` | 切断理由サマリ |
| `02_WLAN-MSM.txt` | WLAN MSM (メディア固有モジュール) イベント |
| `03_DHCPv4.txt` | DHCPv4イベント |
| `04_IPv6-DHCPv6.txt` | IPv6/DHCPv6イベント |
| `04a_Current-IPv4.txt` | 現在のIPv4アドレス情報 |
| `04b_Current-IPv6.txt` | 現在のIPv6アドレス情報 |
| `05_WiFi-Driver.txt` | Wi-Fiドライバ情報 + NetAdapter情報 |
| `06_NCSI.txt` | NCSIイベント・レジストリ設定・接続プロファイル |
| `07a_WLAN-Interfaces.txt` | WLAN インターフェース情報 |
| `07b_WlanReport.html` | 公式WLANレポート (管理者権限時のみ) |
| `07b_WlanReport-SKIPPED.txt` | 管理者権限なし時のスキップ記録 |
| `07c_WLAN-Profiles.txt` | WLANプロファイル一覧 |
| `07d_NetworkProfile.txt` | NetworkProfileイベント |

## 出力形式

`WLANreport-<PC名>-<yyyyMMdd-HHmmss>.zip`

## 修正履歴

| 日付 | 内容 |
|---|---|
| 2026-03-10 | UAC昇格失敗時に一般権限で続行する機能を追加。管理者必須コマンドはスキップしてログに記録。BOM付きUTF-8に変換しパースエラーを修正。 |


## 連絡先
おおえまさふみ <masa@fumi.org>