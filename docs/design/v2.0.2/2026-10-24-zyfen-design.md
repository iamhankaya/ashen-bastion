# Zyfen, the Archmage of Ashen — ikinci karakter (v2.0.2) tasarımı

Tarih: 2026-10-24 · Durum: kullanıcı onayladı (2026-10-24) · Hedef sürüm: v2.0.2

## 1. Niyet ve neden

Ashen Bastion'un ikinci oynanabilir karakteri. Gunslinger'dan **oynanış hissiyle** ayrılmalı: nokta isabetli mermi yerine delip geçen rüzgar kesikleri; koşunun sonlarına doğru rüzgar becerileri bütün haritaya kaos getirir. Yer tutucu Barutçu bu karakterle **tamamen kaldırılır**.

Kısa hikâye çekirdeği (görünüş ve ton için; derin hikâye ve karakter yazımı v2.0.3 / v2.1.0'a ertelendi):
Zyfen, kale düşmeden önce Lordun sağ koluydu. Lord karanlığa sürüklendiğinde onu durdurmaya çalışırken bir gözünü kaybetti. Omuz omuza savaştığı ve her şeyden çok saygı duyduğu dostunu ebedi huzura kavuşturmak için geri dönüyor.

## 2. Hedefler

1. Zyfen oynanabilir ikinci karakter olarak gelir; Barutçu ve ona özel her şey (karakter verisi, görseller, `dinamit` becerisi, ilgili testler) kaldırılır.
2. **Beceri havuzu ikiye ayrılır** (kullanıcı kuralı): *değer artıranlar ortak*, *ekranda bir şey yapanlar karaktere özel*.
3. Zyfen'in kendine özel rüzgar seti: temel saldırı + 7 aktif + 1 özel pasif + 4 evrim.
4. Sona doğru "harita çapında kaos" hissi (özellikle Tufan evrimi).
5. Gunslinger'ın yürüme animasyonu da bu sürümde gelir (v2.0.1'den ertelendi).

## 3. Hedef olmayanlar

- Derin hikâye, diyaloglar, ara sahneler, karakter kilidi/ilerleme sistemi (v2.0.3 / v2.1.0).
- Üçüncü karakter.
- Kıyafetin şimdiden kesinleşmesi (taslak görsellerle seçilecek, §6).

## 4. Anti-hedefler (çalışsa bile başarısızlık sayılır)

- Zyfen'in "mavi mermili Gunslinger" gibi hissettirmesi (kesikler delmeli; savuruş hissi olmalı).
- Ortak havuz ayrımının Gunslinger'ın mevcut dengesini/oynanışını bozması.
- Sim determinizminin bozulması (aynı tohum → aynı hash; gözlemci bağlı/bağsız aynı).
- Görsel olarak oyunun pas/kor/kemik paletinden kopuk, "başka oyundan gelmiş" bir karakter.

## 5. Kimlik ve görünüş

| Alan | Karar (kullanıcı) |
|---|---|
| Ad | **Zyfen** |
| Unvan | **The Archmage of Ashen** (İngilizce kalır) |
| Cinsiyet / yaş | Erkek, 30'larında |
| Saç | Gümüş, uzun ve dağınık, geriye doğru savrulan (seçilen taslaktaki gibi; kullanıcı 2026-10-24) |
| Yara | Bir gözünde yukarıdan aşağı inen çizik; o göz kapalı |
| Büyü | Çıplak elleriyle (asa yok) |
| Rüzgar rengi | Yeşilimsi beyaz; gümüş saçla aynı ailede, biraz yeşil taşıyan |
| Kıyafet | **Seçildi (2026-10-24):** "Yas tutan başbüyücü" taslağı — kömür grisi uzun palto, gümüş işlemeler, kırmızı astar, göğüste kırık zincir + yıldız amblemi, siyah yas kuşağı, **sargılı ön kollar ve eller**. Bronz kale omuzluğu şimdilik yok (sonra yeniden bakılacak). Referans: `docs/design/v2.0.2/zyfen_concept.png` |

VLAD önerisi (kesin değil): kıyafette Lordun sağ kolu olduğu günlerden kalma, yıpranmış bir kale işareti ya da omuzluk.

## 6. Oynanış

### 6.1 Temel değerler (kullanıcı onayladı; dengeleme fazında ölçülerek ayarlanabilir)

| Değer | Gunslinger | Zyfen |
|---|---|---|
| Can | 100 | 85 |
| Hareket hızı | 300 | 310 |
| Atış sayısı (`mag_cap`; rüzgar toplamadan önceki kesik) | 6 | 8 |
| Doldurma (`reload_time`; rüzgar toplama) | 1,0 sn | 1,3 sn |
| Menzil | 700 | 750 |

Kilit: **baştan açık** (VLAD kararı; kullanıcı soruyu yanıtlamadı, Barutçu da kilitsizdi).

### 6.2 Temel saldırı — Rüzgar Kesiği

