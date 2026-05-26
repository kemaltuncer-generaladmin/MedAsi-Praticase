-- PratiCase RLS hardening pass
--
-- Bu migration sadece PratiCase tarafının kendi `praticase.*` tablolarına
-- ve PratiCase'in okumakta olduğu paylaşılan tabloların `select` haklarına
-- dokunur. Qlinik / Medasi tarafının `public.profiles`,
-- `public.wallet_entitlements`, `public.ai_usage_events` ve
-- `public.store_products` tabloları üzerindeki politikaları değiştirmez —
-- bu tablolar paylaşılan kaynaktır ve cüzdan akışı oradan beslenir.
--
-- Cüzdan ekranı `praticase-storekit-verify` edge fonksiyonu üzerinden
-- service-role ile okuma yapar; bu yüzden RLS politikaları edge fonksiyon
-- üzerinden gelen veriyi kısıtlamaz. Aşağıdaki politikalar yalnızca
-- doğrudan PostgREST üzerinden gelen istemci istekleri için geçerlidir.

begin;

------------------------------------------------------------
-- 1. PratiCase kapsamındaki tüm tablolarda RLS açık kalsın
------------------------------------------------------------

alter table if exists praticase.cases enable row level security;
alter table if exists praticase.home_banners enable row level security;
alter table if exists praticase.exam_mode_cards enable row level security;
alter table if exists praticase.user_dashboard_stats enable row level security;
alter table if exists praticase.user_case_progress enable row level security;
alter table if exists praticase.user_case_recommendations enable row level security;
alter table if exists praticase.user_bookmarked_cases enable row level security;
alter table if exists praticase.user_notifications enable row level security;
alter table if exists praticase.user_notes enable row level security;
alter table if exists praticase.user_app_settings enable row level security;
alter table if exists praticase.user_badges enable row level security;
alter table if exists praticase.user_badge_summaries enable row level security;
alter table if exists praticase.exam_sessions enable row level security;
alter table if exists praticase.exam_messages enable row level security;
alter table if exists praticase.oral_exam_sessions enable row level security;
alter table if exists praticase.oral_exam_turns enable row level security;
alter table if exists praticase.session_diagnosis_answers enable row level security;
alter table if exists praticase.session_management_notes enable row level security;
alter table if exists praticase.session_management_plan_items enable row level security;
alter table if exists praticase.session_physical_exam_findings enable row level security;
alter table if exists praticase.session_requested_tests enable row level security;
alter table if exists praticase.session_result_summaries enable row level security;
alter table if exists praticase.session_evaluation_snapshots enable row level security;
alter table if exists praticase.session_ai_enrichments enable row level security;
alter table if exists praticase.leaderboard_scores enable row level security;
alter table if exists praticase.contact_requests enable row level security;
alter table if exists praticase.store_product_app_mappings enable row level security;
alter table if exists praticase.app_store_subscription_links enable row level security;
alter table if exists praticase.notification_campaigns enable row level security;

------------------------------------------------------------
-- 2. Per-user select policies — eksik olabilecek olanlar
--    (idempotent: drop if exists → create)
------------------------------------------------------------

-- user_notes
drop policy if exists "Users can read own PratiCase notes"
  on praticase.user_notes;
create policy "Users can read own PratiCase notes"
  on praticase.user_notes
  for select
  using (auth.uid() = user_id);

drop policy if exists "Users can manage own PratiCase notes"
  on praticase.user_notes;
create policy "Users can manage own PratiCase notes"
  on praticase.user_notes
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- user_app_settings
drop policy if exists "Users can read own PratiCase app settings"
  on praticase.user_app_settings;
create policy "Users can read own PratiCase app settings"
  on praticase.user_app_settings
  for select
  using (auth.uid() = user_id);

drop policy if exists "Users can update own PratiCase app settings"
  on praticase.user_app_settings;
create policy "Users can update own PratiCase app settings"
  on praticase.user_app_settings
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- user_badges
drop policy if exists "Users can read own PratiCase user_badges"
  on praticase.user_badges;
create policy "Users can read own PratiCase user_badges"
  on praticase.user_badges
  for select
  using (auth.uid() = user_id);

-- exam_sessions
drop policy if exists "Users can read own PratiCase exam_sessions"
  on praticase.exam_sessions;
create policy "Users can read own PratiCase exam_sessions"
  on praticase.exam_sessions
  for select
  using (auth.uid() = user_id);

drop policy if exists "Users can write own PratiCase exam_sessions"
  on praticase.exam_sessions;
create policy "Users can write own PratiCase exam_sessions"
  on praticase.exam_sessions
  for insert
  with check (auth.uid() = user_id);

-- exam_messages (per-session via exam_sessions)
drop policy if exists "Users can read own PratiCase exam_messages"
  on praticase.exam_messages;
create policy "Users can read own PratiCase exam_messages"
  on praticase.exam_messages
  for select
  using (
    exists(
      select 1
      from praticase.exam_sessions s
      where s.id = praticase.exam_messages.session_id
        and s.user_id = auth.uid()
    )
  );

-- oral_exam_sessions
drop policy if exists "Users can read own PratiCase oral_exam_sessions"
  on praticase.oral_exam_sessions;
create policy "Users can read own PratiCase oral_exam_sessions"
  on praticase.oral_exam_sessions
  for select
  using (auth.uid() = user_id);

drop policy if exists "Users can write own PratiCase oral_exam_sessions"
  on praticase.oral_exam_sessions;
