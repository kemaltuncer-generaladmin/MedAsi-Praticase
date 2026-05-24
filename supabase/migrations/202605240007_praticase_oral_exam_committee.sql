-- Komite modu: 2-3 hoca aynı sözlü sınavda.
-- Türk tıp fakültesi sözlü sınavının asıl baskısı bir tek hocadan değil,
-- karşıda oturan 2-3 hocadan gelir: biri soru sorarken diğeri atlar,
-- biri "yetersiz" derken öbürü ipucu vermeye çalışır. Bu migration o
-- dinamiği destekler.

begin;

-- exam_sessions: format ('solo' veya 'panel') ve panel persona dizisi
alter table praticase.oral_exam_sessions
  add column if not exists exam_format text not null default 'solo'
    check (exam_format in ('solo', 'panel')),
  add column if not exists panel_persona_ids text[] not null default '{}'::text[],
  add column if not exists panel_summaries jsonb not null default '{}'::jsonb;

-- exam_turns: panel modunda hangi hoca konuştu
alter table praticase.oral_exam_turns
  add column if not exists speaker_persona_id text;

create index if not exists oral_exam_turns_persona_idx
  on praticase.oral_exam_turns(session_id, speaker_persona_id);

-- Panel personalarına rol etiketi ekleyelim (lead, second, observer)
alter table praticase.oral_exam_personas
  add column if not exists panel_role text not null default 'lead'
    check (panel_role in ('lead', 'second', 'observer'));

-- Mevcut 3 persona için roller:
update praticase.oral_exam_personas set panel_role = 'observer' where id = 'patient_assistant';
update praticase.oral_exam_personas set panel_role = 'second'   where id = 'socratic_associate';
update praticase.oral_exam_personas set panel_role = 'lead'     where id = 'stern_professor';

-- Yeni exam mode card: Komite modu için ayrı CTA
insert into praticase.exam_mode_cards(
  id, title, subtitle, icon_key, action_key, sort_order, is_active
) values (
  'oral_exam_committee',
  'Sözlü Sınav — Komite Modu',
  'Üç hoca aynı anda karşında. Biri sorarken diğeri atlar, biri ipucu verirken diğeri yetersiz der. Gerçek sözlü sınav baskısı.',
  'oral_exam',
  'oral_exam_committee',
  62,
  true
) on conflict (id) do update set
  title = excluded.title,
  subtitle = excluded.subtitle,
  icon_key = excluded.icon_key,
  action_key = excluded.action_key,
  sort_order = excluded.sort_order,
  is_active = excluded.is_active,
  updated_at = now();

insert into praticase.home_banners(
  title, subtitle, cta_label, cta_route, sort_order, is_active
) values (
  'Komite Sözlü Sınav',
  'Üç hocalı panel: gerçek tıp fakültesi sözlü sınavı baskısı. Biri sorar, diğeri ipucu verir, üçüncüsü kontra-soru atar.',
  'Komiteye Çık',
  '/oral-exam-committee',
  17,
  true
);

insert into praticase.self_hosted_schema_migrations(version, filename)
values ('202605240007', '202605240007_praticase_oral_exam_committee.sql')
on conflict (version) do nothing;

commit;
