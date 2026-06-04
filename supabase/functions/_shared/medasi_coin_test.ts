import {
  aiCreditCostFromUsage,
  chargeAiCoins,
  ensureAiCoinBalance,
  InsufficientCoinBalanceError,
  loadEffectiveWalletProfile,
  openAiCostFromUsage,
  recordAiUsage,
} from "./medasi_coin.ts";

Deno.test("aiCreditCostFromUsage applies Qlinik minimum coin cost", () => {
  const cost = aiCreditCostFromUsage({
    promptTokenCount: 120,
    candidatesTokenCount: 40,
    totalTokenCount: 160,
  });
  if (cost !== 0.1) {
    throw new Error(`Expected 0.1 coin minimum, got ${cost}`);
  }
});

Deno.test("openAiCostFromUsage applies gpt-4o-mini token prices", () => {
  const cost = openAiCostFromUsage({
    provider: "openai",
    promptTokenCount: 1000000,
    cachedContentTokenCount: 500000,
    candidatesTokenCount: 1000000,
    totalTokenCount: 2000000,
  }, "gpt-4o-mini");
  if (cost.inputCostUsd !== 0.1125) {
    throw new Error(`Expected $0.1125 input cost, got ${cost.inputCostUsd}`);
  }
  if (cost.outputCostUsd !== 0.6) {
    throw new Error(`Expected $0.60 output cost, got ${cost.outputCostUsd}`);
  }
});

Deno.test("aiCreditCostFromUsage prices OpenAI gpt-4o-mini evaluations", () => {
  const cost = aiCreditCostFromUsage({
    provider: "openai",
    promptTokenCount: 1000000,
    candidatesTokenCount: 0,
    totalTokenCount: 1000000,
  }, "gpt-4o-mini");
  if (cost !== 30.6113) {
    throw new Error(`Expected 30.6113 coins, got ${cost}`);
  }
});

Deno.test("ensureAiCoinBalance rejects insufficient wallet balance", async () => {
  const admin = fakeAdmin({ walletBalance: 0.04 });
  try {
    await ensureAiCoinBalance(admin, "user-1");
  } catch (error) {
    if (error instanceof InsufficientCoinBalanceError) return;
    throw error;
  }
  throw new Error("Expected insufficient balance error");
});

Deno.test("ensureAiCoinBalance accepts dedicated AI quota", async () => {
  const admin = fakeAdmin({ walletBalance: 0, aiQuota: 1 });
  await ensureAiCoinBalance(admin, "user-1");
});

Deno.test("wallet snapshot prefers synchronized entitlement totals", async () => {
  const admin = fakeAdmin({ walletBalance: 0, remainingBalance: 42.5 });
  const profile = await loadEffectiveWalletProfile(admin, "user-1");
  if (profile.wallet_balance !== 42.5) {
    throw new Error(
      `Expected synchronized balance 42.5, got ${profile.wallet_balance}`,
    );
  }
});

Deno.test("chargeAiCoins consumes credits and logs usage event", async () => {
  const admin = fakeAdmin({ walletBalance: 5, remainingBalance: 4.9 });
  const result = await chargeAiCoins({
    admin,
    userId: "user-1",
    feature: "praticase-patient-turn",
    model: "gpt-4o-mini",
    usageMetadata: {
      promptTokenCount: 120,
      candidatesTokenCount: 40,
      totalTokenCount: 160,
    },
  });

  if (result.chargedCoinAmount !== 0.1) {
    throw new Error(
      `Expected charged amount 0.1, got ${result.chargedCoinAmount}`,
    );
  }
  if (result.walletBalance !== 4.9) {
    throw new Error(
      `Expected remaining wallet 4.9, got ${result.walletBalance}`,
    );
  }
  if (admin.events.length !== 1) {
    throw new Error("Expected one ai_usage_events insert");
  }
  const usageMetadata = admin.events[0].usage_metadata as Record<
    string,
    unknown
  >;
  if (usageMetadata.app_key !== "praticase") {
    throw new Error("Expected PratiCase app attribution");
  }
  const attribution = usageMetadata.feature_attribution as Record<
    string,
    unknown
  >;
  if (
    attribution.app_key !== "praticase" ||
    attribution.feature !== "praticase-patient-turn"
  ) {
    throw new Error("Expected feature attribution on AI usage event");
  }
});

