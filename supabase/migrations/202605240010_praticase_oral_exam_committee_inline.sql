-- Komite Modu artık ayrı bir giriş noktası olarak listelenmesin.
-- Sözlü sınav setup ekranındaki "Sınav Formatı" seçicisi üzerinden
-- aynı modüle erişilebildiği için ayrı bir exam_mode_cards kartı ve
-- home_banner CTA'sı gereksiz.

begin;

update praticase.exam_mode_cards
set is_active = false,
    updated_at = now()
where id = 'oral_exam_committee';

update praticase.home_banners
set is_active = false,
    updated_at = now()
where cta_route = '/oral-exam-committee';

insert into praticase.self_hosted_schema_migrations(version, filename)
values ('202605240010', '202605240010_praticase_oral_exam_committee_inline.sql')
on conflict (version) do nothing;

commit;
