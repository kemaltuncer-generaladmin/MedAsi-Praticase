import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.4";
import { Buffer } from "node:buffer";
import { compactVerify } from "npm:jose@5.9.6";
import { X509Certificate as PeculiarX509 } from "npm:@peculiar/x509@1.12.3";
import { defaultAppleRootCertificates } from "../_shared/apple_root_certificates.ts";
import { corsHeaders, isAllowedOrigin, jsonResponse } from "../_shared/cors.ts";

// Apple'in resmi `app-store-server-library`'si node:crypto'nun X509Certificate
// sınıfını kullanıyor; Supabase Edge Runtime'da (Deno node-compat) `raw`,
// `toString`, `verify` gibi metotlar "Not implemented" stub'u. Bu yüzden
// kütüphaneyi terk edip JWS doğrulamasını jose (imza) + @peculiar/x509
// (sertifika zinciri) ile elden yapıyoruz; her ikisi de saf JS ve Web Crypto
// üstünde çalışır.

type JsonMap = Record<string, unknown>;

type AppleEnvironment = "production" | "sandbox";
type StoreProvider = "app_store" | "google_play";

const activeSubscriptionPurchaseMessage =
  "Aktif aboneliğinin süresi bitmeden aynı abonelik tekrar alınamaz. Haftalıktan aylığa yükseltme yapabilirsin.";

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
  const authorization = request.headers.get("Authorization");

  if (!supabaseUrl || !supabaseServiceRoleKey) {
    return jsonResponse(
      { error: "İşlem şu anda tamamlanamadı. Lütfen tekrar dene." },
      500,
      origin,
    );
  }

  const admin = createClient(supabaseUrl, supabaseServiceRoleKey, {
    auth: { persistSession: false },
  });
  const rawBody = await request.text();
  let body: JsonMap = {};
  try {
    const parsed = JSON.parse(rawBody || "{}");
    body = isJsonMap(parsed) ? parsed : {};
  } catch (_) {
    body = {};
  }
  const action = stringValue(body.action) || "verify";
  if (action === "payment_entitlement_webhook") {
    return handlePaymentEntitlementWebhook(
      admin,
      request,
      rawBody,
      body,
      origin,
    );
  }
  const signedPayload = stringValue(body.signedPayload);
  if (signedPayload) {
    return handleAppStoreNotification(admin, signedPayload, origin);
  }

  if (!supabaseAnonKey || !authorization) {
    return jsonResponse(
      { error: "Oturum doğrulanamadı. Lütfen tekrar giriş yap." },
      401,
      origin,
    );
  }
  const userClient = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authorization } },
  });

  const { data: authData, error: authError } = await userClient.auth.getUser();
  if (authError || !authData.user) {
    return jsonResponse(
      { error: "Oturum doğrulanamadı. Lütfen tekrar giriş yap." },
      401,
      origin,
    );
  }

  const userId = authData.user.id;

  if (action === "catalog" || action === "store") {
    const payload = await loadCatalogPayload(admin, userId, body);
    return jsonResponse(payload, payload.error ? 503 : 200, origin);
  }

  if (action === "subscription_status") {
    const payload = await loadSubscriptionPayload(admin, userId);
    return jsonResponse(payload, payload.error ? 503 : 200, origin);
  }

  if (action === "wallet_transactions") {
    const payload = await loadWalletTransactionsPayload(admin, userId);
    return jsonResponse(payload, payload.error ? 503 : 200, origin);
  }

  if (action === "redeem_gift_code") {
    return redeemGiftCode(admin, userId, body, origin);
  }

  if (action === "create_payment_checkout") {
    return createPaymentCheckout(admin, authData.user, body, origin);
  }

  return verifyNativePurchase(admin, userId, body, origin);
});

async function verifyNativePurchase(
  // deno-lint-ignore no-explicit-any
  admin: any,
  userId: string,
  body: JsonMap,
  origin: string | null,
) {
  const productCode = stringValue(body.product_code);
  const storeProductId = stringValue(body.store_product_id);
  const provider = normalizeStoreProvider(body.provider);
  const purchaseId = stringValue(body.purchase_id);
  const verification = body.verification_data as JsonMap | undefined;

  if (!productCode || !storeProductId || !verification) {
    return jsonResponse(
      { error: "Satın alma bilgisi eksik. Lütfen tekrar dene." },
      400,
      origin,
    );
  }

  const serverPayload = stringValue(verification.server_verification_data);
  const localPayload = stringValue(verification.local_verification_data);
  const source = stringValue(verification.source);

  if (!serverPayload && !localPayload) {
    return jsonResponse(
      { error: "Satın alma bilgisi eksik. Lütfen tekrar dene." },
      400,
      origin,
    );
  }

  const blockedSubscriptionCodes = await blockedSubscriptionProductCodes(
    admin,
    userId,
  );
  if (blockedSubscriptionCodes.includes(productCode)) {
    return jsonResponse(
      { error: activeSubscriptionPurchaseMessage },
      409,
      origin,
    );
  }

  const product = await loadMappedProduct(
    admin,
    productCode,
    storeProductId,
    provider,
  );
  if (!product) {
    return jsonResponse(
      { error: "Seçilen paket bulunamadı." },
      404,
      origin,
    );
  }

  let receipt: StoreReceipt;
  try {
    receipt = provider === "google_play"
      ? await verifyGooglePlayPurchase({
        product,
        storeProductId,
        purchaseToken: serverPayload,
        purchaseId,
      })
      : await verifyApplePurchase({
        storeProductId,
        purchaseId,
        serverPayload,
        source,
      });
  } catch (error) {
    recordEvent("verify_failed", {
      provider,
      productCode,
      payloadShape: provider === "app_store"
        ? verificationPayloadShape(serverPayload)
        : `token:${serverPayload.length}`,
      purchaseIdPresent: purchaseId.length > 0,
      message: errorMessage(error),
    });
    return jsonResponse(
      { error: "Satın alma şu anda doğrulanamadı. Lütfen tekrar dene." },
      502,
      origin,
    );
  }

  const entitlementKind = (product.entitlement_kind ?? "subscription")
    .toString();
  const durationDays = numberValue(product.duration_days) ?? 30;
  const now = new Date();
  const expiresAt = receipt.expiresAt ??
    new Date(now.getTime() + durationDays * 24 * 3600 * 1000);
  const periodStart = receipt.periodStartedAt ?? now;

  const rawReceipt = {
    app: "praticase",
    app_key: "praticase",
    feature_attribution: receipt.provider === "google_play"
      ? "google_play_purchase_grant"
      : "storekit_purchase_grant",
    product_code: product.code,
    store_product_id: storeProductId,
    provider: receipt.provider,
    original_transaction_id: receipt.originalTransactionId,
    environment: receipt.environment,
    ...receipt.rawReceipt,
  };
  const grantArgs = receipt.provider === "google_play"
    ? {
      p_user_id: userId,
      p_product_id: product.id,
      p_provider: "google_play",
      p_provider_transaction_id: receipt.transactionId,
      p_raw_receipt: rawReceipt,
      p_started_at: periodStart.toISOString(),
      p_expires_at: expiresAt.toISOString(),
    }
    : {
      p_user_id: userId,
      p_product_id: product.id,
      p_provider_transaction_id: receipt.transactionId,
      p_raw_receipt: rawReceipt,
      p_started_at: periodStart.toISOString(),
      p_expires_at: expiresAt.toISOString(),
    };
  const { data: grantResult, error: grantError } = await admin.rpc(
    receipt.provider === "google_play"
      ? "grant_store_product"
      : "grant_app_store_product",
    grantArgs,
  );
  if (grantError) {
    if (grantError.message.includes("Active subscription exists")) {
      const profile = await loadEffectiveWalletProfile(admin, userId);
      return jsonResponse(
        {
          status: "ok",
          entitlement: {
            active: true,
            product_code: product.code,
            product_name: product.name,
            entitlement_type: entitlementKind,
            expires_at: expiresAt.toISOString(),
            period_started_at: periodStart.toISOString(),
            transaction_id: receipt.transactionId,
            original_transaction_id: receipt.originalTransactionId,
            environment: receipt.environment,
            will_auto_renew: receipt.autoRenew,
            idempotent: true,
          },
          profile,
        },
        200,
        origin,
      );
    }
    return jsonResponse(
      { error: friendlyPurchaseGrantError(grantError.message) },
      400,
      origin,
    );
  }
  if (entitlementKind === "subscription" && receipt.provider === "app_store") {
    await saveSubscriptionLink(admin, {
      originalTransactionId: receipt.originalTransactionId,
      userId,
      productCode: stringValue(product.code),
      latestTransactionId: receipt.transactionId,
      latestPurchaseId: purchaseIdFromGrant(grantResult),
      willAutoRenew: receipt.autoRenew,
      expiresAt,
    });
  }

  recordEvent("verify_succeeded", {
    productCode: product.code,
    provider,
    environment: receipt.environment,
  });

  const profile = await loadEffectiveWalletProfile(admin, userId);

  return jsonResponse(
    {
      status: "ok",
      entitlement: {
        active: true,
        product_code: product.code,
        product_name: product.name,
        entitlement_type: entitlementKind,
        expires_at: expiresAt.toISOString(),
        period_started_at: periodStart.toISOString(),
        transaction_id: receipt.transactionId,
        original_transaction_id: receipt.originalTransactionId,
        environment: receipt.environment,
        will_auto_renew: receipt.autoRenew,
        remaining_coin_amount: numberValue(product.coin_amount) ?? 0,
        remaining_question_amount: numberValue(product.question_amount) ?? 0,
      },
      profile: profile,
    },
    200,
    origin,
  );
}

