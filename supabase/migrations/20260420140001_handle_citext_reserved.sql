-- ============================================================
-- 2026-04-20: handle を citext 化 + reserved_handles テーブル + INSERT/UPDATE trigger
--
-- 背景:
--   Universal Links で `https://createlog.app/{handle}` prefix なし handle URL を
--   配布する設計に伴い、handle と Web path (post/privacy/api 等) の衝突を防ぐ必要がある。
--   canonical list は iOS `CreateLog/Resources/ReservedHandles.json` (557 語、
--   marteinn/The-Big-Username-Blocklist + つくろぐ独自追加)。
--   `docs/reserved-handles.md` に 3 箇所同期ルール記載。
--
-- 設計:
--   1. handle を text → citext に変更 (case-insensitive 比較、UNIQUE INDEX 自動で case-insensitive 化)
--   2. `reserved_handles` テーブル (handle citext PK) に 557 語を INSERT
--   3. BEFORE INSERT OR UPDATE trigger で新規/変更時のみ reserved 照合、既存 handle は grandfathered
--   4. DB が真のソース (攻撃経路問わず DB で reject)、iOS/Web validation は UX layer
-- ============================================================

CREATE EXTENSION IF NOT EXISTS citext;

-- handle UNIQUE INDEX を一旦削除 (text → citext 変更時に rebuild 必要)
DROP INDEX IF EXISTS public.idx_profiles_handle;

-- text → citext 変換 (既存値は case そのまま保持)
ALTER TABLE public.profiles
    ALTER COLUMN handle TYPE citext USING handle::citext;

-- citext 化した handle に対する UNIQUE INDEX 再作成 (case-insensitive UNIQUE)
CREATE UNIQUE INDEX idx_profiles_handle
    ON public.profiles (handle)
    WHERE handle IS NOT NULL;

-- ============================================================
-- reserved_handles テーブル
-- ============================================================

CREATE TABLE IF NOT EXISTS public.reserved_handles (
    handle citext PRIMARY KEY
);

COMMENT ON TABLE public.reserved_handles IS
    'Reserved handles (system path, brand, RFC2142, HTTP status, etc.). '
    'Canonical source: createlog-ios/CreateLog/Resources/ReservedHandles.json. '
    'See docs/reserved-handles.md for sync rule.';

-- 書き込みは service_role のみ。anon/authenticated は読む必要もない (trigger 内でのみ参照)。
ALTER TABLE public.reserved_handles ENABLE ROW LEVEL SECURITY;

-- 誰も SELECT/INSERT/UPDATE/DELETE できない (service_role は RLS bypass するので migration で操作可)。
-- トリガー関数は SECURITY DEFINER で動くため、一般ユーザーも間接的に照合可能。

-- ============================================================
-- 557 語を INSERT (conflict 時は skip)
-- ============================================================

