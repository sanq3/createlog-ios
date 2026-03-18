# つくろぐ v2.0 設計ドキュメント

## 概要

つくろぐは、エンジニア・個人開発者のための統合プラットフォーム。作業記録、SNS、ポートフォリオを一つのアプリに統合し、AI時代に増えるエンジニアの市場を先行して取る。

既存のReact Native版（v1.x）はユーザー数0のため、Swiftでフルリビルドする。

### ポジショニング

Studyplus（学生向け学習記録）のエンジニア版。ただしUI/UXは既存アプリの模倣ではなく、スクショを撮ってシェアしたくなるレベルの体験を提供する。ユーザー自身がマーケティングしたくなる品質を目指す。

### ターゲット

- AI時代・バイブコーディングで参入する初心者エンジニア
- 個人開発者・フリーランス
- 日本市場から開始、グローバル展開

### 競合市場

WakaTime（自動記録）、Studyplus（記録SNS）、Qiita/Zenn（技術記事）、Twitter/X（エンジニアSNS）の領域を一つのプラットフォームでカバーする。

---

## MVP（v2.0）スコープ

### 含めるもの

- 認証（Sign in with Apple / Google / GitHub / Email）
- 手動記録（タイマー + 手動入力 + カテゴリ選択）
- 自動記録（VS Code / Cursor拡張によるheartbeat連携）
- レポート（Swift Chartsでグラフ表示、画像生成によるシェア機能）
- カレンダー（ヒートマップ表示、日別詳細）
- タイムライン / フィード（フォロー中 / おすすめ切替）
- SNS（投稿、いいね、リポスト、コメント、ハッシュタグ、メンション）
- フォロー / フォロワー
- プロフィール（ポートフォリオ表示、マイアプリ、統計サマリー）
- 通知（種類別フィルタ、グルーピング、プッシュ通知）
- 発見（検索、トレンド、おすすめユーザー）
- 設定（アカウント、連携管理、通知設定、テーマ、言語）
- プレミアム（月額サブスク、App Store IAP）
- ダーク / ライトモード
- 日本語 / 英語対応

### v2.1以降

- Claude Code / ターミナルツール連携
- GitHub連携
- 比較・ランキング（年齢・職業・経験値別）
- 記事・ノート投稿（Qiita/Zenn市場参入）
- レビューチケット（依頼 + 評価制度）
- 収益の可視化・比較
- アプリ内通貨・決済
- Android版
- Web版

---

## 技術スタック

| 項目 | 技術 |
|---|---|
| 言語 | Swift |
| UIフレームワーク | SwiftUI（メイン）+ UIKit（必要箇所のみ） |
| 最低iOS | iOS 18（iOS 26ではLiquid Glass等の拡張体験を提供） |
| バックエンド | Supabase（PostgreSQL + Auth + Realtime + Storage + Edge Functions） |
| Supabase SDK | supabase-swift |
| ローカルDB | SwiftData |
| グラフ | Swift Charts |
| 画像キャッシュ | Nuke または Kingfisher |
| 認証 | Supabase Auth（Apple / Google / GitHub / Email OAuth） |
| プッシュ通知 | APNs + Supabase Edge Functions |
| CI/CD | GitHub Actions（PR時ビルド+テスト、mainマージ時TestFlight自動デプロイ） |
| テスト | Swift Testing framework |
| VS Code拡張 | TypeScript（VS Code Extension API） |

---

## アーキテクチャ

### モジュラー構成（Swift Package）

```
createlog-ios/
  App/
    CreateLogApp.swift
    AppDelegate.swift
    DI/
    Navigation/               -- Coordinator / Router

  Features/
    Auth/
      Views/
      ViewModels/
      Components/
    Home/
      Views/
      ViewModels/
      Components/
    Discover/
      Views/
      ViewModels/
      Components/
    Recording/
      Views/
        RecordingView.swift
        ReportView.swift
        CalendarView.swift
      ViewModels/
        RecordingViewModel.swift
        ReportViewModel.swift
      Components/
        TimerDisplay.swift
        CategoryPicker.swift
        WeeklyChart.swift
    Notifications/
      Views/
      ViewModels/
      Components/
    Profile/
      Views/
      ViewModels/
      Components/
    Settings/
      Views/
      ViewModels/

  Core/
    DesignSystem/
      Colors.swift
      Typography.swift
      Components/              -- 共通UIコンポーネント
    Networking/
      SupabaseClient.swift
      RequestInterceptor.swift
      RetryPolicy.swift
      OfflineQueue.swift
    Models/
    Storage/
      SwiftDataStore.swift
      KeychainManager.swift
    Utilities/

  Resources/
    Assets.xcassets
    Localizable.xcstrings
```

