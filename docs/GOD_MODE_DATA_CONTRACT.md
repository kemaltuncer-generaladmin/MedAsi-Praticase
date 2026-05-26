# PratiCase God Mode Data Contract

This contract is for the Medasi admin panel. PratiCase content and session
facts remain in the `praticase` schema. Shared wallet, AI usage and purchase
facts remain in `public`; this implementation adds attribution metadata only.

## Access Boundary

- All `god_mode_*` analytics views and RPCs are `service_role` only.
- Analytics surfaces are read-only and aggregate session activity.
- Transcript text, result narratives, moderation context, user identity and
  App Store subscription linkage are not exposed in analytics results.
- Managed writes use validated `god_mode_*` RPCs and require
  `actor_user_id`, `request_id` and `reason`.
- Legacy service-role writes continue to work; audit records label them
  `legacy_direct`.

## Analytics Views

| Surface | Fields |
| --- | --- |
| `god_mode_case_publication_v` | `case_id`, `slug`, `title`, `branch`, `difficulty`, `is_published`, checklist counts, `checklist_record_count`, `missing_content_types`, `health_status`, timestamps |
| `god_mode_osce_funnel_v` | `metric_day`, `mode`, `case_id`, `case_title`, `case_branch`, `started_count`, `completed_count`, `abandoned_count`, `active_count`, `completion_rate_percent`, `average_completed_score` |
| `god_mode_oral_funnel_v` | `metric_day`, `exam_format`, `persona_id`, `branch_id`, `scenario_id`, counts, `completion_rate_percent`, `average_completed_score` |
| `god_mode_score_distribution_v` | `metric_day`, `exam_kind`, `score_band`, `session_count`, `average_score` |
| `god_mode_dropoff_v` | `metric_day`, `exam_kind`, `dropoff_step`, `abandonment_type`, `session_count` |
| `god_mode_active_banners_v` | `banner_id`, CTA routing fields, scheduling fields, `delivery_status`, `is_live_now`, `updated_at` |
| `god_mode_open_support_v` | `status`, `opened_day`, `request_count`, `oldest_opened_at`, `newest_opened_at` |
| `god_mode_content_health_v` | `entity_type`, `entity_key`, `title`, `is_active`, `health_status`, `issue_codes`, `updated_at` |

`god_mode_analytics_snapshot(p_from, p_to)` returns these datasets as one JSON
document with `contractVersion = praticase-god-mode-analytics-v1`. The range
must be positive and no greater than 366 days.

## Management RPCs

| RPC | Managed object | Validation highlights |
| --- | --- | --- |
| `god_mode_upsert_banner` | Home banners | Non-empty title/CTA, approved route shape, valid scheduling window |
| `god_mode_upsert_exam_mode` | Exam-mode cards | Stable identifier/action keys, non-empty title |
| `god_mode_upsert_oral_persona` | Oral personas | Difficulty/committee role enums, prompt minimum, patience range |
| `god_mode_upsert_oral_scenario` | Oral scenarios | Non-empty clinical content, JSON array contracts, valid difficulty |
| `god_mode_upsert_store_mapping` | PratiCase App Store mapping | Existing shared product code, non-blank unique StoreKit identifier |
| `god_mode_upsert_generated_checklist` | Generated OSCE case inputs | Known content type, difficulty enum, object payload |
| `god_mode_upsert_notification_campaign` | Notification campaign | Audience/recipient consistency and safe deep link |
| `god_mode_set_support_status` | Support workflow | `open`, `in_progress`, `resolved`, `closed` only |

The append-only audit table is `praticase.admin_content_audit_events`. Large or
sensitive bodies are recorded as SHA-256 hashes rather than duplicated text.

## Attribution

- AI usage events keep the existing shared record contract and add:
  `usage_metadata.app_key = "praticase"` and
  `usage_metadata.feature_attribution`.
- `feature_attribution` includes the feature plus applicable session,
  operation, exam-kind and format identifiers.
- Speech generation is attribution-recorded as AI usage but remains
  uncharged; this release does not introduce a new wallet gate for TTS.
- StoreKit purchase and renewal grants retain `raw_receipt.app` for
  compatibility and add `raw_receipt.app_key = "praticase"` plus
  `raw_receipt.feature_attribution`.
- The shared wallet debit RPC currently accepts only user and amount; the
  attributed AI usage event is the linked debit attribution record. Its
  signature is not forked by PratiCase.

## Deployment Order

1. Apply `202605270001_praticase_god_mode_analytics.sql`.
2. Apply `202605270002_praticase_god_mode_management_audit.sql`.
3. Deploy the PratiCase Edge Functions.
4. Run `supabase/tests/praticase_god_mode_contract_test.sql`.
5. Run `supabase/tests/praticase_god_mode_management_test.sql` transactionally.
6. Release mobile/web consumers separately after their quality gates pass.
