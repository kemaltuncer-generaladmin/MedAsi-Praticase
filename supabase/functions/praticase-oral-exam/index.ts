import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.4";
import { corsHeaders, isAllowedOrigin, jsonResponse } from "../_shared/cors.ts";
import {
  evaluationModel,
  generateVertexContent,
  historyModel,
  vertexConfigured,
} from "../_shared/vertex_ai.ts";
import {
  chargeAiCoins,
  ensureAiCoinBalance,
  InsufficientCoinBalanceError,
} from "../_shared/medasi_coin.ts";

type JsonMap = Record<string, unknown>;

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

  if (
    !supabaseUrl || !supabaseAnonKey || !supabaseServiceRoleKey ||
    !authorization
  ) {
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

  const admin = createClient(supabaseUrl, supabaseServiceRoleKey, {
    auth: { persistSession: false },
  });

  if (!vertexConfigured()) {
    return jsonResponse(
      { error: "Vertex AI configuration is missing" },
      500,
      origin,
    );
  }

  const body = await request.json().catch(() => ({})) as JsonMap;
  const action = stringValue(body.action);
  const userId = authData.user.id;

  try {
    await ensureAiCoinBalance(admin, userId);
  } catch (error) {
    if (error instanceof InsufficientCoinBalanceError) {
      return jsonResponse(
        {
          error:
            "MedAsi Coin bakiyen yeterli değil. Sözlü sınava devam etmek için cüzdandan coin yükle.",
          wallet_balance: error.walletBalance,
          required_balance: error.requiredBalance,
        },
        402,
        origin,
      );
    }
    throw error;
  }

  try {
    switch (action) {
      case "start":
        return withOrigin(await startSession(admin, userId, body), origin);
      case "turn":
        return withOrigin(await takeTurn(admin, userId, body), origin);
      case "skip":
        return withOrigin(await skipQuestion(admin, userId, body), origin);
      case "finalize":
        return withOrigin(await finalize(admin, userId, body), origin);
      case "list_scenarios":
        return withOrigin(await listScenarios(admin, body), origin);
      default:
        return jsonResponse({ error: "Unknown action" }, 400, origin);
    }
  } catch (error) {
    if (error instanceof InsufficientCoinBalanceError) {
      return jsonResponse(
        {
          error: "MedAsi Coin bakiyen yeterli değil.",
          wallet_balance: error.walletBalance,
          required_balance: error.requiredBalance,
        },
        402,
        origin,
      );
    }
    return jsonResponse(
      {
        error: "Sözlü sınav servisi hatası",
        detail: errorMessage(error),
      },
      502,
      origin,
    );
  }
});

