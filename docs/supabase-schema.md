# Supabaseデータベーススキーマ設計

## ドキュメントメタデータ

- 目的: Supabase テーブル定義、RLS 方針、関連 SQL を一元管理し、スキーマ変更時の基準とする。
- 対象読者: バックエンド開発者、データベース管理者、Codex エージェント。
- 最終更新: 2025-11-06（Codex）
- 関連ドキュメント: `sql/` ディレクトリ, `docs/agents-handbook.md`, `docs/documentation-guidelines.md`

## 概要

つくろぐアプリケーションのデータベース設計仕様書です。
PostgreSQLベース、Row Level Security (RLS) を活用してセキュアなデータアクセスを実現します。

## テーブル構成

### 1. profiles（ユーザープロフィール）

ユーザーの基本情報とプロフィール設定を管理

| カラム名             | 型          | NULL | デフォルト   | 説明                                                                                                                                                                   |
| -------------------- | ----------- | ---- | ------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| id                   | uuid        | NO   | -            | ユーザーID（auth.usersのidと同じ）                                                                                                                                     |
| email                | text        | NO   | -            | メールアドレス                                                                                                                                                         |
| display_name         | text        | YES  | -            | 表示名                                                                                                                                                                 |
| avatar_url           | text        | YES  | -            | プロフィール画像URL                                                                                                                                                    |
| role                 | text        | NO   | 'developer'  | 役割（保存値: developer）※現在は個人開発者のみをサポート                                                                                                               |
| age_group            | text        | YES  | -            | 年齢層（10代/20代/30代/40代/50代以上）                                                                                                                                 |
| gender               | text        | YES  | -            | 性別（男性/女性/その他/回答しない）                                                                                                                                    |
| occupation           | text        | YES  | -            | 職業区分（会社員/フリーランス/学生/その他）                                                                                                                            |
| work_type            | text        | YES  | -            | 作業タイプ（副業/本業）                                                                                                                                                |
| income_status        | text        | YES  | -            | 収益状況（保存値: no_income/under_10k/10k_to_50k/50k_to_100k/100k_to_200k/200k_to_300k/300k_to_500k/over_500k）                                                        |
| experience_years     | text        | YES  | -            | 経験年数（保存値: under_3_months/three_to_six_months/six_to_twelve_months/one_to_two_years/two_to_three_years/three_to_four_years/four_to_five_years/over_five_years） |
| bio                  | text        | YES  | -            | 自己紹介                                                                                                                                                               |
| timezone             | text        | NO   | 'Asia/Tokyo' | タイムゾーン                                                                                                                                                           |
| notification_enabled | boolean     | NO   | true         | 通知有効フラグ                                                                                                                                                         |
| onboarding_completed | boolean     | NO   | false        | オンボーディング完了フラグ                                                                                                                                             |
| created_at           | timestamptz | NO   | now()        | 作成日時                                                                                                                                                               |
| updated_at           | timestamptz | NO   | now()        | 更新日時                                                                                                                                                               |

**インデックス:**

- PRIMARY KEY (id)
- UNIQUE (email)
- INDEX (role, work_type) -- 比較機能用
- INDEX (created_at)

### 2. categories（カテゴリ管理）

デフォルトカテゴリとユーザーカスタムカテゴリ

| カラム名      | 型          | NULL | デフォルト        | 説明                                         |
| ------------- | ----------- | ---- | ----------------- | -------------------------------------------- |
| id            | uuid        | NO   | gen_random_uuid() | カテゴリID                                   |
| user_id       | uuid        | YES  | -                 | ユーザーID（NULLの場合はデフォルトカテゴリ） |
| name          | text        | NO   | -                 | カテゴリ名                                   |
| color         | text        | NO   | -                 | カラーコード（例: #3B82F6）                  |
| icon          | text        | YES  | -                 | アイコン名                                   |
| is_active     | boolean     | NO   | true              | 表示フラグ                                   |
| is_default    | boolean     | NO   | false             | デフォルトカテゴリフラグ                     |
| display_order | integer     | NO   | 0                 | 表示順                                       |
| created_at    | timestamptz | NO   | now()             | 作成日時                                     |
| updated_at    | timestamptz | NO   | now()             | 更新日時                                     |

