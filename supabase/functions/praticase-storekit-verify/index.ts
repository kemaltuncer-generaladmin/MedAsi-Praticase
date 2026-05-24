import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.4";
import { corsHeaders, isAllowedOrigin, jsonResponse } from "../_shared/cors.ts";

type JsonMap = Record<string, unknown>;

Deno.serve(async (request) => {
  const origin = request.headers.get("Origin");

  if (request.method === "OPTIONS") {
    if (!isAllowedOrigin(origin)) {
      return jsonResponse({ error: "Origin not allowed" }, 403, origin);
    }
    return new Response("ok", { headers: corsHeaders(origin) });
  }

  if (!isAllowedOrigin(origin)) {
    return jsonResponse({ error: "Origin not allowed" }, 403, origin);
  }

  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405, origin);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const appleSharedSecret = Deno.env.get("APPLE_STOREKIT_SHARED_SECRET") ?? "";
  const authorization = request.headers.get("Authorization");

  if (
    !supabaseUrl ||
    !supabaseAnonKey ||
    !supabaseServiceRoleKey ||
    !authorization
  ) {
    return jsonResponse(
      { error: "Live Supabase configuration is missing" },
      500,
      origin,
    );
  }

  const userClient = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authorization } },
  });

  const { data: authData, error: authError } = await userClient.auth.getUser();
  if (authError || !authData.user) {
    return jsonResponse({ error: "Unauthorized" }, 401, origin);
  }

  const admin = createClient(supabaseUrl, supabaseServiceRoleKey, {
    auth: { persistSession: false },
  });

  const body = await request.json().catch(() => ({})) as JsonMap;
  const productCode = stringValue(body.product_code);
  const storeProductId = stringValue(body.store_product_id);
  const provider = stringValue(body.provider) || "app_store";
  const purchaseId = stringValue(body.purchase_id);
  const verification = body.verification_data as JsonMap | undefined;

  if (!productCode || !storeProductId || !purchaseId || !verification) {
    return jsonResponse(
      { error: "product_code, store_product_id, purchase_id ve verification_data zorunlu." },
      400,
      origin,
    );
  }

  const serverPayload = stringValue(verification.server_verification_data);
  const localPayload = stringValue(verification.local_verification_data);
  const source = stringValue(verification.source);

  if (!serverPayload && !localPayload) {
    return jsonResponse(
      { error: "App Store doğrulama verisi boş." },
      400,
      origin,
    );
  }

  const userId = authData.user.id;

  let appleResult: AppleReceipt = {
    status: 0,
    environment: "production",
    transactionId: purchaseId,
    originalTransactionId: purchaseId,
    expiresAt: null,
    autoRenew: true,
  };

  if (serverPayload && source === "app_store") {
    try {
      appleResult = await verifyWithApple(serverPayload, appleSharedSecret);
    } catch (error) {
      await recordEvent(admin, userId, "verify_failed", {
        provider,
        productCode,
        message: errorMessage(error),
      });
      return jsonResponse(
        { error: `App Store doğrulaması başarısız: ${errorMessage(error)}` },
        502,
        origin,
      );
    }
  }

  const { data: product, error: productError } = await admin
    .from("store_products")
    .select(
      "code,name,price_cents,currency,interval,coin_amount,question_amount,entitlement_kind,duration_days,app_store_product_id",
    )
    .eq("code", productCode)
    .eq("is_active", true)
    .maybeSingle();

  if (productError || !product) {
    return jsonResponse(
      { error: "Ürün Supabase'de bulunamadı." },
      404,
      origin,
    );
  }
  if (product.app_store_product_id !== storeProductId) {
    return jsonResponse(
      { error: "App Store ürün kimliği Supabase ile uyuşmuyor." },
      409,
      origin,
    );
  }

  const entitlementKind = (product.entitlement_kind ?? "subscription").toString();
  const durationDays = numberValue(product.duration_days) ?? 30;
  const now = new Date();
  const expiresAt = appleResult.expiresAt
    ?? new Date(now.getTime() + durationDays * 24 * 3600 * 1000);
  const periodStart = appleResult.periodStartedAt ?? now;

  const { error: txError } = await admin.from("wallet_transactions").upsert({
    user_id: userId,
    product_code: product.code,
    provider,
    provider_transaction_id: appleResult.transactionId,
    provider_original_transaction_id: appleResult.originalTransactionId,
    status: "completed",
    amount_cents: numberValue(product.price_cents) ?? 0,
    currency: stringValue(product.currency) || "USD",
    environment: appleResult.environment,
    payload: {
      apple: {
        status: appleResult.status,
        autoRenew: appleResult.autoRenew,
      },
      received_at: now.toISOString(),
    },
  }, { onConflict: "provider_transaction_id" });

  if (txError) {
    return jsonResponse({ error: txError.message }, 400, origin);
  }

  const { error: entitlementError } = await admin
    .from("wallet_entitlements")
    .upsert({
      user_id: userId,
      product_code: product.code,
      entitlement_type: entitlementKind,
      status: "active",
      remaining_coin_amount: numberValue(product.coin_amount) ?? 0,
      remaining_question_amount: numberValue(product.question_amount) ?? 0,
      period_started_at: periodStart.toISOString(),
      expires_at: expiresAt.toISOString(),
      provider,
      provider_transaction_id: appleResult.transactionId,
      provider_original_transaction_id: appleResult.originalTransactionId,
    }, { onConflict: "user_id,product_code,entitlement_type" });

  if (entitlementError) {
    return jsonResponse({ error: entitlementError.message }, 400, origin);
  }

  try {
    await admin.rpc("sync_wallet_profile", { p_user_id: userId });
  } catch (error) {
    await recordEvent(admin, userId, "sync_wallet_profile_failed", {
      message: errorMessage(error),
    });
  }

  await recordEvent(admin, userId, "verify_succeeded", {
    productCode: product.code,
    provider,
    environment: appleResult.environment,
  });

  return jsonResponse(
    {
      status: "ok",
      product: product.code,
      product_name: product.name,
      entitlement_type: entitlementKind,
      expires_at: expiresAt.toISOString(),
      period_started_at: periodStart.toISOString(),
      transaction_id: appleResult.transactionId,
      original_transaction_id: appleResult.originalTransactionId,
      environment: appleResult.environment,
      will_auto_renew: appleResult.autoRenew,
    },
    200,
    origin,
  );
});

