-- T3 (2026-04-12): handle_new_user trigger function の security 強化
--
-- ## 問題 (planner T3 先読みで発見、2026-04-11)
-- 現状の `handle_new_user` は `SECURITY DEFINER` 指定があるが、**`SET search_path` が欠落**:
--
--     CREATE OR REPLACE FUNCTION public.handle_new_user() RETURNS trigger
--         LANGUAGE plpgsql SECURITY DEFINER
--         AS $$
--     BEGIN
--       INSERT INTO profiles (id, email)
--       VALUES (NEW.id, NEW.email);
--       RETURN NEW;
--     END;
--     $$;
--
-- これは schema hijack 攻撃を受ける可能性がある:
-- 1. 攻撃者が同名 function を別 schema に仕込む
-- 2. SECURITY DEFINER で unqualified call (`insert into profiles`) が attacker schema 経由で解決
-- 3. postgres superuser 権限で任意 function 実行 (privilege escalation)
--
-- ## 修正
-- `SET search_path = public, pg_temp` を追加し、attacker schema の影響を排除。
-- - `public`: 正式 schema
-- - `pg_temp`: session 内 temporary のみ (attacker schema 不可)
--
-- 既存 trigger は `CREATE OR REPLACE` で上書き、schema 変更は不要。
-- 参考: 同じ pattern が既存 `increment_hashtag_post_count` で既に適用されている (baseline L500-510)

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    INSERT INTO profiles (id, email)
    VALUES (NEW.id, NEW.email);
    RETURN NEW;
END;
$$;

-- 既存の GRANT は baseline で既に付与済、追加不要
-- (anon, authenticated, service_role, postgres)