async function createPaymentCheckout(
  // deno-lint-ignore no-explicit-any
  admin: any,
  user: { id: string; email?: string | null },
  body: JsonMap,
  origin: string | null,
): Promise<Response> {
  const productCode = stringValue(body.product_code);
  if (!productCode) {
    return jsonResponse({ error: "Paket kodu eksik." }, 400, origin);
  }

  const blockedCodes = await blockedSubscriptionProductCodes(admin, user.id);
  if (blockedCodes.includes(productCode)) {
    return jsonResponse(
      { error: activeSubscriptionPurchaseMessage },
      409,
      origin,
    );
  }

  const product = await loadPaymentProduct(admin, productCode);
  if (!product) {
    return jsonResponse({ error: "Seçilen paket bulunamadı." }, 404, origin);
  }
  const apiKey = stringValue(Deno.env.get("MEDASIPAY_API_KEY"));
  if (!apiKey) {
    return jsonResponse(
      { error: "Ödeme servisi şu anda hazır değil." },
      503,
      origin,
    );
  }

  const { data: profile } = await admin
    .from("profiles")
    .select("email,first_name,last_name")
    .eq("id", user.id)
    .maybeSingle();
  const email = stringValue(profile?.email) || stringValue(user.email);
  if (!email) {
    return jsonResponse(
      { error: "Ödeme takibi için hesap e-postası gerekli." },
      400,
      origin,
    );
  }
  const name = [
    stringValue(profile?.first_name),
    stringValue(profile?.last_name),
  ].filter(Boolean).join(" ") || email;
  const priceCents = numberValue(product.price_cents) ?? 0;
  const currency = stringValue(product.currency) || "TRY";
  const snapshot = {
    id: stringValue(product.id),
    code: stringValue(product.code),
    name: stringValue(product.name),
    description: stringValue(product.description),
    price_cents: priceCents,
    currency,
    interval: stringValue(product.interval),
    coin_amount: numberValue(product.coin_amount) ?? 0,
    question_amount: numberValue(product.question_amount) ?? 0,
    entitlement_kind: stringValue(product.entitlement_kind) || "one_time",
    duration_days: numberValue(product.duration_days) ?? 0,
  };
  const checkoutPayload = {
    product: "praticase",
    channel: paymentChannel(body.channel),
    accountId: user.id,
    customerName: name,
    customerEmail: email,
    returnUrl: paymentHttpsUrl(
      Deno.env.get("PRATICASE_PAYMENT_RETURN_URL"),
      "https://praticase.medasi.com.tr/",
    ),
    webhookUrl: paymentHttpsUrl(
      Deno.env.get("PRATICASE_PAYMENT_WEBHOOK_URL"),
      "https://qlinik.medasi.com.tr/functions/v1/praticase-storekit-verify",
    ),
    currency,
    items: [
      {
        sku: snapshot.code,
        name: snapshot.name,
        quantity: 1,
        unitPrice: priceCents / 100,
        priceCents,
        currency,
        entitlementType: snapshot.entitlement_kind,
        entitlementQuantity: paymentEntitlementQuantity(snapshot),
        unit: paymentUnit(snapshot),
        metadata: snapshot,
      },
    ],
    metadata: {
      source: "praticase",
      app: "praticase",
      userId: user.id,
      userEmail: email,
      product: snapshot,
    },
  };

  const response = await fetch(
    `${paymentServiceUrl()}/api/checkout-sessions`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-MedAsi-Api-Key": apiKey,
      },
      body: JSON.stringify(checkoutPayload),
    },
  );
  const payload = await response.json().catch(() => ({})) as JsonMap;
  if (!response.ok) {
    return jsonResponse(
      { error: stringValue(payload.error) || "Ödeme oturumu oluşturulamadı." },
      response.status,
      origin,
    );
  }
  const checkout = normalizePaymentCheckoutPayload(payload);
  if (!stringValue(checkout.checkoutUrl)) {
    return jsonResponse(
      { error: "Ödeme bağlantısı alınamadı. Lütfen tekrar dene." },
      502,
      origin,
    );
  }
  return jsonResponse({ checkout, product: snapshot }, 200, origin);
}

async function redeemGiftCode(
  // deno-lint-ignore no-explicit-any
  admin: any,
  userId: string,
  body: JsonMap,
  origin: string | null,
): Promise<Response> {
  const code = normalizeGiftCode(stringValue(body.code).slice(0, 32));
  if (!code) {
    return jsonResponse(
      {
        error: "Hediye kodunu 16 karakterlik biçimiyle tekrar kontrol edelim.",
      },
      400,
      origin,
    );
  }

  const { data, error } = await admin.rpc("redeem_gift_code", {
    p_user_id: userId,
    p_code: code,
  });
  if (error) {
    return jsonResponse(
      { error: friendlyGiftCodeError(error.message) },
      400,
      origin,
    );
  }

  const redemption = isJsonMap(data) ? data : {};
  const profile = await loadEffectiveWalletProfile(admin, userId);
  return jsonResponse(
    {
      status: "ok",
      redemption: {
        ...redemption,
        profile,
        wallet_balance: numberValue(redemption.wallet_balance) ??
          numberValue(profile.wallet_balance) ?? 0,
        question_quota: numberValue(redemption.question_quota) ??
          numberValue(profile.question_quota) ?? 0,
        ai_quota: numberValue(redemption.ai_quota) ??
          numberValue(profile.ai_quota) ?? 0,
      },
      profile,
    },
    200,
    origin,
  );
}

async function handlePaymentEntitlementWebhook(
  // deno-lint-ignore no-explicit-any
  admin: any,
  request: Request,
  rawBody: string,
  body: JsonMap,
  origin: string | null,
): Promise<Response> {
  const secret = stringValue(
    Deno.env.get("MEDASIPAY_WEBHOOK_SECRET") ??
      Deno.env.get("PAYMENT_WEBHOOK_SECRET"),
  );
  if (!secret) {
    return jsonResponse({ error: "Webhook imza anahtarı eksik." }, 503, origin);
  }
  const signature = request.headers.get("X-MedAsi-Signature") ?? "";
  if (!(await verifyPaymentSignature(rawBody, signature, secret))) {
    return jsonResponse({ error: "Webhook imzası geçersiz." }, 401, origin);
  }
  if (
    stringValue(body.event) !== "payment.entitlement_granted" ||
    stringValue(body.product).toLowerCase() !== "praticase"
  ) {
    return jsonResponse({ error: "Desteklenmeyen ödeme olayı." }, 400, origin);
  }

  const userId = stringValue(body.accountId);
  const orderId = stringValue(body.orderId);
  const reference = stringValue(body.reference);
  const items = Array.isArray(body.items) ? body.items : [];
  const firstItem = isJsonMap(items[0]) ? items[0] : {};
  const productCode = stringValue(firstItem.sku ?? firstItem.code);
  if (!userId || !orderId || !productCode) {
    return jsonResponse(
      { error: "Webhook sipariş bilgisi eksik." },
      400,
      origin,
    );
  }

  const product = await loadPaymentProduct(admin, productCode);
  if (!product) {
    return jsonResponse({ error: "Seçilen paket bulunamadı." }, 404, origin);
  }
  const signedApprovedAt = new Date(stringValue(body.approvedAt));
  const periodStart = Number.isNaN(signedApprovedAt.getTime())
    ? new Date()
    : signedApprovedAt;
  const durationDays = Math.trunc(numberValue(product.duration_days) ?? 0);
  if (durationDays <= 0) {
    return jsonResponse(
      { error: "Paket geçerlilik süresi yapılandırılmamış." },
      503,
      origin,
    );
  }
  const expiresAt = new Date(
    periodStart.getTime() + durationDays * 24 * 3600 * 1000,
  );
  const { error } = await admin.rpc("grant_store_product", {
    p_user_id: userId,
    p_product_id: product.id,
    p_provider: "manual",
    p_provider_transaction_id: `medasipay:${orderId}`,
    p_status: "active",
    p_raw_receipt: {
      app: "praticase",
      provider: "medasipay",
      payment_order_id: orderId,
      reference,
      payload: body,
    },
    p_started_at: periodStart.toISOString(),
    p_expires_at: expiresAt.toISOString(),
  });
  if (error) {
    if (error.message.includes("Active subscription exists")) {
      return jsonResponse(
        {
          error: "Aktif abonelik nedeniyle ödeme hakkı tanımlanamadı.",
          status: "active_subscription_exists",
        },
        409,
        origin,
      );
    }
    return jsonResponse(
      { error: friendlyPurchaseGrantError(error.message) },
      400,
      origin,
    );
  }

  recordEvent("medasipay_entitlement_granted", {
    productCode,
    orderId,
    alreadyActive: false,
  });
  return jsonResponse(
    {
      status: "ok",
      profile: await loadEffectiveWalletProfile(admin, userId),
    },
    200,
    origin,
  );
}

async function loadCatalogPayload(
  // deno-lint-ignore no-explicit-any
  admin: any,
  userId: string,
  body: JsonMap = {},
): Promise<JsonMap> {
  const products = await loadMappedCatalog(
    admin,
    normalizeStoreProvider(body.store_provider ?? body.provider),
  );
  const blockedProductCodes = await blockedSubscriptionProductCodes(
    admin,
    userId,
  );
  const profile = await loadEffectiveWalletProfile(admin, userId);
  const warnings = await walletExpiryWarnings(admin, userId);
  // Aktif aboneliği olan paketleri katalogda tutuyoruz; UI bunları "Aktif"
  // rozeti ile devre dışı gösterir. Sunucu tarafı satın alma denemesini yine
  // `blockedSubscriptionCodes` ile 409 reddeder — savunma çift katmanlı.
  return {
    products: products ?? [],
    blocked_product_codes: blockedProductCodes,
    wallet_warnings: warnings,
    profile,
    // Sadece katalog gerçekten erişilemediyse warning olarak işaretle —
    // top-level `error` kullanmıyoruz çünkü o tüm response'u hata sayar
    // ve UI bakiyeyi de göstermez.
    ...(products == null ? { catalog_unavailable: true } : {}),
  };
}