İki el sırayla savurur (Gunslinger'ın sağ/sol ateşinin karşılığı); avuçtan hilal biçiminde saydam bir rüzgar kesiği çıkar, düz çizgide uçar ve yolundaki düşmanları **deler** (birden fazla düşmana isabet). Şarjör bitince kısa **rüzgar toplama** anı: eller birleşir, etrafında hava döner (doldurmanın karşılığı; aynı `mag_cap`/`reload_time` mekaniği).

### 6.3 Beceri havuzu ayrımı

**Ortak havuz (bütün karakterler)** — mevcut 7 pasif; etki aynı, **ad ve ikon karaktere göre** değişebilir:

| Mevcut | Etki | Zyfen'deki ad (öneri, yalnız `Derin Nefes` konuşuldu) |
|---|---|---|
| Çevik Çizme | hız | (builder/VLAD önerir) |
| Sağlam Yelek | can + yenilenme | " |
| Mıknatıs | toplama alanı | " |
| Ağır Kurşun | hasar | " |
| Hızlı Parmak | saldırı hızı | " |
| Fazladan Mermi | kapasite | **Derin Nefes** (rüzgar toplamadan önce +1 kesik) |
| Hızlı Doldurma | toparlanma | " |

**Gunslinger'a özel** (mevcut aktifler + evrimler, davranış değişmez): Yelpaze Atış, Seken Mermi, Şarapnel, Keskin Nişan, Doldurma Saçılması, Son Mermi Patlar, Çift Tabanca, Barut Kesesi (özel pasif), Gürleyen Yelpaze, Kıyamet Mermisi, Mermi Fırtınası, Zincirleme Patlama. `Dinamit` Barutçu ile birlikte kalkar.

### 6.4 Zyfen'e özel rüzgar seti (kullanıcı onayladı)

Aktifler:
1. **Hava Bıçakları** — yakın düşmanlara yelpaze biçiminde 3–5 küçük kesik.
2. **Girdap** — etrafında dönen hava halkası; yaklaşanları keser ve geri iter.
3. **Hortum** — yavaş ilerleyen küçük hortum; düşmanları içine çeker (ömür sonunda savurmaz; kullanıcı kararı 2026-10-25).
4. **Delen Rüzgar** — en dayanıklı düşmana her şeyi delen ince uzun hava mızrağı.
5. **Bölünen Kesik** — kesik ilk çarptığı düşmanda ikiye ayrılır.
6. **Hava Cebi** — ölen düşman bazen yerinde kısa ömürlü girdap bırakır.
7. **Nefes Dalgası** — rüzgar toplarken etrafa itme dalgası.

Özel pasif: **Fırtına Gözü** — girdap/hortum alanı ve süresi artar.

Evrimler (sona doğru kaos):
- **Ay Orağı** = Bölünen Kesik + hasar pasifi → ekranı boydan boya geçen dev hilal.
- **Kasırga Patlaması** = Nefes Dalgası + toparlanma pasifi → her rüzgar toplayışta bütün ekrana şok dalgası.
- **Göğün Mızrağı** = Delen Rüzgar + saldırı hızı pasifi → ard arda yağan hava mızrakları.
- **Tufan** = Hortum + Fırtına Gözü → haritada dolaşıp her şeyi süpüren 3–4 dev hortum ("bütün haritaya kaos").

Sayısal değerler (hasar, sıklık, seviye başına artış) builder'a bırakılır; Gunslinger'ın eşdeğer becerileriyle aynı güç bandında olmalı ve dengeleme fazında bot A/B ile ölçülmeli (`tools/balance/`).

## 7. Görsel, ses ve yapım

Görselleri ve sesleri **kullanıcı üretir** (görsel: ChatGPT; ses: ElevenLabs ücretli plan), VLAD istemleri yazar ve gelenleri kontrol eder. Sıra:
1. Kıyafet için 3–4 taslak görsel → kullanıcı seçer.
2. Seçilen tasarımla tam gövde kareleri (kolsuz rig yok): 6 yürüme karesi, 3–4 büyü atma karesi, karakter seçim portresi (`*_portrait.png`).
3. Efektler: hilal kesik, küçük bıçaklar, girdap halkası, hortum, hava mızrağı, dev hortum, rüzgar toplama.
4. İkonlar: 8 (7 aktif + Fırtına Gözü) + 4 evrim + ortak havuzdaki 7 pasifin Zyfen'e özel ikonları.
5. Sesler: savuruş (varyasyonlu), rüzgar toplama, hortum, delen rüzgar vb.; evrim sesleri için mevcut yedek `evolution_5`/`evolution_6` + gerekirse 2 yeni.
6. Gunslinger'ın 6 yürüme karesi (v2.0.1'den ertelenen).