### パターン

- **MVVM** — View + ViewModel + Model
- **Coordinator** — 画面遷移の管理、ディープリンク対応
- **依存性注入** — `@Environment`ベース、外部ライブラリ不要
- **Repository** — データアクセス層をViewModelから分離

---

## タブ構成

| タブ | 役割 |
|---|---|
| ホーム | フィード。フォロー中 / おすすめのセグメント切替。投稿カード、ライブステータス表示 |
| 発見 | 検索バー、トレンドタグ、おすすめユーザー、カテゴリフィルタ |
| 記録（中央） | セグメント切替: 記録 / レポート / カレンダー |
| 通知 | 種類別フィルタ（すべて / いいね / フォロー / メンション）、グルーピング表示 |
| プロフィール | ポートフォリオ、マイアプリ、統計サマリー、フォロー/フォロワー |

---

## 画面詳細

### ホーム（フィード）

- セグメント切替: フォロー中 / おすすめ（スワイプでも切替可能）
- 投稿カード: アバター、名前、ハンドル、作業時間バッジ、本文、画像、リアクション
- 投稿ボタン: 右下フローティング（SF Symbol: plus.circle.fill）
- プルトゥリフレッシュ: カスタムアニメーション付き
- 無限スクロール: カーソルベースページネーション、到達前に先読み
- 長押し: Context Menuで投稿プレビュー
- ダブルタップ: いいね + ハートアニメーション演出
- ライブステータス: 「N人が今作業中」のバー表示（Supabase Presence）
- ステータスドット: オンライン / コーディング中 / オフライン

### 発見（検索）

- 検索バー: 上部固定、ユーザー / ハッシュタグ / アプリを横断検索
- トレンドタグ: リアルタイム更新
- おすすめユーザー: 年齢・職業・経験値の近い人を優先表示
- カテゴリフィルタ: iOS / Web / AI / ゲーム等

### 記録タブ — セグメント: 記録 / レポート / カレンダー

**記録:**
- 現在の記録状況（自動トラッキング中なら「VS Codeで記録中」のライブ表示）
- タイマー（手動用、カテゴリ選択付き）
- 今日の記録一覧
- 連携状況（VS Code / Cursor の接続状態表示）

**レポート:**
- 期間切替: 今日 / 今週 / 今月 / 累計
- Swift Chartsによるグラフ（棒グラフで週間推移、円グラフでカテゴリ別割合）
- 数値サマリー（今日の時間、今週の時間、累計、日平均、前週比）
- 連続記録日数（ストリーク）の表示
- シェアボタン: ImageRendererでレポートカードを画像生成。アプリロゴ透かし入り
- 他ユーザーとの比較 → プレミアム機能

**カレンダー:**
- 月表示、日ごとの作業時間をヒートマップ的に色の濃淡で表現
- 日付タップでその日の記録詳細をボトムシートで表示
- 月間サマリー（合計時間、最多カテゴリ、ベストデイ）

### 通知

- フィルタタブ: すべて / いいね / フォロー / メンション / システム
- 未読/既読: スワイプで既読、一括既読ボタン
- タップで該当画面に直接遷移（ディープリンク）
- グルーピング: 「Aと他3人があなたの投稿にいいねしました」

### プロフィール

- ヘッダー: アバター、名前、ハンドル、自己紹介、フォロー/フォロワー数
- 統計バッジ: 累計時間、連続日数、作成アプリ数
- マイアプリセクション: アプリアイコン + 名前 + 説明 + スクリーンショット（横スクロール）、App Storeリンク付き
- マイ投稿: 自分の投稿履歴
- 現在のステータス: リアルタイム表示（作業中等）
- 編集: プロフィール編集画面（アバター、名前、自己紹介、SNSリンク、職業、経験年数）

### 設定