/// Qlinik ile aynı kanonik MC + soru bakiyesini döner.
///
/// Ortak `sync_wallet_profile` RPC'si aktif ve süresi dolmamış
/// `wallet_entitlements` toplamını canlı hesaplar; `profiles` mirror'ı sadece
/// RPC yanıtında olmayan alanlar için kullanılır.
async function loadEffectiveWalletProfile(
  // deno-lint-ignore no-explicit-any
  admin: any,
  userId: string,
): Promise<JsonMap> {
  let syncedProfile: JsonMap = {};
  try {
    const { data: sync, error: syncError } = await admin.rpc(
      "sync_wallet_profile",
      { p_user_id: userId },
    );
    if (syncError) {
      recordEvent("sync_wallet_profile_failed", {
        message: syncError.message,
      });
    } else if (isJsonMap(sync)) {
      syncedProfile = sync;
    }
  } catch (error) {
    recordEvent("sync_wallet_profile_failed", {
      message: errorMessage(error),
    });
  }

  try {
    const { data: profile, error } = await admin
      .from("profiles")
      .select("wallet_balance,question_quota,ai_quota")
      .eq("id", userId)
      .maybeSingle();
    if (error) {
      recordEvent("wallet_profile_snapshot_failed", {
        message: error.message,
      });
    }
    return walletProfileSnapshot(
      syncedProfile,
      isJsonMap(profile) ? profile : {},
    );
  } catch (error) {
    recordEvent("wallet_profile_snapshot_failed", {
      message: errorMessage(error),
    });
    return walletProfileSnapshot(syncedProfile);
  }
}

function walletProfileSnapshot(
  syncedProfile: JsonMap,
  profile: JsonMap = {},
): JsonMap {
  return {
    wallet_balance: numberValue(syncedProfile.wallet_balance) ??
      numberValue(profile.wallet_balance) ?? 0,
    question_quota: Math.round(
      numberValue(syncedProfile.question_quota) ??
        numberValue(profile.question_quota) ?? 0,
    ),
    ai_quota: Math.round(
      numberValue(syncedProfile.ai_quota) ??
        numberValue(profile.ai_quota) ?? 0,
    ),
  };
}

function normalizeGiftCode(value: string) {
  const code = stringValue(value).toUpperCase().replace(/[^A-Z0-9]/g, "");
  return code.length === 16 ? code : "";
}

function friendlyGiftCodeError(message: string) {
  if (message.includes("already redeemed")) {
    return "Bu hediye kodu hesabında zaten kullanılmış.";
  }
  if (message.includes("expired")) {
    return "Bu hediye kodunun süresi dolmuş.";
  }
  if (message.includes("exhausted")) {
    return "Bu hediye kodunun kullanım hakkı tükenmiş.";
  }
  if (message.includes("inactive") || message.includes("not found")) {
    return "Bu hediye kodunu doğrulayamadık. Harf ve rakamları tekrar kontrol edelim.";
  }
  return "Hediye kodu şu an işlenemedi. Biraz sonra tekrar deneyelim.";
}

async function loadMappedCatalog(
  // deno-lint-ignore no-explicit-any
  admin: any,
  provider: StoreProvider = "app_store",
): Promise<JsonMap[] | null> {
  const mappedIds = await loadStoreProductMappings(admin, provider);
  const products = await loadSharedStoreProducts(admin);
  if (products == null) return null;
  return (products ?? []).map((product: JsonMap) => ({
    ...product,
    app_store_product_id: mappedIds.get(stringValue(product.code)) ||
      stringValue(product.app_store_product_id),
  }));
}

async function loadMappedProduct(
  // deno-lint-ignore no-explicit-any
  admin: any,
  productCode: string,
  storeProductId: string,
  provider: StoreProvider = "app_store",
): Promise<JsonMap | null> {
  const mappedProduct = await loadMappedProductByOverride(
    admin,
    productCode,
    storeProductId,
    provider,
  );
  if (mappedProduct) return mappedProduct;

  const products = await loadSharedStoreProducts(admin);
  const product = (products ?? []).find((item) =>
    stringValue(item.code) === productCode &&
    stringValue(item.app_store_product_id) === storeProductId
  );
  return product ?? null;
}

async function loadPaymentProduct(
  // deno-lint-ignore no-explicit-any
  admin: any,
  productCode: string,
): Promise<JsonMap | null> {
  const { data, error } = await admin
    .from("store_products")
    .select(
      "id,code,name,description,price_cents,currency,interval,coin_amount,question_amount,entitlement_kind,duration_days",
    )
    .eq("code", productCode)
    .eq("is_active", true)
    .maybeSingle();
  return error || !data ? null : data as JsonMap;
}

async function loadMappedProductByOverride(
  // deno-lint-ignore no-explicit-any
  admin: any,
  productCode: string,
  storeProductId: string,
  provider: StoreProvider = "app_store",
): Promise<JsonMap | null> {
  const storeIdColumn = provider === "google_play"
    ? "google_play_product_id"
    : "app_store_product_id";
  const { data: mapping, error: mappingError } = await admin
    .schema("praticase")
    .from("store_product_app_mappings")
    .select(`product_code,${storeIdColumn}`)
    .eq("product_code", productCode)
    .eq(storeIdColumn, storeProductId)
    .eq("is_active", true)
    .maybeSingle();
  if (mappingError || !mapping) return null;
  const { data: product, error } = await admin
    .from("store_products")
    .select(
      "id,code,name,price_cents,currency,interval,coin_amount,question_amount,entitlement_kind,duration_days",
    )
    .eq("code", productCode)
    .eq("is_active", true)
    .maybeSingle();
  return error || !product ? null : product as JsonMap;
}

async function loadStoreProductMappings(
  // deno-lint-ignore no-explicit-any
  admin: any,
  provider: StoreProvider = "app_store",
): Promise<Map<string, string>> {
  const storeIdColumn = provider === "google_play"
    ? "google_play_product_id"
    : "app_store_product_id";
  const { data: mappings, error } = await admin
    .schema("praticase")
    .from("store_product_app_mappings")
    .select(`product_code,${storeIdColumn}`)
    .eq("is_active", true);
  if (error) {
    if (
      provider === "google_play" && isMissingGooglePlayProductIdColumn(error)
    ) {
      return new Map();
    }
    return new Map();
  }
  return new Map(
    ((mappings ?? []) as JsonMap[])
      .map((mapping) =>
        [
          stringValue(mapping.product_code),
          stringValue(mapping[storeIdColumn]),
        ] as const
      )
      .filter(([code, storeId]) => code && storeId),
  );
}

/// Qlinik ile aynı `public.store_products` kataloğunu okur.
///
/// Defansif fallback zinciri:
///   1. Tam kolon seti (`...,app_store_product_id`) ile dene.
///   2. Hata "kolon yok" değilse, `is_active` filtresini kaldır
///      (legacy kayıtlarda `is_active` NULL olabilir → Qlinik'te görünür,
///      PratiCase'de "yüklenemedi"ye düşerdi).
///   3. Hâlâ hata varsa minimum kolon seti ile dene.
///   4. Tüm aşamalarda hata server log'una yazılır → telemetry için.
async function loadSharedStoreProducts(
  // deno-lint-ignore no-explicit-any
  admin: any,
): Promise<JsonMap[] | null> {
  const baseColumns =
    "id,code,name,description,price_cents,original_price_cents,currency,interval,features,is_featured,coin_amount,question_amount,badge,entitlement_kind,duration_days,sort_order";
  const withSharedStoreId = `${baseColumns},app_store_product_id`;

  // Adım 1: tam kolon + is_active filtresi.
  const fullActive = await loadSharedStoreProductsWithColumns(
    admin,
    withSharedStoreId,
    { onlyActive: true },
  );
  if (fullActive.products != null && fullActive.products.length > 0) {
    return fullActive.products;
  }

  // Adım 2: kolon hatasıysa minimuma düş.
  let columns = withSharedStoreId;
  let lastError = fullActive.error;
  if (lastError != null && isMissingStoreProductIdColumn(lastError)) {
    columns = baseColumns;
  }

  // Adım 3: is_active filtresi olmadan dene (legacy NULL kayıtları kurtar).
  const withoutFilter = await loadSharedStoreProductsWithColumns(
    admin,
    columns,
    { onlyActive: false },
  );
  if (withoutFilter.products != null && withoutFilter.products.length > 0) {
    recordEvent("catalog_loaded_without_active_filter", {});
    // Aktif olanları client'ta filtreleme — null da geçer.
    return withoutFilter.products.filter((p) => p.is_active !== false);
  }
  if (withoutFilter.error != null) lastError = withoutFilter.error;

  // Adım 4: minimum kolon + filtresiz, son şans.
  const minimal = await loadSharedStoreProductsWithColumns(
    admin,
    baseColumns,
    { onlyActive: false },
  );
  if (minimal.products != null && minimal.products.length > 0) {
    recordEvent("catalog_loaded_minimal_columns", {});
    return minimal.products.filter((p) => p.is_active !== false);
  }

  if (minimal.error != null || lastError != null) {
    recordEvent("catalog_query_failed", {
      message: errorMessage(minimal.error ?? lastError),
    });
    return null;
  }

  // Tüm sorgular boş döndü — gerçekten ürün yok.
  return [];
}

async function loadSharedStoreProductsWithColumns(
  // deno-lint-ignore no-explicit-any
  admin: any,
  columns: string,
  options: { onlyActive: boolean } = { onlyActive: true },
): Promise<{ products: JsonMap[] | null; error: unknown }> {
  let query = admin.from("store_products").select(columns);
  if (options.onlyActive) {
    query = query.eq("is_active", true);
  }
  const { data, error } = await query
    .order("sort_order", { nullsFirst: false })
    .order("price_cents");
  return { products: error ? null : ((data ?? []) as JsonMap[]), error };
}

