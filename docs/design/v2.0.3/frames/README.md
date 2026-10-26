# v2.0.3 UI doku kaynakları (SVG)

Godot'ta `StyleBoxTexture` (9-slice) ya da `TextureRect` olarak içe aktarılır; **CSS filtresi/blur yok**. Maketler `mock/` bu SVG'leri (`docs/design/v2.0.3/.gdignore` içe aktarmayı kapatır; developer gerekenleri `assets/ui/` altına kopyalar) aynı 9-slice değerleriyle (`border-image`) kullanır. Yenilemek: `python3 make_frames.py`.

| Dosya | Tür | Boyut | patch_margin (sol/üst/sağ/alt) | Kullanım |
|---|---|---|---|---|
| `levha.svg` | 9-slice | 144² | 40 | kart/panel (ayar kartı, başarım satırı) |
| `levha-yuksek.svg` | 9-slice | 144² | 40 | yükseltilmiş yüzey, açık satır paneli |
| `dugme-birincil.svg` | 9-slice | 144² | 40 | OYNA, birincil eylemler (bordo) |
| `dugme-dolu.svg` | 9-slice | 144² | 40 | KARAKTERLER, BAŞARIMLAR, GERİ (taş yüzey) |
| `dugme-hayalet.svg` | 9-slice | 144² | 40 | EN İYİ SKORLAR, AYARLAR (kenar çizgili, dolgusuz) |
| `dugme-basili.svg` | 9-slice | 144² | 40 | basılı durum (6 px aşağı + bu doku) |
| `lento.svg` | 9-slice | 240×120 | 60/0/60/0 | ayarlar başlık levhası |
| `oyna-tepe.svg` | sabit | 240×48 | — | OYNA üst kenar orta süsü (sivri uç/sancak ucu) |
| `anahtar-ac.svg` / `anahtar-kapali.svg` | sabit | 156×84 | — | kor mührü anahtarı |
| `tutamak.svg` / `tutamak-sessiz.svg` | sabit | 84² | — | kaydırıcı madalyonu |
| `ray.svg` | 9-slice | 96×28 | 24/0/24/0 | kaydırıcı zincir rayı |
| `ray-dolgu.svg` / `ray-dolgu-sessiz.svg` | 9-slice | 96×28 | 24/0/24/0 | kor dolgusu / sessiz |
| `plaka-1…4.svg`, `plaka-kilitli.svg` | sabit | 108² | — | başarım kademe plakası (I yalın demir · II perçin · III köşebent · IV taç + bordo) |
| `muhur-dolu/aktif/sonuk.svg` | sabit | 72² | — | kademe yolu mührü; kroniği şeridi |
| `zincir-halka(-sonuk).svg` | sabit | 24×40 | — | kademe yolu/kroniği zinciri |
| `ayrac.svg` | 9-slice | 240×20 | 96/0/96/0 | yalnız ana sayfa üst yazısı iki yanı (bölüm/grup başlıklarındaki çizgi `StyleBoxFlat` 3 px `bronz_700`) |
