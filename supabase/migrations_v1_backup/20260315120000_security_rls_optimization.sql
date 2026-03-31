-- ================================================
-- Phase 0.1 セキュリティ修正マイグレーション
-- 実行日: 2026-03-15
-- 内容:
--   1. RLSポリシーを (select auth.uid()) 形式に最適化（全テーブル）
--   2. comparisons_cache のRLSを service_role のみに統一
--   3. avatars バケットのSELECTを認証済みユーザーに拡大（SNS対応）
--   4. monthly_revenues のRLSポリシー定義を一元化
--   5. get_or_create_user_categories に auth.uid() チェック追加
-- ================================================

-- ================================================
-- 1. profiles テーブルのRLSポリシー最適化
--    auth.uid() → (select auth.uid()) で initPlan キャッシュ最適化
-- ================================================

DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
DROP POLICY IF EXISTS "Users can view their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON profiles;

CREATE POLICY "profiles_select_own"
  ON profiles FOR SELECT
  TO authenticated
  USING ((select auth.uid()) = id);

CREATE POLICY "profiles_update_own"
  ON profiles FOR UPDATE
  TO authenticated
  USING ((select auth.uid()) = id);

CREATE POLICY "profiles_insert_own"
  ON profiles FOR INSERT
  TO authenticated
  WITH CHECK ((select auth.uid()) = id);

-- ================================================
-- 2. categories テーブルのRLSポリシー最適化
-- ================================================

DROP POLICY IF EXISTS "Users can view own and default categories" ON categories;
DROP POLICY IF EXISTS "Users can view default categories and their own" ON categories;
DROP POLICY IF EXISTS "Users can insert own categories" ON categories;
DROP POLICY IF EXISTS "Users can create their own categories" ON categories;
DROP POLICY IF EXISTS "Users can update own categories" ON categories;
DROP POLICY IF EXISTS "Users can update their own categories" ON categories;
DROP POLICY IF EXISTS "Users can delete own categories" ON categories;
DROP POLICY IF EXISTS "Users can delete their own categories" ON categories;

CREATE POLICY "categories_select_own_and_default"
  ON categories FOR SELECT
  TO authenticated
  USING (
    (is_default = true AND user_id IS NULL) OR (select auth.uid()) = user_id
  );

CREATE POLICY "categories_insert_own"
  ON categories FOR INSERT
  TO authenticated
  WITH CHECK ((select auth.uid()) = user_id AND is_default = false);

CREATE POLICY "categories_update_own"
  ON categories FOR UPDATE
  TO authenticated
  USING ((select auth.uid()) = user_id AND is_default = false);

CREATE POLICY "categories_delete_own"
  ON categories FOR DELETE
  TO authenticated
  USING ((select auth.uid()) = user_id AND is_default = false);

-- ================================================
-- 3. logs テーブルのRLSポリシー最適化
-- ================================================

DROP POLICY IF EXISTS "Users can view own logs" ON logs;
DROP POLICY IF EXISTS "Users can view their own logs" ON logs;
DROP POLICY IF EXISTS "Users can insert own logs" ON logs;
DROP POLICY IF EXISTS "Users can create their own logs" ON logs;
DROP POLICY IF EXISTS "Users can update own logs" ON logs;
DROP POLICY IF EXISTS "Users can update their own logs" ON logs;
DROP POLICY IF EXISTS "Users can update their recent logs" ON logs;
DROP POLICY IF EXISTS "Users can delete own logs" ON logs;
DROP POLICY IF EXISTS "Users can delete their own logs" ON logs;

CREATE POLICY "logs_select_own"
  ON logs FOR SELECT
  TO authenticated
  USING ((select auth.uid()) = user_id);

CREATE POLICY "logs_insert_own"
  ON logs FOR INSERT
  TO authenticated
  WITH CHECK ((select auth.uid()) = user_id);

CREATE POLICY "logs_update_own"
  ON logs FOR UPDATE
  TO authenticated
  USING ((select auth.uid()) = user_id);

CREATE POLICY "logs_delete_own"
  ON logs FOR DELETE
  TO authenticated
  USING ((select auth.uid()) = user_id);

