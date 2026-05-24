import type { JsonMap } from "./vertex_ai.ts";

// deno-lint-ignore no-explicit-any
type SupabaseAdmin = any;

// deno-lint-ignore no-explicit-any
type QueryBuilder = any;

export class InsufficientCoinBalanceError extends Error {
  constructor(readonly walletBalance: number, readonly requiredBalance: number) {
    super("MedAsi Coin balance is insufficient");
  }
}

export const minimumAiCreditCost = envNumber("MEDASI_AI_MIN_COIN_COST", 0.10);

const GEMINI_2_5_FLASH_INPUT_USD_PER_M = envNumber(
  "VERTEX_GEMINI_2_5_FLASH_INPUT_USD_PER_M",
  0.30,
);
const GEMINI_2_5_FLASH_CACHED_INPUT_USD_PER_M = envNumber(
  "VERTEX_GEMINI_2_5_FLASH_CACHED_INPUT_USD_PER_M",
  0.03,
);
const GEMINI_2_5_FLASH_OUTPUT_USD_PER_M = envNumber(
  "VERTEX_GEMINI_2_5_FLASH_OUTPUT_USD_PER_M",
  2.50,
);
const DEFAULT_USD_TRY = envNumber("MEDASI_USD_TRY_FALLBACK", 45.35);

export async function ensureAiCoinBalance(
  admin: SupabaseAdmin | null,
  userId: string,
): Promise<void> {
  if (!admin || !userId) return;
  const { data, error } = await query(admin.from("profiles"))
    .select("wallet_balance")
    .eq("id", userId)
    .maybeSingle();
  if (error) {
    console.error("praticase_coin_balance_check_failed", error.message);
    return;
  }
  const walletBalance = numberValue(data?.wallet_balance);
  if (walletBalance < minimumAiCreditCost) {
    throw new InsufficientCoinBalanceError(walletBalance, minimumAiCreditCost);
  }
}

export async function chargeAiCoins(options: {
  admin: SupabaseAdmin | null;
  userId: string;
  feature: string;
  model: string;
  usageMetadata: JsonMap;
}): Promise<{ chargedCoinAmount: number; walletBalance: number | null }> {
  if (!options.admin) {
    return { chargedCoinAmount: 0, walletBalance: null };
  }
  const admin = options.admin;

  const chargedCoinAmount = aiCreditCostFromUsage(options.usageMetadata);
  if (chargedCoinAmount <= 0) {
    await logAiUsageEvent({ ...options, admin, chargedCoinAmount: 0 });
    return { chargedCoinAmount: 0, walletBalance: null };
  }

  const { data, error } = await admin.rpc("consume_ai_credits", {
    p_user_id: options.userId,
    p_amount: chargedCoinAmount,
  });
  if (error) {
    throw new InsufficientCoinBalanceError(0, chargedCoinAmount);
  }

  await logAiUsageEvent({ ...options, admin, chargedCoinAmount });
  return {
    chargedCoinAmount,
    walletBalance: nullableNumberValue(data),
  };
}

export function aiCreditCostFromUsage(usageMetadata: JsonMap): number {
  const cost = vertexAiCostFromUsage(usageMetadata);
  const totalCostTL = cost.totalCostUsd * DEFAULT_USD_TRY;
  const coinTlValue = envNumber("MEDASI_COIN_TL_VALUE", 0.30);
  const usageMultiplier = envNumber("MEDASI_AI_COIN_USAGE_MULTIPLIER", 1.35);
  let tokenCostCredit = (totalCostTL / coinTlValue) * usageMultiplier;

  if (
    tokenCostCredit < minimumAiCreditCost &&
    (cost.promptTokens > 0 || cost.candidatesTokens > 0 ||
      cost.thoughtsTokens > 0)
  ) {
    tokenCostCredit = minimumAiCreditCost;
  }

  return Number(tokenCostCredit.toFixed(4));
}

export function vertexAiCostFromUsage(usageMetadata: JsonMap) {
  const promptTokens = positiveInt(usageMetadata.promptTokenCount);
  const candidatesTokens = positiveInt(usageMetadata.candidatesTokenCount);
  const totalTokens = positiveInt(usageMetadata.totalTokenCount);
  const cachedTokens = Math.min(
    promptTokens,
    positiveInt(usageMetadata.cachedContentTokenCount),
  );
  const measuredThoughtsTokens = positiveInt(usageMetadata.thoughtsTokenCount);
  const thoughtsTokens = measuredThoughtsTokens ||
    Math.max(0, totalTokens - promptTokens - candidatesTokens);
  const uncachedInputTokens = Math.max(0, promptTokens - cachedTokens);
  const billableOutputTokens = candidatesTokens + thoughtsTokens;
  const inputCostUsd = (
    uncachedInputTokens * GEMINI_2_5_FLASH_INPUT_USD_PER_M +
    cachedTokens * GEMINI_2_5_FLASH_CACHED_INPUT_USD_PER_M
  ) / 1000000;
  const outputCostUsd = billableOutputTokens *
    GEMINI_2_5_FLASH_OUTPUT_USD_PER_M / 1000000;

  return {
    promptTokens,
    candidatesTokens,
    thoughtsTokens,
    totalTokens: totalTokens || promptTokens + candidatesTokens +
      thoughtsTokens,
    cachedTokens,
    inputCostUsd,
    outputCostUsd,
    totalCostUsd: inputCostUsd + outputCostUsd,
  };
}

async function logAiUsageEvent(options: {
  admin: SupabaseAdmin;
  userId: string;
  feature: string;
  model: string;
  usageMetadata: JsonMap;
  chargedCoinAmount: number;
}) {
  const cost = vertexAiCostFromUsage(options.usageMetadata);
  const { error } = await query(options.admin.from("ai_usage_events")).insert({
    user_id: options.userId,
    feature: options.feature,
    provider: "vertex_ai",
    model: options.model,
    prompt_token_count: cost.promptTokens,
    candidates_token_count: cost.candidatesTokens,
    thoughts_token_count: cost.thoughtsTokens,
    total_token_count: cost.totalTokens,
    cached_content_token_count: cost.cachedTokens,
    input_cost_usd: Number(cost.inputCostUsd.toFixed(6)),
    output_cost_usd: Number(cost.outputCostUsd.toFixed(6)),
    total_cost_usd: Number(cost.totalCostUsd.toFixed(6)),
    charged_coin_amount: options.chargedCoinAmount,
    usage_metadata: options.usageMetadata,
  });
  if (error) {
    console.error("praticase_ai_usage_event_insert_failed", error.message);
  }
}

function query(value: unknown): QueryBuilder {
  return value as QueryBuilder;
}

function envNumber(name: string, fallback: number): number {
  const raw = Deno.env.get(name);
  if (!raw) return fallback;
  const parsed = Number(raw);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

function positiveInt(value: unknown): number {
  const number = Number(value ?? 0);
  return Number.isFinite(number) && number > 0 ? Math.round(number) : 0;
}

function nullableNumberValue(value: unknown): number | null {
  const number = Number(value ?? Number.NaN);
  return Number.isFinite(number) ? number : null;
}

function numberValue(value: unknown): number {
  return nullableNumberValue(value) ?? 0;
}
