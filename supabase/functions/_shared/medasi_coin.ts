import type { JsonMap } from "./openai_ai.ts";

// deno-lint-ignore no-explicit-any
type SupabaseAdmin = any;

// deno-lint-ignore no-explicit-any
type QueryBuilder = any;

export const praticaseAppKey = "praticase";

export class InsufficientCoinBalanceError extends Error {
  constructor(
    readonly walletBalance: number,
    readonly requiredBalance: number,
    readonly aiQuota = 0,
  ) {
    super("MedAsi AI credit balance is insufficient");
  }
}

export const minimumAiCreditCost = envNumber("MEDASI_AI_MIN_COIN_COST", 0.10);

const OPENAI_GPT_4O_INPUT_USD_PER_M = envNumber(
  "OPENAI_GPT_4O_INPUT_USD_PER_M",
  2.50,
);
const OPENAI_GPT_4O_CACHED_INPUT_USD_PER_M = envNumber(
  "OPENAI_GPT_4O_CACHED_INPUT_USD_PER_M",
  1.25,
);
const OPENAI_GPT_4O_OUTPUT_USD_PER_M = envNumber(
  "OPENAI_GPT_4O_OUTPUT_USD_PER_M",
  10.00,
);
const OPENAI_GPT_4O_2024_05_13_INPUT_USD_PER_M = envNumber(
  "OPENAI_GPT_4O_2024_05_13_INPUT_USD_PER_M",
  5.00,
);
const OPENAI_GPT_4O_2024_05_13_OUTPUT_USD_PER_M = envNumber(
  "OPENAI_GPT_4O_2024_05_13_OUTPUT_USD_PER_M",
  15.00,
);
const OPENAI_GPT_4O_MINI_INPUT_USD_PER_M = envNumber(
  "OPENAI_GPT_4O_MINI_INPUT_USD_PER_M",
  0.15,
);
const OPENAI_GPT_4O_MINI_CACHED_INPUT_USD_PER_M = envNumber(
  "OPENAI_GPT_4O_MINI_CACHED_INPUT_USD_PER_M",
  0.075,
);
const OPENAI_GPT_4O_MINI_OUTPUT_USD_PER_M = envNumber(
  "OPENAI_GPT_4O_MINI_OUTPUT_USD_PER_M",
  0.60,
);
const OPENAI_DEFAULT_INPUT_USD_PER_M = envNumber(
  "OPENAI_DEFAULT_INPUT_USD_PER_M",
  OPENAI_GPT_4O_MINI_INPUT_USD_PER_M,
);
const OPENAI_DEFAULT_CACHED_INPUT_USD_PER_M = envNumber(
  "OPENAI_DEFAULT_CACHED_INPUT_USD_PER_M",
  OPENAI_GPT_4O_MINI_CACHED_INPUT_USD_PER_M,
);
const OPENAI_DEFAULT_OUTPUT_USD_PER_M = envNumber(
  "OPENAI_DEFAULT_OUTPUT_USD_PER_M",
  OPENAI_GPT_4O_MINI_OUTPUT_USD_PER_M,
);
const DEFAULT_USD_TRY = envNumber("MEDASI_USD_TRY_FALLBACK", 45.35);

export async function ensureAiCoinBalance(
  admin: SupabaseAdmin | null,
  userId: string,
): Promise<void> {
  if (!admin || !userId) return;
  const profile = await loadEffectiveWalletProfile(admin, userId);
  const walletBalance = numberValue(profile.wallet_balance);
  const aiQuota = numberValue(profile.ai_quota);
  if (availableAiCreditBalance(profile) < minimumAiCreditCost) {
    throw new InsufficientCoinBalanceError(
      walletBalance,
      minimumAiCreditCost,
      aiQuota,
    );
  }
}