**インデックス:**

- PRIMARY KEY (id)
- INDEX (user_id, is_active)
- INDEX (is_default)
- UNIQUE (user_id, name) -- ユーザー内で重複不可

### 3. logs（作業記録）

タイマー記録と手動入力の作業ログ

| カラム名         | 型          | NULL | デフォルト        | 説明               |
| ---------------- | ----------- | ---- | ----------------- | ------------------ |
| id               | uuid        | NO   | gen_random_uuid() | ログID             |
| user_id          | uuid        | NO   | -                 | ユーザーID         |
| title            | text        | NO   | 'その他'          | タイトル           |
| category_id      | uuid        | NO   | -                 | カテゴリID         |
| started_at       | timestamptz | NO   | -                 | 開始時刻           |
| ended_at         | timestamptz | NO   | -                 | 終了時刻           |
| duration_minutes | integer     | NO   | -                 | 作業時間（分）     |
| memo             | text        | YES  | -                 | メモ               |
| is_timer         | boolean     | NO   | false             | タイマー記録フラグ |
| created_at       | timestamptz | NO   | now()             | 作成日時           |
| updated_at       | timestamptz | NO   | now()             | 更新日時           |

**インデックス:**

- PRIMARY KEY (id)
- INDEX (user_id, started_at DESC)
- INDEX (user_id, category_id)
- INDEX (user_id, created_at DESC)

### 4. monthly_revenues（月次収益）

月別の収益記録

| カラム名   | 型            | NULL | デフォルト        | 説明             |
| ---------- | ------------- | ---- | ----------------- | ---------------- |
| id         | uuid          | NO   | gen_random_uuid() | レコードID       |
| user_id    | uuid          | NO   | -                 | ユーザーID       |
| year       | integer       | NO   | -                 | 年               |
| month      | integer       | NO   | -                 | 月（1-12）       |
| revenue    | decimal(10,2) | NO   | 0                 | 収益額（日本円） |
| note       | text          | YES  | -                 | メモ             |
| created_at | timestamptz   | NO   | now()             | 作成日時         |
| updated_at | timestamptz   | NO   | now()             | 更新日時         |

**インデックス:**

- PRIMARY KEY (id)
- UNIQUE (user_id, year, month)
- INDEX (user_id, year DESC, month DESC)

### 5. subscriptions（プレミアム課金管理）

Stripe/App Store課金状態の管理

| カラム名                 | 型          | NULL | デフォルト        | 説明                                            |
| ------------------------ | ----------- | ---- | ----------------- | ----------------------------------------------- |
| id                       | uuid        | NO   | gen_random_uuid() | サブスクリプションID                            |
| user_id                  | uuid        | NO   | -                 | ユーザーID                                      |
| status                   | text        | NO   | 'inactive'        | ステータス（active/inactive/canceled/past_due） |
| plan_type                | text        | NO   | 'free'            | プラン（free/premium）                          |
| provider                 | text        | YES  | -                 | 課金プロバイダ（stripe/app_store）              |
| provider_subscription_id | text        | YES  | -                 | プロバイダ側のサブスクID                        |
| provider_customer_id     | text        | YES  | -                 | プロバイダ側の顧客ID                            |
| current_period_start     | timestamptz | YES  | -                 | 現在の期間開始日                                |
| current_period_end       | timestamptz | YES  | -                 | 現在の期間終了日                                |
| cancel_at_period_end     | boolean     | NO   | false             | 期間終了時にキャンセルフラグ                    |
| created_at               | timestamptz | NO   | now()             | 作成日時                                        |
| updated_at               | timestamptz | NO   | now()             | 更新日時                                        |

