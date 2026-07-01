import { jsonResponse } from "./cors.ts";

export type MedAsiCoreUser = {
  id: string;
  email?: string | null;
  phone?: string | null;
  userMetadata?: Record<string, unknown>;
  appMetadata?: Record<string, unknown>;
};

export class MedAsiCoreAuthError extends Error {
  constructor(
    public code: string,
    message: string,
    public status = 401,
  ) {
    super(message);
    this.name = "MedAsiCoreAuthError";
  }
}

export async function resolvePratiCaseUser(
  request: Request,
): Promise<MedAsiCoreUser> {
  return resolveMedAsiCoreUser(request, "praticase");
}

export function authErrorResponse(
  error: unknown,
  origin: string | null,
  message = "Oturum doğrulanamadı. Lütfen tekrar giriş yap.",
): Response {
  if (error instanceof MedAsiCoreAuthError) {
    return jsonResponse(
      {
        error: error.status >= 500
          ? "MedAsi Core auth yapılandırılmamış."
          : message,
      },
      error.status,
      origin,
    );
  }
  throw error;
}

async function resolveMedAsiCoreUser(
  request: Request,
  app: string,
): Promise<MedAsiCoreUser> {
  const authorization = request.headers.get("authorization") ||
    request.headers.get("Authorization") ||
    "";
  if (!authorization.match(/^Bearer\s+\S+/i)) {
    throw new MedAsiCoreAuthError("AUTH_TOKEN_MISSING", "Oturum gerekli.", 401);
  }

  const coreUrl = withoutTrailingSlash(Deno.env.get("MEDASI_CORE_URL") || "");
  const coreKey = Deno.env.get("MEDASI_CORE_KEY") || "";
  if (!coreUrl) {
    throw new MedAsiCoreAuthError(
      "CORE_AUTH_NOT_CONFIGURED",
      "MedAsi Core auth yapılandırılmamış.",
      500,
    );
  }

  // Fail-closed ama geçici hatalara dayanıklı: 401/403 kesin rettir (retry yok),
  // timeout / network / 5xx / 429 geçici kabul edilir ve tekrar denenir.
  const timeoutMs = 8000;
  const maxRetries = 2;
  let lastError: MedAsiCoreAuthError | null = null;

  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    if (attempt > 0) {
      await new Promise((r) => setTimeout(r, attempt * 500));
    }

    let response: Response;
    try {
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), timeoutMs);
      response = await fetch(`${coreUrl}/v1/auth/resolve`, {
        method: "POST",
        headers: {
          authorization,
          "content-type": "application/json",
          "x-medasi-app": app,
          ...(coreKey ? { "x-medasi-core-key": coreKey } : {}),
        },
        body: JSON.stringify({ app }),
        signal: controller.signal,
      });
      clearTimeout(timer);
    } catch (_error) {
      lastError = new MedAsiCoreAuthError(
        "CORE_AUTH_NETWORK_ERROR",
        "MedAsi Core bağlantı hatası.",
        502,
      );
      continue;
    }

    if (response.ok) {
      const payload = await response.json().catch(() => null);
      if (!payload?.user?.id) {
        throw new MedAsiCoreAuthError(
          "CORE_AUTH_INVALID_RESPONSE",
          "Oturum doğrulanamadı.",
          401,
        );
      }
      return payload.user as MedAsiCoreUser;
    }

    if (response.status === 401 || response.status === 403) {
      throw new MedAsiCoreAuthError(
        "CORE_AUTH_REJECTED",
        "Oturum doğrulanamadı.",
        response.status,
      );
    }

    const retryable = response.status >= 500 || response.status === 429;
    lastError = new MedAsiCoreAuthError(
      "CORE_AUTH_REJECTED",
      "Oturum doğrulanamadı.",
      response.status,
    );
    if (!retryable) throw lastError;
  }

  throw lastError ?? new MedAsiCoreAuthError(
    "CORE_AUTH_REJECTED",
    "MedAsi Core auth geçici olarak kullanılamıyor.",
    502,
  );
}

function withoutTrailingSlash(value: string): string {
  return value.trim().replace(/\/+$/, "");
}
