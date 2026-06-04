# PratiCase Recall Usage

Last reviewed: 2026-06-02

This document explains how PratiCase should use Recall, what the current code already does, where the integration is incomplete, and how PratiCase AI surfaces should read learning gaps.

## 1. Purpose

Recall is the cross-application repetition and weakness layer for the MedAsi ecosystem. In PratiCase, it should help the user understand what to revisit after clinical cases, OSCE attempts, oral exam turns, missed history questions, missed physical exam steps, missed tests, and weak clinical reasoning patterns.

PratiCase has two related but separate personalization paths:

1. User-visible Recall summary:
   - Shows what is due today.
   - Shows weak areas.
   - Gives a short study action.

2. Hidden AI personalization memory:
   - Shapes OSCE scoring feedback.
   - Shapes oral exam follow-up questions.
   - Shapes next-attempt plans.
   - Must not expose raw database memory or hidden event history.

## 2. Current Working Integration

### 2.1 Recall repository

Current code path:

- `lib/src/features/home/data/supabase_recall_repository.dart`
- Interface: `lib/src/features/home/data/recall_repository.dart`
- Domain model: `lib/src/features/home/domain/recall_summary.dart`

`SupabaseRecallRepository` calls Recall directly:

- `GET https://recall.medasi.com.tr/recall/today?source_app=praticase`
- `GET https://recall.medasi.com.tr/recall/weaknesses?source_app=praticase&limit=5`

It uses the current Supabase access token as bearer auth:

```http
Authorization: Bearer <current Supabase access token>
Accept: application/json
```

Important behavior:

- Missing auth returns `RecallSummary.unauthenticated`.
- Recall errors return a safe `RecallSummary.error`.
- Main PratiCase home loading should not be blocked by Recall failure.

### 2.2 Home dashboard usage

Current code path:

- `lib/src/features/home/data/supabase_home_repository.dart`
- Method: `_loadRecallSummary`
- Presentation: `lib/src/features/home/presentation/home_screen.dart`

The dashboard loads Recall summary as an optional add-on:

```text
loadDashboard()
  -> _loadProfile
  -> _loadBanners
  -> _loadStats
  -> _loadContinuedCase
  -> _loadRecommendations
  -> _loadBadgeSummary
  -> _loadUnreadNotificationCount
  -> _loadRecallSummary
```

If Recall fails, the dashboard gets an error summary instead of throwing. This is the desired UX posture: Recall should help, not break the home page.

### 2.3 Recall guidance call

Current code path:

- `SupabaseRecallRepository._loadRecallGuidance`
- Called function name: `praticase-recall-guidance`

The repository sends this sanitized payload:

```json
{
  "source": "recall_praticase_summary",
  "today_total": 3,
  "weaknesses": [
    {
      "title": "Eksik anamnez",
      "topic": "Göğüs ağrısı",
      "risk_level": "high"
    }
  ]
}
```

Expected AI response aliases:

- Sentence: `guidance_sentence`, `sentence`, or `guidance`.
- Action: `study_action`, `recommended_action`, or `action`.

If the function is missing, returns an error, or returns an unusable response, PratiCase uses deterministic fallback guidance.

Implementation note:

- The code calls `praticase-recall-guidance`.
- `supabase/functions/praticase-recall-guidance/index.ts` now exists in this checkout.
- If this function is not deployed to the live Supabase project, AI Recall guidance will fall back in the app.
- This does not break the home page, but live deployment is required for generated guidance.

## 3. PratiCase AI Personalization Memory

PratiCase AI does not rely only on `/recall/*`. It has a stronger hidden personalization memory layer.

Current code path:

- `supabase/functions/_shared/ecosystem_memory.ts`
- Function: `loadPersonalizationMemory`
- Function: `buildPersonalizationContract`

The memory loader reads:

- `core_learning_context`
- `core_app_memory_summary` with `p_app_code = praticase`
- `praticase_learning_user_context`
- `praticase_app_memory_summary`

The resulting hidden prompt includes:

- Ecosystem-level summaries.
- PratiCase-specific recent learning sentences.
- Top gaps.
- Local gap lines such as exam kind, skill label, branch, topic, concept label, and personalization score.

Surfaces using this memory include:

- `supabase/functions/praticase-complete-session/index.ts`
- `supabase/functions/praticase-patient-turn/index.ts`
- `supabase/functions/praticase-oral-exam/index.ts`

## 4. Correct Data Flow

The intended PratiCase flow is:

```text
User starts/completes case or oral/OSCE attempt
  -> PratiCase records session, transcript, selected actions, result details
  -> Result/gap functions identify missed clinical skills
  -> PratiCase app memory summary updates local PratiCase memory
  -> Core ecosystem memory receives portable learning signals
  -> Recall receives or syncs negative learning events
  -> Home dashboard reads /recall/today and /recall/weaknesses
  -> PratiCase AI uses hidden memory to personalize feedback and next attempts
```

Recall and PratiCase memory should reinforce each other:

- Recall answers: "What should I repeat?"
- PratiCase memory answers: "How should the next clinical practice adapt?"

## 5. Recall API Contract Expected by PratiCase

### 5.1 `GET /recall/today`

Accepted response fields:

- Count aliases: `today_total`, `total`, `count`, `pending_count`, `praticase_count`.
- Item aliases: `items`, `recalls`, `data`.

Recommended canonical response:

```json
{
  "today_total": 4,
  "items": [
    {
      "id": "uuid",
      "source_app": "praticase",
      "item_type": "clinical_weakness",
      "title": "Göğüs ağrısında eksik anamnez",
      "subject": "Dahiliye",
      "topic": "Göğüs ağrısı",
      "subtopic": "Ağrı karakterizasyonu",
      "priority": "high",
      "due_at": "2026-06-02T09:00:00Z"
    }
  ]
}
```

### 5.2 `GET /recall/weaknesses`

Accepted array fields:

- `weaknesses`
- `items`
- `data`
- `results`

Recommended canonical response:

```json
{
  "weaknesses": [
    {
      "id": "weak_uuid",
      "title": "Eksik anamnez: göğüs ağrısı",
      "topic": "Göğüs ağrısı",
      "risk_level": "high",
      "source_app": "praticase",
      "source_ref": {
        "type": "case_session",
        "id": "session_uuid"
      }
    }
  ]
}
```

PratiCase normalizes weakness title/topic with fallback logic:

- `title`, `name`, `label`, `weakness_title`, or `topic` can become title.
- `topic`, `subject`, `course`, or title can become topic.
- Missing risk defaults to `medium`.

## 6. How PratiCase Writes Recall Signals

PratiCase now writes portable learning weaknesses to Recall from two places:

1. OSCE/session completion AI enrichment.
2. Theoretical exam incorrect or omitted answers.

Shared helper:

- `supabase/functions/_shared/recall.ts`
- `recordRecallEventInBackground`

Recall endpoint:

- `POST {RECALL_BASE_URL}/recall/events`

Default base URL:

- `https://recall.medasi.com.tr`

Behavior:

- Recall writes are best-effort.
- The same user bearer token is forwarded to Recall.
- Failure to record Recall does not fail case completion or theoretical exam submit.
- Payloads are sanitized and do not include full transcript or full question text.

Recommended event types:

- `case_failed`
- `case_completed`
- `clinical_weakness`
- `osce_station_weakness`
- `oral_exam_weakness`

The Recall master pack currently recognizes PratiCase-style weakness concepts such as:

- `clinical_weakness`
- `osce_station_weakness`

Recommended event payload:

```json
{
  "source_app": "praticase",
  "event_type": "clinical_weakness",
  "subject": "Acil",
  "topic": "Göğüs ağrısı",
  "subtopic": "Riskli semptom sorgulama",
  "source_ref": {
    "type": "case_session",
    "id": "session_uuid",
    "case_id": "case_uuid"
  },
  "payload": {
    "exam_kind": "osce",
    "skill_label": "anamnesis",
    "missed_history": ["riskli semptom sorgulama"],
    "missed_physical_exam": [],
    "missed_tests": ["EKG"],
    "severity": "high"
  },
  "occurred_at": "2026-06-02T09:00:00Z"
}
```

Privacy rule:

- Do not send full transcript by default.
- Do not send patient-chat raw text unless explicitly needed and policy-approved.
- Prefer structured gap labels, case/session IDs, skill names, and severity.

## 7. How PratiCase AI Must Use Recall and Memory

### 7.1 Core rule

Personal weaknesses must not be used as score punishment.

Current-session score should be based on current-session performance. Historical weaknesses may shape:

- `improvementPoints`
- `missedHistory`
- `missedPhysicalExam`
- `missedTests`
- `idealApproach`
- `mentor_summary`
- `next_attempt_plan`
- oral exam follow-up questions
- patient-turn behavior when clinically appropriate

### 7.2 OSCE complete-session behavior

Current code already instructs AI to:

- Score based on current performance.
- Use personalization only for improvement and next attempt planning.
- Avoid treating memory as extra penalty.

