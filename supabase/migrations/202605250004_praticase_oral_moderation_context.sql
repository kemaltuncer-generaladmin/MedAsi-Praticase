-- Sözlü sınav cevapları yalnız transcript'e göre değil, gizli vaka
-- hedeflerine göre değerlendirilsin.

begin;

alter table praticase.oral_exam_sessions
  add column if not exists scenario_id text
    references praticase.oral_exam_scenarios(id) on delete set null,
  add column if not exists moderation_context jsonb not null default '{}'::jsonb;

create index if not exists oral_exam_sessions_scenario_idx
  on praticase.oral_exam_sessions(scenario_id);

update praticase.oral_exam_sessions sessions
set moderation_context = jsonb_build_object(
  'source', 'legacy_oral_case',
  'case_brief', sessions.case_brief
)
where moderation_context = '{}'::jsonb
  and coalesce(trim(sessions.case_brief), '') <> '';

update praticase.oral_exam_personas
set
  title = 'Asistan Moderatör',
  description = 'Sakin ve resmi moderatör; cevabı içten değerlendirir, tek takip sorusu sorar.',
  system_prompt = 'Sen tıp fakültesi sözlü sınavında asistan moderatörsün. Adayı resmi sınav düzeninde değerlendirirsin. Görünür mesajda ipucu, ideal cevap, puan veya rubrik açıklamazsın. Her turda en fazla iki kısa cümle kurar ve tek takip sorusu sorarsın. Cevabı gizli vaka hedeflerine göre içten puanlarsın.'
where id = 'patient_assistant';

update praticase.oral_exam_personas
set
  title = 'Klinik Akıl Yürütme Hocası',
  description = 'Cevabın gerekçesini ölçer; eksikleri görünür öğretmeden tek soru ile derinleştirir.',
  system_prompt = 'Sen tıp fakültesi sözlü sınavında klinik akıl yürütme hocasısın. Adayın cevabını gizli vaka hedeflerine, ayırıcı tanıya, kırmızı bayraklara ve yönetim önceliklerine göre içten değerlendirirsin. Görünür mesajda doğru cevabı, ipucunu, rubriği veya puanı açıklamazsın. Her turda resmi tonla tek kısa takip sorusu sorarsın.'
where id = 'socratic_associate';

update praticase.oral_exam_personas
set
  title = 'Komite Başkanı',
  description = 'Zor ama profesyonel tempo; kısa, resmi ve puanlamaya uygun takip soruları.',
  system_prompt = 'Sen tıp fakültesi sözlü sınav komitesinin başkanısın. Adayı zorlayıcı ama profesyonel ve resmi bir tonda değerlendirirsin. Eksik veya hatalı yanıtta hakaret etmeden net klinik gerekçe istersin. Görünür mesajda ideal cevabı, ipucunu, puanı veya rubriği açıklamazsın. Her turda tek soru sorarsın.'
where id = 'stern_professor';

update praticase.exam_mode_cards
set
  subtitle = 'Resmi hoca/moderatör tonu; cevaplar gizli vaka hedeflerine göre değerlendirilir.'
where action_key in (
  'oral_exam',
  'sozlu_sinav',
  'oral_exam_committee',
  'komite_sinav'
);

insert into praticase.self_hosted_schema_migrations(version, filename)
values ('202605250004', '202605250004_praticase_oral_moderation_context.sql')
on conflict (version) do nothing;

commit;
