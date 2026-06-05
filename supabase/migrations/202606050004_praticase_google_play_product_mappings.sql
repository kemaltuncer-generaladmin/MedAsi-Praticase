-- PratiCase owns this mapping table. Do not alter shared Qlinik/Public wallet
-- product tables from Android release work.

alter table if exists praticase.store_product_app_mappings
  add column if not exists google_play_product_id text;

create unique index if not exists store_product_app_mappings_google_play_product_id_key
  on praticase.store_product_app_mappings (google_play_product_id)
  where google_play_product_id is not null and trim(google_play_product_id) <> '';

comment on column praticase.store_product_app_mappings.google_play_product_id is
  'Optional PratiCase Google Play Billing product id override for the shared Medasi wallet product.';