async function loadWalletTransactionsPayload(
  // deno-lint-ignore no-explicit-any
  admin: any,
  userId: string,
): Promise<JsonMap> {
  // Read all entitlements for the user (subscriptions + one-time purchases)
  // and map each row to a transaction-style event. This avoids requiring a
  // dedicated wallet_transactions table while still surfacing real purchases.
  const { data: rows, error } = await admin
    .from("wallet_entitlements")
    .select(
      "product_code,entitlement_type,status,original_coin_amount,original_question_amount,remaining_coin_amount,remaining_question_amount,period_started_at,expires_at,created_at",
    )
    .eq("user_id", userId)
    .order("period_started_at", { ascending: false })
    .limit(50);
  if (error) {
    return { error: "İşlem geçmişi şu anda yüklenemedi." };
  }
  const entries = (rows ?? []) as JsonMap[];
  const productCodes = Array.from(
    new Set(
      entries.map((row) => stringValue(row.product_code)).filter(Boolean),
    ),
  );
  const nameMap = new Map<string, string>();
  if (productCodes.length > 0) {
    const { data: products } = await admin
      .from("store_products")
      .select("code,name")
      .in("code", productCodes);
    for (const product of (products ?? []) as JsonMap[]) {
      nameMap.set(stringValue(product.code), stringValue(product.name));
    }
  }
  const transactions = entries.map((row) => {
    const code = stringValue(row.product_code);
    const productName = code === "gift_code"
      ? "Hediye kodu"
      : nameMap.get(code) || code || "PratiCase paketi";
    const coin = numberValue(row.original_coin_amount) ?? 0;
    const question = numberValue(row.original_question_amount) ?? 0;
    const status = stringValue(row.status) || "active";
    const expiresIso = stringValue(row.expires_at);
    const expired = expiresIso
      ? new Date(expiresIso).getTime() < Date.now()
      : false;
    return {
      id: `${code}-${
        stringValue(row.period_started_at) || stringValue(row.created_at)
      }`,
      kind: stringValue(row.entitlement_type) || "purchase",
      product_code: code,
      product_name: productName,
      coin_amount: coin,
      question_amount: question,
      remaining_coin_amount: numberValue(row.remaining_coin_amount) ?? 0,
      remaining_question_amount: numberValue(row.remaining_question_amount) ??
        0,
      status,
      expired,
      occurred_at: stringValue(row.period_started_at) ||
        stringValue(row.created_at),
      expires_at: expiresIso,
    };
  });
  const { data: usageRows, error: usageError } = await admin
    .from("ai_usage_events")
    .select("id,feature,charged_coin_amount,created_at")
    .eq("user_id", userId)
    .gt("charged_coin_amount", 0)
    .order("created_at", { ascending: false })
    .limit(50);
  if (usageError) {
    recordEvent("wallet_usage_events_failed", { message: usageError.message });
  }
  const usageTransactions = ((usageRows ?? []) as JsonMap[]).map((row) => {
    const feature = stringValue(row.feature);
    const amount = numberValue(row.charged_coin_amount) ?? 0;
    return {
      id: stringValue(row.id) || `${feature}-${stringValue(row.created_at)}`,
      kind: "usage",
      product_code: feature,
      product_name: aiUsageLabel(feature),
      coin_amount: -amount,
      question_amount: 0,
      remaining_coin_amount: 0,
      remaining_question_amount: 0,
      status: "consumed",
      expired: false,
      occurred_at: stringValue(row.created_at),
      expires_at: "",
    };
  });
  return {
    transactions: [...transactions, ...usageTransactions]
      .sort((left, right) =>
        transactionTime(right).localeCompare(transactionTime(left))
      )
      .slice(0, 50),
  };
}

async function loadSubscriptionPayload(
  // deno-lint-ignore no-explicit-any
  admin: any,
  userId: string,
): Promise<JsonMap> {
  const { data: rows, error } = await admin
    .from("wallet_entitlements")
    .select(
      "product_code,entitlement_type,status,remaining_coin_amount,remaining_question_amount,period_started_at,expires_at",
    )
    .eq("user_id", userId)
    .eq("entitlement_type", "subscription")
    .eq("status", "active")
    .gt("expires_at", new Date().toISOString())
    .order("expires_at", { ascending: false })
    .limit(1);
  if (error) return { error: "Abonelik bilgisi şu anda yüklenemedi." };

  const row = rows?.[0] as JsonMap | undefined;
  let productName = "";
  let willAutoRenew = true;
  if (row) {
    const { data: product } = await admin
      .from("store_products")
      .select("name")
      .eq("code", stringValue(row.product_code))
      .maybeSingle();
    productName = stringValue(product?.name);
    // will_auto_renew önceliği:
    //   1. praticase.app_store_subscription_links (PratiCase'in kendi
    //      satın aldığı abonelik için Apple notification'larından gelir)
    //   2. public.app_store_subscription_links (Qlinik'in mobil
    //      satın aldığı abonelik için — varsa)
    //   3. Default true (server-side bilinmiyorsa Apple "yenilenecek"
    //      kabul edilir; iptal bilgisi gelince false olur)
    const { data: pratiLink } = await admin
      .schema("praticase")
      .from("app_store_subscription_links")
      .select("will_auto_renew")
      .eq("user_id", userId)
      .eq("product_code", stringValue(row.product_code))
      .order("updated_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    if (pratiLink?.will_auto_renew === false) {
      willAutoRenew = false;
    } else if (pratiLink == null) {
      // PratiCase'de link yok → Qlinik veya başka bir Medasi uygulamasından
      // satın alınmış olabilir. public şemada paylaşılan link tablosunu
      // dene; yoksa hata sessizce yutulur ve default kullanılır.
      try {
        const { data: sharedLink } = await admin
          .from("app_store_subscription_links")
          .select("will_auto_renew")
          .eq("user_id", userId)
          .eq("product_code", stringValue(row.product_code))
          .order("updated_at", { ascending: false })
          .limit(1)
          .maybeSingle();
        if (sharedLink?.will_auto_renew === false) willAutoRenew = false;
      } catch (_) {
        // Paylaşılan Apple link tablosu bu kurulumda yoksa yenileme durumu
        // bilinmiyor kabul edilir; cüzdan bakiyesi yine canlı kalır.
      }
    }
  }
  // Ortak entitlement toplamı, Qlinik ile aynı canlı RPC üzerinden okunur.
  const profile = await loadEffectiveWalletProfile(admin, userId);
  return {
    entitlement: row
      ? {
        active: true,
        product_code: row.product_code,
        product_name: productName || "PratiCase Premium",
        expires_at: row.expires_at,
        period_started_at: row.period_started_at,
        will_auto_renew: willAutoRenew,
        remaining_coin_amount: row.remaining_coin_amount,
        remaining_question_amount: row.remaining_question_amount,
      }
      : { active: false },
    warnings: await walletExpiryWarnings(admin, userId),
    profile: profile,
  };
}

async function walletExpiryWarnings(
  // deno-lint-ignore no-explicit-any
  admin: any,
  userId: string,
): Promise<string[]> {
  const now = new Date();
  const windowEnd = new Date(now.getTime() + 3 * 24 * 60 * 60 * 1000);
  const { data, error } = await admin
    .from("wallet_entitlements")
    .select("product_code,expires_at")
    .eq("user_id", userId)
    .eq("status", "active")
    .eq("entitlement_type", "subscription")
    .gt("expires_at", now.toISOString())
    .lte("expires_at", windowEnd.toISOString())
    .order("expires_at", { ascending: true })
    .limit(3);
  if (error) return [];
  return ((data ?? []) as JsonMap[]).map((row) => {
    const expiresAt = Date.parse(stringValue(row.expires_at));
    const days = Math.max(
      1,
      Math.ceil((expiresAt - now.getTime()) / (24 * 60 * 60 * 1000)),
    );
    const product = stringValue(row.product_code) === "weekly_subscription"
      ? "Haftalık paket"
      : "Aylık paket";
    const deadline = days === 1 ? "24 saat içinde" : `${days} gün içinde`;
    return `${product} süren ${deadline} doluyor.`;
  });
}

async function blockedSubscriptionProductCodes(
  // deno-lint-ignore no-explicit-any
  admin: any,
  userId: string,
): Promise<string[]> {
  const { data, error } = await admin
    .from("wallet_entitlements")
    .select("product_code,purchase_id")
    .eq("user_id", userId)
    .eq("status", "active")
    .eq("entitlement_type", "subscription")
    .gt("expires_at", new Date().toISOString());
  if (error) {
    recordEvent("subscription_blocks_failed", { message: error.message });
    return [];
  }

  const entitlements = (data ?? []) as JsonMap[];
  const purchaseIds = [
    ...new Set(
      entitlements.map((row) => stringValue(row.purchase_id)).filter(Boolean),
    ),
  ];
  const sourceApps = new Map<string, string>();
  if (purchaseIds.length > 0) {
    const { data: purchases, error: purchaseError } = await admin
      .from("purchases")
      .select("id,raw_receipt")
      .in("id", purchaseIds);
    if (purchaseError) {
      recordEvent("subscription_purchase_sources_failed", {
        message: purchaseError.message,
      });
    } else {
      for (const purchase of (purchases ?? []) as JsonMap[]) {
        const receipt = isJsonMap(purchase.raw_receipt)
          ? purchase.raw_receipt
          : {};
        sourceApps.set(
          stringValue(purchase.id),
          stringValue(receipt.app_key ?? receipt.app) || "qlinik",
        );
      }
    }
  }
  const scopedEntitlements = sourceApps.size === 0 && purchaseIds.length > 0
    ? entitlements
    : entitlements.filter((row) =>
      (sourceApps.get(stringValue(row.purchase_id)) || "qlinik") === "praticase"
    );
  const activeCodes = new Set(
    scopedEntitlements
      .map((row) => stringValue(row.product_code))
      .filter(Boolean),
  );
  const blocked = new Set<string>();
  if (activeCodes.has("weekly_subscription")) {
    blocked.add("weekly_subscription");
  }
  if (activeCodes.has("monthly_subscription")) {
    blocked.add("weekly_subscription");
    blocked.add("monthly_subscription");
  }
  for (const code of activeCodes) {
    if (code.endsWith("_subscription") && code !== "weekly_subscription") {
      blocked.add(code);
    }
  }
  return [...blocked].sort();
}

