import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.4";
import { corsHeaders, isAllowedOrigin, jsonResponse } from "../_shared/cors.ts";
import {
  evaluationModel,
  generateVertexContent,
  vertexConfigured,
} from "../_shared/vertex_ai.ts";
import {
  chargeAiCoins,
  ensureAiCoinBalance,
  InsufficientCoinBalanceError,
} from "../_shared/medasi_coin.ts";
import {
  loadCaseChecklists,
  mergeCaseChecklistContext,
} from "../_shared/case_checklists.ts";

type JsonMap = Record<string, unknown>;

type AiScore = {
  totalScore: number;
  maxScore: number;
  categoryScores: Array<{ title: string; score: number; maxScore: number }>;
  strongPoints: string[];
  improvementPoints: string[];
  criticalMistakes: string[];
  unnecessaryTests: string[];
  missedHistory: string[];
  missedPhysicalExam: string[];
  idealApproach: string;
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
  const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const authorization = request.headers.get("Authorization");

  if (!supabaseUrl || !supabaseAnonKey || !authorization) {
    return jsonResponse(
      { error: "Live Supabase configuration is missing" },
      500,
      origin,
    );
  }

  const body = await request.json().catch(() => ({}));
  const sessionId = String(body.sessionId ?? body.session_id ?? "").trim();

  if (!sessionId) {
    return jsonResponse({ error: "sessionId is required" }, 400, origin);
  }

  const supabase = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authorization } },
  });
  const admin = supabaseServiceRoleKey
    ? createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: { persistSession: false },
    })
    : null;

  const { data: context, error: contextError } = await buildScoringContext(
    supabase,
    sessionId,
  );
  if (contextError) {
    return jsonResponse({ error: contextError }, 400, origin);
  }
  const userId = String(
    (context?.session as Record<string, unknown> | undefined)?.userId ?? "",
  );
  if (!admin) {
    return jsonResponse(
      { error: "AI enrichment service is unavailable" },
      503,
      origin,
    );
  }
  await admin.schema("praticase").from("session_ai_enrichments").upsert({
    session_id: sessionId,
    user_id: userId,
    status: "running",
    provider: "vertex_ai",
    model: evaluationModel(),
    updated_at: new Date().toISOString(),
  }, { onConflict: "session_id" });

  if (!vertexConfigured()) {
    await recordEnrichmentFailure(
      admin,
      sessionId,
      "Vertex AI configuration is missing",
    );
    return jsonResponse(
      { error: "Vertex AI configuration is missing" },
      500,
      origin,
    );
  }
  try {
    await ensureAiCoinBalance(admin, userId);
  } catch (error) {
    if (error instanceof InsufficientCoinBalanceError) {
      await recordEnrichmentFailure(
        admin,
        sessionId,
        "Yetersiz MedAsi Coin bakiyesi.",
      );
      return jsonResponse(
        {
          error:
            "MedAsi Coin bakiyen yeterli değil. Sonuç karnesini oluşturmak için cüzdandan coin yükleyebilirsin.",
          wallet_balance: error.walletBalance,
          required_balance: error.requiredBalance,
        },
        402,
        origin,
      );
    }
    throw error;
  }

  let score: AiScore;
  let usageMetadata: Record<string, unknown> = {};
  let model = evaluationModel();
  try {
    const generated = await generateVertexContent({
      model,
      systemInstruction:
        "Sen PratiCase OSCE sınav değerlendiricisisin. Öğrenci performansını 100 puan üzerinden, verilen rubrik ve vaka hedeflerine göre değerlendir. Öğrenciye tıbbi karar desteği değil, eğitim amaçlı OSCE performans karnesi üret. Gereksiz tetkikleri, kritik hataları, eksik anamnez ve muayene başlıklarını açıkça belirt. Sadece geçerli JSON döndür; markdown, açıklama veya kod bloğu kullanma.",
      contents: [
        {
          role: "user",
          parts: [
            {
              text:
                `Aşağıdaki OSCE session bağlamını değerlendir ve şu JSON şemasına birebir uy:\n` +
                `{"totalScore":0,"maxScore":100,"categoryScores":[{"title":"İletişim","score":0,"maxScore":10},{"title":"Anamnez","score":0,"maxScore":30},{"title":"Fizik Muayene","score":0,"maxScore":20},{"title":"Ön Tanılar","score":0,"maxScore":15},{"title":"Tetkikler","score":0,"maxScore":15},{"title":"Yönetim","score":0,"maxScore":10}],"strongPoints":[],"improvementPoints":[],"criticalMistakes":[],"unnecessaryTests":[],"missedHistory":[],"missedPhysicalExam":[],"idealApproach":""}\n\n` +
                `Kurallar: totalScore kategori skorlarının toplamı olmalı. Her liste en fazla 5 kısa Türkçe madde içersin. idealApproach 3-5 cümlelik net bir özet olsun.\n\n` +
                `Session JSON:\n${JSON.stringify(context)}`,
            },
          ],
        },
      ],
      temperature: 0.2,
      maxOutputTokens: 2200,
      responseMimeType: "application/json",
    });
    usageMetadata = generated.usageMetadata;
    model = generated.model;
    score = normalizeScore(parseJson(generated.text));
  } catch (error) {
    await recordEnrichmentFailure(admin, sessionId, errorMessage(error));
    return jsonResponse(
      { error: "Vertex AI scoring failed", detail: errorMessage(error) },
      502,
      origin,
    );
  }

  let chargedCoinAmount = 0;
  let walletBalance: number | null = null;
  try {
    const charge = await chargeAiCoins({
      admin,
      userId,
      feature: "praticase-complete-session",
      model,
      usageMetadata,
    });
    chargedCoinAmount = charge.chargedCoinAmount;
    walletBalance = charge.walletBalance;
  } catch (error) {
    if (error instanceof InsufficientCoinBalanceError) {
      await recordEnrichmentFailure(
        admin,
        sessionId,
        "Yetersiz MedAsi Coin bakiyesi.",
      );
      return jsonResponse(
        {
          error:
            "MedAsi Coin bakiyen yeterli değil. Sonuç karnesini oluşturmak için cüzdandan coin yükleyebilirsin.",
          wallet_balance: error.walletBalance,
          required_balance: error.requiredBalance,
        },
        402,
        origin,
      );
    }
    throw error;
  }

  const { data, error } = await admin.schema("praticase")
    .from("session_ai_enrichments")
    .update({
      status: "completed",
      provider: "vertex_ai",
      model,
      feedback: score,
      usage_metadata: usageMetadata,
      charged_coin_amount: chargedCoinAmount,
      error_message: null,
      updated_at: new Date().toISOString(),
    })
    .eq("session_id", sessionId)
    .select("session_id,status,feedback")
    .single();

  if (error) {
    return jsonResponse({ error: error.message }, 400, origin);
  }

  return jsonResponse(
    {
      enrichment: data,
      model,
      chargedCoinAmount,
      walletBalance,
    },
    200,
    origin,
  );
});

