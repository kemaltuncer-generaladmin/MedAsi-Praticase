type AiRole = "user" | "model";

type AiContent = {
  role: AiRole;
  parts: Array<{ text: string }>;
};

type GenerateContentOptions = {
  model?: string;
  systemInstruction: string;
  contents: AiContent[];
  temperature?: number;
  maxOutputTokens?: number;
  responseMimeType?: "application/json" | "text/plain";
  responseSchema?: JsonMap;
};

type GenerateSpeechOptions = {
  model?: string;
  text: string;
  instructions?: string;
  voiceName?: string;
};

type OpenAiChatMessage = {
  role: "system" | "user" | "assistant";
  content: string;
};

type OpenAiChatResponse = {
  choices?: Array<{
    message?: { content?: string | null };
    finish_reason?: string | null;
  }>;
  usage?: {
    prompt_tokens?: number;
    completion_tokens?: number;
    total_tokens?: number;
    prompt_tokens_details?: { cached_tokens?: number };
    completion_tokens_details?: { reasoning_tokens?: number };
  };
  model?: string;
};

export type JsonMap = Record<string, unknown>;

export type OpenAiGeneration = {
  text: string;
  usageMetadata: JsonMap;
  model: string;
  finishReason?: string;
  finishMessage?: string;
};

export type OpenAiSpeechGeneration = {
  audioBase64: string;
  mimeType: string;
  usageMetadata: JsonMap;
  model: string;
  finishReason?: string;
  finishMessage?: string;
};

export const defaultOpenAiTextModel = "gpt-4o-mini";
export const defaultOpenAiTtsModel = "gpt-4o-mini-tts";

export function historyModel(): string {
  return openAiTextModel();
}

export function evaluationModel(): string {
  return openAiTextModel();
}

export function ttsModel(): string {
  return Deno.env.get("OPENAI_TTS_MODEL")?.trim() || defaultOpenAiTtsModel;
}

export function openAiConfigured(): boolean {
  return Boolean(openAiApiKey(false));
}

export async function generateOpenAiText(
  options: GenerateContentOptions,
): Promise<string> {
  const generated = await generateOpenAiContent(options);
  return generated.text;
}

export async function generateOpenAiContent(
  options: GenerateContentOptions,
): Promise<OpenAiGeneration> {
  const apiKey = openAiApiKey();
  const model = options.model?.trim() || openAiTextModel();
  const messages: OpenAiChatMessage[] = [
    { role: "system", content: options.systemInstruction },
    ...options.contents.map((item) => ({
      role: item.role === "model" ? "assistant" as const : "user" as const,
      content: item.parts.map((part) => part.text).join("\n").trim(),
    })).filter((item) => item.content.length > 0),
  ];
  const body: JsonMap = {
    model,
    messages,
    temperature: options.temperature ?? 0.4,
    max_tokens: options.maxOutputTokens ?? 1024,
    store: false,
  };
  if (options.responseSchema) {
    body.response_format = {
      type: "json_schema",
      json_schema: {
        name: "praticase_response",
        strict: false,
        schema: normalizeJsonSchema(options.responseSchema),
      },
    };
  } else if (options.responseMimeType === "application/json") {
    body.response_format = { type: "json_object" };
  }

  const payload = await postOpenAiChat(apiKey, body, options);
  const choice = payload.choices?.[0];
  const text = choice?.message?.content?.trim() ?? "";
  if (!text) {
    throw new Error("OpenAI returned an empty response");
  }

  const usage = payload.usage ?? {};
  return {
    text,
    usageMetadata: {
      provider: "openai",
      raw_usage: usage,
      promptTokenCount: usage.prompt_tokens ?? 0,
      candidatesTokenCount: usage.completion_tokens ?? 0,
      totalTokenCount: usage.total_tokens ?? 0,
      cachedContentTokenCount: usage.prompt_tokens_details?.cached_tokens ?? 0,
      thoughtsTokenCount: usage.completion_tokens_details?.reasoning_tokens ??
        0,
    },
    model: payload.model?.trim() || model,
    finishReason: openAiFinishReason(choice?.finish_reason),
  };
}

