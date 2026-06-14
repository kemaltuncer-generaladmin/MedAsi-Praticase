import { corsHeaders, isAllowedOrigin, jsonResponse } from "../_shared/cors.ts";
import {
  authErrorResponse,
  resolvePratiCaseUser,
} from "../_shared/medasi_core_auth.ts";
import { generateOpenAiContent } from "../_shared/openai_ai.ts";

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

  try {
    await resolvePratiCaseUser(request);
  } catch (error) {
    return authErrorResponse(error, origin, "Oturum doğrulanamadı.");
  }

  const body = await request.json().catch(() => ({})) as JsonMap;
  const summary = sanitizeRecallSummary(body);
  const fallback = fallbackGuidance(summary);

  if (summary.today_total <= 0 && summary.weaknesses.length === 0) {
    return guidanceResponse(fallback, true, origin);
  }

  try {
    const generated = await generateOpenAiContent({
      systemInstruction:
        "Sen PratiCase için kısa, güvenli ve eğitim odaklı Recall çalışma yönlendirmesi yazan bir asistansın. Tıbbi karar, tanı, tedavi veya hasta yönlendirmesi verme. Ham veri, veritabanı, gizli hafıza veya tablo adlarından bahsetme. Yalnız geçerli JSON döndür.",
      contents: [{
        role: "user",
        parts: [{
          text:
            `Aşağıdaki sanitized Recall özetinden PratiCase ana ekranı için kısa yönlendirme üret.\n` +
            `JSON şeması: {"guidance_sentence":"en fazla 150 karakter","study_action":"en fazla 120 karakter"}\n` +
            `Ton: destekleyici, net, klinik pratik/OSCE çalışmasına uygun.\n\n` +
            `${JSON.stringify(summary)}`,
        }],
      }],
      temperature: 0.25,
      maxOutputTokens: 220,
      responseMimeType: "application/json",
    });
    const parsed = parseJson(generated.text);
    return guidanceResponse(sanitizeGuidance(parsed, fallback), false, origin);
  } catch (error) {
    console.error("praticase_recall_guidance_failed", error);
    return guidanceResponse(fallback, true, origin);
  }
});

function guidanceResponse(
  guidance: { guidance_sentence: string; study_action: string },
  fallback: boolean,
  origin: string | null,
) {
  return jsonResponse(
    {
      guidance_sentence: guidance.guidance_sentence,
      study_action: guidance.study_action,
      sentence: guidance.guidance_sentence,
      action: guidance.study_action,
      fallback,
    },
    200,
    origin,
  );
}

function sanitizeRecallSummary(input: JsonMap) {
  const weaknesses = arrayValue(input.weaknesses)
    .slice(0, 5)
    .map((value) => {
      const item = objectValue(value);
      const title = compactText(stringValue(item.title), 90);
      const topic = compactText(stringValue(item.topic), 70);
      const riskLevel = normalizeRisk(stringValue(item.risk_level));
      return {
        title: title || topic || "Genel tekrar",
        topic: topic || title || "Genel",
        risk_level: riskLevel,
      };
    })
    .filter((item) => item.title || item.topic);

  return {
    source: "recall_praticase_summary",
    today_total: clampNumber(input.today_total, 0, 200, 0),
    weaknesses,
  };
}

function sanitizeGuidance(
  input: JsonMap,
  fallback: { guidance_sentence: string; study_action: string },
) {
  return {
    guidance_sentence: compactText(
      stringValue(input.guidance_sentence || input.sentence),
      170,
    ) ||
      fallback.guidance_sentence,
    study_action:
      compactText(stringValue(input.study_action || input.action), 140) ||
      fallback.study_action,
  };
}

function fallbackGuidance(summary: ReturnType<typeof sanitizeRecallSummary>) {
  const topic = summary.weaknesses[0]?.topic || "öncelikli klinik başlık";
  return {
    guidance_sentence:
      `Bugün önce ${topic} için kısa vaka tekrarı yap; ardından bir OSCE denemesiyle pekiştir.`,
    study_action: summary.today_total > 0
      ? `${summary.today_total} Recall tekrarını bitir, sonra tek vaka çöz.`
      : "Kısa klinik tekrar yap, ardından tek vaka çöz.",
  };
}

function parseJson(raw: string): JsonMap {
  const cleaned = raw
    .replace(/^```json\s*/i, "")
    .replace(/^```\s*/i, "")
    .replace(/```$/i, "")
    .trim();
  const parsed = JSON.parse(cleaned);
  return objectValue(parsed);
}

function objectValue(value: unknown): JsonMap {
  if (value && typeof value === "object" && !Array.isArray(value)) {
    return value as JsonMap;
  }
  return {};
}

function arrayValue(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

function stringValue(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function compactText(value: string, maxLength: number) {
  return value.replace(/\s+/g, " ").trim().slice(0, maxLength);
}

function normalizeRisk(value: string) {
  const text = value.toLowerCase();
  if (text === "high" || text === "medium" || text === "low") return text;
  if (text === "urgent" || text === "critical") return "high";
  return "medium";
}

function clampNumber(
  value: unknown,
  min: number,
  max: number,
  fallback: number,
) {
  const parsed = typeof value === "number"
    ? value
    : Number.parseFloat(String(value ?? ""));
  if (!Number.isFinite(parsed)) return fallback;
  return Math.max(min, Math.min(max, Math.round(parsed)));
}