- アカウント管理（メール変更、パスワード、ログアウト、アカウント削除）
- 連携管理（VS Code / Cursor の接続・切断）
- 通知設定（種類別にON/OFF）
- プレミアム管理（プラン確認・変更）
- テーマ切替（ダーク / ライト / システム準拠）
- 言語切替（日本語 / English）
- プライバシーポリシー・利用規約
- お問い合わせ・サポート

---

## デザインシステム

### カラートークン

**ダークモード:**

| 用途 | 値 |
|---|---|
| Background | `#0e0e10` |
| Surface Low | `rgba(200,200,220, 0.03)` |
| Surface High | `rgba(200,200,220, 0.06)` |
| Border | `rgba(200,200,220, 0.06)` ~ `0.1` |
| Text Primary | `#e0e0ec` |
| Text Secondary | `rgba(200,200,220, 0.45)` |
| Text Tertiary | `rgba(200,200,220, 0.25)` |
| Accent | `#d0d0e0` |
| Success | `#4ade80` |
| Error | `#f87171` |
| Recording Active | `#60a5fa` |

**ライトモード:**

| 用途 | 値 |
|---|---|
| Background | `#f8f8fa` |
| Surface Low | `rgba(0,0,0, 0.02)` |
| Surface High | `rgba(0,0,0, 0.04)` |
| Text Primary | `#1a1a1e` |
| Accent | `#4a4a60` |

同じセマンティクスで明暗反転。

### タイポグラフィ

- 大見出し: SF Pro Display, 28pt, Bold
- 小見出し: SF Pro Display, 14pt, Semibold
- 本文: SF Pro Text, 14pt, Regular
- キャプション: SF Pro Text, 11pt, Regular
- 数字表示: tabular-nums（等幅数字）

### アイコン

- SF Symbols統一
- ウェイト: Regular基本、アクティブ時はFill variant
- 絵文字は一切使用しない

### 角丸

- カード: 16pt
- ボタン: 12pt
- アバター: 円形
- 入力フィールド: 10pt

### Liquid Glass（iOS 26）

適用箇所:
- ナビゲーションバー
- タブバー
- フローティングアクションボタン
- ボトムシート
- セグメントコントロール

iOS 18-25は`Material`（.ultraThinMaterial等）で代替。`if #available(iOS 26, *)` で分岐。

### アニメーション原則

- Duration: 200-500ms
- Easing: SwiftUIの`.spring(duration: 0.3)`をベースに
- 目的のないアニメーションは入れない
- 数字はカウントアップで表示
- グラフは下から伸びるトランジション
- 画面遷移はmatchedGeometryEffectで要素の連続性を保つ
- リストはstaggered animation（要素が順番に現れる）

### ハプティクス

- いいね / リアクション: `.impact(.light)`
- 記録開始 / 停止: `.impact(.medium)`
- マイルストーン達成: `.notification(.success)`
- エラー: `.notification(.error)`
- セグメント切替: `.selection`
- 過剰に使わない。意味のあるアクションだけ

---

## データフロー & バックエンド連携

### 既存Supabaseバックエンド

31個のマイグレーションファイル、16以上のテーブル、RLSポリシー、トリガー、PostgreSQL関数が全て構築済み。MVPに必要なスキーマは全て揃っている。

### リアルタイム通信

- タイムライン: Supabase Realtimeチャネル。フォロー中のユーザーに限定したフィルタリングをDB側で実行
- 通知: Supabase Realtime + APNs。Edge Functionsでプッシュ通知を非同期処理
- ステータス: Presenceチャネル。接続切れ時の自動クリアはDBトリガーで実装済み

### データキャッシュ & オフライン対応

- SwiftDataでローカルキャッシュ
- Stale-While-Revalidate方式: ローカルを即表示 → バックグラウンドで最新取得 → 差分更新
- オフライン時の操作はOfflineQueueに保持、復帰時に自動送信

### 画像パイプライン

- アップロード時: クライアントでHEIF圧縮 → Supabase Storageに3サイズ保存（サムネ64px / 中300px / 原寸）
- 表示時: Nuke等の画像キャッシュライブラリでメモリ + ディスク2層キャッシュ
- CDN配信

### ネットワーク層

```
NetworkClient（プロトコル）
  SupabaseClient     -- Auth, Database, Realtime, Storage
  RequestInterceptor -- JWT自動付与、トークンリフレッシュ
  RetryPolicy        -- 指数バックオフ、最大3回
  OfflineQueue       -- オフライン操作の保持と復帰時送信
```