**インデックス:**

- PRIMARY KEY (id)
- UNIQUE (user_id)
- INDEX (status, plan_type)
- INDEX (provider, provider_subscription_id)

### 6. comparisons_cache（比較データキャッシュ）

他の開発者との比較用集計キャッシュ

| カラム名   | 型          | NULL | デフォルト        | 説明                                      |
| ---------- | ----------- | ---- | ----------------- | ----------------------------------------- |
| id         | uuid        | NO   | gen_random_uuid() | キャッシュID                              |
| cache_key  | text        | NO   | -                 | キャッシュキー（例: all_users_daily_avg） |
| filters    | jsonb       | YES  | '{}'              | フィルター条件                            |
| data       | jsonb       | NO   | -                 | 集計データ                                |
| expires_at | timestamptz | NO   | -                 | 有効期限                                  |
| created_at | timestamptz | NO   | now()             | 作成日時                                  |

**インデックス:**

- PRIMARY KEY (id)
- UNIQUE (cache_key, filters)
- INDEX (expires_at)

## Row Level Security (RLS) ポリシー

### profiles

- SELECT: 自分のプロフィールのみ参照可能
- UPDATE: 自分のプロフィールのみ更新可能
- INSERT: 新規登録時のみ（auth.uid() = id）

### categories

- SELECT: デフォルトカテゴリは全員参照可、カスタムは自分のみ
- INSERT/UPDATE/DELETE: 自分のカスタムカテゴリのみ

### logs

- SELECT/INSERT/UPDATE/DELETE: 自分のログのみ
- UPDATE制限: 作成から48時間以内のみ編集可能

### monthly_revenues

- SELECT/INSERT/UPDATE/DELETE: 自分の収益データのみ

### subscriptions

- SELECT/UPDATE: 自分のサブスクリプションのみ
- INSERT: システムのみ（service_role）

### comparisons_cache

- SELECT: 全員参照可能
- INSERT/UPDATE/DELETE: システムのみ（service_role）

## トリガーとファンクション

### 1. handle_new_user()

新規ユーザー登録時にprofilesレコードを自動作成

### 2. update_updated_at()

各テーブルのupdated_atを自動更新

### 3. calculate_duration()

logsテーブルでstarted_at/ended_atから duration_minutes を自動計算

### 4. cleanup_expired_cache()

comparisons_cacheの期限切れデータを定期削除（cron）

## マイグレーション順序

1. 基本テーブル作成（profiles, categories）
2. デフォルトカテゴリデータ投入
3. ログ関連テーブル作成（logs, monthly_revenues）
4. 課金関連テーブル作成（subscriptions）
5. キャッシュテーブル作成（comparisons_cache）
6. RLSポリシー設定
7. トリガー・ファンクション設定
8. インデックス最適化

## Phase 5: アプリショーケース & レビュー交換

### 7. apps（アプリショーケース）

ユーザーが開発したアプリを登録・公開するためのテーブル

| カラム名       | 型            | NULL | デフォルト        | 説明                                          |
| -------------- | ------------- | ---- | ----------------- | --------------------------------------------- |
| id             | uuid          | NO   | gen_random_uuid() | アプリID                                      |
| user_id        | uuid          | NO   | -                 | 所有者のユーザーID                            |
| name           | text          | NO   | -                 | アプリ名                                      |
| description    | text          | YES  | -                 | アプリの説明                                  |
| icon_url       | text          | YES  | -                 | アイコン画像URL                               |
| screenshots    | jsonb         | YES  | '[]'              | スクリーンショットURL配列                     |
| platform       | text          | NO   | 'other'           | プラットフォーム（ios/android/web/other）      |
| app_url        | text          | YES  | -                 | アプリURL                                     |
| store_url      | text          | YES  | -                 | ストアURL                                     |
| github_url     | text          | YES  | -                 | GitHubリポジトリURL                           |
| status         | text          | NO   | 'draft'           | ステータス（draft/published/archived）        |
| category       | text          | YES  | -                 | カテゴリ                                      |
| avg_rating     | decimal(3,2)  | YES  | 0                 | 平均評価                                      |
| review_count   | integer       | YES  | 0                 | レビュー数                                    |
| created_at     | timestamptz   | NO   | now()             | 作成日時                                      |
| updated_at     | timestamptz   | NO   | now()             | 更新日時                                      |

