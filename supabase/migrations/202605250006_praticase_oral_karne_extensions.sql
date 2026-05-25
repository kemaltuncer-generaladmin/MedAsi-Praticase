-- Sözlü sınav karnesi eksikleri: ideal yaklaşım özeti + bir sonraki deneme planı
-- §6/§9 standardına uygun B6/B7 alanları oral_exam_sessions tablosuna eklendi.

begin;

alter table praticase.oral_exam_sessions
  add column if not exists ideal_approach text not null default '',
  add column if not exists next_attempt_plan jsonb not null default '[]'::jsonb,
  add column if not exists critical_errors jsonb not null default '[]'::jsonb;

insert into praticase.self_hosted_schema_migrations(version, filename)
values ('202605250006', '202605250006_praticase_oral_karne_extensions.sql')
on conflict (version) do nothing;

commit;
