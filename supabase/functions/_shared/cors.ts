const defaultAllowedOrigins = [
  "https://praticase.medasi.com.tr",
  "https://www.praticase.medasi.com.tr",
  "http://localhost:3000",
  "http://127.0.0.1:3000",
  "http://localhost:8080",
  "http://127.0.0.1:8080",
  "http://localhost:8081",
  "http://127.0.0.1:8081",
];

const allowedOrigins = new Set(
  (Deno.env.get("PRATICASE_ALLOWED_ORIGINS")?.split(",") ??
    defaultAllowedOrigins)
    .map((origin) => origin.trim())
    .filter((origin) => origin.length > 0),
);

export function isAllowedOrigin(origin: string | null): boolean {
  if (!origin) return true;
  const normalizedOrigin = origin.trim();
  return allowedOrigins.has(normalizedOrigin) ||
    isLocalDevelopmentOrigin(normalizedOrigin);
}

export function corsHeaders(origin: string | null = null): HeadersInit {
  const normalizedOrigin = origin?.trim() ?? "";
  const allowOrigin = allowedOrigins.has(normalizedOrigin) ||
      isLocalDevelopmentOrigin(normalizedOrigin)
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

export function jsonResponse(
  body: Record<string, unknown>,
  status = 200,
  origin: string | null = null,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders(origin),
      "Content-Type": "application/json",
    },
  });
}

function isLocalDevelopmentOrigin(origin: string): boolean {
  try {
    const url = new URL(origin);
    return url.protocol === "http:" &&
      (url.hostname === "localhost" || url.hostname === "127.0.0.1" ||
        url.hostname === "[::1]" || url.hostname === "::1");
  } catch (_) {
    return false;
  }
}