async function startSession(admin: any, userId: string, body: JsonMap) {
  const examFormat = stringValue(body.exam_format) === "panel"
    ? "panel"
    : "solo";
  const personaId = stringValue(body.persona_id) || "stern_professor";
  const branchId = stringValue(body.branch_id) || "dahiliye";
  const scenarioId = stringValue(body.scenario_id);
  const durationSeconds = Math.min(
    1800,
    Math.max(300, numberValue(body.duration_seconds) ?? 900),
  );

  let persona: any = null;
  let panelPersonas: any[] = [];

  if (examFormat === "panel") {
    const { data: all } = await admin
      .schema("praticase")
      .from("oral_exam_personas")
      .select("id,title,difficulty,system_prompt,patience_level,panel_role")
      .order("sort_order");
    const available = all ?? [];
    panelPersonas = ["lead", "second", "observer"]
      .map((role) => available.find((p: any) => p.panel_role === role))
      .filter(Boolean);
    if (panelPersonas.length !== 3) {
      return { error: "Komite modu için üç hoca rolü tanımlı değil." };
    }
    persona = panelPersonas[0];
  } else {
    const { data } = await admin
      .schema("praticase")
      .from("oral_exam_personas")
      .select("id,title,difficulty,system_prompt,patience_level,panel_role")
      .eq("id", personaId)
      .maybeSingle();
    persona = data;
  }
  if (!persona) return { error: "Persona bulunamadı." };

  const { data: branch } = await admin
    .schema("praticase")
    .from("oral_exam_branches")
    .select("id,title,case_seed")
    .eq("id", branchId)
    .maybeSingle();
  if (!branch) return { error: "Branş bulunamadı." };

  let scenario: any = null;
  if (scenarioId) {
    const { data } = await admin
      .schema("praticase")
      .from("oral_exam_scenarios")
      .select(
        "id,title,case_brief,opening_complaint,learning_objectives,expected_differentials,red_flags,ideal_management",
      )
      .eq("id", scenarioId)
      .eq("branch_id", branch.id)
      .maybeSingle();
    scenario = data;
  }

  let caseBrief = "";
  let mentorMessage = "";

  if (scenario) {
    // Kürasyon edilmiş senaryo: AI sadece personaya uygun açılış metnini yazsın
    caseBrief = stringValue(scenario.case_brief);
    const opening = await generateVertexContent({
      model: historyModel(),
      systemInstruction:
        `${persona.system_prompt}\n\nGörev: aşağıda verilen önceden hazırlanmış sözlü sınav vakasını ` +
        `sun ve ilk soruyu sor. Türkçe konuş. Personana uygun tonla:\n` +
        `1) Vaka brifini AYNEN paragraf olarak oku/sun.\n` +
        `2) Tek bir açılış sorusu sor (anamnez/yaklaşım sorusu).\n` +
        `JSON döndür: {"mentor_message":"vaka brifi + tek soru"}`,
      contents: [{
        role: "user",
        parts: [{
          text: `BRANŞ: ${branch.title}\nVAKA BAŞLIK: ${scenario.title}\n\n` +
            `VAKA BRİFİ:\n${scenario.case_brief}\n\n` +
            `HASTANIN AÇILIŞ CÜMLESİ: ${scenario.opening_complaint}\n\n` +
            `Öğrenme hedefleri (rehber): ${
              JSON.stringify(scenario.learning_objectives)
            }\n` +
            `Sınav süresi: ${Math.round(durationSeconds / 60)} dakika.`,
        }],
      }],
      temperature: 0.45,
      maxOutputTokens: 600,
      responseMimeType: "application/json",
    });
    const parsed = safeParse(opening.text);
    mentorMessage = stringValue(parsed.mentor_message) ||
      stringValue(opening.text) ||
      caseBrief;
    await chargeAiCoins({
      admin,
      userId,
      feature: "praticase-oral-exam-start",
      model: opening.model,
      usageMetadata: opening.usageMetadata,
    }).catch(() => {});
  } else {
    // Senaryo seçilmedi → AI rastgele üretir
    const opening = await generateVertexContent({
      model: historyModel(),
      systemInstruction:
        `${persona.system_prompt}\n\nGörev: ${branch.title} stajında sözlü sınav vakası başlat. ` +
        `Türkçe konuş. Önce 2-3 cümlelik vaka brifi (yaş, cinsiyet, şikayet, başvuru yeri, kısa öykü) sun, ` +
        `ardından İLK soruyu sor. Vaka brifi + tek soru. JSON döndür: ` +
        `{"case_brief":"...","mentor_message":"vaka brifi + ilk soru tek paragraf"}.`,
      contents: [{
        role: "user",
        parts: [{
          text:
            `Branş bilgisi: ${branch.case_seed}\nZorluk: ${persona.difficulty}\nHoca tipi: ${persona.title}\n` +
            `Sınav süresi: ${Math.round(durationSeconds / 60)} dakika.\n` +
            `Vaka klinik olarak gerçekçi, ayırt edilebilir, tartışılabilir olsun.`,
        }],
      }],
      temperature: 0.7,
      maxOutputTokens: 600,
      responseMimeType: "application/json",
    });
    const parsed = safeParse(opening.text);
    caseBrief = stringValue(parsed.case_brief);
    mentorMessage = stringValue(parsed.mentor_message) ||
      stringValue(opening.text) ||
      caseBrief;
    if (!caseBrief && mentorMessage) caseBrief = mentorMessage;
    await chargeAiCoins({
      admin,
      userId,
      feature: "praticase-oral-exam-start",
      model: opening.model,
      usageMetadata: opening.usageMetadata,
    }).catch(() => {});
  }

  const panelPersonaIds = examFormat === "panel"
    ? panelPersonas.map((p: any) => p.id)
    : [];

  const { data: session, error } = await admin
    .schema("praticase")
    .from("oral_exam_sessions")
    .insert({
      user_id: userId,
      persona_id: persona.id,
      branch_id: branch.id,
      duration_seconds: durationSeconds,
      case_brief: caseBrief,
      status: "active",
      exam_format: examFormat,
      panel_persona_ids: panelPersonaIds,
    })
    .select(
      "id,duration_seconds,case_brief,started_at,exam_format,panel_persona_ids",
    )
    .single();
  if (error || !session) {
    return { error: error?.message ?? "Sözlü sınav başlatılamadı." };
  }

  await admin.schema("praticase").from("oral_exam_turns").insert({
    session_id: session.id,
    sequence: 1,
    speaker: "mentor",
    speaker_persona_id: persona.id,
    message: mentorMessage,
    is_followup: false,
  });

  return {
    session_id: session.id,
    duration_seconds: session.duration_seconds,
    case_brief: session.case_brief,
    started_at: session.started_at,
    mentor_message: mentorMessage,
    persona: {
      id: persona.id,
      title: persona.title,
      difficulty: persona.difficulty,
    },
    branch: { id: branch.id, title: branch.title },
    exam_format: examFormat,
    panel: examFormat === "panel"
      ? panelPersonas.map((p: any) => ({
        id: p.id,
        title: p.title,
        difficulty: p.difficulty,
        panel_role: p.panel_role,
      }))
      : [],
    active_persona_id: persona.id,
  };
}