function friendlyPurchaseGrantError(message: string): string {
  if (message.includes("Active subscription exists")) {
    return activeSubscriptionPurchaseMessage;
  }
  if (message.includes("duplicate key") || message.includes("already")) {
    return "Bu App Store işlemi daha önce işlendi. Bakiyeni yenileyip kontrol edebilirsin.";
  }
  return "Paket hakkın şu anda etkinleştirilemedi. Lütfen tekrar dene.";
}

function paymentChannel(value: unknown): string {
  return stringValue(value).toLowerCase() === "android" ? "android" : "web";
}

function normalizePaymentCheckoutPayload(payload: JsonMap): JsonMap {
  const checkoutUrl = paymentCheckoutUrl(payload);
  const trackingUrl = stringValue(payload.trackingUrl) ||
    stringValue(payload.tracking_url);
  return {
    ...payload,
    checkoutUrl,
    checkout_url: checkoutUrl,
    trackingUrl,
    tracking_url: trackingUrl,
  };
}

function paymentCheckoutUrl(payload: JsonMap): string {
  const rawUrl = paymentCheckoutUrlCandidate(payload);
  if (!rawUrl) return "";
  try {
    const url = new URL(rawUrl, paymentServiceUrl());
    if (url.protocol === "https:" || isLocalHttpPaymentUrl(url)) {
      return url.toString();
    }
  } catch (_) {
    return "";
  }
  return "";
}

function paymentHttpsUrl(value: unknown, fallback: string): string {
  const candidate = stringValue(value) || fallback;
  try {
    const url = new URL(candidate);
    if (url.protocol === "https:") return url.toString();
  } catch (_) {
    // Use the public HTTPS fallback below.
  }
  return fallback;
}

function paymentCheckoutUrlCandidate(payload: JsonMap): string {
  for (
    const key of [
      "checkoutUrl",
      "checkout_url",
      "paymentUrl",
      "payment_url",
      "redirectUrl",
      "redirect_url",
      "url",
    ]
  ) {
    const value = stringValue(payload[key]);
    if (value) return value;
  }
  for (const key of ["checkout", "session", "data"]) {
    const value = payload[key];
    if (isJsonMap(value)) {
      const nested = paymentCheckoutUrlCandidate(value);
      if (nested) return nested;
    }
  }
  return "";
}

function isLocalHttpPaymentUrl(url: URL): boolean {
  return url.protocol === "http:" &&
    (url.hostname === "localhost" || url.hostname === "127.0.0.1" ||
      url.hostname === "[::1]" || url.hostname === "::1");
}

function paymentUnit(product: JsonMap): string {
  if (stringValue(product.entitlement_kind) === "subscription") {
    return "abonelik";
  }
  if ((numberValue(product.question_amount) ?? 0) > 0) return "soru hakkı";
  if ((numberValue(product.coin_amount) ?? 0) > 0) return "Medasi Coin";
  return "paket";
}

function paymentEntitlementQuantity(product: JsonMap): number {
  const questionAmount = numberValue(product.question_amount) ?? 0;
  if (questionAmount > 0) return questionAmount;
  const coinAmount = numberValue(product.coin_amount) ?? 0;
  if (coinAmount > 0) return coinAmount;
  return 1;
}

function paymentServiceUrl(): string {
  const value = Deno.env.get("MEDASIPAY_API_URL") ??
    Deno.env.get("MEDASI_PAYMENT_API_URL") ??
    "https://odeme.medasi.com.tr";
  const url = new URL(value);
  if (url.protocol !== "https:" && url.hostname !== "localhost") {
    throw new Error("MEDASIPAY_API_URL must use HTTPS.");
  }
  return url.toString().replace(/\/+$/, "");
}

async function verifyPaymentSignature(
  rawBody: string,
  signatureHeader: string,
  secret: string,
): Promise<boolean> {
  const provided = stringValue(signatureHeader).replace(/^sha256=/i, "");
  if (!/^[0-9a-f]{64}$/i.test(provided)) return false;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signed = new Uint8Array(
    await crypto.subtle.sign(
      "HMAC",
      key,
      new TextEncoder().encode(rawBody),
    ),
  );
  const expected = [...signed]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
  let difference = 0;
  for (let index = 0; index < expected.length; index += 1) {
    difference |= expected.charCodeAt(index) ^ provided.charCodeAt(index);
  }
  return difference === 0;
}

function aiUsageLabel(feature: string): string {
  switch (feature) {
    case "praticase-patient-turn":
      return "Sanal hasta görüşmesi";
    case "praticase-complete-session":
      return "AI sonuç karnesi";
    case "praticase-oral-exam-start":
      return "Sözlü sınav başlangıcı";
    case "praticase-oral-exam-turn":
      return "Sözlü sınav yanıtı";
    case "praticase-oral-exam-skip":
      return "Sözlü sınav geçişi";
    case "praticase-oral-exam-finalize":
      return "Sözlü sınav karnesi";
    case "mentor-chat":
      return "Qlinik Mentor AI";
    case "question-solution":
      return "Qlinik soru desteği";
    case "mentor-plan":
      return "Qlinik mentor planı";
    default:
      return "Medasi AI kullanımı";
  }
}

function transactionTime(transaction: JsonMap): string {
  return stringValue(transaction.occurred_at);
}

async function handleAppStoreNotification(
  // deno-lint-ignore no-explicit-any
  admin: any,
  signedPayload: string,
  origin: string | null,
): Promise<Response> {
  try {
    const verifierConfig = loadVerifierConfiguration();
    const notification = await verifyNotificationPayload(signedPayload);
    const notificationType = stringValue(notification.notificationType);
    if (notificationType === "TEST") {
      return jsonResponse({ status: "ok" }, 200, origin);
    }
    const notificationUuid = stringValue(notification.notificationUUID);
    const notificationData = (notification.data as JsonMap | undefined) ?? {};

    const signedTransaction = stringValue(
      notificationData.signedTransactionInfo,
    );
    if (!signedTransaction) {
      return jsonResponse({ status: "ignored" }, 200, origin);
    }
    const transaction = await verifyAndDecodeAppleJws(
      signedTransaction,
      verifierConfig,
    );
    const storeProductId = stringValue(transaction.productId);
    const originalTransactionId = stringValue(
      transaction.originalTransactionId ?? transaction.transactionId,
    );
    if (!storeProductId || !originalTransactionId) {
      return jsonResponse({ status: "ignored" }, 200, origin);
    }

    const product = await loadProductByStoreId(admin, storeProductId);
    if (!product) return jsonResponse({ status: "ignored" }, 200, origin);
    const { data: link } = await admin
      .schema("praticase")
      .from("app_store_subscription_links")
      .select("user_id,product_code")
      .eq("original_transaction_id", originalTransactionId)
      .maybeSingle();
    if (!link) return jsonResponse({ status: "ignored" }, 200, origin);

    let willAutoRenew = true;
    const signedRenewal = stringValue(notificationData.signedRenewalInfo);
    if (signedRenewal) {
      const renewal = await verifyAndDecodeAppleJws(
        signedRenewal,
        verifierConfig,
      );
      willAutoRenew = renewal.autoRenewStatus !== 0;
    }

    const inactiveTypes = new Set([
      "EXPIRED",
      "GRACE_PERIOD_EXPIRED",
      "REFUND",
      "REVOKE",
    ]);
    const activeTypes = new Set([
      "SUBSCRIBED",
      "DID_RENEW",
      "OFFER_REDEEMED",
      "REFUND_REVERSED",
    ]);
    if (inactiveTypes.has(notificationType)) {
      await closePratiCasePurchases(
        admin,
        stringValue(link.user_id),
        stringValue(product.id),
        notificationType === "REFUND" || notificationType === "REVOKE"
          ? "refunded"
          : "expired",
      );
      await saveSubscriptionLink(admin, {
        originalTransactionId,
        userId: stringValue(link.user_id),
        productCode: stringValue(product.code),
        latestTransactionId: stringValue(transaction.transactionId) ||
          originalTransactionId,
        willAutoRenew: false,
        expiresAt: dateFromMilliseconds(transaction.expiresDate),
        notificationUuid,
      });
    } else if (activeTypes.has(notificationType)) {
      const transactionId = stringValue(transaction.transactionId);
      if (!transactionId || transaction.revocationDate != null) {
        throw new Error("Notification transaction is not active");
      }
      const expiresAt = dateFromMilliseconds(transaction.expiresDate) ??
        new Date();
      const periodStart = dateFromMilliseconds(transaction.purchaseDate) ??
        new Date();
      const { data: grantResult, error: grantError } = await admin.rpc(
        "grant_app_store_product",
        {
          p_user_id: link.user_id,
          p_product_id: product.id,
          p_provider_transaction_id: transactionId,
          p_raw_receipt: {
            app: "praticase",
            app_key: "praticase",
            feature_attribution: "storekit_subscription_notification",
            event: notificationType,
            notification_uuid: notificationUuid,
            store_product_id: storeProductId,
            original_transaction_id: originalTransactionId,
          },
          p_started_at: periodStart.toISOString(),
          p_expires_at: expiresAt.toISOString(),
        },
      );
      if (grantError) throw grantError;
      await saveSubscriptionLink(admin, {
        originalTransactionId,
        userId: stringValue(link.user_id),
        productCode: stringValue(product.code),
        latestTransactionId: transactionId,
        latestPurchaseId: purchaseIdFromGrant(grantResult),
        willAutoRenew,
        expiresAt,
        notificationUuid,
      });
    } else {
      await saveSubscriptionLink(admin, {
        originalTransactionId,
        userId: stringValue(link.user_id),
        productCode: stringValue(product.code),
        latestTransactionId: stringValue(transaction.transactionId) ||
          originalTransactionId,
        willAutoRenew,
        expiresAt: dateFromMilliseconds(transaction.expiresDate),
        notificationUuid,
      });
    }
    return jsonResponse({ status: "ok" }, 200, origin);
  } catch (_) {
    return jsonResponse(
      { error: "Bildirim şu anda işlenemedi." },
      500,
      origin,
    );
  }
}

