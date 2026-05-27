import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.4";
import {
  Environment,
  SignedDataVerifier,
  VerificationException,
  VerificationStatus,
} from "npm:@apple/app-store-server-library@3.1.0";
import { Buffer } from "node:buffer";
import { defaultAppleRootCertificates } from "../_shared/apple_root_certificates.ts";
import { corsHeaders, isAllowedOrigin, jsonResponse } from "../_shared/cors.ts";

type JsonMap = Record<string, unknown>;

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
  const body = await request.json().catch(() => ({})) as JsonMap;
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

  const action = stringValue(body.action) || "verify";
  const userId = authData.user.id;

  if (action === "catalog" || action === "store") {
    const payload = await loadCatalogPayload(admin, userId);
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

  const productCode = stringValue(body.product_code);
  const storeProductId = stringValue(body.store_product_id);
  const provider = stringValue(body.provider) || "app_store";
  const purchaseId = stringValue(body.purchase_id);
  const verification = body.verification_data as JsonMap | undefined;

  if (
    provider !== "app_store" ||
    !productCode ||
    !storeProductId ||
    !purchaseId ||
    !verification
  ) {
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

  if (source !== "app_store" || !serverPayload) {
    return jsonResponse(
      { error: "Satın alma şu anda doğrulanamadı. Lütfen tekrar dene." },
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

  let appleResult: AppleReceipt;
  try {
    appleResult = await verifyPurchase(
      serverPayload,
      purchaseId,
      storeProductId,
    );
  } catch (error) {
    recordEvent("verify_failed", {
      provider,
      productCode,
      payloadShape: verificationPayloadShape(serverPayload),
      purchaseIdPresent: purchaseId.length > 0,
      message: errorMessage(error),
    });
    return jsonResponse(
      { error: "Satın alma şu anda doğrulanamadı. Lütfen tekrar dene." },
      502,
      origin,
    );
  }

  const product = await loadMappedProduct(admin, productCode, storeProductId);
  if (!product) {
    return jsonResponse(
      { error: "Seçilen paket bulunamadı." },
      404,
      origin,
    );
  }

  const entitlementKind = (product.entitlement_kind ?? "subscription")
    .toString();
  const durationDays = numberValue(product.duration_days) ?? 30;
  const now = new Date();
  const expiresAt = appleResult.expiresAt ??
    new Date(now.getTime() + durationDays * 24 * 3600 * 1000);
  const periodStart = appleResult.periodStartedAt ?? now;

  const { data: grantResult, error: grantError } = await admin.rpc(
    "grant_app_store_product",
    {
      p_user_id: userId,
      p_product_id: product.id,
      p_provider_transaction_id: appleResult.transactionId,
      p_raw_receipt: {
        app: "praticase",
        app_key: "praticase",
        feature_attribution: "storekit_purchase_grant",
        product_code: product.code,
        store_product_id: storeProductId,
        original_transaction_id: appleResult.originalTransactionId,
        environment: appleResult.environment,
      },
      p_started_at: periodStart.toISOString(),
      p_expires_at: expiresAt.toISOString(),
    },
  );
  if (grantError) {
    return jsonResponse(
      { error: friendlyPurchaseGrantError(grantError.message) },
      400,
      origin,
    );
  }
  if (entitlementKind === "subscription") {
    await saveSubscriptionLink(admin, {
      originalTransactionId: appleResult.originalTransactionId,
      userId,
      productCode: stringValue(product.code),
      latestTransactionId: appleResult.transactionId,
      latestPurchaseId: purchaseIdFromGrant(grantResult),
      willAutoRenew: appleResult.autoRenew,
      expiresAt,
    });
  }

  recordEvent("verify_succeeded", {
    productCode: product.code,
    provider,
    environment: appleResult.environment,
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
        transaction_id: appleResult.transactionId,
        original_transaction_id: appleResult.originalTransactionId,
        environment: appleResult.environment,
        will_auto_renew: appleResult.autoRenew,
        remaining_coin_amount: numberValue(product.coin_amount) ?? 0,
        remaining_question_amount: numberValue(product.question_amount) ?? 0,
      },
      profile: profile,
    },
    200,
    origin,
  );
});

async function loadCatalogPayload(
  // deno-lint-ignore no-explicit-any
  admin: any,
  userId: string,
): Promise<JsonMap> {
  const products = await loadMappedCatalog(admin);
  const blockedProductCodes = await blockedSubscriptionProductCodes(
    admin,
    userId,
  );
  const profile = await loadEffectiveWalletProfile(admin, userId);
  const warnings = await walletExpiryWarnings(admin, userId);
  return {
    products: (products ?? []).filter((product) =>
      !blockedProductCodes.includes(stringValue(product.code))
    ),
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

async function loadMappedCatalog(
  // deno-lint-ignore no-explicit-any
  admin: any,
): Promise<JsonMap[] | null> {
  const mappedIds = await loadAppStoreProductMappings(admin);
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
): Promise<JsonMap | null> {
  const mappedProduct = await loadMappedProductByOverride(
    admin,
    productCode,
    storeProductId,
  );
  if (mappedProduct) return mappedProduct;

  const products = await loadSharedStoreProducts(admin);
  const product = (products ?? []).find((item) =>
    stringValue(item.code) === productCode &&
    stringValue(item.app_store_product_id) === storeProductId
  );
  return product ?? null;
}

async function loadMappedProductByOverride(
  // deno-lint-ignore no-explicit-any
  admin: any,
  productCode: string,
  storeProductId: string,
): Promise<JsonMap | null> {
  const { data: mapping, error: mappingError } = await admin
    .schema("praticase")
    .from("store_product_app_mappings")
    .select("product_code,app_store_product_id")
    .eq("product_code", productCode)
    .eq("app_store_product_id", storeProductId)
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

async function loadAppStoreProductMappings(
  // deno-lint-ignore no-explicit-any
  admin: any,
): Promise<Map<string, string>> {
  const { data: mappings, error } = await admin
    .schema("praticase")
    .from("store_product_app_mappings")
    .select("product_code,app_store_product_id")
    .eq("is_active", true);
  if (error) return new Map();
  return new Map(
    ((mappings ?? []) as JsonMap[])
      .map((mapping) =>
        [
          stringValue(mapping.product_code),
          stringValue(mapping.app_store_product_id),
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
    const productName = nameMap.get(code) || code || "PratiCase paketi";
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
    .select("product_code")
    .eq("user_id", userId)
    .eq("status", "active")
    .eq("entitlement_type", "subscription")
    .gt("expires_at", new Date().toISOString());
  if (error) {
    recordEvent("subscription_blocks_failed", { message: error.message });
    return [];
  }

  const activeCodes = new Set(
    ((data ?? []) as JsonMap[])
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
    const verified = await verifyNotificationPayload(signedPayload);
    const notificationType = stringValue(
      verified.notification.notificationType,
    );
    if (notificationType === "TEST") {
      return jsonResponse({ status: "ok" }, 200, origin);
    }

    const signedTransaction = stringValue(
      verified.notification.data?.signedTransactionInfo,
    );
    if (!signedTransaction) {
      return jsonResponse({ status: "ignored" }, 200, origin);
    }
    const transaction = await verified.verifier.verifyAndDecodeTransaction(
      signedTransaction,
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
    const signedRenewal = stringValue(
      verified.notification.data?.signedRenewalInfo,
    );
    if (signedRenewal) {
      const renewal = await verified.verifier.verifyAndDecodeRenewalInfo(
        signedRenewal,
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
        notificationUuid: stringValue(verified.notification.notificationUUID),
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
            notification_uuid: verified.notification.notificationUUID,
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
        notificationUuid: stringValue(verified.notification.notificationUUID),
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
        notificationUuid: stringValue(verified.notification.notificationUUID),
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

type AppleReceipt = {
  status: number;
  environment: string;
  transactionId: string;
  originalTransactionId: string;
  expiresAt: Date | null;
  periodStartedAt?: Date | null;
  autoRenew: boolean;
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

function loadServerApiConfiguration(): AppStoreServerConfiguration {
  const verifierConfig = loadVerifierConfiguration();
  const keyId = Deno.env.get("PRATICASE_APP_STORE_KEY_ID")?.trim() ?? "";
  const issuerId = Deno.env.get("PRATICASE_APP_STORE_ISSUER_ID")?.trim() ?? "";
  const encodedPrivateKey =
    Deno.env.get("PRATICASE_APP_STORE_PRIVATE_KEY_BASE64")?.trim() ?? "";
  if (!keyId || !issuerId || !encodedPrivateKey) {
    throw new Error("App Store Server API configuration is incomplete");
  }
  const privateKey = new TextDecoder().decode(
    Uint8Array.from(atob(encodedPrivateKey), (char) => char.charCodeAt(0)),
  );
  if (!privateKey.includes("PRIVATE KEY")) {
    throw new Error("App Store Server API key material is invalid");
  }
  return {
    ...verifierConfig,
    keyId,
    issuerId,
    privateKey,
  };
}

async function verifyWithAppStoreServerApi(
  transactionId: string,
  expectedProductId: string,
): Promise<AppleReceipt> {
  if (!transactionId) throw new Error("Missing transaction identifier");
  const config = loadServerApiConfiguration();
  let productionError: unknown;

  try {
    return await verifyTransactionInEnvironment(
      config,
      transactionId,
      expectedProductId,
      Environment.PRODUCTION,
    );
  } catch (error) {
    productionError = error;
  }
  try {
    return await verifyTransactionInEnvironment(
      config,
      transactionId,
      expectedProductId,
      Environment.SANDBOX,
    );
  } catch (sandboxError) {
    throw new Error(
      `Apple transaction lookup failed (production=${
        errorMessage(productionError)
      }, sandbox=${errorMessage(sandboxError)})`,
    );
  }
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
      message: errorMessage(signedError),
    });
    return await verifyWithAppStoreServerApi(transactionId, expectedProductId);
  }
}

async function verifySignedTransaction(
  signedTransaction: string,
  expectedProductId: string,
): Promise<AppleReceipt> {
  const config = loadVerifierConfiguration();
  let productionError: unknown;
  try {
    const verifier = signedDataVerifier(config, Environment.PRODUCTION);
    const transaction = await verifier.verifyAndDecodeTransaction(
      signedTransaction,
    );
    return receiptFromTransaction(
      transaction,
      expectedProductId,
      Environment.PRODUCTION,
    );
  } catch (error) {
    productionError = error;
  }
  try {
    const verifier = signedDataVerifier(config, Environment.SANDBOX);
    const transaction = await verifier.verifyAndDecodeTransaction(
      signedTransaction,
    );
    return receiptFromTransaction(
      transaction,
      expectedProductId,
      Environment.SANDBOX,
    );
  } catch (sandboxError) {
    throw new Error(
      `Apple signed transaction validation failed (production=${
        verificationFailureCode(productionError)
      }, sandbox=${verificationFailureCode(sandboxError)})`,
    );
  }
}

async function verifyNotificationPayload(signedPayload: string) {
  const config = loadVerifierConfiguration();
  try {
    const verifier = signedDataVerifier(config, Environment.PRODUCTION);
    const notification = await verifier.verifyAndDecodeNotification(
      signedPayload,
    );
    return { notification, verifier };
  } catch (_) {
    const verifier = signedDataVerifier(config, Environment.SANDBOX);
    const notification = await verifier.verifyAndDecodeNotification(
      signedPayload,
    );
    return { notification, verifier };
  }
}

async function verifyTransactionInEnvironment(
  config: AppStoreServerConfiguration,
  transactionId: string,
  expectedProductId: string,
  environment: Environment,
): Promise<AppleReceipt> {
  const response = await fetchAppStoreTransaction(
    config,
    transactionId,
    environment,
  );
  if (!response.signedTransactionInfo) {
    throw new Error("Apple transaction information is missing");
  }
  const verifier = signedDataVerifier(config, environment);
  const transaction = await verifier.verifyAndDecodeTransaction(
    response.signedTransactionInfo,
  );
  return receiptFromTransaction(transaction, expectedProductId, environment);
}

async function fetchAppStoreTransaction(
  config: AppStoreServerConfiguration,
  transactionId: string,
  environment: Environment,
): Promise<{ signedTransactionInfo?: string }> {
  const host = environment === Environment.PRODUCTION
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

function receiptFromTransaction(
  transaction: {
    productId?: unknown;
    revocationDate?: unknown;
    transactionId?: unknown;
    originalTransactionId?: unknown;
    expiresDate?: unknown;
    purchaseDate?: unknown;
  },
  expectedProductId: string,
  environment: Environment,
): AppleReceipt {
  if (
    transaction.productId !== expectedProductId ||
    transaction.revocationDate != null
  ) {
    throw new Error("Apple transaction does not match the selected product");
  }

  const transactionValue = stringValue(transaction.transactionId);
  const originalTransactionValue = stringValue(
    transaction.originalTransactionId ?? transaction.transactionId,
  );
  if (!transactionValue || !originalTransactionValue) {
    throw new Error("Apple transaction identifier is missing");
  }
  const expiresAt = dateFromMilliseconds(transaction.expiresDate);
  return {
    status: 0,
    environment: environment === Environment.PRODUCTION
      ? "production"
      : "sandbox",
    transactionId: transactionValue,
    originalTransactionId: originalTransactionValue,
    expiresAt,
    periodStartedAt: dateFromMilliseconds(transaction.purchaseDate),
    autoRenew: expiresAt != null,
  };
}

function signedDataVerifier(
  config: AppleVerifierConfiguration,
  environment: Environment,
) {
  return new SignedDataVerifier(
    config.rootCertificates,
    true,
    environment,
    config.bundleId,
    environment === Environment.PRODUCTION ? config.appAppleId : undefined,
  );
}

function dateFromMilliseconds(value: unknown): Date | null {
  const milliseconds = Number(value ?? 0);
  return Number.isFinite(milliseconds) && milliseconds > 0
    ? new Date(milliseconds)
    : null;
}

function verificationFailureCode(error: unknown): string {
  if (error instanceof VerificationException) {
    return VerificationStatus[error.status] ?? `status_${error.status}`;
  }
  return error instanceof Error && error.message ? error.message : "unknown";
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