export async function chargeAiCoins(options: {
  admin: SupabaseAdmin | null;
  userId: string;
  feature: string;
  model: string;
  usageMetadata: JsonMap;
  attribution?: JsonMap;
}): Promise<{ chargedCoinAmount: number; walletBalance: number | null }> {
  if (!options.admin) {
    return { chargedCoinAmount: 0, walletBalance: null };
  }
  const admin = options.admin;

  const chargedCoinAmount = aiCreditCostFromUsage(
    options.usageMetadata,
    options.model,
  );
  if (chargedCoinAmount <= 0) {
    await logAiUsageEvent({ ...options, admin, chargedCoinAmount: 0 });
    return { chargedCoinAmount: 0, walletBalance: null };
  }

  const profile = await loadEffectiveWalletProfile(admin, options.userId);
  if (availableAiCreditBalance(profile) < chargedCoinAmount) {
    throw new InsufficientCoinBalanceError(
      numberValue(profile.wallet_balance),
      chargedCoinAmount,
      numberValue(profile.ai_quota),
    );
  }

  const { data, error } = await admin.rpc("consume_ai_credits", {
    p_user_id: options.userId,
    p_amount: chargedCoinAmount,
  });
  if (error) {
    const latestProfile = await loadEffectiveWalletProfile(
      admin,
      options.userId,
    );
    throw new InsufficientCoinBalanceError(
      numberValue(latestProfile.wallet_balance),
      chargedCoinAmount,
      numberValue(latestProfile.ai_quota),
    );
  }

  await logAiUsageEvent({ ...options, admin, chargedCoinAmount });
  await syncWalletProfile(admin, options.userId);
  return {
    chargedCoinAmount,
    walletBalance: nullableNumberValue(data),
  };
}

export async function syncWalletProfile(
  admin: SupabaseAdmin | null,
  userId: string,
): Promise<JsonMap> {
  if (!admin || !userId) return {};
  try {
    const { data, error } = await admin.rpc("sync_wallet_profile", {
      p_user_id: userId,
    });
    if (error) {
      console.error("praticase_wallet_profile_sync_failed", error.message);
      return {};
    }
    return isJsonMap(data) ? data : {};
  } catch (error) {
    console.error("praticase_wallet_profile_sync_failed", errorMessage(error));
    return {};
  }
}

export async function loadEffectiveWalletProfile(
  admin: SupabaseAdmin | null,
  userId: string,
): Promise<JsonMap> {
  if (!admin || !userId) {
    return { wallet_balance: 0, question_quota: 0 };
  }

  const syncedProfile = await syncWalletProfile(admin, userId);
  try {
    const { data: profile, error } = await query(admin.from("profiles"))
      .select("wallet_balance,question_quota,ai_quota")
      .eq("id", userId)
      .maybeSingle();
    if (error) {
      console.error("wallet_profile_snapshot_failed", error.message);
    }
    return walletProfileSnapshot(
      syncedProfile,
      isJsonMap(profile) ? profile : {},
    );
  } catch (error) {
    console.error("wallet_profile_snapshot_failed", errorMessage(error));
    return walletProfileSnapshot(syncedProfile);
  }
}

function walletProfileSnapshot(
  syncedProfile: JsonMap,
  profile: JsonMap = {},
): JsonMap {
  return {
    wallet_balance: nullableNumberValue(syncedProfile.wallet_balance) ??
      nullableNumberValue(profile.wallet_balance) ?? 0,
    question_quota: Math.round(
      nullableNumberValue(syncedProfile.question_quota) ??
        nullableNumberValue(profile.question_quota) ?? 0,
    ),
    ai_quota: Math.round(
      nullableNumberValue(syncedProfile.ai_quota) ??
        nullableNumberValue(profile.ai_quota) ?? 0,
    ),
  };
}

function availableAiCreditBalance(profile: JsonMap): number {
  return numberValue(profile.wallet_balance) + numberValue(profile.ai_quota);
}

export async function recordAiUsage(options: {
  admin: SupabaseAdmin | null;
  userId: string;
  feature: string;
  model: string;
  usageMetadata: JsonMap;
  attribution?: JsonMap;
}): Promise<void> {
  if (!options.admin) return;
  await logAiUsageEvent({
    ...options,
    admin: options.admin,
    chargedCoinAmount: 0,
  });
}