async function loadProductByStoreId(
  // deno-lint-ignore no-explicit-any
  admin: any,
  storeProductId: string,
): Promise<JsonMap | null> {
  const { data: mapping, error } = await admin
    .schema("praticase")
    .from("store_product_app_mappings")
    .select("product_code")
    .eq("app_store_product_id", storeProductId)
    .eq("is_active", true)
    .maybeSingle();
  if (!error && mapping) {
    const { data: product } = await admin
      .from("store_products")
      .select("id,code")
      .eq("code", stringValue(mapping.product_code))
      .eq("is_active", true)
      .maybeSingle();
    if (product) return product as JsonMap;
  }

  const products = await loadSharedStoreProducts(admin);
  return (products ?? []).find((item) =>
    stringValue(item.app_store_product_id) === storeProductId
  ) ?? null;
}

async function saveSubscriptionLink(
  // deno-lint-ignore no-explicit-any
  admin: any,
  values: {
    originalTransactionId: string;
    userId: string;
    productCode: string;
    latestTransactionId: string;
    latestPurchaseId?: string;
    willAutoRenew: boolean;
    expiresAt: Date | null;
    notificationUuid?: string;
  },
) {
  await admin.schema("praticase").from("app_store_subscription_links").upsert({
    original_transaction_id: values.originalTransactionId,
    user_id: values.userId,
    product_code: values.productCode,
    latest_transaction_id: values.latestTransactionId,
    latest_purchase_id: values.latestPurchaseId || null,
    will_auto_renew: values.willAutoRenew,
    expires_at: values.expiresAt?.toISOString() ?? null,
    latest_notification_uuid: values.notificationUuid || null,
    updated_at: new Date().toISOString(),
  }, { onConflict: "original_transaction_id" });
}

async function closePratiCasePurchases(
  // deno-lint-ignore no-explicit-any
  admin: any,
  userId: string,
  productId: string,
  status: "expired" | "refunded",
) {
  const { data: purchases, error } = await admin
    .from("purchases")
    .select("id,raw_receipt")
    .eq("user_id", userId)
    .eq("product_id", productId)
    .eq("provider", "app_store")
    .eq("status", "active");
  if (error) throw error;
  for (const purchase of purchases ?? []) {
    const rawReceipt = purchase.raw_receipt as JsonMap | undefined;
    if (stringValue(rawReceipt?.app) !== "praticase") continue;
    const { error: statusError } = await admin.rpc("set_purchase_status", {
      p_purchase_id: purchase.id,
      p_status: status,
    });
    if (statusError) throw statusError;
  }
}

function purchaseIdFromGrant(value: unknown): string {
  if (Array.isArray(value)) value = value[0];
  return value && typeof value === "object"
    ? stringValue((value as JsonMap).purchase_id)
    : "";
}

async function verifyApplePurchase(values: {
  storeProductId: string;
  purchaseId: string;
  serverPayload: string;
  source: string;
}): Promise<StoreReceipt> {
  if (
    values.source !== "app_store" ||
    !values.serverPayload ||
    !values.purchaseId
  ) {
    throw new Error("Apple purchase payload is incomplete");
  }
  const receipt = await verifyPurchase(
    values.serverPayload,
    values.purchaseId,
    values.storeProductId,
  );
  return {
    ...receipt,
    provider: "app_store",
    rawReceipt: {},
  };
}

async function verifyGooglePlayPurchase(values: {
  product: JsonMap;
  storeProductId: string;
  purchaseToken: string;
  purchaseId: string;
}): Promise<StoreReceipt> {
  if (!values.purchaseToken) {
    throw new Error("Google Play purchase token is missing");
  }
  const entitlementKind = stringValue(values.product.entitlement_kind);
  const interval = stringValue(values.product.interval).toLowerCase();
  const isSubscription = entitlementKind === "subscription" ||
    ["week", "month", "year"].includes(interval);
  return isSubscription
    ? await verifyGooglePlaySubscription(values)
    : await verifyGooglePlayOneTimeProduct(values);
}

async function verifyGooglePlayOneTimeProduct(values: {
  storeProductId: string;
  purchaseToken: string;
  purchaseId: string;
}): Promise<StoreReceipt> {
  const payload = await fetchGooglePlayPublisher(
    `purchases/products/${encodeURIComponent(values.storeProductId)}/tokens/${
      encodeURIComponent(values.purchaseToken)
    }`,
  );
  const purchaseState = numberValue(payload.purchaseState) ?? -1;
  if (purchaseState !== 0) {
    throw new Error(`Google Play purchase is not completed: ${purchaseState}`);
  }
  const tokenHash = await sha256Hex(values.purchaseToken);
  const orderId = stringValue(payload.orderId);
  const transactionId = orderId || values.purchaseId ||
    `google_play:${tokenHash}`;
  return {
    status: 0,
    provider: "google_play",
    environment: googlePlayEnvironment(payload),
    transactionId,
    originalTransactionId: transactionId,
    expiresAt: null,
    periodStartedAt: dateFromMilliseconds(payload.purchaseTimeMillis),
    autoRenew: false,
    rawReceipt: {
      google_play_purchase_token_hash: tokenHash,
      order_id: orderId,
      purchase_state: purchaseState,
      acknowledgement_state: numberValue(payload.acknowledgementState),
      consumption_state: numberValue(payload.consumptionState),
      purchase_type: numberValue(payload.purchaseType),
      region_code: stringValue(payload.regionCode),
    },
  };
}

async function verifyGooglePlaySubscription(values: {
  storeProductId: string;
  purchaseToken: string;
  purchaseId: string;
}): Promise<StoreReceipt> {
  const payload = await fetchGooglePlayPublisher(
    `purchases/subscriptionsv2/tokens/${
      encodeURIComponent(values.purchaseToken)
    }`,
  );
  const state = stringValue(payload.subscriptionState);
  const lineItems = Array.isArray(payload.lineItems)
    ? payload.lineItems as JsonMap[]
    : [];
  const matchingLine =
    lineItems.find((line) =>
      stringValue(line.productId) === values.storeProductId
    ) ?? lineItems[0];
  if (!matchingLine) {
    throw new Error("Google Play subscription line item is missing");
  }
  const expiresAt = dateFromIso(stringValue(matchingLine.expiryTime));
  const now = Date.now();
  const hasActiveWindow = expiresAt == null || expiresAt.getTime() > now;
  const allowedStates = new Set([
    "SUBSCRIPTION_STATE_ACTIVE",
    "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
    "SUBSCRIPTION_STATE_CANCELED",
  ]);
  if (!allowedStates.has(state) || !hasActiveWindow) {
    throw new Error(`Google Play subscription is not active: ${state}`);
  }
  const autoRenewingPlan = isJsonMap(matchingLine.autoRenewingPlan)
    ? matchingLine.autoRenewingPlan
    : {};
  const tokenHash = await sha256Hex(values.purchaseToken);
  const linkedToken = stringValue(payload.linkedPurchaseToken);
  const linkedTokenHash = linkedToken ? await sha256Hex(linkedToken) : "";
  const orderId = stringValue(payload.latestOrderId);
  const transactionId = orderId || values.purchaseId ||
    `google_play:${tokenHash}`;
  return {
    status: 0,
    provider: "google_play",
    environment: googlePlayEnvironment(payload),
    transactionId,
    originalTransactionId: linkedTokenHash || transactionId,
    expiresAt,
    periodStartedAt: dateFromIso(stringValue(payload.startTime)),
    autoRenew: autoRenewingPlan.autoRenewEnabled === true,
    rawReceipt: {
      google_play_purchase_token_hash: tokenHash,
      linked_purchase_token_hash: linkedTokenHash,
      order_id: orderId,
      subscription_state: state,
      acknowledgement_state: stringValue(payload.acknowledgementState),
      line_item_product_id: stringValue(matchingLine.productId),
      region_code: stringValue(payload.regionCode),
    },
  };
}