async function recordEnrichmentFailure(
  // deno-lint-ignore no-explicit-any
  admin: any,
  sessionId: string,
  message: string,
) {
  await admin.schema("praticase").from("session_ai_enrichments").update({
    status: "failed",
    error_message: message.slice(0, 500),
    updated_at: new Date().toISOString(),
  }).eq("session_id", sessionId);
}

async function buildScoringContext(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  sessionId: string,
): Promise<{ data?: JsonMap; error?: string }> {
  const { data: session, error: sessionError } = await supabase
    .schema("praticase")
    .from("exam_sessions")
    .select(
      "id,user_id,case_id,mode,current_step,started_at,ended_at,cases(title,branch,difficulty,duration_minutes,setting,candidate_prompt,patient_profile,expected_history,expected_physical_exam,expected_differentials,expected_tests,unnecessary_tests,management_steps,critical_mistakes,rubric)",
    )
    .eq("id", sessionId)
    .single();
  if (sessionError || !session) return { error: "Exam session not found" };

  const [
    messages,
    physical,
    tests,
    diagnosisAnswer,
    diagnosisOptions,
    managementNote,
    managementItems,
  ] = await Promise.all([
    supabase.schema("praticase").from("exam_messages")
      .select("sender,message,created_at")
      .eq("session_id", sessionId)
      .order("created_at"),
    supabase.schema("praticase").from("session_physical_exam_findings")
      .select(
        "created_at,physical_exam_options(title,finding,point_value,is_critical,physical_exam_groups(title))",
      )
      .eq("session_id", sessionId),
    supabase.schema("praticase").from("session_requested_tests")
      .select(
        "created_at,test_options(title,result,point_cost,is_unnecessary,test_groups(title))",
      )
      .eq("session_id", sessionId),
    supabase.schema("praticase").from("session_diagnosis_answers")
      .select("primary_diagnosis,selected_option_ids,reasoning")
      .eq("session_id", sessionId)
      .maybeSingle(),
    supabase.schema("praticase").from("diagnosis_options")
      .select("id,title,is_primary,is_correct,sort_order")
      .eq("case_id", String(session.case_id ?? ""))
      .order("sort_order"),
    supabase.schema("praticase").from("session_management_notes")
      .select("diagnosis,plan_note")
      .eq("session_id", sessionId)
      .maybeSingle(),
    supabase.schema("praticase").from("session_management_plan_items")
      .select(
        "created_at,management_plan_options(category,title,point_value,is_recommended)",
      )
      .eq("session_id", sessionId),
  ]);

  const firstError = [
    messages.error,
    physical.error,
    tests.error,
    diagnosisAnswer.error,
    diagnosisOptions.error,
    managementNote.error,
    managementItems.error,
  ].find(Boolean);
  if (firstError) return { error: firstError.message };

  const caseData = Array.isArray(session.cases)
    ? session.cases[0]
    : session.cases;
  const checklists = await loadCaseChecklists(
    supabase,
    String(session.case_id ?? ""),
  );
  return {
    data: {
      session: {
        id: session.id,
        userId: session.user_id,
        mode: session.mode,
        currentStep: session.current_step,
        startedAt: session.started_at,
        endedAt: session.ended_at,
      },
      case: mergeCaseChecklistContext(caseData ?? {}, checklists),
      transcript: messages.data ?? [],
      selectedPhysicalExam: physical.data ?? [],
      requestedTests: tests.data ?? [],
      diagnosisAnswer: diagnosisAnswer.data ?? null,
      diagnosisOptions: diagnosisOptions.data ?? [],
      managementNote: managementNote.data ?? null,
      managementItems: managementItems.data ?? [],
    },
  };
}

