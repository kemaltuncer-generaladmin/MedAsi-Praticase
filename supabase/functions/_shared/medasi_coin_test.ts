import {
  aiCreditCostFromUsage,
  chargeAiCoins,
  ensureAiCoinBalance,
  InsufficientCoinBalanceError,
  loadEffectiveWalletProfile,
  openAiCostFromUsage,
  recordAiUsage,
} from "./medasi_coin.ts";

const ADMIN = {} as unknown; // truthy placeholder; charging now goes through Core
const USAGE = { promptTokenCount: 120, candidatesTokenCount: 40, totalTokenCount: 160 };

// --- Cost calculation (pure, unchanged) ---------------------------------------

Deno.test("aiCreditCostFromUsage applies Qlinik minimum coin cost", () => {
  const cost = aiCreditCostFromUsage({
    promptTokenCount: 120,
    candidatesTokenCount: 40,
    totalTokenCount: 160,
  });
  if (cost !== 0.1) throw new Error(`Expected 0.1 coin minimum, got ${cost}`);
});

Deno.test("openAiCostFromUsage applies gpt-4o-mini token prices", () => {
  const cost = openAiCostFromUsage({
    provider: "openai",
    promptTokenCount: 1000000,
    cachedContentTokenCount: 500000,
    candidatesTokenCount: 1000000,
    totalTokenCount: 2000000,
  }, "gpt-4o-mini");
  if (cost.inputCostUsd !== 0.1125) throw new Error(`Expected $0.1125 input cost, got ${cost.inputCostUsd}`);
  if (cost.outputCostUsd !== 0.6) throw new Error(`Expected $0.60 output cost, got ${cost.outputCostUsd}`);
});

Deno.test("aiCreditCostFromUsage prices OpenAI gpt-4o-mini evaluations", () => {
  const cost = aiCreditCostFromUsage({
    provider: "openai",
    promptTokenCount: 1000000,
    candidatesTokenCount: 0,
    totalTokenCount: 1000000,
  }, "gpt-4o-mini");
  if (cost !== 30.6113) throw new Error(`Expected 30.6113 coins, got ${cost}`);
});

// --- Wallet charging now served by MedAsi Core --------------------------------

Deno.test("chargeAiCoins calls Core and maps the result", async () => {
  const calls: Array<{ url: string; body: Record<string, unknown> }> = [];
  await withCore(async (url, init) => {
    calls.push({ url: url.toString(), body: JSON.parse((init?.body as string) || "{}") });
    return jsonResponse({ ok: true, chargedCoinAmount: 0.1, walletBalance: 4.9 });
  }, async () => {
    const result = await chargeAiCoins({
      admin: ADMIN,
      userId: "user-1",
      feature: "praticase-patient-turn",
      model: "gpt-4o-mini",
      usageMetadata: USAGE,
      attribution: { exam_kind: "osce" },
    });
    assertEquals(result.chargedCoinAmount, 0.1);
    assertEquals(result.walletBalance, 4.9);
    const call = calls.find((c) => c.url.endsWith("/v1/wallet/charge-ai"));
    assertEquals(call?.body.feature, "praticase-patient-turn");
    assertEquals((call?.body.attribution as Record<string, unknown>)?.exam_kind, "osce");
  });
});

Deno.test("chargeAiCoins surfaces Core insufficient balance", async () => {
  await withCore(
    () => Promise.resolve(jsonResponse({
      error: { code: "INSUFFICIENT_MC", details: { walletBalance: 0.04, requiredBalance: 0.1, aiQuota: 0 } },
    }, 402)),
    async () => {
      try {
        await chargeAiCoins({ admin: ADMIN, userId: "user-1", feature: "f", model: "gpt-4o-mini", usageMetadata: USAGE });
      } catch (error) {
        if (error instanceof InsufficientCoinBalanceError) return;
        throw error;
      }
      throw new Error("Expected InsufficientCoinBalanceError");
    },
  );
});

Deno.test("chargeAiCoins no-charge fallback without admin", async () => {
  const result = await chargeAiCoins({
    admin: null,
    userId: "user-1",
    feature: "praticase-complete-session",
    model: "gpt-4o-mini",
    usageMetadata: USAGE,
  });
  if (result.chargedCoinAmount !== 0 || result.walletBalance !== null) {
    throw new Error("Expected no-charge fallback");
  }
});

Deno.test("ensureAiCoinBalance rejects when Core reports insufficient", async () => {
  await withCore(
    () => Promise.resolve(jsonResponse({ error: { code: "INSUFFICIENT_MC", details: {} } }, 402)),
    async () => {
      try {
        await ensureAiCoinBalance(ADMIN, "user-1");
      } catch (error) {
        if (error instanceof InsufficientCoinBalanceError) return;
        throw error;
      }
      throw new Error("Expected insufficient balance error");
    },
  );
});

Deno.test("recordAiUsage posts an uncharged usage event to Core", async () => {
  const calls: string[] = [];
  await withCore(async (url) => {
    calls.push(url.toString());
    return jsonResponse({ ok: true });
  }, async () => {
    await recordAiUsage({
      admin: ADMIN,
      userId: "user-1",
      feature: "praticase-speech",
      model: "gpt-4o-mini-tts",
      usageMetadata: { promptTokenCount: 120 },
      attribution: { operation: "text_to_speech" },
    });
    if (!calls.some((u) => u.endsWith("/v1/wallet/record-usage"))) {
      throw new Error("Expected record-usage Core call");
    }
  });
});

Deno.test("loadEffectiveWalletProfile maps the Core profile", async () => {
  await withCore(
    () => Promise.resolve(jsonResponse({ ok: true, wallet_balance: 42.5, question_quota: 3, ai_quota: 1 })),
    async () => {
      const profile = await loadEffectiveWalletProfile(ADMIN, "user-1");
      assertEquals(profile.wallet_balance, 42.5);
    },
  );
});

async function withCore(fetchImpl: typeof fetch, run: () => Promise<void>) {
  const prevUrl = Deno.env.get("MEDASI_CORE_URL");
  const prevKey = Deno.env.get("MEDASI_CORE_KEY");
  Deno.env.set("MEDASI_CORE_URL", "https://core.medasi.test");
  Deno.env.set("MEDASI_CORE_KEY", "internal-key");
  const originalFetch = globalThis.fetch;
  globalThis.fetch = fetchImpl;
  try {
    await run();
  } finally {
    globalThis.fetch = originalFetch;
    if (prevUrl === undefined) Deno.env.delete("MEDASI_CORE_URL");
    else Deno.env.set("MEDASI_CORE_URL", prevUrl);
    if (prevKey === undefined) Deno.env.delete("MEDASI_CORE_KEY");
    else Deno.env.set("MEDASI_CORE_KEY", prevKey);
  }
}

function jsonResponse(value: unknown, status = 200) {
  return new Response(JSON.stringify(value), {
    status,
    headers: { "content-type": "application/json" },
  });
}

function assertEquals(actual: unknown, expected: unknown) {
  if (actual !== expected) {
    throw new Error(`Expected ${String(expected)}, got ${String(actual)}`);
  }
}