create policy "Users can write own PratiCase oral_exam_sessions"
  on praticase.oral_exam_sessions
  for insert
  with check (auth.uid() = user_id);

-- oral_exam_turns (per-session via oral_exam_sessions)
drop policy if exists "Users can read own PratiCase oral_exam_turns"
  on praticase.oral_exam_turns;
create policy "Users can read own PratiCase oral_exam_turns"
  on praticase.oral_exam_turns
  for select
  using (
    exists(
      select 1
      from praticase.oral_exam_sessions s
      where s.id = praticase.oral_exam_turns.session_id
        and s.user_id = auth.uid()
    )
  );

-- session_* tabloları (per-user via session join)
drop policy if exists "Users can read own PratiCase session_diagnosis_answers"
  on praticase.session_diagnosis_answers;
create policy "Users can read own PratiCase session_diagnosis_answers"
  on praticase.session_diagnosis_answers
  for select
  using (
    exists(
      select 1
      from praticase.exam_sessions s
      where s.id = praticase.session_diagnosis_answers.session_id
        and s.user_id = auth.uid()
    )
  );

drop policy if exists "Users can read own PratiCase session_management_notes"
  on praticase.session_management_notes;
create policy "Users can read own PratiCase session_management_notes"
  on praticase.session_management_notes
  for select
  using (
    exists(
      select 1
      from praticase.exam_sessions s
      where s.id = praticase.session_management_notes.session_id
        and s.user_id = auth.uid()
    )
  );

drop policy if exists "Users can read own PratiCase session_management_plan_items"
  on praticase.session_management_plan_items;
create policy "Users can read own PratiCase session_management_plan_items"
  on praticase.session_management_plan_items
  for select
  using (
    exists(
      select 1
      from praticase.exam_sessions s
      where s.id = praticase.session_management_plan_items.session_id
        and s.user_id = auth.uid()
    )
  );

drop policy if exists "Users can read own PratiCase session_physical_exam_findings"
  on praticase.session_physical_exam_findings;
create policy "Users can read own PratiCase session_physical_exam_findings"
  on praticase.session_physical_exam_findings
  for select
  using (
    exists(
      select 1
      from praticase.exam_sessions s
      where s.id = praticase.session_physical_exam_findings.session_id
        and s.user_id = auth.uid()
    )
  );

drop policy if exists "Users can read own PratiCase session_requested_tests"
  on praticase.session_requested_tests;
create policy "Users can read own PratiCase session_requested_tests"
  on praticase.session_requested_tests
  for select
  using (
    exists(
      select 1
      from praticase.exam_sessions s
      where s.id = praticase.session_requested_tests.session_id
        and s.user_id = auth.uid()
    )
  );

drop policy if exists "Users can read own PratiCase session_result_summaries"
  on praticase.session_result_summaries;
create policy "Users can read own PratiCase session_result_summaries"
  on praticase.session_result_summaries
  for select
  using (
    exists(
      select 1
      from praticase.exam_sessions s
      where s.id = praticase.session_result_summaries.session_id
        and s.user_id = auth.uid()
    )
  );

-- leaderboard: kullanıcı sadece kendi sırasını PostgREST'ten görür;
-- liderlik tablosu gösterimi edge fonksiyon/service-role üzerinden gider.
drop policy if exists "Users can read own PratiCase leaderboard row"
  on praticase.leaderboard_scores;
create policy "Users can read own PratiCase leaderboard row"
  on praticase.leaderboard_scores
  for select
  using (auth.uid() = user_id);

-- contact_requests: kullanıcı kendi destek talebini yazabilir + okuyabilir.
drop policy if exists "Users can insert own PratiCase contact_requests"
  on praticase.contact_requests;
create policy "Users can insert own PratiCase contact_requests"
  on praticase.contact_requests
  for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can read own PratiCase contact_requests"
  on praticase.contact_requests;
create policy "Users can read own PratiCase contact_requests"
  on praticase.contact_requests
  for select
  using (auth.uid() = user_id);

------------------------------------------------------------
-- 3. Admin / store eşleme tabloları — sadece read public,
--    yazma service_role üzerinden.
------------------------------------------------------------

drop policy if exists "Public can read PratiCase store product mappings"
  on praticase.store_product_app_mappings;
create policy "Public can read PratiCase store product mappings"
  on praticase.store_product_app_mappings
  for select
  using (is_active is not false);

drop policy if exists "Users can read own PratiCase app_store_subscription_links"
  on praticase.app_store_subscription_links;
create policy "Users can read own PratiCase app_store_subscription_links"
  on praticase.app_store_subscription_links
  for select
  using (auth.uid() = user_id);

-- notification_campaigns: yalnızca service_role yazar; aktif kampanyaları
-- authenticated kullanıcılar okuyabilir.
drop policy if exists "Authenticated can read active PratiCase campaigns"
  on praticase.notification_campaigns;
create policy "Authenticated can read active PratiCase campaigns"
  on praticase.notification_campaigns
  for select
  to authenticated
  using (coalesce(is_active, true));

------------------------------------------------------------
-- 4. Paylaşılan Medasi tabloları — değişiklik YOK
------------------------------------------------------------
-- public.profiles, public.wallet_entitlements, public.ai_usage_events,
-- public.store_products, public.app_store_subscription_links (public şema
-- varyantı varsa) ve consume_ai_credits/sync_wallet_profile RPC'leri
-- Qlinik tarafının migration repository'sinden yönetilir. Bu migration
-- bunlara dokunmaz; PratiCase edge fonksiyonu service-role ile okur.

commit;
