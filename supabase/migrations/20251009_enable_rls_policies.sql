-- Row Level Security (RLS) ポリシーの有効化と設定

-- 1. profilesテーブルのRLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- ユーザーは自分のプロフィールのみ閲覧可能
CREATE POLICY "Users can view own profile" ON profiles
  FOR SELECT USING (auth.uid() = id);

-- ユーザーは自分のプロフィールのみ更新可能
CREATE POLICY "Users can update own profile" ON profiles
  FOR UPDATE USING (auth.uid() = id);

-- ユーザーは自分のプロフィールのみ作成可能
CREATE POLICY "Users can insert own profile" ON profiles
  FOR INSERT WITH CHECK (auth.uid() = id);


-- 2. logsテーブルのRLS
ALTER TABLE logs ENABLE ROW LEVEL SECURITY;

-- ユーザーは自分のログのみ閲覧可能
CREATE POLICY "Users can view own logs" ON logs
  FOR SELECT USING (auth.uid() = user_id);

-- ユーザーは自分のログのみ作成可能
CREATE POLICY "Users can insert own logs" ON logs
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ユーザーは自分のログのみ更新可能
CREATE POLICY "Users can update own logs" ON logs
  FOR UPDATE USING (auth.uid() = user_id);

-- ユーザーは自分のログのみ削除可能
CREATE POLICY "Users can delete own logs" ON logs
  FOR DELETE USING (auth.uid() = user_id);


-- 3. categoriesテーブルのRLS
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;

-- ユーザーは自分のカテゴリまたはデフォルトカテゴリのみ閲覧可能
CREATE POLICY "Users can view own and default categories" ON categories
  FOR SELECT USING (
    auth.uid() = user_id OR
    user_id IS NULL  -- デフォルトカテゴリ
  );

-- ユーザーは自分のカテゴリのみ作成可能
CREATE POLICY "Users can insert own categories" ON categories
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ユーザーは自分のカテゴリのみ更新可能
CREATE POLICY "Users can update own categories" ON categories
  FOR UPDATE USING (auth.uid() = user_id);

-- ユーザーは自分のカテゴリのみ削除可能
CREATE POLICY "Users can delete own categories" ON categories
  FOR DELETE USING (auth.uid() = user_id);


-- 4. monthly_revenuesテーブルのRLS
ALTER TABLE monthly_revenues ENABLE ROW LEVEL SECURITY;

-- ユーザーは自分の収益データのみ閲覧可能
CREATE POLICY "Users can view own revenues" ON monthly_revenues
  FOR SELECT USING (auth.uid() = user_id);

-- ユーザーは自分の収益データのみ作成可能
CREATE POLICY "Users can insert own revenues" ON monthly_revenues
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ユーザーは自分の収益データのみ更新可能
CREATE POLICY "Users can update own revenues" ON monthly_revenues
  FOR UPDATE USING (auth.uid() = user_id);

-- ユーザーは自分の収益データのみ削除可能
CREATE POLICY "Users can delete own revenues" ON monthly_revenues
  FOR DELETE USING (auth.uid() = user_id);


-- 5. subscriptionsテーブルのRLS
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;

-- ユーザーは自分のサブスクリプションのみ閲覧可能
CREATE POLICY "Users can view own subscriptions" ON subscriptions
  FOR SELECT USING (auth.uid() = user_id);

-- サブスクリプションの作成・更新はサーバー側のみ（service_roleキー使用時のみ）
-- 通常のユーザーは作成・更新不可


-- 6. comparisons_cacheテーブルのRLS
ALTER TABLE comparisons_cache ENABLE ROW LEVEL SECURITY;

-- 全ユーザーがキャッシュを読み取り可能（統計データのため）
CREATE POLICY "All authenticated users can view cache" ON comparisons_cache
  FOR SELECT USING (auth.role() = 'authenticated');

-- キャッシュの書き込みはサービスロールのみ（Edge Functionから）
-- 通常のユーザーは作成・更新・削除不可
