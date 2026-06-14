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

  const response = await fetch(`${coreUrl}/v1/auth/resolve`, {
    method: "POST",
    headers: {
      authorization,
      "content-type": "application/json",
      "x-medasi-app": app,
      ...(coreKey ? { "x-medasi-core-key": coreKey } : {}),
    },
    body: JSON.stringify({ app }),
  });

  if (!response.ok) {
    throw new MedAsiCoreAuthError(
      "CORE_AUTH_REJECTED",
      "Oturum doğrulanamadı.",
      response.status,
    );
  }

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

function withoutTrailingSlash(value: string): string {
  return value.trim().replace(/\/+$/, "");
}