async function takeTurn(admin: any, userId: string, body: JsonMap) {
  const sessionId = stringValue(body.session_id);
  const candidateMessage = stringValue(body.message);
  if (!sessionId || !candidateMessage) {
    return { error: "session_id ve message zorunlu." };
  }
  const session = await loadSession(admin, sessionId, userId);
  if (!session) return { error: "Sözlü sınav oturumu bulunamadı." };
  if (session.status !== "active") {
    return { error: "Sözlü sınav oturumu kapatılmış." };
  }

  const branch = await loadBranch(admin, session.branch_id);
  if (!branch) return { error: "Sözlü sınav yapılandırması eksik." };

  const turns = await loadTurns(admin, sessionId);
  const panel = await loadPanelPersonas(admin, session);
  const panelMap = new Map<string, any>(
    panel.map((p: any) => [p.id, p] as [string, any]),
  );
  const lead = panel.find((p: any) => p.panel_role === "lead") ?? panel[0];
  const second = panel.find((p: any) => p.panel_role === "second");
  const observer = panel.find((p: any) => p.panel_role === "observer");

  let activePersona: any;
  if (session.exam_format === "panel" && panel.length === 3) {
    // Açılış sorusunu lead sorar; her cevap sonrası soru sırası diğer
    // komisyon üyelerine geçer. Üçü değerlendirse de yalnız biri soru sorar.
    const questionRotation = [second, observer, lead].filter(Boolean);
    const answerCount = turns.filter((t: any) =>
      t.speaker === "candidate"
    ).length;
    activePersona = questionRotation[answerCount % questionRotation.length];
  } else {
    activePersona = panelMap.get(session.persona_id) ?? lead;
  }

  const nextSequence = (turns.at(-1)?.sequence ?? 0) + 1;

  await admin.schema("praticase").from("oral_exam_turns").insert({
    session_id: sessionId,
    sequence: nextSequence,
    speaker: "candidate",
    message: candidateMessage,
    is_followup: false,
  });

  const elapsedSeconds = Math.max(
    0,
    Math.round((Date.now() - new Date(session.started_at).getTime()) / 1000),
  );
  const remainingSeconds = Math.max(
    0,
    session.duration_seconds - elapsedSeconds,
  );

  const transcript = [...turns, {
    sequence: nextSequence,
    speaker: "candidate",
    message: candidateMessage,
  }];

  const isPanelTurn = session.exam_format === "panel" && panel.length === 3;
  const panelContext = isPanelTurn
    ? `\n\nKOMİTE MODU. Sınav masasında 3 hoca var:\n` +
      panel.map((p: any) =>
        `- ${p.title} (${
          p.panel_role === "lead"
            ? "ana sorgulayıcı"
            : p.panel_role === "second"
            ? "yardımcı sorgulayıcı"
            : "gözlemci"
        }): ${p.difficulty}`
      ).join("\n") +
      `\n\nAdayın bu yanıtını üç hoca da aynı turda değerlendirir. ` +
      `Her hoca kendi tonuyla en fazla bir kısa cümle konuşsun. ` +
      `Yalnız "${activePersona.title}" konuşmasının sonunda TEK takip sorusu sorsun; ` +
      `diğer iki hoca kesinlikle soru sormasın.`
    : "";

  const response = await generateVertexContent({
    model: historyModel(),
    systemInstruction: `${activePersona.system_prompt}\n` +
      `Sen ${activePersona.title}'sin. Şu anda sözlü sınavda aday seninle konuşuyor.${panelContext}\n\n` +
      `Klinik vaka: ${session.case_brief}\n` +
      `Branş: ${branch.title}. Zorluk: ${activePersona.difficulty}.\n` +
      `Sınavda kalan süre: ${Math.round(remainingSeconds / 60)} dakika ${
        remainingSeconds % 60
      } saniye.\n` +
      `Kalan süre <2dk ise hoca sınavı kapatmaya hazır olabilir.\n\n` +
      `Görevin:\n` +
      `1) Adayın son cevabını klinik olarak değerlendir (eksik mi, hatalı mı, doğru mu).\n` +
      `2) Türkçe kısa hoca yanıtı yaz. ASLA aynı anda iki soru sorma. ` +
      `Yanıtın değerlendirme + bir takip sorusu olsun. ` +
      `Eğer aday "öğretilmedi" derse profesyonelce uyar. ` +
      `Eğer süre <2dk kaldıysa "Şimdi sınavı bitirelim, son bir şey sorayım..." gibi kapatmaya yönel.\n` +
      (isPanelTurn
        ? `3) JSON döndür: {"mentor_message":"${activePersona.title} tarafından sorulan tek takip sorusu",` +
          `"committee_messages":[{"persona_id":"...","message":"...","asks_question":false},` +
          `{"persona_id":"...","message":"...","asks_question":false},` +
          `{"persona_id":"${activePersona.id}","message":"değerlendirme ve tek soru","asks_question":true}],`
        : `3) JSON döndür: {"mentor_message":"...",`) +
      `"is_followup":bool,"turn_evaluation":` +
      `{"score_delta":-10..15,"is_correct":bool,"reasoning":"kısa not"},"should_end":bool}`,
    contents: [{
      role: "user",
      parts: [{
        text: `Aşağıdaki tüm dialog transcript'i:\n` +
          transcript.map((t: any) => {
            if (t.speaker === "candidate") return `ADAY: ${t.message}`;
            if (t.speaker === "system") return `SİSTEM: ${t.message}`;
            const who = t.speaker_persona_id
              ? (panelMap.get(t.speaker_persona_id)?.title ?? "HOCA")
              : "HOCA";
            return `${who.toUpperCase()}: ${t.message}`;
          }).join("\n\n"),
      }],
    }],
    temperature: 0.55,
    maxOutputTokens: 900,
    responseMimeType: "application/json",
  });
  const parsed = safeParse(response.text);
  let mentorMessage = stringValue(parsed.mentor_message);
  if (!mentorMessage) {
    const rawFallback = stringValue(response.text)
      .replace(/^```json\s*/i, "")
      .replace(/^```\s*/i, "")
      .replace(/```$/i, "")
      .trim();
    mentorMessage = rawFallback ||
      `${activePersona.title}: Devam edelim, lütfen son cevabını biraz daha açar mısın?`;
  }
  const isFollowup = parsed.is_followup === true;
  const shouldEnd = parsed.should_end === true || remainingSeconds <= 0;
  const turnEval = (parsed.turn_evaluation as JsonMap | undefined) ?? {};
  const mentorReplies = isPanelTurn
    ? committeeReplies(parsed, panel, activePersona, mentorMessage)
    : [{
      persona_id: activePersona.id,
      persona_title: activePersona.title,
      message: mentorMessage,
      asks_question: isFollowup,
    }];
  const questionMessage =
    mentorReplies.find((reply) => reply.asks_question)?.message ??
      mentorMessage;

  await chargeAiCoins({
    admin,
    userId,
    feature: "praticase-oral-exam-turn",
    model: response.model,
    usageMetadata: response.usageMetadata,
  }).catch(() => {});

  await admin.schema("praticase").from("oral_exam_turns").insert(
    mentorReplies.map((reply, index) => ({
      session_id: sessionId,
      sequence: nextSequence + index + 1,
      speaker: "mentor",
      speaker_persona_id: reply.persona_id,
      message: reply.message,
      is_followup: reply.asks_question,
      evaluation: reply.persona_id === activePersona.id ? turnEval : {},
    })),
  );

  return {
    mentor_message: questionMessage,
    committee_messages: mentorReplies,
    is_followup: isFollowup,
    should_end: shouldEnd,
    remaining_seconds: remainingSeconds,
    turn_evaluation: turnEval,
    active_persona_id: activePersona.id,
    active_persona_title: activePersona.title,
  };
}

async function skipQuestion(admin: any, userId: string, body: JsonMap) {
  const sessionId = stringValue(body.session_id);
  if (!sessionId) return { error: "session_id zorunlu." };
  const session = await loadSession(admin, sessionId, userId);
  if (!session) return { error: "Sözlü sınav oturumu bulunamadı." };
  if (session.status !== "active") return { error: "Sözlü sınav kapanmış." };

  const branch = await loadBranch(admin, session.branch_id);
  const turns = await loadTurns(admin, sessionId);
  const panel = await loadPanelPersonas(admin, session);
  const lead = panel.find((p: any) => p.panel_role === "lead") ?? panel[0];
  const second = panel.find((p: any) => p.panel_role === "second");
  const observer = panel.find((p: any) => p.panel_role === "observer");
  const isPanelTurn = session.exam_format === "panel" && panel.length === 3;
  const questionRotation = [second, observer, lead].filter(Boolean);
  const answerCount =
    turns.filter((t: any) => t.speaker === "candidate").length;
  const activePersona = isPanelTurn
    ? questionRotation[answerCount % questionRotation.length]
    : (panel.find((p: any) => p.id === session.persona_id) ?? lead);

  const nextSequence = (turns.at(-1)?.sequence ?? 0) + 1;

  await admin.schema("praticase").from("oral_exam_turns").insert({
    session_id: sessionId,
    sequence: nextSequence,
    speaker: "candidate",
    message: "(aday bu soruyu pas geçti)",
    is_followup: false,
    was_skipped: true,
    evaluation: { score_delta: -5 },
  });

  const response = await generateVertexContent({
    model: historyModel(),
    systemInstruction: `${activePersona?.system_prompt ?? ""}\n` +
      `Sen ${activePersona?.title}'sin. Aday bir soruyu pas geçti. ` +
      `Tonuna uygun (Sabırlı: anlayışlı, Sokratik: ipucuyla yeniden çerçevele, Sert: sert uyarı) ` +
      `Türkçe kısa hoca yanıtı ver. Yeni bir soruya geç. ` +
      (isPanelTurn
        ? `Komisyondaki üç hoca da aynı turda birer kısa tepki versin; yalnız ${activePersona.title} ` +
          `tek yeni soru sorsun. JSON: {"mentor_message":"soruyu soran hoca mesajı",` +
          `"committee_messages":[{"persona_id":"...","message":"...","asks_question":false},` +
          `{"persona_id":"...","message":"...","asks_question":false},` +
          `{"persona_id":"${activePersona.id}","message":"... tek soru","asks_question":true}]}`
        : `JSON: {"mentor_message":"..."}`),
    contents: [{
      role: "user",
      parts: [{
        text: `Vaka: ${session.case_brief}\nBranş: ${branch?.title ?? ""}\n` +
          `Son aday cevabı: PAS GEÇTİ.`,
      }],
    }],
    temperature: 0.55,
    maxOutputTokens: 360,
    responseMimeType: "application/json",
  });
  const parsed = safeParse(response.text);
  let mentorMessage = stringValue(parsed.mentor_message);
  if (!mentorMessage) {
    mentorMessage = stringValue(response.text) ||
      `${
        activePersona?.title ?? "Hoca"
      }: Geç o zaman, bir sonraki soruya geçelim.`;
  }
  const mentorReplies = isPanelTurn
    ? committeeReplies(parsed, panel, activePersona, mentorMessage)
    : [{
      persona_id: activePersona.id,
      persona_title: activePersona.title,
      message: mentorMessage,
      asks_question: false,
    }];

  await chargeAiCoins({
    admin,
    userId,
    feature: "praticase-oral-exam-skip",
    model: response.model,
    usageMetadata: response.usageMetadata,
  }).catch(() => {});

  await admin.schema("praticase").from("oral_exam_turns").insert(
    mentorReplies.map((reply, index) => ({
      session_id: sessionId,
      sequence: nextSequence + index + 1,
      speaker: "mentor",
      speaker_persona_id: reply.persona_id,
      message: reply.message,
      is_followup: reply.asks_question,
    })),
  );

  return {
    mentor_message: mentorMessage,
    committee_messages: mentorReplies,
    skipped: true,
    active_persona_id: activePersona.id,
    active_persona_title: activePersona.title,
  };
}

