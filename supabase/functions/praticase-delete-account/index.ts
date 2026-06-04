import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.4";
import { corsHeaders, isAllowedOrigin, jsonResponse } from "../_shared/cors.ts";

type JsonMap = Record<string, unknown>;

const confirmationToken = "DELETE_ACCOUNT";

const praticaseUserTables = [
  "user_learning_events",
  "app_store_subscription_links",
  "session_ai_enrichments",
  "session_evaluation_snapshots",
  "oral_exam_sessions",
  "exam_sessions",
  "user_notes",
  "contact_requests",
  "user_badges",
  "leaderboard_scores",
  "user_app_settings",
  "user_badge_summaries",
  "user_notifications",
  "user_bookmarked_cases",
  "user_case_recommendations",
  "user_case_progress",
  "user_dashboard_stats",
];

Deno.serve(async (request) => {
  const origin = request.headers.get("Origin");

  if (request.method === "OPTIONS") {
    if (!isAllowedOrigin(origin)) {
      return jsonResponse({ error: "Origin not allowed" }, 403, origin);
    }
    return new Response("ok", { headers: corsHeaders(origin) });
  }

  if (!isAllowedOrigin(origin)) {
    return jsonResponse({ error: "Origin not allowed" }, 403, origin);
  }

  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405, origin);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const authorization = request.headers.get("Authorization");

  if (!supabaseUrl || !supabaseAnonKey || !supabaseServiceRoleKey) {
    return jsonResponse(
      { error: "Hesap silme işlemi şu anda tamamlanamadı. Lütfen tekrar dene." },
      500,
      origin,
    );
  }

  if (!authorization) {
    return jsonResponse(
      { error: "Oturum doğrulanamadı. Lütfen tekrar giriş yap." },
      401,
      origin,
    );
  }

  const body = await parseBody(request);
  if (stringValue(body.confirmation) !== confirmationToken) {
    return jsonResponse(
      { error: "Hesap silme onayı eksik." },
      400,
      origin,
    );
  }

  const userClient = createClient(supabaseUrl, supabaseAnonKey, {
    auth: { persistSession: false },
    global: { headers: { Authorization: authorization } },
  });

  const { data: authData, error: authError } = await userClient.auth.getUser();
  if (authError || !authData.user) {
    return jsonResponse(
      { error: "Oturum doğrulanamadı. Lütfen tekrar giriş yap." },
      401,
      origin,
    );
  }

  const userId = authData.user.id;
  const admin = createClient(supabaseUrl, supabaseServiceRoleKey, {
    auth: { persistSession: false },
  });

  await deletePratiCaseRows(admin, userId);
  await deleteSharedProfile(admin, userId);

  const { error: deleteError } = await admin.auth.admin.deleteUser(userId);
  if (deleteError) {
    return jsonResponse(
      { error: "Hesap silme işlemi şu anda tamamlanamadı. Lütfen tekrar dene." },
      500,
      origin,
    );
  }

  await deleteSharedProfile(admin, userId);

  return jsonResponse({ deleted: true }, 200, origin);
});

async function parseBody(request: Request): Promise<JsonMap> {
  try {
    const parsed = await request.json();
    return isJsonMap(parsed) ? parsed : {};
  } catch (_) {
    return {};
  }
}

async function deletePratiCaseRows(
  admin: any,
  userId: string,
): Promise<void> {
  for (const table of praticaseUserTables) {
    const { error } = await admin
      .schema("praticase")
      .from(table)
      .delete()
      .eq("user_id", userId);
    if (error && !isIgnorableCleanupError(error)) {
      return;
    }
  }
}

async function deleteSharedProfile(
  admin: any,
  userId: string,
): Promise<void> {
  const { error } = await admin.from("profiles").delete().eq("id", userId);
  if (error && !isIgnorableCleanupError(error)) {
    return;
  }
}

function isIgnorableCleanupError(error: { code?: string; message?: string }) {
  const message = error.message?.toLowerCase() ?? "";
  return (
    error.code === "PGRST205" ||
    message.includes("could not find the table") ||
    message.includes("does not exist")
  );
}

function isJsonMap(value: unknown): value is JsonMap {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function stringValue(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}