type AppleReceipt = {
  status: number;
  environment: string;
  transactionId: string;
  originalTransactionId: string;
  expiresAt: Date | null;
  periodStartedAt?: Date | null;
  autoRenew: boolean;
};

async function verifyWithApple(
  receiptData: string,
  sharedSecret: string,
): Promise<AppleReceipt> {
  if (!sharedSecret) {
    throw new Error("APPLE_STOREKIT_SHARED_SECRET tanımlı değil");
  }
  const payload = {
    "receipt-data": receiptData,
    "password": sharedSecret,
    "exclude-old-transactions": true,
  };
  const tryUrl = async (url: string) => {
    const response = await fetch(url, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(payload),
    });
    if (!response.ok) {
      throw new Error(`Apple verifyReceipt ${response.status}`);
    }
    return await response.json() as JsonMap;
  };

  let body = await tryUrl("https://buy.itunes.apple.com/verifyReceipt");
  if (body.status === 21007) {
    body = await tryUrl("https://sandbox.itunes.apple.com/verifyReceipt");
  }
  const status = numberValue(body.status) ?? -1;
  if (status !== 0) {
    throw new Error(`Apple receipt status ${status}`);
  }

  const latest = Array.isArray(body.latest_receipt_info)
    ? body.latest_receipt_info[0] as JsonMap
    : (body.receipt as JsonMap | undefined);

  const pendingInfo = Array.isArray(body.pending_renewal_info)
    ? body.pending_renewal_info[0] as JsonMap
    : undefined;

  const transactionId = stringValue(latest?.transaction_id ?? latest?.original_transaction_id);
  const originalTransactionId = stringValue(latest?.original_transaction_id ?? transactionId);
  const expiresMs = Number(latest?.expires_date_ms ?? 0);
  const startMs = Number(latest?.purchase_date_ms ?? 0);

  return {
    status,
    environment: stringValue(body.environment) || "production",
    transactionId: transactionId || crypto.randomUUID(),
    originalTransactionId: originalTransactionId || transactionId || crypto.randomUUID(),
    expiresAt: Number.isFinite(expiresMs) && expiresMs > 0 ? new Date(expiresMs) : null,
    periodStartedAt: Number.isFinite(startMs) && startMs > 0 ? new Date(startMs) : null,
    autoRenew: stringValue(pendingInfo?.auto_renew_status ?? "1") === "1",
  };
}

async function recordEvent(
  // deno-lint-ignore no-explicit-any
  admin: any,
  userId: string,
  event: string,
  context: JsonMap,
) {
  try {
    await admin.from("wallet_audit_events").insert({
      user_id: userId,
      event,
      context,
    });
  } catch (_) {
    // best-effort logging only
  }
}

function stringValue(value: unknown) {
  if (value == null) return "";
  return typeof value === "string" ? value.trim() : String(value).trim();
}

function numberValue(value: unknown) {
  const numeric = Number(value);
  return Number.isFinite(numeric) ? numeric : null;
}

function errorMessage(error: unknown) {
  return error instanceof Error ? error.message : String(error);
}