async function finalize(admin: any, userId: string, body: JsonMap) {
  const sessionId = stringValue(body.session_id);
  if (!sessionId) return { error: "session_id zorunlu." };
  const session = await loadSession(admin, sessionId, userId);
  if (!session) return { error: "Sözlü sınav oturumu bulunamadı." };

  const branch = await loadBranch(admin, session.branch_id);
  const turns = await loadTurns(admin, sessionId);
  const panel = await loadPanelPersonas(admin, session);
  const panelMap = new Map<string, any>(
    panel.map((p: any) => [p.id, p] as [string, any]),
  );

  if (turns.length === 0) {
    await admin.schema("praticase")
      .from("oral_exam_sessions")
      .update({ status: "abandoned", ended_at: new Date().toISOString() })
      .eq("id", sessionId);
    return { error: "Sınav transcripti boş, değerlendirilemiyor." };
  }

  const transcriptText = turns.map((t: any) => {
    if (t.speaker === "candidate") {
      return `ADAY${t.was_skipped ? " (PAS)" : ""}: ${t.message}`;
    }
    if (t.speaker === "system") return `SİSTEM: ${t.message}`;
    const who = t.speaker_persona_id
      ? (panelMap.get(t.speaker_persona_id)?.title ?? "HOCA")
      : "HOCA";
    return `${who.toUpperCase()}: ${t.message}`;
  }).join("\n\n");

  const isPanel = session.exam_format === "panel" && panel.length >= 2;
  const panelPromptSection = isPanel
    ? `\n\nKomite sınavı. Hocalar:\n` +
      panel.map((p: any) => `- ${p.title} (${p.panel_role})`).join("\n") +
      `\n\nEK ÇIKTI: panel_summaries alanı ekle. Her hocadan AYRI bir yorum: ` +
      `{"<persona_id>": {"verdict":"geçer/sınırda/kalır","note":"2 cümle"}}.\n` +
      `Ayrıca mentor_summary alanı 3-5 cümlelik dramatize edilmiş "komite kararı" konuşmasıdır ` +
      `(örn: "Komite tartıştı. Profesör katı değerlendirmesini paylaştı, doçent ipucu vermişti..."). ` +
      `Bu konuşmayı lead hoca yapıyor gibi yaz.`
    : "";

  const evaluation = await generateVertexContent({
    model: evaluationModel(),
    systemInstruction:
      `Sen tıp fakültesi sözlü sınav değerlendiricisisin. Adayın TÜM transcripti veriliyor. ` +
      `100 puan üzerinden rubrik puanlama yap:\n` +
      `- Klinik akıl yürütme: 40\n- Bilgi doğruluğu: 30\n- İletişim/özgüven: 15\n- Soru-cevap hızı: 10\n- Profesyonellik: 5\n\n` +
      `JSON döndür:\n{` +
      `"total_score":0,"reasoning_score":0,"knowledge_score":0,"communication_score":0,"pace_score":0,"professionalism_score":0,` +
      `"mentor_summary":"...","strong_points":[],"improvement_points":[],"missed_points":[],"panel_summaries":{}` +
      `}\nListeler en fazla 5 madde, her madde 1 cümle.${panelPromptSection}`,
    contents: [{
      role: "user",
      parts: [{
        text:
          `Format: ${session.exam_format}\nBranş: ${branch?.title}\nVaka: ${session.case_brief}\n\n` +
          `TRANSCRIPT:\n${transcriptText}`,
      }],
    }],
    temperature: 0.2,
    maxOutputTokens: 1800,
    responseMimeType: "application/json",
  });
  const parsed = safeParse(evaluation.text);

  await chargeAiCoins({
    admin,
    userId,
    feature: "praticase-oral-exam-finalize",
    model: evaluation.model,
    usageMetadata: evaluation.usageMetadata,
  }).catch(() => {});

  const reasoning = clamp(numberValue(parsed.reasoning_score) ?? 0, 0, 40);
  const knowledge = clamp(numberValue(parsed.knowledge_score) ?? 0, 0, 30);
  const communication = clamp(
    numberValue(parsed.communication_score) ?? 0,
    0,
    15,
  );
  const pace = clamp(numberValue(parsed.pace_score) ?? 0, 0, 10);
  const professionalism = clamp(
    numberValue(parsed.professionalism_score) ?? 0,
    0,
    5,
  );
  const total = clamp(
    numberValue(parsed.total_score) ??
      (reasoning + knowledge + communication + pace + professionalism),
    0,
    100,
  );
  const panelSummaries =
    (parsed.panel_summaries && typeof parsed.panel_summaries === "object")
      ? parsed.panel_summaries as JsonMap
      : {};

  const update = await admin
    .schema("praticase")
    .from("oral_exam_sessions")
    .update({
      status: "completed",
      ended_at: new Date().toISOString(),
      total_score: total,
      max_score: 100,
      reasoning_score: reasoning,
      knowledge_score: knowledge,
      communication_score: communication,
      pace_score: pace,
      professionalism_score: professionalism,
      mentor_summary: stringValue(parsed.mentor_summary),
      strong_points: Array.isArray(parsed.strong_points)
        ? parsed.strong_points
        : [],
      improvement_points: Array.isArray(parsed.improvement_points)
        ? parsed.improvement_points
        : [],
      missed_points: Array.isArray(parsed.missed_points)
        ? parsed.missed_points
        : [],
      panel_summaries: panelSummaries,
      updated_at: new Date().toISOString(),
    })
    .eq("id", sessionId)
    .select(
      "id,total_score,max_score,reasoning_score,knowledge_score,communication_score,pace_score,professionalism_score,mentor_summary,strong_points,improvement_points,missed_points,case_brief,exam_format,panel_persona_ids,panel_summaries",
    )
    .single();
  if (update.error) return { error: update.error.message };
  return {
    result: update.data,
    panel: panel.map((p: any) => ({
      id: p.id,
      title: p.title,
      panel_role: p.panel_role,
    })),
  };
}

