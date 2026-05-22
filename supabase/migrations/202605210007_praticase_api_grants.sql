begin;

grant usage on schema praticase to anon, authenticated;

grant select on all tables in schema praticase to anon, authenticated;
grant insert, update, delete on all tables in schema praticase to authenticated;
grant usage, select on all sequences in schema praticase to authenticated;

alter default privileges in schema praticase
grant select on tables to anon, authenticated;

alter default privileges in schema praticase
grant insert, update, delete on tables to authenticated;

alter default privileges in schema praticase
grant usage, select on sequences to authenticated;

grant execute on function praticase.record_patient_question(uuid, text) to authenticated;
grant execute on function praticase.finalize_exam_session(uuid) to authenticated;

commit;