### 自動トラッキング（VS Code / Cursor拡張）

- TypeScriptで開発、VS Code Marketplace公開
- エディタイベント（ファイル開く、保存、キー入力）を検知
- 5分間隔でheartbeatsをバッチ送信（コスト最適化）
- api_keysテーブルのSHA-256ハッシュで認証
- CursorはVS Code拡張がそのまま動作

---

## スケーラビリティ（DAU 1万超え対策）

- ページネーション: カーソルベース（created_at基準）
- N+1問題回避: PostgreSQL関数で1クエリ取得（stats_functions実装済み）
- レート制限: Edge Functionsでユーザーごとのリクエスト制限
- CDN: 画像・静的アセットはSupabase StorageのCDN配信
- インデックス: foreign keyとクエリパターンに戦略的インデックス配置済み
- 事前集計: daily_statsテーブルでリアルタイム集計を回避（トリガー実装済み）
- Realtimeコネクション管理: 不要時はチャネル切断、接続数を最小化
- heartbeatsバッチ送信: 個別送信ではなく5分間隔でまとめて送信

---

## セキュリティ

- 認証トークン: Keychainに保存（UserDefaults禁止）
- RLS: 全テーブルに適用済み。フロントからの不正アクセスはDB層でブロック
- API Keys: SHA-256ハッシュで保存（平文保存なし）
- Certificate Pinning: Supabaseとの通信をピン留め
- 入力バリデーション: クライアント側 + DB側CHECK制約で二重チェック
- 24時間編集窓: 投稿は作成から24時間以内のみ編集可能（DB制約実装済み）

---

## UI/UXの原則

- 絵文字は一切使用しない。アイコンはSF Symbols
- AI感のあるデザインは禁止（紫・ネオン・サイバー系は使わない）
- アーバングレーのモノトーン基調。質感と動きで魅せる
- グラスモーフィズム + アニメーションで奥行きと没入感を表現
- オプティミスティックUI: いいね等はタップ即反映、サーバー確認を待たない
- スケルトンUI: ローディング中は灰色のプレースホルダー表示。スピナーは使わない
- ハプティクスとアニメーションを連動させ「気持ちいい」操作感を実現
- エラーはインラインバナーで表示。画面遷移させない
- 空状態はイラスト + メッセージで案内（アプリ独自のイラストを用意）
- ナビゲーション: グラスモーフィズム適用、スクロールで半透明化
- シート: ボトムシートで詳細表示。フルモーダルは最小限
- トースト: 操作完了の軽い通知
- レポートのシェア画像は映えるデザインにし、アプリロゴの透かしを入れる。ユーザーが自発的に拡散したくなる品質

---

## コスト最適化

- Supabase無料枠の最大活用
- Realtimeの接続数を最小限に、不要時はチャネル切断
- heartbeatsはバッチ送信（5分間隔）
- 画像はクライアント側でHEIF圧縮してからアップロード
- daily_statsは事前集計（リアルタイム集計を回避）
- 画像は3サイズ保存し、表示コンテキストに応じた最小サイズを取得

---

## テスト & CI/CD

**テスト:**
- Unit Tests: ViewModel、ネットワーク層、データ変換（Swift Testing framework）
- UI Tests: 主要画面遷移、記録フロー、認証フロー

**CI/CD（GitHub Actions）:**
- PR作成時: ビルド + Unit Test自動実行
- mainマージ時: TestFlightへ自動デプロイ
- App Store提出: 手動トリガー

---

## 展開計画

- 日本市場から開始
- App Store規約を調査し、全機能が規約に準拠していることを確認
- ユーザーフィードバックを収集しながらv2.1以降の機能を段階的に追加
- 将来的にAndroid版、Web版をリリース
- 多言語・多地域の規約に対応しながらグローバル展開

---

## 課金モデル

- 基本無料 + プレミアム（月額サブスク、App Store IAP）
- Twitter的ビジネスモデルを参考
- 無料でコア体験は全て使える
- プレミアム: 詳細分析、他ユーザーとの比較、レビューチケット優先マッチング、記事の収益化機能等
- 将来的にアプリ内通貨・決済の導入も検討

---

## 補足: ウィジェット対応

App Groupsを初期から設定し、将来的にロック画面ウィジェット（今日の作業時間、ストリーク等）を追加できる設計にしておく。
