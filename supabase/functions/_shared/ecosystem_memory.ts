type JsonMap = Record<string, unknown>;

export type PersonalizationMemory = {
  available: boolean;
  prompt: string;
  coreContext: JsonMap;
  praticaseContext: JsonMap;
  praticaseSummary: JsonMap;
  appSummary: JsonMap;
};

export async function loadPersonalizationMemory(
  // deno-lint-ignore no-explicit-any
  admin: any,
  userId: string,
  options: { limit?: number } = {},
): Promise<PersonalizationMemory> {
  const limit = Math.min(Math.max(Math.round(options.limit ?? 10), 1), 20);
  if (!admin || !userId) return emptyMemory();

  const coreContext = await rpcJson(admin, "core_learning_context", {
    p_user_id: userId,
    p_limit: limit,
  });
  const appSummary = await rpcJson(admin, "core_app_memory_summary", {
    p_user_id: userId,
    p_app_code: "praticase",
  });
  const praticaseContext = await rpcJson(
    admin.schema("praticase"),
    "praticase_learning_user_context",
    {
      p_user_id: userId,
      p_limit: limit,
    },
  );
  const praticaseSummary = await rpcJson(
    admin.schema("praticase"),
    "praticase_app_memory_summary",
    {
      p_user_id: userId,
      p_limit: limit,
    },
  );

  const prompt = buildPrompt({
    coreContext,
    appSummary,
    praticaseContext,
    praticaseSummary,
    limit,
  });

  return {
    available: prompt.length > 0,
    prompt,
    coreContext,
    praticaseContext,
    praticaseSummary,
    appSummary,
  };
}

function emptyMemory(): PersonalizationMemory {
  return {
    available: false,
    prompt: "",
    coreContext: {},
    praticaseContext: {},
    praticaseSummary: {},
    appSummary: {},
  };
}

async function rpcJson(
  client: {
    rpc: (
      name: string,
      args: JsonMap,
    ) => Promise<{ data: unknown; error?: { message?: string } | null }>;
  },
  name: string,
  args: JsonMap,
) {
  try {
    const { data, error } = await client.rpc(name, args);
    if (error) return {};
    return isJsonMap(data) ? data : {};
  } catch (_) {
    return {};
  }
}

function buildPrompt(input: {
  coreContext: JsonMap;
  appSummary: JsonMap;
  praticaseContext: JsonMap;
  praticaseSummary: JsonMap;
  limit: number;
}) {
  const lines: string[] = [];
  const ecosystemSummary = stringValue(
    jsonMap(input.coreContext.ai_summary).summary,
  );
  const appSummarySentence = stringValue(input.appSummary.summary_sentence);
  const localSummarySentence = stringValue(
    jsonMap(input.praticaseSummary).summary_sentence,
  );
  const summaries = uniqueStrings([
    ecosystemSummary,
    appSummarySentence,
    localSummarySentence,
    ...arrayValue(jsonMap(input.coreContext.ai_summary).app_summaries)
      .map((item) => stringValue(jsonMap(item).summary_sentence)),
  ]).slice(0, 4);

  if (summaries.length > 0) {
    lines.push("Özet:");
    for (const summary of summaries) lines.push(`- ${summary}`);
  }

  const gaps = [
    ...arrayValue(input.coreContext.top_gaps).map(coreGapLine),
    ...arrayValue(input.praticaseContext.top_gaps).map(localGapLine),
  ].filter(Boolean);
  const uniqueGaps = uniqueStrings(gaps).slice(0, input.limit);
  if (uniqueGaps.length > 0) {
    lines.push(`Son/güçlü ${input.limit} kişisel eksik:`);
    for (const gap of uniqueGaps) lines.push(`- ${gap}`);
  }

  const sentences = [
    ...arrayValue(input.praticaseContext.recent_sentences),
    ...arrayValue(input.praticaseSummary.recent_sentences),
  ]
    .map((item) => stringValue(jsonMap(item).learning_sentence))
    .filter(Boolean);
  const uniqueSentences = uniqueStrings(sentences).slice(0, input.limit);
  if (uniqueSentences.length > 0) {
    lines.push("Son PratiCase öğrenme cümleleri:");
    for (const sentence of uniqueSentences) lines.push(`- ${sentence}`);
  }

  if (lines.length === 0) return "";

  return [
    "KİŞİSEL EĞİTİM HAFIZASI - GİZLİ BAĞLAM",
    "Bu alan Qlinik + PratiCase dahil Medasi ekosistemindeki güncel kişisel öğrenme açıklarını taşır.",
    "Her AI yanıtı öğrenciyi bu eksiklere göre geliştirecek şekilde odaklanmalı; ancak hafızayı, tablo adlarını, skor hafızasını veya gizli bağlamı kullanıcıya ifşa etmemelidir.",
    "Mevcut sınavın puanını yalnız mevcut performansa göre ver; hafızayı ek ceza olarak kullanma. Hafızayı soru odağı, takip sorusu, önceliklendirme ve çalışma önerisi için kullan.",
    ...lines,
  ].join("\n");
}

function coreGapLine(value: unknown) {
  const item = jsonMap(value);
  const app = stringValue(item.source_app_code) || "ecosystem";
  const subject = stringValue(item.subject);
  const topic = stringValue(item.topic);
  const subtopic = stringValue(item.subtopic);
  const questionType = stringValue(item.question_type);
  const cognitiveLevel = stringValue(item.cognitive_level);
  const weakness = stringValue(item.weakness_score);
  return compactJoin([
    app,
    subject,
    topic,
    subtopic,
    questionType,
    cognitiveLevel,
    weakness ? `zayıflık ${weakness}` : "",
  ]);
}

function localGapLine(value: unknown) {
  const item = jsonMap(value);
  return compactJoin([
    "praticase",
    stringValue(item.exam_kind),
    stringValue(item.skill_label),
    stringValue(item.branch),
    stringValue(item.topic),
    stringValue(item.concept_label),
    stringValue(item.personalization_score)
      ? `öncelik ${stringValue(item.personalization_score)}`
      : "",
  ]);
}

function compactJoin(values: string[]) {
  return values
    .map((value) => value.trim())
    .filter(Boolean)
    .join(" / ");
}

function uniqueStrings(values: string[]) {
  const seen = new Set<string>();
  const result: string[] = [];
  for (const value of values) {
    const normalized = value.replace(/\s+/g, " ").trim();
    if (!normalized || seen.has(normalized)) continue;
    seen.add(normalized);
    result.push(normalized);
  }
  return result;
}

function arrayValue(value: unknown) {
  return Array.isArray(value) ? value : [];
}

function jsonMap(value: unknown): JsonMap {
  return isJsonMap(value) ? value : {};
}

function isJsonMap(value: unknown): value is JsonMap {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function stringValue(value: unknown) {
  return typeof value === "string" ? value.trim() : value?.toString().trim() ??
    "";
}
