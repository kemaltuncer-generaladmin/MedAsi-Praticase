import type { JsonMap } from "./openai_ai.ts";

// Wallet charging is now served by MedAsi Core. The cost CALCULATION below is
// kept locally (pure, identical to Core) for callers/tests, but every wallet
// side effect (balance, consume, usage log, refund, profile) goes through Core,
// which owns the ecosystem RPCs 1:1. Signatures are unchanged so call sites stay
// the same. There is no local fallback: a missing MEDASI_CORE_URL fails closed.

type SupabaseAdmin = unknown;

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

const OPENAI_GPT_4O_INPUT_USD_PER_M = envNumber("OPENAI_GPT_4O_INPUT_USD_PER_M", 2.50);
const OPENAI_GPT_4O_CACHED_INPUT_USD_PER_M = envNumber("OPENAI_GPT_4O_CACHED_INPUT_USD_PER_M", 1.25);
const OPENAI_GPT_4O_OUTPUT_USD_PER_M = envNumber("OPENAI_GPT_4O_OUTPUT_USD_PER_M", 10.00);
const OPENAI_GPT_4O_2024_05_13_INPUT_USD_PER_M = envNumber("OPENAI_GPT_4O_2024_05_13_INPUT_USD_PER_M", 5.00);
const OPENAI_GPT_4O_2024_05_13_OUTPUT_USD_PER_M = envNumber("OPENAI_GPT_4O_2024_05_13_OUTPUT_USD_PER_M", 15.00);
const OPENAI_GPT_4O_MINI_INPUT_USD_PER_M = envNumber("OPENAI_GPT_4O_MINI_INPUT_USD_PER_M", 0.15);
const OPENAI_GPT_4O_MINI_CACHED_INPUT_USD_PER_M = envNumber("OPENAI_GPT_4O_MINI_CACHED_INPUT_USD_PER_M", 0.075);
const OPENAI_GPT_4O_MINI_OUTPUT_USD_PER_M = envNumber("OPENAI_GPT_4O_MINI_OUTPUT_USD_PER_M", 0.60);
const OPENAI_DEFAULT_INPUT_USD_PER_M = envNumber("OPENAI_DEFAULT_INPUT_USD_PER_M", OPENAI_GPT_4O_MINI_INPUT_USD_PER_M);
const OPENAI_DEFAULT_CACHED_INPUT_USD_PER_M = envNumber("OPENAI_DEFAULT_CACHED_INPUT_USD_PER_M", OPENAI_GPT_4O_MINI_CACHED_INPUT_USD_PER_M);
const OPENAI_DEFAULT_OUTPUT_USD_PER_M = envNumber("OPENAI_DEFAULT_OUTPUT_USD_PER_M", OPENAI_GPT_4O_MINI_OUTPUT_USD_PER_M);
const DEFAULT_USD_TRY = envNumber("MEDASI_USD_TRY_FALLBACK", 45.35);

// --- MedAsi Core wallet client -------------------------------------------------

function coreEndpoint(): { url: string; key: string } {
  const url = (Deno.env.get("MEDASI_CORE_URL") || "").trim().replace(/\/+$/, "");
  const key = Deno.env.get("MEDASI_CORE_KEY") || "";
  if (!url) {
    throw new Error("MedAsi Core wallet is not configured (MEDASI_CORE_URL).");
  }
  return { url, key };
}

async function coreWallet(path: string, body: JsonMap): Promise<JsonMap> {
  const { url, key } = coreEndpoint();
  const response = await fetch(`${url}/v1/wallet/${path}`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-medasi-app": praticaseAppKey,
      ...(key ? { "x-medasi-core-key": key } : {}),
    },
    body: JSON.stringify(body),
  });
  const data = await response.json().catch(() => null);
  if (!response.ok) {
    const error = isJsonMap(data) && isJsonMap(data.error) ? data.error : {};
    const details = isJsonMap(error.details) ? error.details : {};
    if (response.status === 402 || error.code === "INSUFFICIENT_MC") {
      throw new InsufficientCoinBalanceError(
        numberValue(details.walletBalance),
        numberValue(details.requiredBalance) || minimumAiCreditCost,
        numberValue(details.aiQuota),
      );
    }
    console.error("praticase_core_wallet_failed", response.status);
    throw new Error(`MedAsi Core wallet error: ${response.status}`);
  }
  return isJsonMap(data) ? data : {};
}

export async function ensureAiCoinBalance(
  admin: SupabaseAdmin | null,
  userId: string,
): Promise<void> {
  if (!admin || !userId) return;
  await coreWallet("ensure-balance", { userId });
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
  const data = await coreWallet("charge-ai", {
    userId: options.userId,
    feature: options.feature,
    model: options.model,
    usage: options.usageMetadata,
    attribution: options.attribution ?? {},
  });
  return {
    chargedCoinAmount: numberValue(data.chargedCoinAmount),
    walletBalance: nullableNumberValue(data.walletBalance),
  };
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
  await coreWallet("record-usage", {
    userId: options.userId,
    feature: options.feature,
    model: options.model,
    usage: options.usageMetadata,
    attribution: options.attribution ?? {},
  });
}

export async function syncWalletProfile(
  admin: SupabaseAdmin | null,
  userId: string,
): Promise<JsonMap> {
  if (!admin || !userId) return {};
  try {
    return await coreWallet("profile", { userId });
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
    return { wallet_balance: 0, question_quota: 0, ai_quota: 0 };
  }
  const data = await coreWallet("profile", { userId });
  return {
    wallet_balance: numberValue(data.wallet_balance),
    question_quota: Math.round(numberValue(data.question_quota)),
    ai_quota: Math.round(numberValue(data.ai_quota)),
  };
}

// --- Cost calculation (pure, identical to Core) --------------------------------

export function aiCreditCostFromUsage(usageMetadata: JsonMap, model = ""): number {
  const cost = aiCostFromUsage(usageMetadata, model);
  const totalCostTL = cost.totalCostUsd * DEFAULT_USD_TRY;
  const coinTlValue = envNumber("MEDASI_COIN_TL_VALUE", 0.30);
  const usageMultiplier = envNumber("MEDASI_AI_COIN_USAGE_MULTIPLIER", 1.35);
  let tokenCostCredit = (totalCostTL / coinTlValue) * usageMultiplier;

  if (
    tokenCostCredit < minimumAiCreditCost &&
    (cost.promptTokens > 0 || cost.candidatesTokens > 0 || cost.thoughtsTokens > 0)
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
  const thoughtsTokens = Math.max(measuredReasoningTokens, inferredReasoningTokens);
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
    totalTokens: totalTokens || promptTokens + candidatesTokens + thoughtsTokens,
    cachedTokens,
    inputCostUsd,
    outputCostUsd,
    totalCostUsd: inputCostUsd + outputCostUsd,
  };
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
