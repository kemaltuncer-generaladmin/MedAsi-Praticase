import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.4";
import { corsHeaders, isAllowedOrigin, jsonResponse } from "../_shared/cors.ts";
import {
  generateVertexContent,
  historyModel,
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
  const message = String(body.message ?? "").trim();

  if (!sessionId || !message) {
    return jsonResponse(
      { error: "sessionId and message are required" },
      400,
      origin,
    );
  }
  if (message.length > 1200) {
    return jsonResponse(
      { error: "Message is too long" },
      413,
      origin,
    );
  }

  if (!vertexConfigured()) {
    return jsonResponse(
      { error: "Vertex AI configuration is missing" },
      500,
      origin,
    );
  }

  const supabase = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authorization } },
  });
  const admin = supabaseServiceRoleKey
    ? createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: { persistSession: false },
    })
    : null;

  const { data: session, error: sessionError } = await supabase
    .schema("praticase")
    .from("exam_sessions")
    .select(
      "id,user_id,case_id,mode,current_step,cases(title,branch,difficulty,setting,candidate_prompt,patient_profile,expected_history,expected_physical_exam,expected_differentials,expected_tests,unnecessary_tests,management_steps,critical_mistakes)",
    )
    .eq("id", sessionId)
    .eq("status", "active")
    .eq("current_step", "history")
    .single();

  if (sessionError || !session) {
    return jsonResponse({ error: "Exam session not found" }, 404, origin);
  }
  try {
    await ensureAiCoinBalance(admin, String(session.user_id ?? ""));
  } catch (error) {
    if (error instanceof InsufficientCoinBalanceError) {
      return jsonResponse(
        {
          error:
            "MedAsi Coin bakiyen yeterli değil. Cüzdandan coin yükleyip kaldığın yerden devam edebilirsin.",
          wallet_balance: error.walletBalance,
          required_balance: error.requiredBalance,
        },
        402,
        origin,
      );
    }
    throw error;
  }

  const { data: previousMessages, error: messagesError } = await supabase
    .schema("praticase")
    .from("exam_messages")
    .select("sender,message,created_at")
    .eq("session_id", sessionId)
    .order("created_at", { ascending: false })
    .limit(12);

  if (messagesError) {
    return jsonResponse({ error: messagesError.message }, 400, origin);
  }

  const caseData = Array.isArray(session.cases)
    ? session.cases[0]
    : session.cases;
  const checklists = await loadCaseChecklists(
    supabase,
    String(session.case_id ?? ""),
  );
  const mergedCaseData = mergeCaseChecklistContext(caseData ?? {}, checklists);
  const patientProfile = mergedCaseData.patient_profile ?? {};
  const history = (previousMessages ?? []).reverse().map((item) => ({
    role: item.sender === "patient" ? "model" as const : "user" as const,
    parts: [{ text: String(item.message ?? "") }],
  }));
  const context = {
    caseTitle: mergedCaseData.title,
    branch: mergedCaseData.branch,
    setting: mergedCaseData.setting,
    candidatePrompt: mergedCaseData.candidate_prompt,
    patientProfile,
    expectedHistory: mergedCaseData.expected_history ?? [],
    expectedPhysicalExam: mergedCaseData.expected_physical_exam ?? [],
    expectedDifferentials: mergedCaseData.expected_differentials ?? [],
    expectedTests: mergedCaseData.expected_tests ?? [],
    unnecessaryTests: mergedCaseData.unnecessary_tests ?? [],
    managementSteps: mergedCaseData.management_steps ?? [],
    criticalMistakes: mergedCaseData.critical_mistakes ?? [],
    adminGeneratedChecklists: mergedCaseData.admin_generated_checklists ?? {},
  };

  let aiResponse = "";
  let usageMetadata: Record<string, unknown> = {};
  let model = historyModel();
  try {
    const generated = await generateVertexContent({
      model,
      systemInstruction:
        "Sen PratiCase OSCE simülasyonunda sanal hastasın. Hoca, asistan veya açıklayıcı kaynak gibi konuşma; hasta gibi kısa, doğal ve Türkçe cevap ver. Sadece adayın sorduğu soruya yanıt ver. Sorulmadıkça kritik bilgiyi, tanıyı, ideal yaklaşımı veya rubrik ipucunu verme. Tıbbi terimi anlamazsan hastanın anlayacağı dille netleştirme isteyebilirsin. Verilen vaka bağlamı dışına taşma; bilinmeyen bilgide 'bilmiyorum', 'hatırlamıyorum' veya 'emin değilim' de. Sert, yargılayıcı veya aşırı uzun cevap verme.",
      contents: [
        {
          role: "user",
          parts: [
            {
              text: `Vaka bağlamı JSON:\n${
                JSON.stringify(context)
              }\n\nBu bağlamı gizli tut. Aday şimdi şunu sordu:\n${message}`,
            },
          ],
        },
        ...history,
        { role: "user", parts: [{ text: message }] },
      ],
      temperature: 0.45,
      maxOutputTokens: 280,
    });
    aiResponse = generated.text;
    usageMetadata = generated.usageMetadata;
    model = generated.model;
  } catch (error) {
    return jsonResponse(
      { error: "Vertex AI patient turn failed", detail: errorMessage(error) },
      502,
      origin,
    );
  }

  let chargedCoinAmount = 0;
  let walletBalance: number | null = null;
  try {
    const charge = await chargeAiCoins({
      admin,
      userId: String(session.user_id ?? ""),
      feature: "praticase-patient-turn",
      model,
      usageMetadata,
    });
    chargedCoinAmount = charge.chargedCoinAmount;
    walletBalance = charge.walletBalance;
  } catch (error) {
    if (error instanceof InsufficientCoinBalanceError) {
      return jsonResponse(
        {
          error:
            "MedAsi Coin bakiyen yeterli değil. Cüzdandan coin yükleyip kaldığın yerden devam edebilirsin.",
          wallet_balance: error.walletBalance,
          required_balance: error.requiredBalance,
        },
        402,
        origin,
      );
    }
    throw error;
  }

  const { error: insertCandidateError } = await supabase
    .schema("praticase")
    .from("exam_messages")
    .insert({ session_id: sessionId, sender: "candidate", message });

  if (insertCandidateError) {
    return jsonResponse({ error: insertCandidateError.message }, 400, origin);
  }

  const { data: patientMessage, error: insertPatientError } = await supabase
    .schema("praticase")
    .from("exam_messages")
    .insert({ session_id: sessionId, sender: "patient", message: aiResponse })
    .select("id")
    .single();

  if (insertPatientError) {
    return jsonResponse({ error: insertPatientError.message }, 400, origin);
  }

  return jsonResponse(
    {
      patientMessageId: patientMessage?.id ?? null,
      response: aiResponse,
      model,
      chargedCoinAmount,
      walletBalance,
    },
    200,
    origin,
  );
});

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}
