// delete-account: 認証済みユーザーが自分のアカウントを削除する。
//
// ## 動作
// 1. Authorization ヘッダの JWT から user を取得 (auth.admin.getUser)
// 2. service_role で auth.users から削除 (CASCADE で profiles/posts/logs/... 全て削除される想定)
//
// ## セキュリティ
// - service_role key は Edge Function runtime でのみ参照可能
// - リクエスト元が自分の user_id と一致することを auth.getUser で検証
// - body から渡される user_id は信用しない (hint 扱い、実際は session から取る)
//
// ## 呼び出し元
// iOS 側 SupabaseAuthService.deleteAccount() → functions.invoke("delete-account")

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      {
        status: 405,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !serviceRoleKey) {
      throw new Error("Missing Supabase env vars");
    }

    // service_role クライアント (admin 権限)
    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    // リクエスト側の JWT から user を取得
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Missing Authorization header" }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const jwt = authHeader.replace(/^Bearer\s+/i, "");
    const { data: userData, error: userError } = await adminClient.auth
      .getUser(jwt);

    if (userError || !userData?.user) {
      return new Response(
        JSON.stringify({ error: "Invalid session" }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const userId = userData.user.id;

    // auth.users から削除 → ON DELETE CASCADE で profiles/posts/logs/... が消える前提
    const { error: deleteError } = await adminClient.auth.admin.deleteUser(
      userId,
    );

    if (deleteError) {
      console.error("Failed to delete user", userId, deleteError);
      return new Response(
        JSON.stringify({ error: "Failed to delete account" }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    return new Response(
      JSON.stringify({ ok: true, deleted_user_id: userId }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (err) {
    console.error("delete-account error", err);
    return new Response(
      JSON.stringify({ error: "Internal error" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
