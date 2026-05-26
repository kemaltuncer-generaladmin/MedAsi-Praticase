begin;

-- Qlinik and PratiCase share the live Medasi wallet package catalog. If this
-- optional override table already exists from an older PratiCase migration,
-- do not force PratiCase-only StoreKit identifiers.
alter table if exists praticase.store_product_app_mappings
  drop constraint if exists store_product_app_mappings_praticase_bundle_check;

comment on table praticase.store_product_app_mappings is
  'Optional PratiCase StoreKit overrides for shared Medasi/Qlinik wallet products.';

commit;
