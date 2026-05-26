-- Ecosystem-readable PratiCase learning memory.
-- Converts each theory/OSCE/oral learning event into one short sentence and
-- exposes a user-scoped context RPC for other Medasi products.

begin;

alter table praticase.user_learning_events
  add column if not exists learning_sentence text not null default '';

create or replace function praticase.learning_difficulty_tr(
  p_difficulty text
)
returns text
language sql
immutable
as $$
  select case lower(coalesce(nullif(trim(p_difficulty), ''), 'unknown'))
    when 'easy' then 'kolay'
    when 'medium' then 'orta'
    when 'hard' then 'zor'
    when 'kolay' then 'kolay'
    when 'orta' then 'orta'
    when 'zor' then 'zor'
    else 'belirsiz zorlukta'
  end
$$;

create or replace function praticase.learning_outcome_phrase(
  p_outcome text
)
returns text
language sql
immutable
as $$
  select case coalesce(p_outcome, '')
    when 'incorrect' then 'yanlış yaptı'
    when 'omitted' then 'boş bıraktı'
    when 'unsafe' then 'kritik güvenlik hatası yaptı'
    when 'unnecessary' then 'gereksiz aksiyon yaptı'
    when 'missed' then 'kaçırdı'
    when 'partial' then 'kısmi bıraktı'
    when 'low_score' then 'düşük performans gösterdi'
    else 'gelişim ihtiyacı gösterdi'
  end
$$;

create or replace function praticase.build_learning_sentence(
  p_exam_kind text,
  p_outcome text,
  p_severity text,
  p_skill_code text,
  p_branch text,
  p_topic text,
  p_concept_label text,
  p_evidence text,
  p_metadata jsonb
)
returns text
language plpgsql
immutable
as $$
declare
  v_exam_kind text := coalesce(p_exam_kind, '');
  v_branch text := coalesce(nullif(trim(p_branch), ''), 'Genel');
  v_topic text := coalesce(nullif(trim(p_topic), ''), 'Genel');
  v_concept text := coalesce(
    nullif(trim(p_concept_label), ''),
    nullif(trim(p_evidence), ''),
    v_topic
  );
  v_skill text := praticase.learning_skill_label(p_skill_code);
  v_outcome text := praticase.learning_outcome_phrase(p_outcome);
  v_metadata jsonb := case
    when jsonb_typeof(coalesce(p_metadata, '{}'::jsonb)) = 'object'
      then coalesce(p_metadata, '{}'::jsonb)
    else '{}'::jsonb
  end;
  v_question_type text := coalesce(
    nullif(trim(v_metadata ->> 'question_type'), ''),
    'unknown'
  );
  v_cognitive_level text := coalesce(
    nullif(trim(v_metadata ->> 'cognitive_level'), ''),
    'unknown'
  );
  v_difficulty text := praticase.learning_difficulty_tr(
    v_metadata ->> 'difficulty'
  );
  v_sentence text;
begin
  if v_exam_kind = 'theoretical' then
    v_sentence := format(
      'Kullanıcı PratiCase teorik sınavında %s dersi %s konusunda %s alt başlığındaki %s düzeyi %s tipindeki %s soruyu %s.',
      v_branch,
      v_topic,
      v_concept,
      v_cognitive_level,
      v_question_type,
      v_difficulty,
      v_outcome
    );
  elsif v_exam_kind = 'oral_exam' then
    v_sentence := format(
      'Kullanıcı PratiCase sözlü sınavında %s branşında %s bağlamında %s becerisinde %s başlığında %s.',
      v_branch,
      v_topic,
      v_skill,
      v_concept,
      v_outcome
    );
  else
    v_sentence := format(
      'Kullanıcı PratiCase OSCE geçmişinde %s branşındaki %s istasyonunda %s becerisinde %s başlığında %s.',
      v_branch,
      v_topic,
      v_skill,
      v_concept,
      v_outcome
    );
  end if;

  return regexp_replace(v_sentence, '\s+', ' ', 'g');
end;
$$;

create or replace function praticase.set_learning_sentence()
returns trigger
language plpgsql
as $$
begin
  new.learning_sentence := praticase.build_learning_sentence(
    new.exam_kind,
    new.outcome,
    new.severity,
    new.skill_code,
    new.branch,
    new.topic,
    new.concept_label,
    new.evidence,
    new.metadata
  );
  return new;
end;
$$;

drop trigger if exists set_learning_sentence
  on praticase.user_learning_events;
create trigger set_learning_sentence
before insert or update on praticase.user_learning_events
for each row execute function praticase.set_learning_sentence();

update praticase.user_learning_events
set learning_sentence = praticase.build_learning_sentence(
  exam_kind,
  outcome,
  severity,
  skill_code,
  branch,
  topic,
  concept_label,
  evidence,
  metadata
);

create or replace view praticase.user_learning_history_sentences
with (security_invoker = true) as
select
  events.user_id,
  events.id as event_id,
  events.exam_kind,
  events.outcome,
  events.severity,
  events.skill_code,
  praticase.learning_skill_label(events.skill_code) as skill_label,
  events.branch,
  events.topic,
  events.concept_label,
  events.learning_sentence,
  events.occurrence_count,
  events.last_seen_at,
  events.created_at
from praticase.user_learning_events events
where events.learning_sentence <> '';

create or replace function praticase.praticase_learning_user_context(
  p_user_id uuid,
  p_limit integer default 80
)
returns jsonb
language sql
stable
security definer
set search_path = praticase, public, extensions
as $$
  with authz as (
    select coalesce(auth.uid() = p_user_id, false)
      or coalesce(auth.role(), '') = 'service_role' as ok
  ),
  recent_sentences as (
    select
      event_id,
      exam_kind,
      outcome,
      severity,
      skill_code,
      skill_label,
      branch,
      topic,
      concept_label,
      learning_sentence,
      occurrence_count,
      last_seen_at
    from praticase.user_learning_history_sentences, authz
    where authz.ok
      and user_id = p_user_id
    order by last_seen_at desc
    limit least(greatest(coalesce(p_limit, 80), 1), 200)
  ),
  top_gaps as (
    select
      exam_kind,
      skill_code,
      skill_label,
      concept_label,
      topic,
      branch,
      event_count,
      occurrence_count,
      critical_count,
      incorrect_count,
      omitted_count,
      missed_count,
      unnecessary_count,
      unsafe_count,
      personalization_score,
      latest_seen_at
    from praticase.user_learning_gap_rollups, authz
    where authz.ok
      and user_id = p_user_id
    order by personalization_score desc, latest_seen_at desc
    limit least(greatest(coalesce(p_limit, 80), 1), 200)
  )
  select jsonb_build_object(
    'source', 'praticase',
    'schema_version', 'praticase-learning-sentences-v1',
    'user_id', p_user_id,
    'recent_sentences',
      coalesce(
        (select jsonb_agg(to_jsonb(recent_sentences)) from recent_sentences),
        '[]'::jsonb
      ),
    'top_gaps',
      coalesce(
        (select jsonb_agg(to_jsonb(top_gaps)) from top_gaps),
        '[]'::jsonb
      )
  )
$$;

grant select on praticase.user_learning_history_sentences
to authenticated, service_role;

grant execute on function praticase.praticase_learning_user_context(
  uuid,
  integer
) to authenticated, service_role;

insert into praticase.self_hosted_schema_migrations(version, filename)
values ('202605270004', '202605270004_praticase_learning_sentences.sql')
on conflict (version) do nothing;

commit;