**インデックス:**
- PRIMARY KEY (id)
- INDEX (user_id)
- INDEX (status)
- INDEX (platform)
- INDEX (category)
- INDEX (created_at DESC)
- INDEX (avg_rating DESC)

**RLSポリシー:**
- SELECT: 公開アプリは全認証ユーザー閲覧可、自分のアプリは全ステータス閲覧可
- INSERT/UPDATE/DELETE: 自分のアプリのみ

### 8. app_tags（アプリタグ）

アプリに紐づくタグ

| カラム名    | 型          | NULL | デフォルト        | 説明       |
| ----------- | ----------- | ---- | ----------------- | ---------- |
| id          | uuid        | NO   | gen_random_uuid() | タグID     |
| app_id      | uuid        | NO   | -                 | アプリID   |
| tag         | text        | NO   | -                 | タグ文字列 |
| created_at  | timestamptz | NO   | now()             | 作成日時   |

**インデックス:**
- PRIMARY KEY (id)
- UNIQUE (app_id, tag)
- INDEX (app_id)
- INDEX (tag)

**RLSポリシー:**
- SELECT: アプリが見える場合のみ（公開アプリまたは自分のアプリ）
- INSERT/DELETE: 自分のアプリのタグのみ

### 9. review_requests（レビューリクエスト）

レビュー交換のリクエスト

| カラム名           | 型          | NULL | デフォルト        | 説明                                                           |
| ------------------ | ----------- | ---- | ----------------- | -------------------------------------------------------------- |
| id                 | uuid        | NO   | gen_random_uuid() | リクエストID                                                   |
| app_id             | uuid        | NO   | -                 | 対象アプリID                                                   |
| requester_id       | uuid        | NO   | -                 | リクエスト作成者                                               |
| title              | text        | NO   | -                 | リクエストタイトル                                             |
| description        | text        | YES  | -                 | 説明                                                           |
| review_points      | text[]      | YES  | -                 | レビューしてほしいポイント                                     |
| status             | text        | NO   | 'open'            | ステータス（open/matched/in_progress/completed/cancelled）     |
| matched_at         | timestamptz | YES  | -                 | マッチング日時                                                 |
| deadline           | timestamptz | YES  | -                 | レビュー期限                                                   |
| max_reviewers      | integer     | NO   | 1                 | 最大レビュアー数                                               |
| current_reviewers  | integer     | NO   | 0                 | 現在のレビュアー数                                             |
| created_at         | timestamptz | NO   | now()             | 作成日時                                                       |
| updated_at         | timestamptz | NO   | now()             | 更新日時                                                       |

**インデックス:**
- PRIMARY KEY (id)
- INDEX (app_id)
- INDEX (requester_id)
- INDEX (status)
- INDEX (created_at DESC)

**RLSポリシー:**
- SELECT: オープン/マッチ/進行中/完了は全認証ユーザー、キャンセルは作成者のみ
- INSERT/UPDATE: 自分のリクエストのみ
- DELETE: 自分のopenリクエストのみ

### 10. reviews（レビュー）

実際のレビュー内容