async function listScenarios(admin: any, body: JsonMap) {
  const branchId = stringValue(body.branch_id);
  let q = admin
    .schema("praticase")
    .from("oral_exam_scenarios")
    .select("id,branch_id,title,case_brief,difficulty_floor,sort_order")
    .order("sort_order");
  if (branchId) q = q.eq("branch_id", branchId);
  const { data, error } = await q;
  if (error) return { error: error.message };
  return { scenarios: data ?? [] };
}

async function loadSession(admin: any, sessionId: string, userId: string) {
  const { data } = await admin
    .schema("praticase")
    .from("oral_exam_sessions")
    .select(
      "id,user_id,persona_id,branch_id,duration_seconds,case_brief,status,started_at,exam_format,panel_persona_ids",
    )
    .eq("id", sessionId)
    .eq("user_id", userId)
    .maybeSingle();
  return data;
}

async function loadPanelPersonas(admin: any, session: any) {
  if (session.exam_format === "panel") {
    const ids = Array.isArray(session.panel_persona_ids)
      ? session.panel_persona_ids
      : [];
    if (ids.length === 0) {
      const { data } = await admin
        .schema("praticase")
        .from("oral_exam_personas")
        .select("id,title,difficulty,system_prompt,patience_level,panel_role")
        .order("sort_order");
      return data ?? [];
    }
    const { data } = await admin
      .schema("praticase")
      .from("oral_exam_personas")
      .select("id,title,difficulty,system_prompt,patience_level,panel_role")
      .in("id", ids);
    return data ?? [];
  }
  const { data } = await admin
    .schema("praticase")
    .from("oral_exam_personas")
    .select("id,title,difficulty,system_prompt,patience_level,panel_role")
    .eq("id", session.persona_id);
  return data ?? [];
}