-- ================================================
-- 4. monthly_revenues テーブルのRLSポリシー一元化・最適化
--    sql/05 と migrations/20251009 の重複ポリシーを解消
-- ================================================

DROP POLICY IF EXISTS "Users can view own revenues" ON monthly_revenues;
DROP POLICY IF EXISTS "Users can view their own revenues" ON monthly_revenues;
DROP POLICY IF EXISTS "Users can insert own revenues" ON monthly_revenues;
DROP POLICY IF EXISTS "Users can insert their own revenues" ON monthly_revenues;
DROP POLICY IF EXISTS "Users can update own revenues" ON monthly_revenues;
DROP POLICY IF EXISTS "Users can update their own revenues" ON monthly_revenues;
DROP POLICY IF EXISTS "Users can delete own revenues" ON monthly_revenues;
DROP POLICY IF EXISTS "Users can delete their own revenues" ON monthly_revenues;
DROP POLICY IF EXISTS "Users can manage their own revenues" ON monthly_revenues;

CREATE POLICY "monthly_revenues_select_own"
  ON monthly_revenues FOR SELECT
  TO authenticated
  USING ((select auth.uid()) = user_id);

CREATE POLICY "monthly_revenues_insert_own"
  ON monthly_revenues FOR INSERT
  TO authenticated
  WITH CHECK ((select auth.uid()) = user_id);

CREATE POLICY "monthly_revenues_update_own"
  ON monthly_revenues FOR UPDATE
  TO authenticated
  USING ((select auth.uid()) = user_id)
  WITH CHECK ((select auth.uid()) = user_id);

CREATE POLICY "monthly_revenues_delete_own"
  ON monthly_revenues FOR DELETE
  TO authenticated
  USING ((select auth.uid()) = user_id);

-- ================================================
-- 5. subscriptions テーブルのRLSポリシー最適化
-- ================================================

DROP POLICY IF EXISTS "Users can view own subscriptions" ON subscriptions;
DROP POLICY IF EXISTS "Users can view their own subscription" ON subscriptions;
DROP POLICY IF EXISTS "Users can update their own subscription" ON subscriptions;

CREATE POLICY "subscriptions_select_own"
  ON subscriptions FOR SELECT
  TO authenticated
  USING ((select auth.uid()) = user_id);

-- subscriptions の INSERT/UPDATE/DELETE は service_role のみ。
-- RLS が有効な状態でポリシーが存在しない場合、デフォルトで全操作を拒否。
-- service_role は BYPASSRLS によりこのテーブルを操作可能。

-- ================================================
-- 6. comparisons_cache のRLSを service_role のみに統一
--    20251121（認証ユーザーSELECT許可）と 20251201（service_role限定）の不一致を解消
--    → service_role のみに統一
-- ================================================

DROP POLICY IF EXISTS "All authenticated users can view cache" ON comparisons_cache;
DROP POLICY IF EXISTS "Anyone can view cache" ON comparisons_cache;
DROP POLICY IF EXISTS "Service role can read comparisons cache" ON comparisons_cache;
DROP POLICY IF EXISTS "Service role can insert comparisons cache" ON comparisons_cache;
DROP POLICY IF EXISTS "Service role can update comparisons cache" ON comparisons_cache;
DROP POLICY IF EXISTS "Service role can delete comparisons cache" ON comparisons_cache;

-- 注意: Supabase の service_role は BYPASSRLS 権限を持つため、
-- 以下のポリシーは通常評価されない。
-- FORCE ROW LEVEL SECURITY を設定した場合にのみ有効になるフォールバック定義。
CREATE POLICY "comparisons_cache_select_service_role"
  ON comparisons_cache FOR SELECT
  TO service_role
  USING (true);

CREATE POLICY "comparisons_cache_insert_service_role"
  ON comparisons_cache FOR INSERT
  TO service_role
  WITH CHECK (true);

CREATE POLICY "comparisons_cache_update_service_role"
  ON comparisons_cache FOR UPDATE
  TO service_role
  USING (true)
  WITH CHECK (true);