INSERT INTO public.reserved_handles (handle) VALUES
    ('.git'), ('.htaccess'), ('.htpasswd'), ('.well-known'), ('400'), ('401'), ('403'), ('404'), ('405'), ('406'), ('407'), ('408'), ('409'), ('410'), ('411'), ('412'), ('413'), ('414'), ('415'), ('416'),
    ('417'), ('421'), ('422'), ('423'), ('424'), ('426'), ('428'), ('429'), ('431'), ('500'), ('501'), ('502'), ('503'), ('504'), ('505'), ('506'), ('507'), ('508'), ('509'), ('510'),
    ('511'), ('_astro'), ('_domainkey'), ('about'), ('about-us'), ('abuse'), ('access'), ('account'), ('accounts'), ('ad'), ('add'), ('admin'), ('administration'), ('administrator'), ('ads'), ('ads.txt'), ('advertise'), ('advertising'), ('aes128-ctr'), ('aes128-gcm'),
    ('aes192-ctr'), ('aes256-ctr'), ('aes256-gcm'), ('affiliate'), ('affiliates'), ('ajax'), ('alert'), ('alerts'), ('alpha'), ('amp'), ('analytics'), ('api'), ('app'), ('app-ads.txt'), ('apps'), ('asc'), ('assets'), ('atom'), ('auth'), ('authentication'),
    ('authorize'), ('autoconfig'), ('autodiscover'), ('avatar'), ('backup'), ('banner'), ('banners'), ('bbs'), ('beta'), ('billing'), ('billings'), ('blog'), ('blogs'), ('board'), ('bookmark'), ('bookmarks'), ('broadcasthost'), ('business'), ('buy'), ('cache'),
    ('calendar'), ('campaign'), ('captcha'), ('careers'), ('cart'), ('cas'), ('categories'), ('category'), ('cdn'), ('cgi'), ('cgi-bin'), ('chacha20-poly1305'), ('change'), ('changelog'), ('channel'), ('channels'), ('chart'), ('chat'), ('checkout'), ('clear'),
    ('client'), ('close'), ('cloud'), ('cms'), ('com'), ('comment'), ('comments'), ('community'), ('compare'), ('compose'), ('config'), ('connect'), ('contact'), ('contest'), ('cookies'), ('copy'), ('copyright'), ('count'), ('cp'), ('cpanel'),
    ('create'), ('createlog'), ('crossdomain.xml'), ('css'), ('curve25519-sha256'), ('customer'), ('customers'), ('customize'), ('dashboard'), ('db'), ('deals'), ('debug'), ('delete'), ('desc'), ('destroy'), ('dev'), ('developer'), ('developers'), ('diffie-hellman-group-exchange-sha256'), ('diffie-hellman-group14-sha1'),
    ('disconnect'), ('discover'), ('discuss'), ('dns'), ('dns0'), ('dns1'), ('dns2'), ('dns3'), ('dns4'), ('docs'), ('documentation'), ('domain'), ('download'), ('downloads'), ('downvote'), ('draft'), ('drop'), ('ecdh-sha2-nistp256'), ('ecdh-sha2-nistp384'), ('ecdh-sha2-nistp521'),
    ('edit'), ('editor'), ('email'), ('en'), ('enterprise'), ('error'), ('errors'), ('event'), ('events'), ('example'), ('exception'), ('exit'), ('explore'), ('export'), ('extensions'), ('false'), ('family'), ('faq'), ('faqs'), ('favicon.ico'),
    ('features'), ('feed'), ('feedback'), ('feeds'), ('file'), ('files'), ('filter'), ('follow'), ('follower'), ('followers'), ('following'), ('fonts'), ('forgot'), ('forgot-password'), ('forgotpassword'), ('form'), ('forms'), ('forum'), ('forums'), ('friend'),
    ('friends'), ('ftp'), ('get'), ('git'), ('go'), ('graphql'), ('group'), ('groups'), ('guest'), ('guidelines'), ('guides'), ('head'), ('header'), ('help'), ('hide'), ('hmac-sha'), ('hmac-sha1'), ('hmac-sha1-etm'), ('hmac-sha2-256'), ('hmac-sha2-256-etm'),
    ('hmac-sha2-512'), ('hmac-sha2-512-etm'), ('home'), ('host'), ('hosting'), ('hostmaster'), ('htpasswd'), ('http'), ('httpd'), ('https'), ('humans.txt'), ('icons'), ('images'), ('imap'), ('img'), ('import'), ('index'), ('info'), ('insert'), ('investors'),
    ('invitations'), ('invite'), ('invites'), ('invoice'), ('is'), ('isatap'), ('issues'), ('it'), ('ja'), ('jobs'), ('join'), ('js'), ('json'), ('keybase.txt'), ('learn'), ('legal'), ('license'), ('licensing'), ('like'), ('limit'),
    ('live'), ('load'), ('local'), ('localdomain'), ('localhost'), ('lock'), ('login'), ('logout'), ('lost-password'), ('m'), ('mail'), ('mail0'), ('mail1'), ('mail2'), ('mail3'), ('mail4'), ('mail5'), ('mail6'), ('mail7'), ('mail8'),
    ('mail9'), ('mailer-daemon'), ('mailerdaemon'), ('map'), ('marketing'), ('marketplace'), ('master'), ('me'), ('media'), ('member'), ('members'), ('message'), ('messages'), ('metrics'), ('mis'), ('mobile'), ('moderator'), ('modify'), ('more'), ('mx'),
    ('mx1'), ('my'), ('net'), ('network'), ('new'), ('news'), ('newsletter'), ('newsletters'), ('next'), ('nil'), ('no-reply'), ('nobody'), ('noc'), ('none'), ('noreply'), ('notification'), ('notifications'), ('ns'), ('ns0'), ('ns1'),
    ('ns2'), ('ns3'), ('ns4'), ('ns5'), ('ns6'), ('ns7'), ('ns8'), ('ns9'), ('null'), ('oauth'), ('oauth2'), ('offer'), ('offers'), ('official'), ('online'), ('openid'), ('order'), ('orders'), ('overview'), ('owa'),
    ('owner'), ('page'), ('pages'), ('partners'), ('passwd'), ('password'), ('pay'), ('payment'), ('payments'), ('paypal'), ('photo'), ('photos'), ('pixel'), ('plans'), ('plugins'), ('policies'), ('policy'), ('pop'), ('pop3'), ('popular'),
    ('portal'), ('portfolio'), ('post'), ('postfix'), ('postmaster'), ('posts'), ('poweruser'), ('preferences'), ('premium'), ('press'), ('previous'), ('pricing'), ('print'), ('privacy'), ('privacy-policy'), ('private'), ('prod'), ('product'), ('production'), ('profile'),
    ('profiles'), ('project'), ('projects'), ('promo'), ('public'), ('purchase'), ('put'), ('quota'), ('realtime'), ('redirect'), ('reduce'), ('refund'), ('refunds'), ('register'), ('registration'), ('remove'), ('replies'), ('reply'), ('report'), ('request'),
    ('request-password'), ('reset'), ('reset-password'), ('response'), ('return'), ('returns'), ('review'), ('reviews'), ('robots.txt'), ('root'), ('rootuser'), ('rpc'), ('rsa-sha2-2'), ('rsa-sha2-512'), ('rss'), ('rules'), ('sales'), ('save'), ('script'), ('sdk'),
    ('search'), ('secure'), ('security'), ('select'), ('services'), ('session'), ('sessions'), ('settings'), ('setup'), ('share'), ('shift'), ('shop'), ('signin'), ('signout'), ('signup'), ('site'), ('sitemap'), ('sites'), ('smtp'), ('sort'),
    ('source'), ('sql'), ('ssh'), ('ssh-rsa'), ('ssl'), ('ssladmin'), ('ssladministrator'), ('sslwebmaster'), ('staff'), ('stage'), ('staging'), ('stat'), ('static'), ('statistics'), ('stats'), ('status'), ('storage'), ('store'), ('style'), ('styles'),
    ('stylesheet'), ('stylesheets'), ('subdomain'), ('subscribe'), ('sudo'), ('supabase'), ('super'), ('superuser'), ('support'), ('survey'), ('sync'), ('sysadmin'), ('system'), ('tablet'), ('tag'), ('tags'), ('team'), ('telnet'), ('terms'), ('terms-of-use'),
    ('test'), ('testimonials'), ('theme'), ('themes'), ('today'), ('tools'), ('topic'), ('topics'), ('tour'), ('training'), ('translate'), ('translations'), ('trending'), ('trial'), ('true'), ('tsukurog'), ('umac-128'), ('umac-128-etm'), ('umac-64'), ('umac-64-etm'),
    ('undefined'), ('unfollow'), ('unlike'), ('unsubscribe'), ('update'), ('upgrade'), ('usenet'), ('user'), ('username'), ('users'), ('uucp'), ('var'), ('verify'), ('video'), ('view'), ('void'), ('vote'), ('vpn'), ('webmail'), ('webmaster'),
    ('website'), ('widget'), ('widgets'), ('wiki'), ('wpad'), ('write'), ('www'), ('www-data'), ('www1'), ('www2'), ('www3'), ('www4'), ('you'), ('yourname'), ('yourusername'), ('zlib'), ('つくろぐ')