function parseJson(raw: string): JsonMap {
  const cleaned = raw
    .replace(/^```json\s*/i, "")
    .replace(/^```\s*/i, "")
    .replace(/```$/i, "")
    .trim();
  return JSON.parse(cleaned) as JsonMap;
}

function normalizeScore(input: JsonMap): AiScore {
  const categoryScores = normalizeCategories(input.categoryScores);
  const total = categoryScores.reduce((sum, item) => sum + item.score, 0);
  return {
    totalScore: clampNumber(input.totalScore, 0, 100, total),
    maxScore: clampNumber(input.maxScore, 1, 100, 100),
    categoryScores,
    strongPoints: stringArray(input.strongPoints),
    improvementPoints: stringArray(input.improvementPoints),
    criticalMistakes: stringArray(input.criticalMistakes),
    unnecessaryTests: stringArray(input.unnecessaryTests),
    missedHistory: stringArray(input.missedHistory),
    missedPhysicalExam: stringArray(input.missedPhysicalExam),
    idealApproach: String(input.idealApproach ?? "").trim(),
  };
}

function normalizeCategories(value: unknown): AiScore["categoryScores"] {
  const defaults = [
    { title: "İletişim", maxScore: 10 },
    { title: "Anamnez", maxScore: 30 },
    { title: "Fizik Muayene", maxScore: 20 },
    { title: "Ön Tanılar", maxScore: 15 },
    { title: "Tetkikler", maxScore: 15 },
    { title: "Yönetim", maxScore: 10 },
  ];
  const rows = Array.isArray(value) ? value as JsonMap[] : [];
  return defaults.map((fallback) => {
    const found = rows.find((item) =>
      String(item.title ?? "").toLocaleLowerCase("tr-TR") ===
        fallback.title.toLocaleLowerCase("tr-TR")
    );
    return {
      title: fallback.title,
      score: clampNumber(found?.score, 0, fallback.maxScore, 0),
      maxScore: fallback.maxScore,
    };
  });
}

function stringArray(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => String(item ?? "").trim())
    .filter(Boolean)
    .slice(0, 5);
}

function clampNumber(
  value: unknown,
  min: number,
  max: number,
  fallback: number,
): number {
  const parsed = typeof value === "number"
    ? value
    : Number.parseFloat(String(value ?? ""));
  if (!Number.isFinite(parsed)) return fallback;
  return Math.max(min, Math.min(max, Math.round(parsed)));
}

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}
