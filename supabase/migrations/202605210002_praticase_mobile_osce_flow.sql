begin;

alter table praticase.cases
  add column if not exists solved_count integer not null default 0 check (solved_count >= 0),
  add column if not exists summary text not null default '',
  add column if not exists flow_steps jsonb not null default '[]'::jsonb,
  add column if not exists goals jsonb not null default '[]'::jsonb;

create table if not exists praticase.case_patient_response_rules (
  id uuid primary key default extensions.gen_random_uuid(),
  case_id uuid not null references praticase.cases(id) on delete cascade,
  match_terms text[] not null default '{}',
  response text not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists praticase.physical_exam_groups (
  id uuid primary key default extensions.gen_random_uuid(),
  case_id uuid not null references praticase.cases(id) on delete cascade,
  title text not null,
  sort_order integer not null default 0
);

create table if not exists praticase.physical_exam_options (
  id uuid primary key default extensions.gen_random_uuid(),
  group_id uuid not null references praticase.physical_exam_groups(id) on delete cascade,
  title text not null,
  finding text not null default '',
  point_value integer not null default 0,
  is_critical boolean not null default false,
  sort_order integer not null default 0
);

create table if not exists praticase.test_groups (
  id uuid primary key default extensions.gen_random_uuid(),
  case_id uuid not null references praticase.cases(id) on delete cascade,
  title text not null,
  sort_order integer not null default 0
);

create table if not exists praticase.test_options (
  id uuid primary key default extensions.gen_random_uuid(),
  group_id uuid not null references praticase.test_groups(id) on delete cascade,
  title text not null,
  result text not null default '',
  point_cost integer not null default 0,
  is_unnecessary boolean not null default false,
  sort_order integer not null default 0
);

create table if not exists praticase.diagnosis_options (
  id uuid primary key default extensions.gen_random_uuid(),
  case_id uuid not null references praticase.cases(id) on delete cascade,
  title text not null,
  is_primary boolean not null default false,
  is_correct boolean not null default false,
  sort_order integer not null default 0
);

create table if not exists praticase.exam_sessions (
  id uuid primary key default extensions.gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  case_id uuid not null references praticase.cases(id) on delete cascade,
  mode text not null default 'exam' check (mode in ('exam', 'training')),
  current_step text not null default 'history' check (
    current_step in ('history', 'physical_exam', 'tests', 'diagnosis', 'completed')
  ),
  budget_points integer not null default 300 check (budget_points >= 0),
  remaining_points integer not null default 300 check (remaining_points >= 0),
  status text not null default 'active' check (
    status in ('active', 'completed', 'abandoned')
  ),
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  updated_at timestamptz not null default now()
);

create table if not exists praticase.exam_messages (
  id uuid primary key default extensions.gen_random_uuid(),
  session_id uuid not null references praticase.exam_sessions(id) on delete cascade,
  sender text not null check (sender in ('patient', 'candidate', 'system')),
  message text not null,
  created_at timestamptz not null default now()
);

create table if not exists praticase.session_physical_exam_findings (
  session_id uuid not null references praticase.exam_sessions(id) on delete cascade,
  option_id uuid not null references praticase.physical_exam_options(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (session_id, option_id)
);

create table if not exists praticase.session_requested_tests (
  session_id uuid not null references praticase.exam_sessions(id) on delete cascade,
  option_id uuid not null references praticase.test_options(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (session_id, option_id)
);

create table if not exists praticase.session_diagnosis_answers (
  session_id uuid primary key references praticase.exam_sessions(id) on delete cascade,
  primary_diagnosis text not null default '',
  selected_option_ids uuid[] not null default '{}',
  reasoning text not null default '',
  updated_at timestamptz not null default now()
);

alter table praticase.case_patient_response_rules enable row level security;
alter table praticase.physical_exam_groups enable row level security;
alter table praticase.physical_exam_options enable row level security;
alter table praticase.test_groups enable row level security;
alter table praticase.test_options enable row level security;
alter table praticase.diagnosis_options enable row level security;
alter table praticase.exam_sessions enable row level security;
alter table praticase.exam_messages enable row level security;
alter table praticase.session_physical_exam_findings enable row level security;
alter table praticase.session_requested_tests enable row level security;
alter table praticase.session_diagnosis_answers enable row level security;

drop policy if exists "Public can read published patient rules" on praticase.case_patient_response_rules;
create policy "Public can read published patient rules"
on praticase.case_patient_response_rules for select
using (
  exists (
    select 1 from praticase.cases
    where cases.id = case_patient_response_rules.case_id
      and cases.is_published
  )
);

drop policy if exists "Public can read published physical groups" on praticase.physical_exam_groups;
create policy "Public can read published physical groups"
on praticase.physical_exam_groups for select
using (
  exists (
    select 1 from praticase.cases
    where cases.id = physical_exam_groups.case_id
      and cases.is_published
  )
);

drop policy if exists "Public can read published physical options" on praticase.physical_exam_options;
create policy "Public can read published physical options"
on praticase.physical_exam_options for select
using (
  exists (
    select 1
    from praticase.physical_exam_groups
    join praticase.cases on cases.id = physical_exam_groups.case_id
    where physical_exam_groups.id = physical_exam_options.group_id
      and cases.is_published
  )
);

drop policy if exists "Public can read published test groups" on praticase.test_groups;
create policy "Public can read published test groups"
on praticase.test_groups for select
using (
  exists (
    select 1 from praticase.cases
    where cases.id = test_groups.case_id
      and cases.is_published
  )
);

drop policy if exists "Public can read published test options" on praticase.test_options;
create policy "Public can read published test options"
on praticase.test_options for select
using (
  exists (
    select 1
    from praticase.test_groups
    join praticase.cases on cases.id = test_groups.case_id
    where test_groups.id = test_options.group_id
      and cases.is_published
  )
);

drop policy if exists "Public can read published diagnoses" on praticase.diagnosis_options;
create policy "Public can read published diagnoses"
on praticase.diagnosis_options for select
using (
  exists (
    select 1 from praticase.cases
    where cases.id = diagnosis_options.case_id
      and cases.is_published
  )
);

drop policy if exists "Users can read own exam sessions" on praticase.exam_sessions;
create policy "Users can read own exam sessions"
on praticase.exam_sessions for select
using (auth.uid() = user_id);

drop policy if exists "Users can create own exam sessions" on praticase.exam_sessions;
create policy "Users can create own exam sessions"
on praticase.exam_sessions for insert
with check (auth.uid() = user_id);

drop policy if exists "Users can update own exam sessions" on praticase.exam_sessions;
create policy "Users can update own exam sessions"
on praticase.exam_sessions for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "Users can read own exam messages" on praticase.exam_messages;
create policy "Users can read own exam messages"
on praticase.exam_messages for select
using (
  exists (
    select 1 from praticase.exam_sessions
    where exam_sessions.id = exam_messages.session_id
      and exam_sessions.user_id = auth.uid()
  )
);

drop policy if exists "Users can create own exam messages" on praticase.exam_messages;
create policy "Users can create own exam messages"
on praticase.exam_messages for insert
with check (
  exists (
    select 1 from praticase.exam_sessions
    where exam_sessions.id = exam_messages.session_id
      and exam_sessions.user_id = auth.uid()
  )
);

drop policy if exists "Users can read own physical selections" on praticase.session_physical_exam_findings;
create policy "Users can read own physical selections"
on praticase.session_physical_exam_findings for select
using (
  exists (
    select 1 from praticase.exam_sessions
    where exam_sessions.id = session_physical_exam_findings.session_id
      and exam_sessions.user_id = auth.uid()
  )
);

drop policy if exists "Users can write own physical selections" on praticase.session_physical_exam_findings;
create policy "Users can write own physical selections"
on praticase.session_physical_exam_findings for insert
with check (
  exists (
    select 1 from praticase.exam_sessions
    where exam_sessions.id = session_physical_exam_findings.session_id
      and exam_sessions.user_id = auth.uid()
  )
);

drop policy if exists "Users can read own test selections" on praticase.session_requested_tests;
create policy "Users can read own test selections"
on praticase.session_requested_tests for select
using (
  exists (
    select 1 from praticase.exam_sessions
    where exam_sessions.id = session_requested_tests.session_id
      and exam_sessions.user_id = auth.uid()
  )
);

drop policy if exists "Users can write own test selections" on praticase.session_requested_tests;
create policy "Users can write own test selections"
on praticase.session_requested_tests for insert
with check (
  exists (
    select 1 from praticase.exam_sessions
    where exam_sessions.id = session_requested_tests.session_id
      and exam_sessions.user_id = auth.uid()
  )
);

drop policy if exists "Users can read own diagnosis answer" on praticase.session_diagnosis_answers;
create policy "Users can read own diagnosis answer"
on praticase.session_diagnosis_answers for select
using (
  exists (
    select 1 from praticase.exam_sessions
    where exam_sessions.id = session_diagnosis_answers.session_id
      and exam_sessions.user_id = auth.uid()
  )
);

drop policy if exists "Users can write own diagnosis answer" on praticase.session_diagnosis_answers;
create policy "Users can write own diagnosis answer"
on praticase.session_diagnosis_answers for insert
with check (
  exists (
    select 1 from praticase.exam_sessions
    where exam_sessions.id = session_diagnosis_answers.session_id
      and exam_sessions.user_id = auth.uid()
  )
);

drop policy if exists "Users can update own diagnosis answer" on praticase.session_diagnosis_answers;
create policy "Users can update own diagnosis answer"
on praticase.session_diagnosis_answers for update
using (
  exists (
    select 1 from praticase.exam_sessions
    where exam_sessions.id = session_diagnosis_answers.session_id
      and exam_sessions.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1 from praticase.exam_sessions
    where exam_sessions.id = session_diagnosis_answers.session_id
      and exam_sessions.user_id = auth.uid()
  )
);

create or replace view praticase.user_case_library
with (security_invoker = true) as
select
  cases.id as case_id,
  cases.title,
  cases.branch,
  cases.difficulty,
  cases.setting,
  cases.duration_minutes,
  cases.points,
  cases.icon_key,
  cases.summary,
  cases.solved_count,
  progress.progress_percent,
  progress.last_score,
  exists (
    select 1 from praticase.user_bookmarked_cases bookmarks
    where bookmarks.user_id = auth.uid()
      and bookmarks.case_id = cases.id
  ) as is_bookmarked
from praticase.cases
left join praticase.user_case_progress progress
  on progress.case_id = cases.id
  and progress.user_id = auth.uid()
where cases.is_published;

create or replace function praticase.record_patient_question(
  p_session_id uuid,
  p_message text
)
returns table(patient_message_id uuid, response text)
language plpgsql
security invoker
as $$
declare
  v_case_id uuid;
  v_response text;
  v_message_id uuid;
begin
  select case_id into v_case_id
  from praticase.exam_sessions
  where id = p_session_id
    and user_id = auth.uid()
    and status = 'active';

  if v_case_id is null then
    raise exception 'Exam session not found';
  end if;

  insert into praticase.exam_messages(session_id, sender, message)
  values (p_session_id, 'candidate', trim(p_message));

  select rules.response into v_response
  from praticase.case_patient_response_rules rules
  where rules.case_id = v_case_id
    and (
      cardinality(rules.match_terms) = 0
      or exists (
        select 1
        from unnest(rules.match_terms) as term
        where lower(trim(p_message)) like '%' || lower(term) || '%'
      )
    )
  order by rules.sort_order
  limit 1;

  if v_response is not null then
    insert into praticase.exam_messages(session_id, sender, message)
    values (p_session_id, 'patient', v_response)
    returning id into v_message_id;
  end if;

  return query select v_message_id, v_response;
end;
$$;

create index if not exists case_patient_rules_case_order_idx
  on praticase.case_patient_response_rules (case_id, sort_order);
create index if not exists physical_exam_groups_case_order_idx
  on praticase.physical_exam_groups (case_id, sort_order);
create index if not exists test_groups_case_order_idx
  on praticase.test_groups (case_id, sort_order);
create index if not exists diagnosis_options_case_order_idx
  on praticase.diagnosis_options (case_id, sort_order);
create index if not exists exam_sessions_user_updated_idx
  on praticase.exam_sessions (user_id, updated_at desc);
create index if not exists exam_messages_session_created_idx
  on praticase.exam_messages (session_id, created_at);

commit;