async function fetchGooglePlayPublisher(path: string): Promise<JsonMap> {
  const packageName = googlePlayPackageName();
  const accessToken = await googlePlayAccessToken();
  const response = await fetch(
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${
      encodeURIComponent(packageName)
    }/${path}`,
    { headers: { Authorization: `Bearer ${accessToken}` } },
  );
  if (!response.ok) {
    throw new Error(
      `Google Play API HTTP ${response.status}: ${
        truncateText(await response.text(), 240)
      }`,
    );
  }
  const payload = await response.json();
  if (!isJsonMap(payload)) {
    throw new Error("Google Play API response is not an object");
  }
  return payload;
}

async function googlePlayAccessToken(): Promise<string> {
  const serviceAccount = googlePlayServiceAccount();
  const tokenUri = serviceAccount.tokenUri ||
    "https://oauth2.googleapis.com/token";
  const assertion = await createGooglePlayJwt(serviceAccount, tokenUri);
  const response = await fetch(tokenUri, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!response.ok) {
    throw new Error(
      `Google Play OAuth HTTP ${response.status}: ${
        truncateText(await response.text(), 240)
      }`,
    );
  }
  const payload = await response.json();
  if (!isJsonMap(payload)) throw new Error("Google OAuth response is invalid");
  const accessToken = stringValue(payload.access_token);
  if (!accessToken) throw new Error("Google OAuth access token is missing");
  return accessToken;
}

function googlePlayServiceAccount(): {
  clientEmail: string;
  privateKey: string;
  tokenUri: string;
} {
  const encoded = stringValue(
    Deno.env.get("PRATICASE_GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64") ||
      Deno.env.get("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64"),
  );
  const rawJson = encoded
    ? new TextDecoder().decode(
      Uint8Array.from(atob(encoded.replace(/\s/g, "")), (char) =>
        char.charCodeAt(0)),
    )
    : stringValue(
      Deno.env.get("PRATICASE_GOOGLE_PLAY_SERVICE_ACCOUNT_JSON") ||
        Deno.env.get("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON"),
    );
  if (!rawJson) {
    throw new Error("Google Play service account JSON is not configured");
  }
  const parsed = JSON.parse(rawJson);
  if (!isJsonMap(parsed)) {
    throw new Error("Google Play service account JSON is invalid");
  }
  const clientEmail = stringValue(parsed.client_email);
  const privateKey = stringValue(parsed.private_key).replace(/\\n/g, "\n");
  const tokenUri = stringValue(parsed.token_uri) ||
    "https://oauth2.googleapis.com/token";
  if (!clientEmail || !privateKey.includes("PRIVATE KEY")) {
    throw new Error("Google Play service account credentials are incomplete");
  }
  return { clientEmail, privateKey, tokenUri };
}

async function createGooglePlayJwt(
  serviceAccount: { clientEmail: string; privateKey: string },
  tokenUri: string,
): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: serviceAccount.clientEmail,
    scope: "https://www.googleapis.com/auth/androidpublisher",
    aud: tokenUri,
    iat: now,
    exp: now + 3600,
  };
  const signingInput = `${base64UrlJson(header)}.${base64UrlJson(payload)}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToDer(serviceAccount.privateKey),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(
    await crypto.subtle.sign(
      "RSASSA-PKCS1-v1_5",
      key,
      new TextEncoder().encode(signingInput),
    ),
  );
  return `${signingInput}.${base64UrlBytes(signature)}`;
}

function pemToDer(pem: string): Uint8Array {
  const base64 = pem
    .replace(/-----BEGIN [^-]+-----/g, "")
    .replace(/-----END [^-]+-----/g, "")
    .replace(/\s/g, "");
  return Uint8Array.from(atob(base64), (char) => char.charCodeAt(0));
}

function googlePlayPackageName(): string {
  return stringValue(Deno.env.get("PRATICASE_GOOGLE_PLAY_PACKAGE_NAME")) ||
    "com.medasi.praticase";
}

function googlePlayEnvironment(payload: JsonMap): string {
  return payload.testPurchase != null || numberValue(payload.purchaseType) === 0
    ? "test"
    : "production";
}

function dateFromIso(value: string): Date | null {
  if (!value) return null;
  const timestamp = Date.parse(value);
  return Number.isFinite(timestamp) ? new Date(timestamp) : null;
}

async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

type AppleReceipt = {
  status: number;
  environment: string;
  transactionId: string;
  originalTransactionId: string;
  expiresAt: Date | null;
  periodStartedAt?: Date | null;
  autoRenew: boolean;
};

type StoreReceipt = AppleReceipt & {
  provider: StoreProvider;
  rawReceipt: JsonMap;
};

type AppleVerifierConfiguration = {
  bundleId: string;
  appAppleId: number;
  rootCertificates: Buffer[];
};

type AppStoreServerConfiguration = AppleVerifierConfiguration & {
  keyId: string;
  issuerId: string;
  privateKey: string;
  source: "praticase" | "shared";
};

function loadVerifierConfiguration(): AppleVerifierConfiguration {
  const bundleId = Deno.env.get("PRATICASE_APP_STORE_BUNDLE_ID")?.trim() ||
    "com.medasi.praticase";
  const appAppleId = Number(Deno.env.get("PRATICASE_APP_STORE_APP_ID") ?? "");
  const encodedCertificates =
    Deno.env.get("PRATICASE_APPLE_ROOT_CA_CERTIFICATES_BASE64")?.trim() ?? "";

  if (!Number.isSafeInteger(appAppleId) || appAppleId <= 0) {
    throw new Error("App Store verification configuration is incomplete");
  }

  const rootCertificates = encodedCertificates
    ? encodedCertificates.split(",")
      .map((certificate) => certificate.trim())
      .filter(Boolean)
      .map((certificate) => Buffer.from(certificate, "base64"))
    : defaultAppleRootCertificates();
  if (rootCertificates.length === 0) {
    throw new Error("App Store verification certificates are invalid");
  }
  return {
    bundleId,
    appAppleId,
    rootCertificates,
  };
}

function loadServerApiConfigurations(): AppStoreServerConfiguration[] {
  const verifierConfig = loadVerifierConfiguration();
  const configs = [
    appStoreServerConfigFromEnv(verifierConfig, {
      source: "praticase",
      keyIdName: "PRATICASE_APP_STORE_KEY_ID",
      issuerIdName: "PRATICASE_APP_STORE_ISSUER_ID",
      privateKeyBase64Name: "PRATICASE_APP_STORE_PRIVATE_KEY_BASE64",
      privateKeyName: "PRATICASE_APP_STORE_PRIVATE_KEY",
    }),
    appStoreServerConfigFromEnv(verifierConfig, {
      source: "shared",
      keyIdName: "APP_STORE_CONNECT_KEY_ID",
      issuerIdName: "APP_STORE_CONNECT_ISSUER_ID",
      privateKeyBase64Name: "APP_STORE_CONNECT_PRIVATE_KEY_BASE64",
      privateKeyName: "APP_STORE_CONNECT_PRIVATE_KEY",
    }),
  ].filter((config): config is AppStoreServerConfiguration => config != null);

  const uniqueConfigs = new Map<string, AppStoreServerConfiguration>();
  for (const config of configs) {
    uniqueConfigs.set(`${config.keyId}:${config.issuerId}`, config);
  }
  if (uniqueConfigs.size === 0) {
    throw new Error("App Store Server API configuration is incomplete");
  }
  return Array.from(uniqueConfigs.values());
}

function appStoreServerConfigFromEnv(
  verifierConfig: AppleVerifierConfiguration,
  names: {
    source: "praticase" | "shared";
    keyIdName: string;
    issuerIdName: string;
    privateKeyBase64Name: string;
    privateKeyName: string;
  },
): AppStoreServerConfiguration | null {
  const keyId = Deno.env.get(names.keyIdName)?.trim() ?? "";
  const issuerId = Deno.env.get(names.issuerIdName)?.trim() ?? "";
  const privateKey = readPrivateKeyEnv(
    names.privateKeyBase64Name,
    names.privateKeyName,
  );
  if (!keyId || !issuerId || !privateKey) return null;
  if (!privateKey.includes("PRIVATE KEY")) {
    throw new Error("App Store Server API key material is invalid");
  }
  return {
    ...verifierConfig,
    keyId,
    issuerId,
    privateKey,
    source: names.source,
  };
}

function readPrivateKeyEnv(base64Name: string, rawName: string): string {
  const encoded = Deno.env.get(base64Name)?.trim() ?? "";
  if (encoded) {
    return new TextDecoder().decode(
      Uint8Array.from(atob(encoded), (char) => char.charCodeAt(0)),
    ).replace(/\\n/g, "\n").trim();
  }
  return (Deno.env.get(rawName)?.trim() ?? "").replace(/\\n/g, "\n");
}

async function verifyPurchase(
  signedTransaction: string,
  transactionId: string,
  expectedProductId: string,
): Promise<AppleReceipt> {
  try {
    return await verifySignedTransaction(signedTransaction, expectedProductId);
  } catch (signedError) {
    recordEvent("signed_transaction_verify_failed", {
      productId: expectedProductId,
      message: deepErrorMessage(signedError),
    });
    return await verifyWithAppStoreServerApi(transactionId, expectedProductId);
  }
}

async function verifySignedTransaction(
  signedTransaction: string,
  expectedProductId: string,
): Promise<AppleReceipt> {
  const config = loadVerifierConfiguration();
  try {
    const payload = await verifyAndDecodeAppleJws(signedTransaction, config);
    return receiptFromTransactionPayload(
      payload,
      expectedProductId,
      config.bundleId,
    );
  } catch (error) {
    recordEvent("signed_transaction_diagnostic", {
      expectedBundle: config.bundleId,
      expectedAppAppleId: config.appAppleId,
      rootCertCount: config.rootCertificates.length,
      error: deepErrorMessage(error),
      jws: describeJwsForDiagnostics(signedTransaction),
    });
    throw error;
  }
}

async function verifyWithAppStoreServerApi(
  transactionId: string,
  expectedProductId: string,
): Promise<AppleReceipt> {
  if (!transactionId) throw new Error("Missing transaction identifier");
  const configs = loadServerApiConfigurations();
  const verifierConfig = loadVerifierConfiguration();
  const failures: string[] = [];

  for (const config of configs) {
    let productionError: unknown;
    try {
      return await verifyTransactionInEnvironment(
        config,
        verifierConfig,
        transactionId,
        expectedProductId,
        "production",
      );
    } catch (error) {
      productionError = error;
    }
    try {
      return await verifyTransactionInEnvironment(
        config,
        verifierConfig,
        transactionId,
        expectedProductId,
        "sandbox",
      );
    } catch (sandboxError) {
      failures.push(
        `${config.source}: production=${
          errorMessage(productionError)
        }, sandbox=${errorMessage(sandboxError)}`,
      );
    }
  }
  throw new Error(`Apple transaction lookup failed (${failures.join("; ")})`);
}

/// Verify any Apple-signed JWS by walking the embedded x5c chain back to a
/// trusted Apple root, then verifying the JWS signature with the leaf key.
/// Returns the decoded payload JSON; caller is responsible for checking
/// bundleId / productId / appAppleId since the payload schema differs between
/// transactions, notifications, and renewal info.
async function verifyAndDecodeAppleJws(
  jws: string,
  config: AppleVerifierConfiguration,
): Promise<JsonMap> {
  const parts = jws.split(".");
  if (parts.length !== 3) {
    throw new Error("Malformed JWS: expected 3 segments");
  }
  const header = JSON.parse(b64UrlDecode(parts[0])) as {
    alg?: string;
    x5c?: unknown;
  };
  if (header.alg !== "ES256") {
    throw new Error(`Unsupported JWS algorithm: ${header.alg}`);
  }
  if (!Array.isArray(header.x5c) || header.x5c.length === 0) {
    throw new Error("JWS header missing x5c certificate chain");
  }
  const chain = (header.x5c as string[]).map((b64) => {
    const der = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
    return new PeculiarX509(der);
  });

  // 1) Each cert must be signed by the next in the chain
  for (let i = 0; i < chain.length - 1; i++) {
    const child = chain[i];
    const parent = chain[i + 1];
    const ok = await child.verify({
      publicKey: await parent.publicKey.export(),
    });
    if (!ok) {
      throw new Error(`Chain link ${i} is not signed by the next certificate`);
    }
  }

  // 2) The final cert must byte-equal one of the Apple root anchors we ship
  const rootDer = new Uint8Array(chain[chain.length - 1].rawData);
  const trusted = config.rootCertificates.some((apple) =>
    bytesEqual(rootDer, new Uint8Array(apple))
  );
  if (!trusted) {
    throw new Error(
      "Certificate chain does not terminate at a trusted Apple root",
    );
  }

  // 3) Verify the JWS itself with the leaf certificate's public key
  const leafKey = await chain[0].publicKey.export();
  let payloadBytes: Uint8Array;
  try {
    const result = await compactVerify(jws, leafKey, {
      algorithms: ["ES256"],
    });
    payloadBytes = result.payload;
  } catch (error) {
    throw new Error(
      `JWS signature failed leaf verification: ${errorMessage(error)}`,
    );
  }

  return JSON.parse(new TextDecoder().decode(payloadBytes)) as JsonMap;
}

function bytesEqual(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) return false;
  for (let i = 0; i < a.length; i++) {
    if (a[i] !== b[i]) return false;
  }
  return true;
}