Deno.test("chargeAiCoins includes caller feature attribution metadata", async () => {
  const admin = fakeAdmin({ walletBalance: 5, remainingBalance: 4.9 });
  await chargeAiCoins({
    admin,
    userId: "user-1",
    feature: "praticase-oral-exam-turn",
    model: "gpt-4o-mini",
    usageMetadata: {
      promptTokenCount: 120,
      candidatesTokenCount: 40,
      totalTokenCount: 160,
    },
    attribution: {
      exam_kind: "oral_exam",
      session_id: "session-1",
    },
  });
  const usageMetadata = admin.events[0].usage_metadata as Record<
    string,
    unknown
  >;
  const attribution = usageMetadata.feature_attribution as Record<
    string,
    unknown
  >;
  if (
    attribution.exam_kind !== "oral_exam" ||
    attribution.session_id !== "session-1"
  ) {
    throw new Error("Expected operation attribution to be preserved");
  }
});

Deno.test("chargeAiCoins allows dedicated AI quota to cover usage", async () => {
  const admin = fakeAdmin({
    walletBalance: 0,
    aiQuota: 1,
    remainingBalance: 0,
    remainingAiQuota: 0.9,
  });
  const result = await chargeAiCoins({
    admin,
    userId: "user-1",
    feature: "praticase-patient-turn",
    model: "gpt-4o-mini",
    usageMetadata: {
      promptTokenCount: 120,
      candidatesTokenCount: 40,
      totalTokenCount: 160,
    },
  });

  if (result.chargedCoinAmount !== 0.1) {
    throw new Error(
      `Expected charged amount 0.1, got ${result.chargedCoinAmount}`,
    );
  }
  if (admin.events.length !== 1) {
    throw new Error("Expected one ai_usage_events insert");
  }
});

Deno.test("chargeAiCoins allows no-charge fallback without service role", async () => {
  const result = await chargeAiCoins({
    admin: null,
    userId: "user-1",
    feature: "praticase-complete-session",
    model: "gpt-4o-mini",
    usageMetadata: {
      promptTokenCount: 120,
      candidatesTokenCount: 40,
      totalTokenCount: 160,
    },
  });

  if (result.chargedCoinAmount !== 0 || result.walletBalance !== null) {
    throw new Error("Expected no-charge fallback");
  }
});

Deno.test("recordAiUsage attributes uncharged AI usage without wallet mutation", async () => {
  const admin = fakeAdmin({ walletBalance: 0 });
  await recordAiUsage({
    admin,
    userId: "user-1",
    feature: "praticase-speech",
    model: "gpt-4o-mini-tts",
    usageMetadata: { promptTokenCount: 120 },
    attribution: {
      exam_kind: "osce",
      operation: "text_to_speech",
    },
  });

  if (admin.events.length !== 1 || admin.events[0].charged_coin_amount !== 0) {
    throw new Error("Expected one uncharged AI usage event");
  }
  const usageMetadata = admin.events[0].usage_metadata as Record<
    string,
    unknown
  >;
  const attribution = usageMetadata.feature_attribution as Record<
    string,
    unknown
  >;
  if (
    usageMetadata.app_key !== "praticase" ||
    attribution.operation !== "text_to_speech"
  ) {
    throw new Error("Expected attributed TTS usage event");
  }
});

function fakeAdmin(
  options: {
    walletBalance: number;
    aiQuota?: number;
    remainingBalance?: number;
    remainingAiQuota?: number;
  },
) {
  return {
    events: [] as Record<string, unknown>[],
    from(table: string) {
      if (table === "profiles") {
        return {
          select() {
            return this;
          },
          eq() {
            return this;
          },
          async maybeSingle() {
            return {
              data: {
                wallet_balance: options.walletBalance,
                ai_quota: options.aiQuota ?? 0,
              },
              error: null,
            };
          },
        };
      }
      return {
        insert: async (value: Record<string, unknown>) => {
          this.events.push(value);
          return { error: null };
        },
      };
    },
    async rpc(name: string, params: Record<string, unknown>) {
      if (name === "sync_wallet_profile") {
        return {
          data: {
            wallet_balance: options.remainingBalance ?? options.walletBalance,
            question_quota: 0,
            ai_quota: options.remainingAiQuota ?? options.aiQuota ?? 0,
          },
          error: null,
        };
      }
      if (name !== "consume_ai_credits") {
        throw new Error(`Unexpected RPC ${name}`);
      }
      if (
        Number(params.p_amount ?? 0) >
          options.walletBalance + (options.aiQuota ?? 0)
      ) {
        return { data: null, error: { message: "insufficient" } };
      }
      return { data: options.remainingBalance ?? 0, error: null };
    },
  };
}