export function aiCreditCostFromUsage(
  usageMetadata: JsonMap,
  model = "",
): number {
  const cost = aiCostFromUsage(usageMetadata, model);
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

export function aiCostFromUsage(usageMetadata: JsonMap, model = "") {
  return openAiCostFromUsage(usageMetadata, model);
}

export function openAiCostFromUsage(usageMetadata: JsonMap, model = "") {
  const promptTokens = positiveInt(usageMetadata.promptTokenCount);
  const candidatesTokens = positiveInt(usageMetadata.candidatesTokenCount);
  const totalTokens = positiveInt(usageMetadata.totalTokenCount);
  const cachedTokens = Math.min(
    promptTokens,
    positiveInt(usageMetadata.cachedContentTokenCount),
  );
  const measuredReasoningTokens = positiveInt(usageMetadata.thoughtsTokenCount);
  const inferredReasoningTokens = Math.max(
    0,
    totalTokens - promptTokens - candidatesTokens,
  );
  const thoughtsTokens = Math.max(
    measuredReasoningTokens,
    inferredReasoningTokens,
  );
  const uncachedInputTokens = Math.max(0, promptTokens - cachedTokens);
  const billableOutputTokens = candidatesTokens + thoughtsTokens;
  const pricing = openAiTextPricing(model);
  const inputCostUsd = (
    uncachedInputTokens * pricing.inputUsdPerMTokens +
    cachedTokens * pricing.cachedInputUsdPerMTokens
  ) / 1000000;
  const outputCostUsd = billableOutputTokens *
    pricing.outputUsdPerMTokens / 1000000;

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
  attribution?: JsonMap;
  chargedCoinAmount: number;
}) {
  const cost = aiCostFromUsage(options.usageMetadata, options.model);
  const usageMetadata = {
    ...options.usageMetadata,
    app_key: praticaseAppKey,
    feature_attribution: {
      app_key: praticaseAppKey,
      feature: options.feature,
      ...(options.attribution ?? {}),
    },
  };
  const provider = stringValue(options.usageMetadata.provider) || "openai";
  const { error } = await query(options.admin.from("ai_usage_events")).insert({
    user_id: options.userId,
    feature: options.feature,
    provider,
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
    usage_metadata: usageMetadata,
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

function openAiTextPricing(model: string) {
  const normalized = model.trim().toLowerCase();
  if (normalized === "gpt-4o-2024-05-13") {
    return {
      inputUsdPerMTokens: OPENAI_GPT_4O_2024_05_13_INPUT_USD_PER_M,
      cachedInputUsdPerMTokens: OPENAI_GPT_4O_2024_05_13_INPUT_USD_PER_M,
      outputUsdPerMTokens: OPENAI_GPT_4O_2024_05_13_OUTPUT_USD_PER_M,
    };
  }
  if (normalized.startsWith("gpt-4o-mini")) {
    return {
      inputUsdPerMTokens: OPENAI_GPT_4O_MINI_INPUT_USD_PER_M,
      cachedInputUsdPerMTokens: OPENAI_GPT_4O_MINI_CACHED_INPUT_USD_PER_M,
      outputUsdPerMTokens: OPENAI_GPT_4O_MINI_OUTPUT_USD_PER_M,
    };
  }
  if (normalized.startsWith("gpt-4o")) {
    return {
      inputUsdPerMTokens: OPENAI_GPT_4O_INPUT_USD_PER_M,
      cachedInputUsdPerMTokens: OPENAI_GPT_4O_CACHED_INPUT_USD_PER_M,
      outputUsdPerMTokens: OPENAI_GPT_4O_OUTPUT_USD_PER_M,
    };
  }
  return {
    inputUsdPerMTokens: OPENAI_DEFAULT_INPUT_USD_PER_M,
    cachedInputUsdPerMTokens: OPENAI_DEFAULT_CACHED_INPUT_USD_PER_M,
    outputUsdPerMTokens: OPENAI_DEFAULT_OUTPUT_USD_PER_M,
  };
}

function stringValue(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function nullableNumberValue(value: unknown): number | null {
  const number = Number(value ?? Number.NaN);
  return Number.isFinite(number) ? number : null;
}

function numberValue(value: unknown): number {
  return nullableNumberValue(value) ?? 0;
}

function isJsonMap(value: unknown): value is JsonMap {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}