ON CONFLICT (handle) DO NOTHING;

-- ============================================================
-- Trigger: profiles.handle INSERT/UPDATE 時に reserved 照合
-- 既存 handle は grandfathered (trigger は INSERT/UPDATE 時のみ発火、既存 row は scan しない)
-- stripped match (`_` `.` `-` 除去) にも対応 (`a_d_m_i_n` → "admin" 衝突)
-- ============================================================

CREATE OR REPLACE FUNCTION public.check_reserved_handle()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    stripped citext;
BEGIN
    -- handle が変わっていなければ skip (UPDATE で他 column だけ変更のケース)
    IF TG_OP = 'UPDATE' AND NEW.handle IS NOT DISTINCT FROM OLD.handle THEN
        RETURN NEW;
    END IF;

    IF NEW.handle IS NULL THEN
        RETURN NEW;
    END IF;

    -- direct match (citext なので case-insensitive で自動照合)
    IF EXISTS (SELECT 1 FROM public.reserved_handles WHERE handle = NEW.handle) THEN
        RAISE EXCEPTION 'handle "%" is reserved', NEW.handle
            USING ERRCODE = 'check_violation';
    END IF;

    -- stripped match (区切り文字除去版でも照合)
    stripped := translate(NEW.handle::text, '_.-', '')::citext;
    IF stripped IS DISTINCT FROM NEW.handle
       AND EXISTS (SELECT 1 FROM public.reserved_handles WHERE handle = stripped) THEN
        RAISE EXCEPTION 'handle "%" collides with reserved word "%" when stripped', NEW.handle, stripped
            USING ERRCODE = 'check_violation';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS check_reserved_handle_trigger ON public.profiles;
CREATE TRIGGER check_reserved_handle_trigger
    BEFORE INSERT OR UPDATE OF handle ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.check_reserved_handle();

COMMENT ON FUNCTION public.check_reserved_handle() IS
    'Reject reserved handles on INSERT/UPDATE. Existing handles (pre-migration) are grandfathered. '
    'Case-insensitive (via citext) + stripped match (_.-). '
    'Canonical source: createlog-ios/CreateLog/Resources/ReservedHandles.json';
