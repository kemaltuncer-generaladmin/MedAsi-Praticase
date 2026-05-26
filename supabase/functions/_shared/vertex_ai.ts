type VertexRole = "user" | "model";

type VertexContent = {
  role: VertexRole;
  parts: Array<{ text: string }>;
};

type GenerateContentOptions = {
  model?: string;
  location?: string;
  systemInstruction: string;
  contents: VertexContent[];
  temperature?: number;
  maxOutputTokens?: number;
  responseMimeType?: "application/json" | "text/plain";
  responseSchema?: JsonMap;
};

type GenerateSpeechOptions = {
  model?: string;
  location?: string;
  text: string;
  languageCode?: string;
  voiceName?: string;
  temperature?: number;
};

type ServiceAccount = {
  client_email: string;
  private_key: string;
  project_id?: string;
  token_uri?: string;
};

type VertexCandidate = {
  content?: { parts?: Array<{ text?: string }> };
  finishReason?: string;
  finishMessage?: string;
};

type VertexSpeechPart = {
  inlineData?: { data?: string; mimeType?: string };
  inline_data?: { data?: string; mime_type?: string };
  text?: string;
};

type VertexSpeechCandidate = {
  content?: { parts?: VertexSpeechPart[] };
  finishReason?: string;
  finishMessage?: string;
};

export type JsonMap = Record<string, unknown>;

export type VertexGeneration = {
  text: string;
  usageMetadata: JsonMap;
  model: string;
  finishReason?: string;
  finishMessage?: string;
};

export type VertexSpeechGeneration = {
  audioBase64: string;
  mimeType: string;
  usageMetadata: JsonMap;
  model: string;
  finishReason?: string;
  finishMessage?: string;
};

type VertexResponse = {
  candidates?: VertexCandidate[];
  usageMetadata?: JsonMap;
};

type VertexSpeechResponse = {
  candidates?: VertexSpeechCandidate[];
  usageMetadata?: JsonMap;
  usage_metadata?: JsonMap;
};

const accessTokenCache = {
  token: "",
  expiresAt: 0,
};

export const defaultHistoryModel = "gemini-2.5-flash";
export const defaultEvaluationModel = "gemini-3.5-flash";
export const defaultTtsModel = "gemini-2.5-flash-tts";

export function historyModel(): string {
  return Deno.env.get("VERTEX_AI_HISTORY_MODEL")?.trim() || defaultHistoryModel;
}

export function evaluationModel(): string {
  return Deno.env.get("VERTEX_AI_EVALUATION_MODEL")?.trim() ||
    defaultEvaluationModel;
}

export function ttsModel(): string {
  return Deno.env.get("VERTEX_AI_TTS_MODEL")?.trim() || defaultTtsModel;
}

export async function generateVertexText(
  options: GenerateContentOptions,
): Promise<string> {
  const generated = await generateVertexContent(options);
  return generated.text;
}

export async function generateVertexSpeech(
  options: GenerateSpeechOptions,
): Promise<VertexSpeechGeneration> {
  const account = serviceAccount();
  const projectId = Deno.env.get("VERTEX_AI_PROJECT_ID")?.trim() ||
    account.project_id?.trim();
  if (!projectId) {
    throw new Error("Vertex AI project id is missing");
  }

  const location = options.location ||
    Deno.env.get("VERTEX_AI_TTS_LOCATION")?.trim() ||
    Deno.env.get("VERTEX_AI_LOCATION")?.trim() ||
    "global";
  const model = options.model?.trim() || ttsModel();
  const token = await accessToken(account);
  const endpoint =
    `https://aiplatform.googleapis.com/v1beta1/projects/${projectId}/locations/${location}/publishers/google/models/${model}:generateContent`;

  const response = await fetch(endpoint, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      contents: [
        {
          role: "user",
          parts: [{ text: options.text }],
        },
      ],
      generation_config: {
        speech_config: {
          language_code: options.languageCode?.trim() || "tr-TR",
          voice_config: {
            prebuilt_voice_config: {
              voice_name: options.voiceName?.trim() || "Achird",
            },
          },
        },
        temperature: options.temperature ?? 1.2,
      },
    }),
  });

  if (!response.ok) {
    await response.body?.cancel();
    throw new Error(`Vertex AI speech request failed with ${response.status}`);
  }

  const payload = await response.json() as VertexSpeechResponse;
  const candidate = payload.candidates?.[0];
  const part = candidate?.content?.parts?.find((item) =>
    item.inlineData?.data || item.inline_data?.data
  );
  const inline = part?.inlineData ?? part?.inline_data;
  const audioBase64 = inline?.data?.trim() ?? "";
  if (!audioBase64) {
    throw new Error("Vertex AI speech returned an empty audio response");
  }

  return {
    audioBase64,
    mimeType: part?.inlineData?.mimeType ?? part?.inline_data?.mime_type ??
      "audio/pcm",
    usageMetadata: payload.usageMetadata ?? payload.usage_metadata ?? {},
    model,
    finishReason: candidate?.finishReason,
    finishMessage: candidate?.finishMessage,
  };
}