| カラム名           | 型          | NULL | デフォルト        | 説明                                           |
| ------------------ | ----------- | ---- | ----------------- | ---------------------------------------------- |
| id                 | uuid        | NO   | gen_random_uuid() | レビューID                                     |
| review_request_id  | uuid        | NO   | -                 | 対応するリクエストID                           |
| app_id             | uuid        | NO   | -                 | 対象アプリID                                   |
| reviewer_id        | uuid        | NO   | -                 | レビュアーID                                   |
| rating             | integer     | NO   | -                 | 評価（1-5）                                    |
| title              | text        | NO   | -                 | レビュータイトル                               |
| body               | text        | NO   | -                 | レビュー本文                                   |
| pros               | text[]      | YES  | -                 | 良い点                                         |
| cons               | text[]      | YES  | -                 | 改善点                                         |
| status             | text        | NO   | 'draft'           | ステータス（draft/submitted/published）        |
| submitted_at       | timestamptz | YES  | -                 | 提出日時                                       |
| created_at         | timestamptz | NO   | now()             | 作成日時                                       |
| updated_at         | timestamptz | NO   | now()             | 更新日時                                       |

**インデックス:**
- PRIMARY KEY (id)
- UNIQUE (review_request_id, reviewer_id)
- INDEX (app_id)
- INDEX (reviewer_id)
- INDEX (review_request_id)
- INDEX (status)
- INDEX (rating)

**トリガー:** レビュー公開/変更/削除時にappsテーブルのavg_ratingとreview_countを自動更新

**RLSポリシー:**
- SELECT: 公開レビューは全員、自分のレビューは全ステータス、リクエスト作成者も閲覧可
- INSERT: 自分のレビューのみ（自分のアプリへの自己レビューは不可）
- UPDATE: 自分のdraft/submittedレビューのみ
- DELETE: 自分のdraftレビューのみ

### 11. reviewer_scores（レビュアースコア）

レビュアーの信頼性スコアとペナルティ

| カラム名              | 型            | NULL | デフォルト        | 説明                           |
| --------------------- | ------------- | ---- | ----------------- | ------------------------------ |
| id                    | uuid          | NO   | gen_random_uuid() | レコードID                     |
| user_id               | uuid          | NO   | -                 | ユーザーID                     |
| total_reviews         | integer       | NO   | 0                 | 総レビュー数                   |
| completed_reviews     | integer       | NO   | 0                 | 完了レビュー数                 |
| avg_review_quality    | decimal(3,2)  | YES  | 0                 | 平均レビュー品質（1-5）        |
| reliability_score     | decimal(5,2)  | NO   | 100.00            | 信頼性スコア（0-100）          |
| penalties_count       | integer       | NO   | 0                 | ペナルティ累計回数             |
| last_penalty_at       | timestamptz   | YES  | -                 | 最後のペナルティ日時           |
| streak_completed      | integer       | NO   | 0                 | 連続完了数                     |
| created_at            | timestamptz   | NO   | now()             | 作成日時                       |
| updated_at            | timestamptz   | NO   | now()             | 更新日時                       |

**インデックス:**
- PRIMARY KEY (id)
- UNIQUE (user_id)
- INDEX (reliability_score DESC)

**RLSポリシー:**
- SELECT: 全認証ユーザー閲覧可
- INSERT: 自分のレコードのみ
- UPDATE: service_roleのみ（不正防止、Edge Function経由）

## マイグレーション順序

1. 基本テーブル作成（profiles, categories）
2. デフォルトカテゴリデータ投入
3. ログ関連テーブル作成（logs, monthly_revenues）
4. 課金関連テーブル作成（subscriptions）
5. キャッシュテーブル作成（comparisons_cache）
6. RLSポリシー設定
7. トリガー・ファンクション設定
8. インデックス最適化
9. アプリショーケース（apps, app_tags）
10. レビュー交換（review_requests, reviews, reviewer_scores）

## パフォーマンス考慮事項

- logsテーブルは最も頻繁にアクセスされるため、適切なインデックスが重要
- 集計クエリは comparisons_cache を活用して負荷軽減
- 長期的にはlogsテーブルのパーティショニングを検討（月単位）
- appsテーブルのavg_ratingはレビュー変更時にトリガーで自動更新（クエリ時計算を回避）
- reviewer_scoresはユーザーごと1レコードのため、マッチング時の検索が高速
