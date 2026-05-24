begin;

-- PratiCase owns these presentation records. Shared Qlinik/Medasi payment and
-- question contracts remain unchanged; only PratiCase-facing copy is updated.
update praticase.exam_mode_cards
set
  title = 'Teorik Sınav',
  subtitle = 'Medasi soru havuzundan ders, konu ve soru sayısı seçerek deneme oluştur.',
  updated_at = now()
where id = 'theoretical_exam';

update praticase.home_banners
set subtitle =
  'Klinik karnendeki eksik anamnez, muayene ve tetkik başlıklarından hedefli tekrar yap.'
where title = 'Zayıf Alan Tekrarı';

update praticase.home_banners
set subtitle =
  'Medasi soru havuzundan ders ve konu seçerek klinik performansını teoriyle destekle.'
where title = 'Teorik Sınav Köprüsü';

commit;