Expected behavior:

- If the user repeatedly misses focused history in chest pain cases, the AI may say: "Bir sonraki denemede ilk 60 saniyeyi ağrının karakteri, eşlik eden bulgular ve risk faktörlerine ayır."
- It must not say: "Geçmişte de bunu kaçırdığın için skorunu düşürdüm."

### 7.3 Oral exam behavior

Oral exam AI may use memory to:

- Select a follow-up question targeting a known weak reasoning step.
- Build final feedback around one main weakness.
- Suggest a single measurable drill for the next attempt.

It must not:

- Reveal hidden memory.
- Give away ideal answer during a live oral turn.
- Turn every response into a long weakness report.

### 7.4 Patient-turn behavior

Patient simulation must not coach the user directly.

Allowed:

- If the user asks a relevant question, the patient answer may naturally expose the detail needed to test a weak area.

Disallowed:

- "You should ask me about risk factors because your memory says you miss that."
- Any explicit coaching while playing patient.

## 8. Known Gaps and Risks

### 8.1 Deploy `praticase-recall-guidance`

The Flutter repository calls `praticase-recall-guidance`, and this checkout now includes the matching function directory.

Impact:

- Home Recall AI guidance uses AI only after this function is deployed.
- User still sees Recall counts/weaknesses if Recall API works.

Required live checklist:

1. Deploy `supabase/functions/praticase-recall-guidance`.
2. Confirm the Supabase function name matches the Flutter invoke name.
3. Confirm OpenAI provider env is available for the function.
4. Confirm fallback still works if the AI provider is unavailable.

### 8.2 Recall write path exists, live ingestion still needs QA

The app reads Recall and now emits Recall events from OSCE completion and theoretical exam submit. QA must still verify that the live Recall deployment accepts those events and turns them into items.

If events are not written or synced:

- `/recall/today` may be empty.
- `/recall/weaknesses` may be empty.
- AI memory may still work locally, causing a mismatch between PratiCase AI and Recall dashboard.

### 8.3 Two gap systems can diverge

PratiCase has local learning gap rollups. Recall has cross-app items. They must be bridged by policy:

- Local PratiCase memory can remain detailed.
- Recall should receive portable, reviewable weakness items.
- Core ecosystem memory should receive app summaries and top gaps.

## 9. Acceptance Criteria

Recall is working correctly in PratiCase when:

1. A signed-in user with missed OSCE/case skills gets non-empty `/recall/weaknesses?source_app=praticase`.
2. Due clinical weaknesses appear in `/recall/today?source_app=praticase`.
3. Home dashboard displays Recall summary without blocking other dashboard data.
4. Missing Recall service returns a safe error state, not a crashed home screen.
5. `praticase-recall-guidance` is deployed and returns sanitized guidance, or the fallback path is intentionally accepted.
6. OSCE scoring does not penalize historical weaknesses.
7. Final feedback and next attempt plan use at most one or two personal weak signals.
8. Patient simulation does not expose memory or coach during patient roleplay.
9. Raw transcripts are not sent to Recall by default.
10. OSCE completion emits a best-effort `clinical_weakness` or `osce_station_weakness` Recall event when meaningful gaps exist.
11. Theoretical incorrect/omitted answers emit best-effort `clinical_weakness` Recall events.

## 10. QA Checklist

Use a test user with at least one completed case:

1. Complete an OSCE case with missed history and missed tests.
2. Confirm PratiCase local gap/memory RPCs return top gaps.
3. Confirm Recall endpoints return PratiCase due items or weaknesses.
4. Open home dashboard and verify Recall summary appears.
5. Temporarily make Recall unavailable and verify home still loads.
6. Check whether `praticase-recall-guidance` is deployed and reachable.
7. Complete another session and verify AI feedback uses memory for next action, not score penalty.
8. Inspect AI output for forbidden wording:
   - database
   - table
   - hidden context
   - previous records say
   - core memory
9. Confirm no service role key, anon key, access token, or raw private transcript is written into logs or docs.

## 11. Implementation Notes for Future Work

Recommended next implementation order:

1. Deploy `praticase-recall-guidance`.
2. Verify live Recall accepts OSCE and theoretical Recall events.
3. Add an integration test: missed clinical skill -> Recall weakness -> home Recall card.
4. Add a privacy review for any future richer PratiCase payload fields.
5. Align local PratiCase memory summary and Recall weakness labels so user-facing terminology is consistent.
6. Add observability for Recall failures without showing noisy errors to the user.