function describeJwsForDiagnostics(signedTransaction: string): JsonMap {
  const parts = (signedTransaction || "").split(".");
  if (parts.length !== 3) return { shape: "non_jws", segments: parts.length };
  try {
    const header = JSON.parse(b64UrlDecode(parts[0])) as JsonMap;
    const payload = JSON.parse(b64UrlDecode(parts[1])) as JsonMap;
    const x5c = Array.isArray(header.x5c) ? header.x5c as unknown[] : [];
    return {
      headerAlg: stringValue(header.alg),
      headerKid: stringValue(header.kid),
      x5cLength: x5c.length,
      leafCertLength: x5c[0]
        ? String((x5c[0] as string).length ?? 0).slice(0, 8)
        : "0",
      payloadBundleId: stringValue(payload.bundleId),
      payloadAppAppleId: stringValue(payload.appAppleId),
      payloadProductId: stringValue(payload.productId),
      payloadEnvironment: stringValue(payload.environment),
      payloadType: stringValue(payload.type),
      payloadInAppOwnershipType: stringValue(payload.inAppOwnershipType),
    };
  } catch (error) {
    return { decodeError: errorMessage(error) };
  }
}

function b64UrlDecode(value: string): string {
  const padded = value.replace(/-/g, "+").replace(/_/g, "/").padEnd(
    value.length + ((4 - value.length % 4) % 4),
    "=",
  );
  return new TextDecoder().decode(
    Uint8Array.from(atob(padded), (char) => char.charCodeAt(0)),
  );
}

function deepErrorMessage(error: unknown): string {
  if (error instanceof Error) {
    const cause = (error as { cause?: unknown }).cause;
    const causeText = cause != null ? ` cause=${errorMessage(cause)}` : "";
    return `${error.name}: ${error.message}${causeText}`;
  }
  return String(error);
}

async function verifyNotificationPayload(
  signedPayload: string,
): Promise<JsonMap> {
  const config = loadVerifierConfiguration();
  return await verifyAndDecodeAppleJws(signedPayload, config);
}

async function verifyTransactionInEnvironment(
  config: AppStoreServerConfiguration,
  verifierConfig: AppleVerifierConfiguration,
  transactionId: string,
  expectedProductId: string,
  environment: AppleEnvironment,
): Promise<AppleReceipt> {
  const response = await fetchAppStoreTransaction(
    config,
    transactionId,
    environment,
  );
  if (!response.signedTransactionInfo) {
    throw new Error("Apple transaction information is missing");
  }
  const payload = await verifyAndDecodeAppleJws(
    response.signedTransactionInfo,
    verifierConfig,
  );
  return receiptFromTransactionPayload(
    payload,
    expectedProductId,
    verifierConfig.bundleId,
  );
}

async function fetchAppStoreTransaction(
  config: AppStoreServerConfiguration,
  transactionId: string,
  environment: AppleEnvironment,
): Promise<{ signedTransactionInfo?: string }> {
  const host = environment === "production"
    ? "https://api.storekit.itunes.apple.com"
    : "https://api.storekit-sandbox.itunes.apple.com";
  const token = await createAppStoreServerJwt(config);
  const response = await fetch(
    `${host}/inApps/v1/transactions/${encodeURIComponent(transactionId)}`,
    { headers: { Authorization: `Bearer ${token}` } },
  );
  if (!response.ok) {
    throw new Error(
      `HTTP ${response.status}: ${truncateText(await response.text(), 240)}`,
    );
  }
  return await response.json() as { signedTransactionInfo?: string };
}

async function createAppStoreServerJwt(
  config: AppStoreServerConfiguration,
): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "ES256", kid: config.keyId, typ: "JWT" };
  const payload = {
    iss: config.issuerId,
    iat: now,
    exp: now + 20 * 60,
    aud: "appstoreconnect-v1",
    bid: config.bundleId,
  };
  const signingInput = `${base64UrlJson(header)}.${base64UrlJson(payload)}`;
  const key = await importAppStorePrivateKey(config.privateKey);
  const signature = new Uint8Array(
    await crypto.subtle.sign(
      { name: "ECDSA", hash: "SHA-256" },
      key,
      new TextEncoder().encode(signingInput),
    ),
  );
  return `${signingInput}.${base64UrlBytes(signature)}`;
}

async function importAppStorePrivateKey(
  privateKey: string,
): Promise<CryptoKey> {
  const pem = privateKey.trim()
    .replace(/^['"]|['"]$/g, "")
    .replace(/\\n/g, "\n")
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s+/g, "");
  const binary = Uint8Array.from(atob(pem), (char) => char.charCodeAt(0));
  return await crypto.subtle.importKey(
    "pkcs8",
    binary,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
}

function base64UrlJson(value: JsonMap): string {
  return base64UrlBytes(new TextEncoder().encode(JSON.stringify(value)));
}

function base64UrlBytes(value: Uint8Array): string {
  let binary = "";
  for (const byte of value) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(
    /=+$/,
    "",
  );
}

function receiptFromTransactionPayload(
  payload: JsonMap,
  expectedProductId: string,
  expectedBundleId: string,
): AppleReceipt {
  const bundleId = stringValue(payload.bundleId);
  if (bundleId && expectedBundleId && bundleId !== expectedBundleId) {
    throw new Error(
      `Apple transaction bundle mismatch: expected ${expectedBundleId} got ${bundleId}`,
    );
  }
  if (
    stringValue(payload.productId) !== expectedProductId ||
    payload.revocationDate != null
  ) {
    throw new Error("Apple transaction does not match the selected product");
  }
  const transactionId = stringValue(payload.transactionId);
  const originalTransactionId = stringValue(
    payload.originalTransactionId ?? payload.transactionId,
  );
  if (!transactionId || !originalTransactionId) {
    throw new Error("Apple transaction identifier is missing");
  }
  const expiresAt = dateFromMilliseconds(payload.expiresDate);
  const environment: AppleEnvironment =
    stringValue(payload.environment).toLowerCase() === "sandbox"
      ? "sandbox"
      : "production";
  return {
    status: 0,
    environment,
    transactionId,
    originalTransactionId,
    expiresAt,
    periodStartedAt: dateFromMilliseconds(payload.purchaseDate),
    autoRenew: expiresAt != null,
  };
}

function dateFromMilliseconds(value: unknown): Date | null {
  const milliseconds = Number(value ?? 0);
  return Number.isFinite(milliseconds) && milliseconds > 0
    ? new Date(milliseconds)
    : null;
}

function verificationPayloadShape(value: string): string {
  if (!value) return "empty";
  const parts = value.split(".");
  if (parts.length !== 3) return `non_jws:${value.length}`;
  try {
    const headerText = atob(
      parts[0].replace(/-/g, "+").replace(/_/g, "/"),
    );
    const header = JSON.parse(headerText);
    const alg = stringValue(header.alg) || "unknown_alg";
    const hasCertificateChain = Array.isArray(header.x5c);
    return `jws:${alg}:x5c_${hasCertificateChain ? "yes" : "no"}`;
  } catch (_) {
    return "jws:unreadable_header";
  }
}

function recordEvent(event: string, context: JsonMap) {
  console.info("praticase_storekit_event", { event, ...context });
}

function isMissingStoreProductIdColumn(error: unknown) {
  const message = errorMessage(error).toLowerCase();
  return message.includes("app_store_product_id") &&
    (message.includes("column") ||
      message.includes("schema cache") ||
      message.includes("does not exist") ||
      message.includes("could not find"));
}

function isMissingGooglePlayProductIdColumn(error: unknown) {
  const message = errorMessage(error).toLowerCase();
  return message.includes("google_play_product_id") &&
    (message.includes("column") ||
      message.includes("schema cache") ||
      message.includes("does not exist") ||
      message.includes("could not find"));
}

function normalizeStoreProvider(value: unknown): StoreProvider {
  return stringValue(value).toLowerCase() === "google_play"
    ? "google_play"
    : "app_store";
}

function stringValue(value: unknown) {
  if (value == null) return "";
  return typeof value === "string" ? value.trim() : String(value).trim();
}

function numberValue(value: unknown) {
  const numeric = Number(value);
  return Number.isFinite(numeric) ? numeric : null;
}

function isJsonMap(value: unknown): value is JsonMap {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function truncateText(value: string, maxLength: number): string {
  return value.length <= maxLength
    ? value
    : `${value.substring(0, maxLength)}...`;
}

function errorMessage(error: unknown) {
  if (error instanceof Error) {
    return error.message || error.name || String(error);
  }
  if (typeof DOMException !== "undefined" && error instanceof DOMException) {
    return error.message || error.name || String(error);
  }
  return String(error);
}
