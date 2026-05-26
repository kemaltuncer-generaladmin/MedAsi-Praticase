-- PratiCase consumes the shared Medasi/Qlinik store catalog. This table is
-- only an optional app-specific StoreKit override; if it is empty, the edge
-- function falls back to the shared public.store_products product identifier.

create table if not exists praticase.store_product_app_mappings (
  product_code text primary key references public.store_products(code) on delete cascade,
  app_store_product_id text not null unique,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table if exists praticase.store_product_app_mappings
  drop constraint if exists store_product_app_mappings_praticase_bundle_check;

alter table praticase.store_product_app_mappings enable row level security;

revoke all on table praticase.store_product_app_mappings from anon, authenticated;
grant select, insert, update, delete on table praticase.store_product_app_mappings
  to service_role;

comment on table praticase.store_product_app_mappings is
  'Optional PratiCase StoreKit overrides for shared Medasi/Qlinik wallet products.';

create table if not exists praticase.app_store_subscription_links (
  original_transaction_id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  product_code text not null references public.store_products(code) on delete cascade,
  latest_transaction_id text not null,
  latest_purchase_id uuid references public.purchases(id) on delete set null,
  will_auto_renew boolean not null default true,
  expires_at timestamptz,
  latest_notification_uuid text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists app_store_subscription_links_user_idx
  on praticase.app_store_subscription_links(user_id, product_code);

alter table praticase.app_store_subscription_links enable row level security;

revoke all on table praticase.app_store_subscription_links from anon, authenticated;
grant select, insert, update, delete on table praticase.app_store_subscription_links
  to service_role;

comment on table praticase.app_store_subscription_links is
  'PratiCase-only Apple subscription linkage for server notifications; entitlements remain in shared public wallet tables.';
