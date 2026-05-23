import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.4";

type JsonMap = Record<string, unknown>;

const defaultAllowedOrigins = [
  "https://praticase.medasi.com.tr",
  "https://www.praticase.medasi.com.tr",
  "http://localhost:3000",
  "http://127.0.0.1:3000",
  "http://localhost:8080",
  "http://127.0.0.1:8080",
];

const allowedOrigins = new Set(
  (Deno.env.get("PRATICASE_ALLOWED_ORIGINS")?.split(",") ??
    defaultAllowedOrigins)
    .map((origin) => origin.trim())
    .filter((origin) => origin.length > 0),
);

type QuestionRow = {
  id: string;
  subject: string;
  topic: string;
  difficulty: string;
  text: string;
  options: unknown;
  correct_index: number;
  explanation: string;
  option_rationales: unknown;
  tags: unknown;
};

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
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const authorization = request.headers.get("Authorization");

  if (!supabaseUrl || !supabaseAnonKey || !serviceRoleKey || !authorization) {
    return jsonResponse(
      { error: "Live Supabase configuration is missing" },
      500,
      origin,
    );
  }

  const userClient = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authorization } },
  });
  const { data: authData, error: authError } = await userClient.auth.getUser();
  if (authError || !authData.user) {
    return jsonResponse({ error: "Unauthorized" }, 401, origin);
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });
  const body = await request.json().catch(() => ({})) as JsonMap;
  const action = stringValue(body.action);

  if (action === "filters") {
    return withOrigin(await loadFilters(admin), origin);
  }
  if (action === "questions") {
    return withOrigin(await loadQuestions(admin, body), origin);
  }

  return jsonResponse({ error: "Unknown action" }, 400, origin);
});

async function loadFilters(admin: any) {
  const { data, error } = await admin
    .from("questions")
    .select("subject,topic")
    .eq("is_user_generated", false)
    .order("subject")
    .order("topic")
    .limit(10000);

  if (error) return { error: error.message };

  const seen = new Set<string>();
  const filters = [];
  for (const row of data ?? []) {
    const subject = stringValue(row.subject);
    const topic = stringValue(row.topic);
    if (!subject) continue;
    const key = `${subject}\u0000${topic}`;
    if (seen.has(key)) continue;
    seen.add(key);
    filters.push({ subject, topic });
  }
  return { filters };
}

async function loadQuestions(
  admin: any,
  body: JsonMap,
) {
  const subjects = stringArray(body.subjects).slice(0, 24);
  const topic = stringValue(body.topic);
  const limit = clampNumber(body.limit, 1, 100, 20);
  const fetchLimit = Math.min(Math.max(limit * 8, 120), 1000);

  let query = admin
    .from("questions")
    .select(
      "id,subject,topic,difficulty,text,options,correct_index,explanation,option_rationales,tags",
    )
    .eq("is_user_generated", false)
    .order("created_at", { ascending: false })
    .limit(fetchLimit);

  if (subjects.length > 0) query = query.in("subject", subjects);
  if (topic) query = query.eq("topic", topic);

  const { data, error } = await query;
  if (error) return { error: error.message };

  const questions = shuffle((data ?? []) as QuestionRow[])
    .slice(0, limit)
    .map(publicExamQuestion);
  return { questions };
}

function publicExamQuestion(row: QuestionRow) {
  return {
    id: stringValue(row.id),
    subject: stringValue(row.subject),
    topic: stringValue(row.topic),
    difficulty: stringValue(row.difficulty),
    text: stringValue(row.text),
    options: stringArray(row.options),
    correct_index: numberValue(row.correct_index) ?? -1,
    explanation: stringValue(row.explanation),
    option_rationales: stringArray(row.option_rationales),
    tags: stringArray(row.tags),
  };
}

function withOrigin(payload: JsonMap, origin: string | null) {
  const status = payload.error ? 400 : 200;
  return jsonResponse(payload, status, origin);
}

function isAllowedOrigin(origin: string | null) {
  if (!origin) return true;
  return allowedOrigins.has(origin.trim());
}

function corsHeaders(origin: string | null = null): HeadersInit {
  const normalizedOrigin = origin?.trim() ?? "";
  const allowOrigin = allowedOrigins.has(normalizedOrigin)
    ? normalizedOrigin
    : defaultAllowedOrigins[0];

  return {
    "Access-Control-Allow-Origin": allowOrigin,
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    Vary: "Origin",
  };
}

function jsonResponse(
  body: JsonMap,
  status = 200,
  origin: string | null = null,
) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders(origin),
      "Content-Type": "application/json",
    },
  });
}

function shuffle<T>(values: T[]) {
  const items = [...values];
  for (let i = items.length - 1; i > 0; i -= 1) {
    const j = Math.floor(Math.random() * (i + 1));
    [items[i], items[j]] = [items[j], items[i]];
  }
  return items;
}

function clampNumber(
  value: unknown,
  min: number,
  max: number,
  fallback: number,
) {
  const numeric = numberValue(value);
  if (numeric === null) return fallback;
  return Math.min(Math.max(Math.round(numeric), min), max);
}

function numberValue(value: unknown) {
  const numeric = Number(value);
  return Number.isFinite(numeric) ? numeric : null;
}

function stringValue(value: unknown) {
  return typeof value === "string" ? value.trim() : value?.toString().trim() ??
    "";
}

function stringArray(value: unknown) {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => stringValue(item))
    .filter((item) => item.length > 0);
}