CREATE POLICY "comparisons_cache_delete_service_role"
  ON comparisons_cache FOR DELETE
  TO service_role
  USING (true);

-- ================================================
-- 7. avatars バケットのRLS方針をSNS前提に更新
--    現状: owner-only（他ユーザーのアバター表示不可）
--    変更: 認証済みユーザーにSELECT許可（SNS機能で他ユーザーのアバター表示に必要）
--    INSERT/UPDATE/DELETE は引き続き owner-only
-- ================================================

-- 既存のSELECTポリシーを削除
DROP POLICY IF EXISTS "Users can read own avatar" ON storage.objects;
DROP POLICY IF EXISTS "Avatar images are publicly accessible" ON storage.objects;

-- 認証済みユーザーなら誰でもアバターを閲覧可能（SNS対応）
CREATE POLICY "Authenticated users can view avatars"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (bucket_id = 'avatars');

-- INSERT/UPDATE/DELETE のポリシーは既存のまま維持
-- （20251201_lockdown_avatars_bucket.sql で作成済み）
-- 念のため冪等性を確保するために再作成
DROP POLICY IF EXISTS "Users can upload own avatar" ON storage.objects;
DROP POLICY IF EXISTS "Users can upload their own avatar" ON storage.objects;
DROP POLICY IF EXISTS "Users can update own avatar" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own avatar" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete own avatar" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own avatar" ON storage.objects;

CREATE POLICY "avatars_insert_own"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'avatars' AND
    (select auth.uid())::text = (storage.foldername(name))[1]
  );

CREATE POLICY "avatars_update_own"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'avatars' AND
    (select auth.uid())::text = (storage.foldername(name))[1]
  )
  WITH CHECK (
    bucket_id = 'avatars' AND
    (select auth.uid())::text = (storage.foldername(name))[1]
  );

CREATE POLICY "avatars_delete_own"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'avatars' AND
    (select auth.uid())::text = (storage.foldername(name))[1]
  );

-- ================================================
-- 8. SECURITY DEFINER 関数に auth.uid() チェック追加
--    get_or_create_user_categories: p_user_id が auth.uid() と一致するか検証
-- ================================================

CREATE OR REPLACE FUNCTION get_or_create_user_categories(p_user_id UUID)
RETURNS VOID AS $$
BEGIN
  -- セキュリティチェック: 呼び出し元ユーザーと p_user_id が一致するか検証
  -- service_role（auth.uid() IS NULL）は許可、通常ユーザーは本人のみ許可
  IF (select auth.uid()) IS NOT NULL AND p_user_id IS DISTINCT FROM (select auth.uid()) THEN
    RAISE EXCEPTION 'unauthorized: p_user_id does not match auth.uid()';
  END IF;

  -- ユーザー用のカテゴリが存在しない場合、デフォルトからコピー
  IF NOT EXISTS (SELECT 1 FROM categories WHERE user_id = p_user_id) THEN
    INSERT INTO public.categories (user_id, name, color, icon, is_active, is_default, display_order)
    SELECT
      p_user_id,
      name,
      color,
      icon,
      is_active,
      false, -- ユーザーカテゴリは is_default=false
      display_order
    FROM public.categories
    WHERE is_default = true;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

-- ================================================
-- 完了メッセージ
-- ================================================
-- Phase 0.1 セキュリティ修正マイグレーション完了
-- 適用されたポリシー:
--   - profiles: 3ポリシー（SELECT/UPDATE/INSERT）
--   - categories: 4ポリシー（SELECT/INSERT/UPDATE/DELETE）
--   - logs: 4ポリシー（SELECT/INSERT/UPDATE/DELETE）
--   - monthly_revenues: 4ポリシー（SELECT/INSERT/UPDATE/DELETE）
--   - subscriptions: 1ポリシー（SELECT）
--   - comparisons_cache: 4ポリシー（service_role のみ）
--   - storage.objects (avatars): 4ポリシー（SELECT=認証済み全員、他=owner-only）
--   - get_or_create_user_categories: auth.uid() チェック追加