export async function generateOpenAiSpeech(
  options: GenerateSpeechOptions,
): Promise<OpenAiSpeechGeneration> {
  const apiKey = openAiApiKey();
  const model = options.model?.trim() || ttsModel();
  const response = await fetch("https://api.openai.com/v1/audio/speech", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      input: options.text,
      voice: openAiVoiceName(options.voiceName),
      instructions: options.instructions?.trim() ||
        "Türkçe, doğal, net ve klinik sınav bağlamına uygun konuş.",
      response_format: "mp3",
      speed: 1,
    }),
  });

  if (!response.ok) {
    const errorBody = await response.text();
    throw new Error(
      `OpenAI speech request failed with ${response.status}: ${
        errorBody.slice(0, 500)
      }`,
    );
  }

  const audioBytes = new Uint8Array(await response.arrayBuffer());
  return {
    audioBase64: bytesToBase64(audioBytes),
    mimeType: response.headers.get("content-type")?.split(";")[0]?.trim() ||
      "audio/mpeg",
    usageMetadata: { provider: "openai", totalTokenCount: 1 },
    model,
  };
}

function openAiTextModel(): string {
  return Deno.env.get("OPENAI_MODEL")?.trim() || defaultOpenAiTextModel;
}

function openAiApiKey(required = true): string {
  const key = Deno.env.get("OPENAI_API_KEY")?.trim() || "";
  if (!key && required) {
    throw new Error("OpenAI API key is missing");
  }
  return key;
}

async function postOpenAiChat(
  apiKey: string,
  body: JsonMap,
  options: GenerateContentOptions,
): Promise<OpenAiChatResponse> {
  const response = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
  if (response.ok) return await response.json() as OpenAiChatResponse;

  const errorBody = await response.text();
  const canRetryJsonMode = Boolean(options.responseSchema) &&
    options.responseMimeType === "application/json" &&
    /response_format|json_schema|schema/i.test(errorBody);
  if (canRetryJsonMode) {
    const retryBody = { ...body, response_format: { type: "json_object" } };
    const retry = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(retryBody),
    });
    if (retry.ok) return await retry.json() as OpenAiChatResponse;
    const retryErrorBody = await retry.text();
    throw new Error(
      `OpenAI request failed with ${retry.status}: ${
        retryErrorBody.slice(0, 500)
      }`,
    );
  }

  throw new Error(
    `OpenAI request failed with ${response.status}: ${errorBody.slice(0, 500)}`,
  );
}

function normalizeJsonSchema(value: unknown): unknown {
  if (Array.isArray(value)) {
    return value.map((item) => normalizeJsonSchema(item));
  }
  if (!value || typeof value !== "object") return value;

  const output: JsonMap = {};
  for (const [key, raw] of Object.entries(value as JsonMap)) {
    if (key === "type" && typeof raw === "string") {
      output.type = normalizeJsonSchemaType(raw);
      continue;
    }
    output[key] = normalizeJsonSchema(raw);
  }
  return output;
}

function normalizeJsonSchemaType(type: string): string {
  switch (type.trim().toUpperCase()) {
    case "OBJECT":
      return "object";
    case "ARRAY":
      return "array";
    case "STRING":
      return "string";
    case "NUMBER":
      return "number";
    case "INTEGER":
      return "integer";
    case "BOOLEAN":
      return "boolean";
    case "NULL":
      return "null";
    default:
      return type.trim().toLowerCase();
  }
}

function openAiFinishReason(reason: string | null | undefined): string {
  switch (reason) {
    case "length":
      return "MAX_TOKENS";
    case "content_filter":
      return "SAFETY";
    case "stop":
      return "STOP";
    default:
      return reason?.toUpperCase() ?? "";
  }
}

function openAiVoiceName(requested: string | undefined): string {
  const configured = Deno.env.get("OPENAI_TTS_VOICE")?.trim();
  if (configured) return configured;
  const normalized = (requested ?? "").trim().toLowerCase();
  const builtInVoices = new Set([
    "alloy",
    "ash",
    "ballad",
    "cedar",
    "coral",
    "echo",
    "fable",
    "marin",
    "nova",
    "onyx",
    "sage",
    "shimmer",
    "verse",
  ]);
  if (builtInVoices.has(normalized)) return normalized;
  switch ((requested ?? "").trim()) {
    case "Charon":
      return "onyx";
    case "Achird":
    default:
      return "alloy";
  }
}

function bytesToBase64(bytes: Uint8Array): string {
  let binary = "";
  const chunkSize = 0x8000;
  for (let i = 0; i < bytes.length; i += chunkSize) {
    binary += String.fromCharCode(...bytes.slice(i, i + chunkSize));
  }
  return btoa(binary);
}
