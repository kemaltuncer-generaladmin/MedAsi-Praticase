begin;

grant usage on schema public to anon, authenticated;

grant select on public.profiles to authenticated;
grant insert, update on public.profiles to authenticated;

commit;
