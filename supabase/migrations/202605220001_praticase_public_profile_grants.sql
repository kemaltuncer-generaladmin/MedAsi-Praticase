begin;

-- `public.profiles` grants and policies are owned by the live shared
-- Medasi/Qlinik auth schema. PratiCase consumes that contract and does not
-- mutate the shared auth surface.

commit;
