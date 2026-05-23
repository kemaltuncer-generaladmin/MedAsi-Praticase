begin;

create table if not exists praticase.exam_mode_cards (
  id text primary key,
  title text not null,
  subtitle text not null default '',
  icon_key text not null default 'exam',
  action_key text not null default 'cases',
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table praticase.exam_mode_cards enable row level security;

drop policy if exists "Authenticated can read active exam modes"
  on praticase.exam_mode_cards;

create policy "Authenticated can read active exam modes"
on praticase.exam_mode_cards for select
to authenticated
using (is_active);

insert into praticase.exam_mode_cards(
  id,
  title,
  subtitle,
  icon_key,
  action_key,
  sort_order,
  is_active
)
values
  (
    'single_station',
    'Tek İstasyon',
    'Bir vaka seç, süreli OSCE akışına gir.',
    'timer',
    'single_station',
    10,
    true
  ),
  (
    'mini_osce',
    'Mini OSCE',
    'Peş peşe kısa istasyonlarla sınav temposu çalış.',
    'mini_osce',
    'mini_osce',
    20,
    true
  ),
  (
    'weak_areas',
    'Zayıf Konulardan Sınav',
    'Gelişim verilerine göre tekrar gerektiren vakalara dön.',
    'weak_areas',
    'weak_areas',
    30,
    true
  ),
  (
    'branch_package',
    'Branş Paketi',
    'Genel Cerrahi, Kadın Doğum veya Üroloji odaklı ilerle.',
    'branch',
    'branch_package',
    40,
    true
  ),
  (
    'theoretical_exam',
    'Kuramsal Sınav',
    'Qlinik soru bankasından ders, konu ve soru sayısı seçerek komite denemesi oluştur.',
    'theoretical',
    'theoretical_exam',
    50,
    true
  )
on conflict (id) do update set
  title = excluded.title,
  subtitle = excluded.subtitle,
  icon_key = excluded.icon_key,
  action_key = excluded.action_key,
  sort_order = excluded.sort_order,
  is_active = excluded.is_active,
  updated_at = now();

grant select on praticase.exam_mode_cards to authenticated, service_role;

commit;
