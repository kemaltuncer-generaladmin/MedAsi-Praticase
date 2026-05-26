import {
  aiCreditCostFromUsage,
  chargeAiCoins,
  ensureAiCoinBalance,
  InsufficientCoinBalanceError,
  vertexAiCostFromUsage,
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

Deno.test("vertexAiCostFromUsage follows Qlinik inferred thinking tokens", () => {
  const cost = vertexAiCostFromUsage({
    promptTokenCount: 100,
    candidatesTokenCount: 50,
    thoughtsTokenCount: 25,
    totalTokenCount: 300,
  });
  if (cost.thoughtsTokens !== 150) {
    throw new Error(
      `Expected 150 inferred thought tokens, got ${cost.thoughtsTokens}`,
    );
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

Deno.test("chargeAiCoins consumes credits and logs usage event", async () => {
  const admin = fakeAdmin({ walletBalance: 5, remainingBalance: 4.9 });
  const result = await chargeAiCoins({
    admin,
    userId: "user-1",
    feature: "praticase-patient-turn",
    model: "gemini-2.5-flash",
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
});

Deno.test("chargeAiCoins allows no-charge fallback without service role", async () => {
  const result = await chargeAiCoins({
    admin: null,
    userId: "user-1",
    feature: "praticase-complete-session",
    model: "gemini-2.5-flash",
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

function fakeAdmin(
  options: { walletBalance: number; remainingBalance?: number },
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
              data: { wallet_balance: options.walletBalance },
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
      if (name !== "consume_ai_credits") {
        throw new Error(`Unexpected RPC ${name}`);
      }
      if (Number(params.p_amount ?? 0) > options.walletBalance) {
        return { data: null, error: { message: "insufficient" } };
      }
      return { data: options.remainingBalance ?? 0, error: null };
    },
  };
}