async function loadPersona(admin: any, id: string) {
  const { data } = await admin
    .schema("praticase")
    .from("oral_exam_personas")
    .select("id,title,difficulty,system_prompt,patience_level,panel_role")
    .eq("id", id)
    .maybeSingle();
  return data;
}

async function loadBranch(admin: any, id: string) {
  const { data } = await admin
    .schema("praticase")
    .from("oral_exam_branches")
    .select("id,title,case_seed")
    .eq("id", id)
    .maybeSingle();
  return data;
}

async function loadTurns(admin: any, sessionId: string) {
  const { data } = await admin
    .schema("praticase")
    .from("oral_exam_turns")
    .select(
      "sequence,speaker,speaker_persona_id,message,is_followup,was_skipped,evaluation",
    )
    .eq("session_id", sessionId)
    .order("sequence");
  return data ?? [];
}

function withOrigin(payload: JsonMap, origin: string | null) {
  const status = payload.error ? 400 : 200;
  return jsonResponse(payload, status, origin);
}

function committeeReplies(
  parsed: JsonMap,
  panel: any[],
  activePersona: any,
  fallbackMessage: string,
) {
  const rawMessages = Array.isArray(parsed.committee_messages)
    ? parsed.committee_messages.filter((message) =>
      message && typeof message === "object"
    ) as JsonMap[]
    : [];

  const messageFor = (personaId: string) => {
    const raw = rawMessages.find((message) =>
      stringValue(message.persona_id) === personaId
    );
    return stringValue(raw?.message);
  };

  const comments = panel
    .filter((persona: any) => persona.id !== activePersona.id)
    .map((persona: any) => ({
      persona_id: persona.id,
      persona_title: persona.title,
      message: messageFor(persona.id) ||
        "Yanıtınızı komisyon değerlendirmesine aldım.",
      asks_question: false,
    }));
  comments.push({
    persona_id: activePersona.id,
    persona_title: activePersona.title,
    message: messageFor(activePersona.id) || fallbackMessage,
    asks_question: true,
  });
  return comments;
}

function safeParse(raw: string): JsonMap {
  const cleaned = raw
    .replace(/^```json\s*/i, "")
    .replace(/^```\s*/i, "")
    .replace(/```$/i, "")
    .trim();
  try {
    return JSON.parse(cleaned) as JsonMap;
  } catch {
    // JSON parse failed — try to salvage the first {...} block, otherwise
    // expose the raw text so the user still sees a mentor response instead
    // of an empty bubble.
    const start = cleaned.indexOf("{");
    const end = cleaned.lastIndexOf("}");
    if (start >= 0 && end > start) {
      try {
        return JSON.parse(cleaned.slice(start, end + 1)) as JsonMap;
      } catch {
        // fall through to raw fallback
      }
    }
    return cleaned ? { mentor_message: cleaned } : {};
  }
}

function clamp(value: number, min: number, max: number) {
  return Math.max(min, Math.min(max, Math.round(value)));
}

function numberValue(value: unknown) {
  const numeric = Number(value);
  return Number.isFinite(numeric) ? numeric : null;
}

function stringValue(value: unknown) {
  return typeof value === "string"
    ? value.trim()
    : value == null
    ? ""
    : String(value).trim();
}

function errorMessage(error: unknown) {
  return error instanceof Error ? error.message : String(error);
}
