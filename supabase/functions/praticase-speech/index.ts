import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.4";
import { corsHeaders, isAllowedOrigin, jsonResponse } from "../_shared/cors.ts";
import {
  generateVertexSpeech,
  ttsModel,
  vertexConfigured,
} from "../_shared/vertex_ai.ts";

type VoiceRole = "patient" | "mentor";

const allowedVoices = new Set([
  "Achernar",
  "Achird",
  "Algenib",
  "Algieba",
  "Alnilam",
  "Aoede",
  "Autonoe",
  "Callirrhoe",
  "Charon",
  "Despina",
  "Enceladus",
  "Erinome",
  "Fenrir",
  "Gacrux",
  "Iapetus",
  "Kore",
  "Laomedeia",
  "Leda",
  "Orus",
  "Pulcherrima",
  "Puck",
  "Rasalgethi",
  "Sadachbia",
  "Sadaltager",
  "Schedar",
  "Sulafat",
  "Umbriel",
  "Vindemiatrix",
  "Zephyr",
  "Zubenelgenubi",
]);

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
  const authorization = request.headers.get("Authorization");

  if (!supabaseUrl || !supabaseAnonKey || !authorization) {
    return jsonResponse(
      { error: "Ses motoru şu anda başlatılamadı. Lütfen tekrar dene." },
      500,
      origin,
    );
  }

  const body = await request.json().catch(() => ({}));
  const text = normalizeSpeechText(String(body.text ?? ""));
  const role = voiceRole(String(body.voiceRole ?? body.voice_role ?? ""));

  if (!text) {
    return jsonResponse(
      { error: "Seslendirmek için hasta yanıtı bulunamadı." },
      400,
      origin,
    );
  }
  if (new TextEncoder().encode(text).length > 1800) {
    return jsonResponse(
      {
        error: "Seslendirilecek yanıt çok uzun. Daha kısa yanıtla tekrar dene.",
      },
      413,
      origin,
    );
  }

  const supabase = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authorization } },
  });
  const { data: userResult, error: userError } = await supabase.auth.getUser();
  if (userError || !userResult.user) {
    return jsonResponse(
      { error: "Sesli sınav için oturum doğrulanamadı." },
      401,
      origin,
    );
  }

  if (!vertexConfigured()) {
    return jsonResponse(
      { error: "Gemini ses motoru şu anda yapılandırılmamış." },
      503,
      origin,
    );
  }

  try {
    const voiceName = voiceNameFor(role, String(body.voiceName ?? ""));
    const generated = await generateVertexSpeech({
      model: ttsModel(),
      text: buildSpeechPrompt({ role, text }),
      languageCode: "tr-TR",
      voiceName,
      temperature: role === "mentor" ? 1.0 : 1.25,
    });
    return jsonResponse(
      {
        audioContent: wavBase64FromPcmBase64(generated.audioBase64),
        mimeType: "audio/wav",
        engine: generated.model,
        voiceName,
      },
      200,
      origin,
    );
  } catch (error) {
    console.error("praticase_speech_failed", errorMessage(error));
    return jsonResponse(
      { error: "Gemini ses üretimi şu anda alınamadı." },
      502,
      origin,
    );
  }
});

function buildSpeechPrompt(options: { role: VoiceRole; text: string }): string {
  const style = options.role === "mentor"
    ? "Style: Read only SPEECH_TEXT in Turkish as a calm OSCE examiner. Use clear diction, measured pace, and a professional but human tone."
    : "Style: Read only SPEECH_TEXT in Turkish as a real patient. Sound natural, short-breathed, mildly concerned, and conversational. Do not sound like a teacher or narrator.";
  return [
    "You are a Turkish text-to-speech voice director.",
    "Do not read these instructions aloud.",
    style,
    "Preserve the meaning exactly; do not add medical advice or extra words.",
    "SPEECH_TEXT:",
    options.text,
  ].join("\n");
}

function normalizeSpeechText(raw: string): string {
  return raw
    .replace(/\s+/g, " ")
    .replace(/\bUSG\b/gi, "ultrason")
    .replace(/\bBT\b/g, "bilgisayarlı tomografi")
    .replace(/\bKVA\b/gi, "böğür")
    .replace(/\bCRP\b/g, "C R P")
    .replace(/\bHb\b/g, "hemoglobin")
    .replace(/\bWBC\b/g, "lökosit")
    .trim();
}

function voiceRole(value: string): VoiceRole {
  return value.trim().toLowerCase() === "mentor" ? "mentor" : "patient";
}

function voiceNameFor(role: VoiceRole, requested: string): string {
  const normalized = requested.trim();
  if (allowedVoices.has(normalized)) return normalized;
  return role === "mentor" ? "Charon" : "Achird";
}

function wavBase64FromPcmBase64(
  pcmBase64: string,
  sampleRate = 24000,
  channels = 1,
  bitsPerSample = 16,
): string {
  const pcm = base64ToBytes(pcmBase64);
  const header = new Uint8Array(44);
  writeString(header, 0, "RIFF");
  writeUint32(header, 4, 36 + pcm.length);
  writeString(header, 8, "WAVE");
  writeString(header, 12, "fmt ");
  writeUint32(header, 16, 16);
  writeUint16(header, 20, 1);
  writeUint16(header, 22, channels);
  writeUint32(header, 24, sampleRate);
  writeUint32(header, 28, sampleRate * channels * (bitsPerSample / 8));
  writeUint16(header, 32, channels * (bitsPerSample / 8));
  writeUint16(header, 34, bitsPerSample);
  writeString(header, 36, "data");
  writeUint32(header, 40, pcm.length);

  const wav = new Uint8Array(header.length + pcm.length);
  wav.set(header, 0);
  wav.set(pcm, header.length);
  return bytesToBase64(wav);
}

function writeString(bytes: Uint8Array, offset: number, value: string): void {
  for (let i = 0; i < value.length; i++) {
    bytes[offset + i] = value.charCodeAt(i);
  }
}

function writeUint16(bytes: Uint8Array, offset: number, value: number): void {
  bytes[offset] = value & 0xff;
  bytes[offset + 1] = (value >> 8) & 0xff;
}

function writeUint32(bytes: Uint8Array, offset: number, value: number): void {
  bytes[offset] = value & 0xff;
  bytes[offset + 1] = (value >> 8) & 0xff;
  bytes[offset + 2] = (value >> 16) & 0xff;
  bytes[offset + 3] = (value >> 24) & 0xff;
}

function base64ToBytes(value: string): Uint8Array {
  return Uint8Array.from(atob(value), (char) => char.charCodeAt(0));
}

function bytesToBase64(bytes: Uint8Array): string {
  const chunks: string[] = [];
  const chunkSize = 0x8000;
  for (let i = 0; i < bytes.length; i += chunkSize) {
    const chunk = bytes.subarray(i, i + chunkSize);
    let binary = "";
    for (const byte of chunk) binary += String.fromCharCode(byte);
    chunks.push(binary);
  }
  return btoa(chunks.join(""));
}

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}
