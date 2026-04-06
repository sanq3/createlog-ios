-- ============================================================
-- auth.users INSERT 時に profiles を自動作成するトリガー
-- v1 backup で定義されていた handle_new_user を v2 スキーマに再適用する。
-- v2 移行時にトリガーが一部環境で失われており、サインアップ成功しても
-- profiles レコードが作成されず FK 制約違反・空プロフィール問題が発生していた。
-- ============================================================

-- handle_new_user: auth.users INSERT 時に profiles レコードを挿入
-- SECURITY DEFINER + search_path 固定でスキーマハイジャック対策
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    INSERT INTO public.profiles (id, email)
    VALUES (NEW.id, NEW.email)
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$;

-- トリガー再作成 (冪等)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- 既存 auth.users のうち profiles が無いものを backfill
-- (トリガー欠落時代にサインアップしたユーザーの救済)
-- ============================================================
INSERT INTO public.profiles (id, email)
SELECT u.id, u.email
FROM auth.users u
LEFT JOIN public.profiles p ON p.id = u.id
WHERE p.id IS NULL
ON CONFLICT (id) DO NOTHING;