Animasyon (kullanıcı kararı 2026-10-24): **kol düzeneği kullanılmaz**; Zyfen kollarıyla birlikte tek parça tam gövde karelerle çizilir.
- Kareler: yürüme 6 kare + büyü atma 3–4 kare (eller öne savrulur); karakter hedef yönüne aynalanır.
- Kesik, avuçtaki sabit bir atış noktasından (karakter verisinde tanımlı) çıkar ve hedefe gider; el hedefin tam açısına dönmez.
- Kod: `rig`'de kollar isteğe bağlı olur (kolsuz karakterde kol sprite'ları oluşturulmaz/gizlenir; atış noktası gövdeye göre tanımlanır), büyü atma kareleri sim'deki atış olayına bağlanır. Gunslinger'ın kol düzeneği değişmez. Bu iş "uygulama 2 — Zyfen temeli" fazına girer.

## 8. Kısıtlar

- Godot 4.7.2; sim deterministik ve sunumdan ayrık (`scripts/sim/`); sunum RNG'si ayrı.
- Tek kapı: `bash tools/gate.sh` yeşil; kabul testleri (`test/acceptance/`) değişirse "Test itirazı" süreci.
- Mevcut pickup'lar (Kara Bomba, Sonsuz Tambur, Öfke Barutu, Kızgın Namlu…) ve başarımlar ortak kalır; Zyfen ile de anlamlı çalışmalı (ör. "Sonsuz Tambur" sırasında sınırsız kesik). Pickup adlarının silah temalı olması bu sürümde değişmez.
- `cifte_yol` ("iki farklı karakterle 5 dk") Barutçu yerine Zyfen ile karşılanır; Barutçu'ya bağlı kayıtlı ilerleme/ayar (seçili karakter `barutcu`) güvenle Gunslinger'a düşmeli.
- Esin kaynağı adları belgelerde ve kodda geçmez.

## 9. Builder'a bırakılanlar

- Beceri sayısal değerleri ve seviye ilerlemesi (§6.4).
- Ortak/özel ayrımının veri modeli (ör. skill verisinde `pool: common|<karakter>` alanı, karakter başına ad/ikon eşlemesi).
- Delip geçen mermi (pierce) türünün sim'deki uygulaması.
- Ortak pasiflerin Zyfen'deki adları (Derin Nefes hariç).
- Pipeline fazlarının bölünmesi ve sırası.

## 10. VLAD kararları (builder kontrolünden)

- **Gunslinger tohumları:** havuz ayrımı (ör. `dinamit`'in Gunslinger tekliflerinden çıkması) aynı tohumda Gunslinger'ın seviye kartlarını ve hash'ini değiştirir. Bu kabul edilir: determinizm "aynı sürüm + aynı tohum → aynı hash" anlamındadır; eski sürümle bit-bit aynılık aranmaz. `expected_tables`, determinizm/uzun doğrulama beklentileri ve `tools/balance` tabanları yeniden üretilir ("Test itirazı" ile, v2.0.1'deki T73 örneği gibi). "Denge bozulmadı" ölçütü: Gunslinger'ın bot A/B medyan hayatta kalma ve 10–20 dk kalan can değerleri v2.0.1'e göre ±%5 içinde.
- **`cifte_yol` ve eski Barutçu kaydı:** başarım deposundaki (`chars5`) `barutcu` kaydı korunur ve sayılmaya devam eder; oyuncu kazandığını kaybetmez. Seçili karakter `barutcu` ise Gunslinger'a düşer.

## 11. Yayın koşulu (kullanıcı)

- **Kod yer tutucu görsellerle paralel ilerler:** görseller/sesler gelmeden kod fazları (havuz ayrımı, Zyfen verisi, rüzgar becerileri, pierce, Barutçu'nun kaldırılması, testler) yer tutucu sanatla (`placeholder: true`, basit kod çizimi/geçici ikon) yazılabilir ve entegrasyon branch'ine merge edilebilir.
- **v2.0.2, Zyfen bitmeden çıkmaz:** son kapı (ana branch'e merge ve sürüm etiketi), Zyfen'in bütün görsel ve ses varlıkları gelip bağlanmadan açılmaz. Gunslinger yürüme kareleri de v2.0.2 kapsamındadır.

## 12. Hareketli portreler (kullanıcı, 2026-10-24)

- Karakter seçim ve seviye atlama ekranlarındaki portreler **iki karakterde de** (Zyfen ve Gunslinger) hareketli döngü olur: pelerin/saç dalgalanması, eldeki rüzgar (Gunslinger'da duman/köz), arka planda köz ve kül; kamera ve yüz sabit.
- Üretim: durağan portreden image-to-video (yeşil değil, arka planlı), VLAD 3–4 sn'lik dikişsiz döngüyü keser (çapraz geçiş) ve Godot'nun oynatabildiği biçime çevirir (`.ogv` ya da kare dizisi; APK etkisi döngü başına ~1–2 MB hedef).
- Kod: portre gösteren ekranlar döngüyü oynatır; video yüklenemezse durağan portre yedek olarak gösterilir. Bu iş görsel bağlama fazına girer.