export async function generateVertexContent(
  options: GenerateContentOptions,
): Promise<VertexGeneration> {
  const account = serviceAccount();
  const projectId = Deno.env.get("VERTEX_AI_PROJECT_ID")?.trim() ||
    account.project_id?.trim();
  if (!projectId) {
    throw new Error("Vertex AI project id is missing");
  }

  const location = options.location ||
    Deno.env.get("VERTEX_AI_LOCATION")?.trim() || "global";
  const model = options.model?.trim() || historyModel();
  const token = await accessToken(account);
  const endpoint =
    `https://aiplatform.googleapis.com/v1/projects/${projectId}/locations/${location}/publishers/google/models/${model}:generateContent`;

  const response = await fetch(endpoint, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      systemInstruction: {
        parts: [{ text: options.systemInstruction }],
      },
      contents: options.contents,
      generationConfig: {
        temperature: options.temperature ?? 0.4,
        topP: 0.95,
        maxOutputTokens: options.maxOutputTokens ?? 1024,
        ...(options.responseMimeType
          ? { responseMimeType: options.responseMimeType }
          : {}),
        ...(options.responseSchema
          ? { responseSchema: options.responseSchema }
          : {}),
      },
    }),
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(
      `Vertex AI request failed with ${response.status}: ${body.slice(0, 500)}`,
    );
  }

  const payload = await response.json() as VertexResponse;
  const candidate = payload.candidates?.[0];
  const text = candidate?.content?.parts
    ?.map((part) => part.text ?? "")
    .join("")
    .trim();
  if (!text) {
    throw new Error("Vertex AI returned an empty response");
  }
  return {
    text,
    usageMetadata: payload.usageMetadata ?? {},
    model,
    finishReason: candidate?.finishReason,
    finishMessage: candidate?.finishMessage,
  };
}

export function vertexConfigured(): boolean {
  return Boolean(
    Deno.env.get("GOOGLE_VERTEX_SERVICE_ACCOUNT_JSON")?.trim() ||
      Deno.env.get("GOOGLE_VERTEX_SERVICE_ACCOUNT_JSON_BASE64")?.trim() ||
      Deno.env.get("VERTEX_AI_SERVICE_ACCOUNT_JSON")?.trim() ||
      Deno.env.get("VERTEX_AI_SERVICE_ACCOUNT_JSON_BASE64")?.trim() ||
      Deno.env.get("GOOGLE_SERVICE_ACCOUNT_JSON")?.trim() ||
      Deno.env.get("GOOGLE_SERVICE_ACCOUNT_JSON_BASE64")?.trim() ||
      Deno.env.get("VERTEX_SERVICE_ACCOUNT_JSON")?.trim(),
  );
}

function serviceAccount(): ServiceAccount {
  const raw = Deno.env.get("GOOGLE_VERTEX_SERVICE_ACCOUNT_JSON")?.trim() ||
    Deno.env.get("VERTEX_AI_SERVICE_ACCOUNT_JSON")?.trim() ||
    Deno.env.get("GOOGLE_SERVICE_ACCOUNT_JSON")?.trim() ||
    Deno.env.get("VERTEX_SERVICE_ACCOUNT_JSON")?.trim();
  const encoded =
    Deno.env.get("GOOGLE_VERTEX_SERVICE_ACCOUNT_JSON_BASE64")?.trim() ||
    Deno.env.get("VERTEX_AI_SERVICE_ACCOUNT_JSON_BASE64")?.trim() ||
    Deno.env.get("GOOGLE_SERVICE_ACCOUNT_JSON_BASE64")?.trim();
  const json = raw || (encoded ? atob(encoded) : "");
  if (!json) {
    throw new Error("Vertex AI service account secret is missing");
  }

  const parsed = JSON.parse(json) as ServiceAccount;
  if (!parsed.client_email || !parsed.private_key) {
    throw new Error("Vertex AI service account secret is invalid");
  }
  return parsed;
}

async function accessToken(account: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (accessTokenCache.token && accessTokenCache.expiresAt - 60 > now) {
    return accessTokenCache.token;
  }

  const assertion = await signedJwt(account, now);
  const response = await fetch(
    account.token_uri || "https://oauth2.googleapis.com/token",
    {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion,
      }),
    },
  );

  if (!response.ok) {
    throw new Error(
      `Google OAuth token request failed with ${response.status}`,
    );
  }

  const payload = await response.json() as {
    access_token?: string;
    expires_in?: number;
  };
  if (!payload.access_token) {
    throw new Error("Google OAuth token response did not include a token");
  }
  accessTokenCache.token = payload.access_token;
  accessTokenCache.expiresAt = now + (payload.expires_in ?? 3600);
  return accessTokenCache.token;
}

async function signedJwt(
  account: ServiceAccount,
  now: number,
): Promise<string> {
  const header = base64UrlJson({ alg: "RS256", typ: "JWT" });
  const claim = base64UrlJson({
    iss: account.client_email,
    scope: "https://www.googleapis.com/auth/cloud-platform",
    aud: account.token_uri || "https://oauth2.googleapis.com/token",
    exp: now + 3600,
    iat: now,
  });
  const unsigned = `${header}.${claim}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(account.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );
  return `${unsigned}.${base64UrlBytes(new Uint8Array(signature))}`;
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const base64 = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");
  return Uint8Array.from(atob(base64), (char) => char.charCodeAt(0)).buffer;
}

function base64UrlJson(value: Record<string, unknown>): string {
  return base64UrlBytes(new TextEncoder().encode(JSON.stringify(value)));
}

function base64UrlBytes(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}
