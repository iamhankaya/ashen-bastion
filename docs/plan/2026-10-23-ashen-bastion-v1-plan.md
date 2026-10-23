### VLAD notları (plana ek, plandan önceliklidir)
- **Prova eşlemesi düzeltmesi:** Pipeline'da ayrı bir `prova` fazı var (T20261023-63, devops, uygulama-1'e bağlı). İmzalı release APK hattı ve keystore (planda U2-9) **prova fazına** aittir. U1-11 yalnızca debug APK + cihaz içi stres ölçümü olarak kalır. Uygulama-2 release imzalamaya dokunmaz.
- **Bulut ağı (2026-10-23 ölçümü):** VLAD container'ından `github.com/godotengine/godot-builds` (GitHub proxy 403), `dl.google.com`, `kenney.nl`, `freesound.org`, `downloads.tuxfamily.org` erişilemiyor; `maven.google.com` erişilebilir. C0 yerel kurulumu deneyecek; başarısız olursa **yedek: gate GitHub Actions'ta** koşar (vlad/* push'larında `bash tools/gate.sh`), çalışan sonucu GitHub MCP (`actions_list`, `get_job_logs`) ile okur ve raporuna yazar. Gate'siz ilerlenmez.
- **Ses dosyası kaynağı:** CC0 SFX indirme bulutta engelliyse kullanıcıdan alınır ya da CI'da indirilir; açık nokta.

Ashen Bastion v1 SON PLAN (T20261023-57). Taslak ve iki eleştiri işlendi.

Notlar:
- `writing-plans` skill'i yüklendi. `superpowers:brainstorming` yüklenemedi. Skill'in "Plan Document Header" şablonu yerine rolün `## Çıktı` başlıkları kullanıldı, çünkü rol kuralı öncelikli.
- Bu oturumda Godot, GUT ve godot-builds'e erişim yok (taslaktaki proxy 403 bulgusu geçerli). Sürüm, URL ve paket adı bilgileri "varsayım" ve C0 görevi bunları doğrulayıp sabitler. Repoda kod yok (greenfield).
- Kartın `exposure` değeri `local`, `### Sistem tasarımı` buna göre kısa.
- Planın dayandığı tasarım belgesini ve DESIGN-UI.md'yi bu turda yeniden okumadım; sayılar taslaktan taşındı.
- Kullanıcıya soru sorulmadı, dosya değiştirilmedi.

**Kart `gate` komutu (tek satır):** `bash tools/gate.sh`

Ortam bayrakları gate komutunun parçası değil, isteğe bağlı: `GATE_EXPORT=1` (debug APK), `GATE_NIGHTLY=1` (20 dk koşu, sızıntı, seed dağılımı), `GATE_RENDER=1` (xvfb shader smoke).

### Bileşenler

Tek mimari kural: **simülasyon (`scripts/sim/`) sahne ağacından VE autoload'lardan bağımsız saf GDScript'tir. Görünüm (`scripts/view/`, `scenes/`, `scripts/audio/`) simülasyonu yalnızca okur.** Gerekçe: 300+ düşman için düşman başına Node yok. Headless test ve bot ile 20 dakikalık oyun GPU'suz koşturulabilir. Sim örneği kendi olay veriyolunu taşıdığı için testler arasında global durum sızmaz.

| Bileşen | Sorumluluk | Yapmaz | Bağımlılık |
|---|---|---|---|
| `GameSim` (`scripts/sim/game_sim.gd`) | Sabit 60 Hz adımlı oyun durumu: süre, seviye, XP, can, durum makinesi. Alt sistemleri sırayla çağırır. `SkillApi` yüzeyini (beceri davranışlarının kullandığı yöntemler) sunar. Gözlem kancaları: `state_hash`, `event_log`, `check_invariants`, `alive_ids`, `work` sayaçları. | Çizmez, Node/Input/autoload bilmez | tüm sim sınıfları, `GameData` |
| `SimBus` (`scripts/sim/sim_bus.gd`) | Örnek başına sinyal veriyolu (RefCounted). View/UI/ses `sim.bus`'a bağlanır. | Sim kararları ona bağlı değil | – |
| `GameData` (`scripts/sim/game_data.gd`, **autoload değil**) | `data/**` yükler, `validate()` ile şemayı doğrular, tipli tanım nesneleri verir. `GameData.load_default()` önbellekli. | Oyun durumu tutmaz | JSON dosyaları |
| `EnemyPool` / `ProjectilePool` / `GemPool` / `ZonePool` | SoA (`Packed*Array`) havuzlar, LIFO serbest-liste, nesil sayacıyla kimlik. `ProjectilePool` mermi başına vurulan küme (`hit_ids`) tutar. | Çizmez | – |
| `SpatialHash` | Hücre 96 px. Her adım yeniden kurulur (artan indeks sırasıyla). Daire sorgusu **artan id sıralı** döner. | Fizik motoru kullanmaz | – |
| `Magazine` | Ortak şarjör ve doldurma durum makinesi | Hasar hesaplamaz | `StatBlock` |
| `Targeting` | Tabanca başına hedef seçimi | Ateş etmez | `EnemyPool`, `SpatialHash` |
| `DamageSystem` | Hasar/zırh/ölüm/XP taşı, `on_hit`/`on_kill` | Hedef seçmez | pool'lar, `Loadout` |
| `StatBlock` | Pasiflerden toplanan çarpanlar | Beceri mantığı yok | `Loadout` |
| `Loadout` | 6+6 yuva, evrim koşulu, `roll_choices()` | UI bilmez | `GameData`, `SkillBehavior` |
| `SkillBehavior` + `scripts/sim/skills/*.gd` | Bir becerinin kancaları (bkz. `docs/dev/skill-hooks.md`) | Doğrudan çizim yok | `SkillApi` (= `GameSim`) |
| `SpawnDirector` | `waves` verisine göre doğurma, boss/lord, uzak düşmanı geri taşıma, spawn kaybı sayacı | Düşman davranışı yok | `EnemyPool`, `rng_spawn` |
| `EnemyAI` (sim içinde) | Hareket, engel itme, temas hasarı | – | `SpatialHash`, engel listesi |
| `MapSim` | Chunk başına deterministik harabe yerleşimi, engel daireleri | Görsel yok | `rng_map` |
| `XpCurve`, `Difficulty` | Saf fonksiyonlar (tamsayı XP) | – | – |
| `PlayerRig` (`scripts/sim/player_rig.gd`) | `muzzle_world(...)` **tek kaynak**: sim mermi çıkış noktasını bununla hesaplar, view aynı fonksiyonla çizer | – | karakter verisi |
| Görünüm: `EnemyRenderer`, `ProjectileRenderer`, `GemRenderer`, `FxRenderer` | Tür başına tek `MultiMeshInstance2D`. Kare başına tek `buffer` yazımı, canlı sayısı kadar `visible_instance_count`. | Mantık yok | `GameSim` |
| `PlayerView`, `GroundView`, `RuinView`, `CameraRig` | Parçalı rig, zemin, y-sıralı harabe, kamera | – | `GameSim`, `MapSim` |
| UI: `VirtualJoystick`, `Hud`, `LevelUpScreen`, `PauseScreen`, `ResultScreen`, `MainMenu` | `docs/ui` maketlerini uygular | Oyun kuralı yok | `sim.bus`, `Settings` |
| `InputGate`, `PauseLogic` (saf sınıflar, `scripts/ctrl/`) | İlk parmak kuralı, 600 ms girdi kilidi, LEVEL_UP'ta duraklama, arka plan/odak kaybı kararı | Node bilmez | – |
| `GameController` | Girdi → `step(move)` (kare başına en çok 3 adım), ekran geçişleri. Karar mantığı `InputGate`/`PauseLogic`'tedir. | Karar mantığı yok | hepsi |
| `Settings`, `Events` (tek autoload çifti) | `Settings`: `user://settings.cfg` (yol enjekte edilebilir). `Events`: yalnız uygulama/UI olayları (pause, settings_changed). | Sim olayı taşımaz | – |
| Ses: `AudioDirector`, `Sfx`, `MusicPlan` (`scripts/audio/`) | `MusicPlan`: saf fonksiyon, hangi müzik hangi durumda. `AudioDirector`: crossfade ve bus. `Sfx`: havuzlu çalma. | Sim'e dokunmaz | `sim.bus`, `Settings` |
| `tools/art/` (Python) | Chroma key, kırpma, bölme, manifest | – | Pillow, numpy |
| `tools/audio/` (Python) | WAV → OGG, loudness, döngü crossfade, SFX lisans denetimi | – | numpy, scipy, soundfile, pyloudnorm |
| `tools/gate.sh`, `tools/ci/*` | Godot kurulumu, lint, test, veri doğrulama, gate öz-testi, CI | – | – |

### Sistem tasarımı

`exposure: local`, kısa:
- **Süreç modeli:** tek süreç, ağ yok. Android'de yalnızca `VIBRATE` izni verilir, `INTERNET` yok.
- **Sim adımı:** `GameSim.step(move)` **yalnızca sabit** `STEP=1/60` ilerler (dt parametresi yok). Controller zaman biriktirici kullanır ve kare başına en çok 3 adım atar. Cihaz yetişemezse oyun yavaş çekim akar. Bu kabul edilen davranıştır (dt ölçeklenmez, tasarım deterministik kalır). `Engine.max_fps=60` (varsayım, VSync açık). Interpolasyon v1'de yok.
- **Renderer:** `gl_compatibility`.
- **Determinizm:**
  - Dört ayrı RNG akışı: `rng_spawn`, `rng_choice`, `rng_map`, `rng_combat`. Her biri `hash(seed, akış_adı)` ile türetilir. Yeni özellik başka akışın dizisini kaydırmaz.
  - Sonucu etkileyen yerde Dictionary yinelemesi yok (sıralı Array ve indeksli havuz kullanılır). Serbest-liste LIFO. `query_circle` artan id sıralı.
  - RNG dizisi Godot sürümleri arası aynı olmayabilir. Testler **aynı ikili ile iki koşunun `state_hash` eşitliğini** ve **aralık/dağılım** beklentilerini doğrular, sabit "altın" sayı yazmaz.
- **Saklama:** yalnızca `user://settings.cfg`. Oyun kaydı yok.
- **Kurtarma:** arka plana alınınca otomatik duraklat. Çökme sonrası durum yok.
- **Performans yaklaşımı:**
  - SoA diziler, `MultiMesh.buffer` ile toplu çizim, fizik motorsuz hash ızgara + daire-daire çarpışma.
  - Ayrıştırma üç karede bir kademeli. Hot path'te `Array`/Dictionary oluşturma yok (önceden ayrılmış Packed diziler).
  - MultiMesh yazımı: kalıcı `PackedFloat32Array`'a doğrudan indeks yazımı. Düşman sırası = `alive_ids()` sırası. Havuz sıkıştırılmaz, kimlik/nesil kuralı bozulmaz.
  - Havuz üst sınırları: düşman 400, mermi 600, XP taşı 300, bölge 64.
  - **Bütçe iddiası yok.** "Cihaz = masaüstü × 6" varsayımı kaldırıldı. Ölçüm üç katmanlıdır:
    1. Gate'te deterministik iş sayaçları (`GameSim.work`).
    2. Uygulama-1'in ilk görevinde masaüstü mikro-ölçüm. Zaman yalnız bilgidir.
    3. Debug APK'da cihaz içi 60 sn stres ölçümü (`user://perf.json` + ekranda). Sonucu kullanıcı paylaşır.
  - **Gerçekçi yedek merdiveni** (`docs/dev/perf.md`, sırayla):
    1. `alive_cap`/mermi CAP düşür (düşman 400→300, mermi 600→400).
    2. Hash hücresi 96→128, ayrıştırma 4 karede bir.
    3. Mermi–düşman çarpışmasını iki kareye böl.
    4. Karga/hayalet çarpışma yok sayma.
    - GDExtension bulutta derlenemediği için **kapsam dışıdır**. "PackedArray toplu işlem" gerçek yedek sayılmaz. "300+" hedefinin altına inilirse karar kullanıcıya gider (Açık noktalar).
- **Düşman çizim sırası (kasıtlı sınır):** düşman MultiMesh'leri harabe+oyuncu y-sıralı katmanının altında. Düşman–harabe y-sort yok. Karga (uçan) en üstte.
- **Dağıtım:**
  - Uygulama-1: CI'da debug APK, **repoya commit'li standart debug keystore** (`tools/ci/debug.keystore`, `android`/`androiddebugkey`; sır değil). Böylece her CI APK'sı aynı imzayla güncelleme olarak kurulur.
  - Uygulama-2: imzalı release APK. Keystore GitHub secret'ta, repo public.
- **Güvenlik işaretli bileşen:** auth/veri silme yok. **Release imza ve CI secret akışı (U2-9)**: VLAD kısa güvenlik incelemesi eklesin (public repo, `pull_request` olay modeli, secret'ın PR'da erişilememesi, anahtarın log'a düşmemesi). Ses/lisans akışında güvenlik etkisi yok.

### Arayüzler

#### Sabitler ve ölçü
- Dünya birimi = ekran pikseli (1080×2400 referans, `stretch=canvas_items`, `aspect=expand`, dikey).
- Girdi `InputEventScreenTouch/Drag`. Masaüstü testinde `emulate_touch_from_mouse=true`.
- `InputGate` (saf sınıf) kuralları:
  - İlk parmak joystick, ikinci parmak yok sayılır.
  - Ölü bölge 0,12. Maks. yarıçap 150 px.
  - Parmak kalkınca topuz 120 ms'de söner.
  - Devam/seviye atlama sonrası 600 ms girdi kilidi.
- `VirtualJoystick` yalnızca `InputGate`'in `move: Vector2` çıktısını gösterir. Hareket vektörünü tek `InputGate.move()` üretir.

#### `GameSim`
```gdscript
class_name GameSim extends RefCounted
enum State { RUNNING, LEVEL_UP, WON, LOST }
const STEP := 1.0 / 60.0
func _init(p_seed: int, character_id: StringName, opts: Dictionary = {}) -> void
  # opts: "end_mode": "lord"(varsayılan; end_time'da Kale Lordu doğar, ölümü WON)
  #                  | "timer" (time >= end_time => WON; demo)
  #       "end_time": float = 1200.0, "start_time": float = 0.0,
  #       "data": GameData, "log_events": bool = false (test: true; üretimde false),
  #       "max_log": int = 200000
func step(move: Vector2) -> void           # her çağrı tam STEP ilerler; |move|<=1; State != RUNNING ise no-op
func pending_choices() -> Array[Choice]    # State == LEVEL_UP iken 1..3 eleman
func choose(index: int) -> bool            # State != LEVEL_UP ya da geçersiz indeks => false, hiçbir şey değişmez
var bus: SimBus
var state: int; var time: float; var step_count: int; var level: int; var xp: int; var xp_to_next: int
var pending_levels: int                    # bekleyen seviye atlama sayısı
var hp: float; var max_hp: float; var kills: int; var player_pos: Vector2
var magazine: Magazine; var loadout: Loadout; var enemies: EnemyPool
var projectiles: ProjectilePool; var gems: GemPool; var zones: ZonePool; var stats: StatBlock
var evolved_log: Array[StringName]
var event_log: Array                       # opts.log_events ise Dictionary kayıtları, bkz. aşağıda
var work: Dictionary                       # deterministik iş sayaçları
var spawn_dropped: int                     # havuz doluluğundan kaybolan doğurma sayısı
# Gözlem kancaları (testler/bot/gate; üretim mantığı çağırmaz):
func state_hash() -> int                   # step_count, player (pos/hp/xp/level), canlı düşman (indeks, pos, hp), mermi/taş sayısı + toplam taş XP, şarjör, loadout seviyeleri, 4 RNG durumu; konumlar 1/64 px nicemleme ile
func check_invariants() -> PackedStringArray   # boşsa sağlam, bkz. aşağıda
func alive_ids() -> PackedInt32Array       # artan id sırası
func debug_grant(skill_id: StringName, lvl: int = 1) -> void   # yuva sınırına uyar; evrim id verilirse koşulsuz uygulanır
func debug_spawn(type_id: StringName, pos: Vector2) -> int     # enemy_id veya -1
func debug_fill(type_id: StringName, n: int, ring_radius: float) -> int   # stres/perf: n düşmanı halkaya koyar, doğan sayı
func debug_set_time(t: float) -> void
func debug_add_xp(n: int) -> void
func debug_force_choices(ids: Array[StringName]) -> void       # sonraki roll_choices tam bu kimlikleri döner (tek kullanımlık)
```
`class Choice` (ayrı dosya `choice.gd`): `kind: StringName ("upgrade"|"new"|"evolution"|"heal")`, `skill_id`, `from_level`, `to_level`, `title`, `desc`, `icon`.

**Adım sırası (sabit):** (1) tick'ler: şarjör, soğumalar, durum süreleri, (2) oyuncu hareketi, (3) hash yeniden kur, (4) hedefleme + ateş (tabanca 0 sonra 1), (5) bağımsız beceriler (`tick`), (6) mermi hareketi + çarpışma + `hit_ids`, (7) düşman AI + temas hasarı, (8) ölüm/XP/taş toplama, (9) doğurma, (10) durum: seviye atlama, WON/LOST.

**Oyun sonu öncelikleri:**
- Aynı adımda Lord ölümü ve `hp<=0` ise **WON** (Lord ölümü önce işlenir).
- `end_mode:"timer"`'da süre dolması ile `hp<=0` aynı adımda ise LOST.
- WON/LOST olduğu adımda bekleyen LEVEL_UP iptal edilir (`pending_levels=0`, seçimler atılır).
- WON/LOST sonrası `step` ve `choose` no-op.

**Seviye atlama:**
- XP eşiği aşıldığı adımda `level` artar, `xp -= xp_to_next`, `pending_levels += 1`.
- Bir adımda birden çok eşik aşılabilir.
- `pending_levels>0` ise State `LEVEL_UP` olur (sim donar). Her `choose` bir bekleyeni tüketir. Kalan varsa yeni `roll_choices` ile LEVEL_UP sürer, yoksa RUNNING.
- LEVEL_UP'ta XP kazanımı olmaz.

**`start_time` / `debug_set_time(t)` semantiği:**
- Yalnızca ileri atlama.
- `at` olayları (boss/halka) **atlanan aralıkta tetiklenmez** (`at < t` olanlar "yapıldı" işaretlenir). `at == t` sonraki adımda tetiklenir.
- Hız oranı/zorluk/`alive_cap` yeni `t`'ye göre hesaplanır.
- XP/seviye/beceri değişmez (testler bunları `debug_*` ile kurar).

**Spawn başarısızlığı:** havuz doluysa `spawn` `-1` döner. Doğrulama kaybı: olay yeniden denenmez ve kuyruğa girmez. `spawn_dropped++`, `event_log`'a `spawn_dropped`. Kesirli oran biriktiricisi korunur.

**`event_log` kayıtları** (`{"step":int,"type":StringName, …alanlar}`): `shot{gun,origin,dir,dmg,index_in_mag,is_last}`, `damage{target,amount,raw,kind:"bullet|explosion|contact|dot",source}`, `explosion{pos,radius,dmg,source}`, `kill{enemy_id,type,pos}`, `spawn{type,id,pos}`, `spawn_dropped{type}`, `reload_start{duration}`, `reload_end{}`, `refund{n}`, `dry_fire{gun}`, `gem_dropped{value}`, `gem_collected{value}`, `level_up{level}`, `choices{ids}`, `choice_made{skill_id}`, `evolution{evo_id}`, `boss_warning{kind}`, `boss_spawn{type}`, `run_end{won}`. Kabul testleri `GameSim.event_log`'u okur, havuz içine bakmaz.

**`check_invariants()` denetler:**
- `hp<=max_hp`.
- NaN/inf yok (konum, hp, hız).
- `enemies.count<=CAP`, `projectiles.count<=CAP`, `gems.count<=CAP`.
- `xp>=0` ve `xp<xp_to_next` (LEVEL_UP dışında).
- Her canlı kimliğin indeksi geçerli ve nesil uyumlu.
- `time` monoton.
- `magazine.count` içinde `0..cap`.
- Slot sayısı ≤6+6.
- Taş XP korunumu (birleşmede toplam değer değişmez).

**`work` sayaçları** (her adımda sıfırlanmaz, kümülatif; gate farkı `step_count`'a böler): `hash_inserts`, `hash_queries`, `cells_scanned`, `collision_tests`, `enemy_updates`, `proj_updates`, `explosions`.

#### `SimBus` (örnek başına)
Sinyaller: `magazine_changed(count, cap)`, `reload_started(duration)`, `reload_finished()`, `shot_fired(gun, origin, dir)`, `last_bullet_fired(origin)`, `dry_fire(gun)`, `enemy_killed(type_id, pos)`, `gem_collected(value)`, `player_damaged(amount, hp)`, `level_up(level)`, `choice_made(skill_id)`, `evolution_gained(evo_id)`, `boss_warning(kind)`, `boss_spawned(type_id)`, `explosion(pos, radius)`, `run_ended(won, stats)`. Sim bunları yalnızca bildirim için yayınlar. Mantık sinyale bağlı değildir. `boss_warning` olaydan 5 sn önce yayınlanır, UI bandı 2,4 sn gösterir (UI süreyi kendi tutar).

#### Kimlik
`enemy_id = (generation << 16) | index`. Nesil 16 bit, sarma davranışı birim testle belgelenir (65536. yeniden kullanımda 0'a döner, çakışma yalnızca aynı indeks ve aynı nesilde olur, canlı id'ler arasında olmaz). `EnemyPool.is_alive(id)` nesil uyumsuzluğunda `false`.

#### `SpatialHash`
```gdscript
class_name SpatialHash extends RefCounted
func _init(cell: float = 96.0) -> void
func clear() -> void
func insert(id: int, pos: Vector2) -> void      # çağıran artan indeks sırasıyla ekler
func query_circle(center: Vector2, radius: float, out: PackedInt32Array) -> void  # out temizlenir; id'ler ARTAN sıralı
```

#### Havuzlar
```gdscript
class_name EnemyPool extends RefCounted
const CAP := 400
var count: int; var pos: PackedVector2Array; var hp: PackedFloat32Array
var type_idx: PackedInt32Array; var flash: PackedFloat32Array
func spawn(type_id: StringName, p: Vector2, hp_mult: float, contact_mult: float, speed_mult: float) -> int  # -1 = dolu
func kill(id: int) -> void
func is_alive(id: int) -> bool
func radius_of(id: int) -> float
class_name ProjectilePool extends RefCounted
const CAP := 600
const HIT_SLOTS := 12                      # mermi başına vurulan düşman kümesi (halka tampon)
func spawn(p: Vector2, v: Vector2, dmg: float, o: Dictionary = {}) -> int
  # o: pierce:int, bounces:int, life:float(=1.2), flags:int, ex_radius, ex_dmg, push:float, gun:int
  # flags: EXPLODES(isabette), EXPLODE_ON_EXPIRE(dinamit), EXPLODE_ON_BOUNCE(zincirleme), RICOCHET, RADIAL(yalnız görsel)
func has_hit(pid: int, enemy_id: int) -> bool
func mark_hit(pid: int, enemy_id: int) -> void
class_name GemPool extends RefCounted
const CAP := 300
func drop(p: Vector2, value: int) -> void  # CAP aşılırsa en yakın iki taş birleşir (toplam değer korunur)
```
- Pierce ve bounce: mermi bir düşmana yalnızca bir kez vurur (`has_hit`). Sekmede hedef = `hit_ids`'te olmayan en yakın düşman (≤300 px), yoksa mermi biter.
- Pierce biterse mermi söner.
- `keskin_nisan` mermi değil, **hitscan**dır (`SkillApi.hitscan`): çizgi üzerindeki tüm düşmanlara vurur.
- Taş birleştirme "en yakın iki" araması her adım değil, yalnızca `drop` CAP'i aştığında ve mevcut taşların ızgara hücre komşuluğunda yapılır (O(n²) yok).

#### `Magazine` (kesin kurallar)
```gdscript
class_name Magazine extends RefCounted
signal changed(count: int, cap: int); signal reload_started(duration: float); signal reload_finished()
var count: int; var cap: int; var reloading: bool; var reload_left: float; var reload_total: float
func can_fire() -> bool                  # count > 0 and not reloading
func consume() -> Dictionary             # {"ok":bool,"index":int,"is_last":bool}
func refund(n: int) -> void              # reloading ise yok sayılır; count = min(cap, count + n)
func tick(dt: float, stats: StatBlock) -> void
func start_reload(stats: StatBlock) -> void
func set_cap(new_cap: int) -> void       # StatBlock değişince sim çağırır
func reset_cycle_flags() -> void
var refund_used: bool                    # kiyamet_mermisi: döngü başına bir geri yazma; reload_finished'te false olur
```
- **Cap:** `cap = 6 + stats.mag_add`.
- `consume()` yalnız `can_fire()` iken `count -= 1` yapar. `index = cap − count_önce + 1` (1..cap). `is_last = (count_sonra == 0)`.
- **Cap değişimi:** pasif seviyesi yalnız `choose()` anında artar (sim LEVEL_UP'ta donuk). Cap artarsa `count += (yeni_cap − eski_cap)` (anında eklenir), `reloading` ise doldurma bitince zaten `count=cap`.
- **Doldurma:**
  - `count==0 && !reloading` iken `tick` bir sonraki adımın **başında** doldurmayı otomatik başlatır.
  - `reload_total = max(0.35, base × stats.reload_time_mult)` `start_reload` anında hesaplanır; doldurma ortasında stat değişimi bu doldurmayı etkilemez.
  - `reload_left` dt kadar azalır, 0'a inince `count = cap`, `reloading=false`, `reload_finished`, `refund_used=false`.
- **Sıra:** ateş fazında son kurşun `consume()` edilince aynı adımda `on_last_bullet` çalışır. `refund` bu sırada `count`'u 0'dan yükseltirse bir sonraki adım başında doldurma **başlamaz**. `kiyamet_mermisi` geri yazması bu yüzden döngü başına bir kez ile sınırlıdır: ikinci "son kurşun"da `refund_used` true olduğundan geri yazma olmaz, doldurma başlar ve `reload_finished`'te bayrak sıfırlanır.
- **Çift tabanca atış aralığı** (`cift_tabanca` tablosundaki "atış aralığı"): **tabanca başına**. İki tabanca yarım aralık faz farkıyla sırayla ateş eder (tabanca 0 `t=0`'da, tabanca 1 `interval/2`'de başlar). Toplam hız = `2/interval` mermi/sn. Sv1'de 6 kurşun yaklaşık 0,75 sn'de biter (ardından 1,0 sn doldurma). Aralık `interval / (1 + hizli_parmak_toplamı)`. Hedef yoksa o tabanca ateş etmez ve mermi harcanmaz.
- Doldurma sırasında bir tabanca hedefe sahipse (ve soğuması bitmişse) `dry_fire` olayı yayınlanır (tabanca başına en çok 0,5 sn'de bir).

#### `Targeting`
```gdscript
static func pick(gun: int, from: Vector2, range: float, enemies: EnemyPool, grid: SpatialHash, other_target: int) -> int  # -1 = yok
```
- Menzil `700 × stats.range_mult` (v1'de 1.0). Silah 0: menzildeki en yakın. Silah 1: menzilde elit/boss varsa onların en yakını, yoksa silah 0'ın hedefi dışındaki en yakın (ikinci), tek düşman varsa aynı hedef.
- **Eşitlik kırıcı:** eşit uzaklıkta **en düşük indeks**. Hedef 0,1 sn'de bir yenilenir, hedef ölünce hemen. Yenileme sırası: önce tabanca 0 sonra tabanca 1 (silah 1, silah 0'ın yenilenmiş hedefini görür).
- Hedef yoksa ateş yok, şarjör harcanmaz, kol hareket yönüne bakar.

#### `Loadout`, `StatBlock`, `SkillBehavior`, `ShotContext`
```gdscript
class_name Loadout extends RefCounted
const ACTIVE_SLOTS := 6; const PASSIVE_SLOTS := 6
func level_of(skill_id: StringName) -> int
func actives() -> Array[SkillState]; func passives() -> Array[SkillState]
func add_or_upgrade(skill_id: StringName) -> void
func evolution_ready() -> StringName
func apply_evolution(evo_id: StringName) -> void       # ham aktifi yerinde değiştirir
func roll_choices(rng: RandomNumberGenerator) -> Array[Choice]   # sim buraya rng_choice verir
class_name StatBlock extends RefCounted
var bullet_dmg_mult := 1.0; var fire_rate_mult := 1.0; var reload_time_mult := 1.0; var mag_add := 0
var area_mult := 1.0; var explosion_dmg_mult := 1.0; var move_speed_mult := 1.0
var max_hp_add := 0.0; var regen := 0.0; var pickup_mult := 1.0; var range_mult := 1.0
func rebuild(loadout: Loadout, data: GameData) -> void
class_name SkillBehavior extends RefCounted
func setup(api: GameSim, def: SkillDef, level: int) -> void
func modify_shot(ctx: ShotContext) -> void         # şarjörden çıkan her kurşun
func on_last_bullet(ctx: ShotContext) -> void
func on_reload_start() -> void
func on_reload_tick(dt: float) -> void             # doldurma süresince (mermi_firtinasi halkaları)
func on_reload_end() -> void
func on_kill(enemy_id: int, pos: Vector2) -> void
func on_hit(enemy_id: int, proj_id: int) -> void
func tick(dt: float) -> void                       # şarjörsüz, soğumalı silahlar
class_name ShotContext extends RefCounted
var gun: int; var index_in_mag: int; var is_last: bool; var origin: Vector2; var dir: Vector2
var damage: float; var pierce: int; var bounces: int; var flags: int
var ex_radius: float; var ex_dmg: float; var push: float; var tags: PackedStringArray
```
**`SkillApi` (GameSim'in yöntemleri, beceri davranışları bunlarla çalışır):** `spawn_projectile(p, v, dmg, o) -> int`, `explode(pos, radius, dmg, source: StringName)` (zırhı yok sayar, `area_mult`/`explosion_dmg_mult` uygular), `hitscan(origin, dir, range, dmg) -> int` (çizgi üzerindeki hepsi, mesafe sırasıyla), `damage_enemy(id, amount, kind)`, `pick_highest_hp(from, range) -> int` (eşitlikte en düşük indeks), `magazine` (refund), `rng_combat`.

**Kayıt:** `scripts/sim/skills/skill_registry.gd` → `const BEHAVIORS := { &"cift_tabanca": …, … }` alfabetik; becerinin JSON'undaki `behavior` buradan çözülür.

**Sözleşme kanca eşlemesi** (`docs/dev/skill-hooks.md`, C2'de yazılır, `test_contract_hooks.gd` 12 kimliğin de dokümanda geçtiğini doğrular):

| Beceri | Kancalar / API | Gerekli bayrak/alan |
|---|---|---|
| `cift_tabanca` | temel atış: sim şarjörden çıkarır, `modify_shot` çağrılır | – |
| `seken_mermi` | `modify_shot`: `index_in_mag % N == 0` ise `bounces`, `damage×`, RICOCHET | RICOCHET, `hit_ids` |
| `yelpaze_atis` | `tick`: soğuma, `spawn_projectile` ×N yelpazede (menzil 380, kısa ömür) | – |
| `dinamit` | `tick`: soğuma, yay atış `spawn_projectile` (fitil 0,8 sn) | EXPLODE_ON_EXPIRE |
| `son_mermi_patlar` | `on_last_bullet`: `ctx.flags|=EXPLODES`, `ex_radius/ex_dmg` | EXPLODES |
| `doldurma_sacilmasi` | `on_reload_start`: radyal `spawn_projectile` ×N | RADIAL |
| `sarapnel` | `on_kill`: `rng_combat` şans, `spawn_projectile` ×N (menzil 260) | – |
| `keskin_nisan` | `tick`: `pick_highest_hp` + `hitscan` | – |
| `zincirleme_patlama` (evrim) | `modify_shot`: RICOCHET + EXPLODE_ON_BOUNCE, her 2. kurşun | EXPLODE_ON_BOUNCE |
| `kiyamet_mermisi` (evrim) | `on_last_bullet`: devasa patlama + `magazine.refund(2)` (`refund_used`) | EXPLODES |
| `mermi_firtinasi` (evrim) | `on_reload_start` (2×cap salvo) + `on_reload_tick` (0,15 sn'de 6'lı halka) | RADIAL |
| `gurleyen_yelpaze` (evrim) | `tick`: 13 saçma, `pierce 2`, `push 160` | `push` |

Bu eşleme doğrulanamazsa sözleşme bir kanca ekler. Sözleşme sonrası kanca imzası değişmez, yalnızca sona eklenir.

#### `XpCurve` (tamsayı aritmetik)
```gdscript
static func need(n: int) -> int   # = 8 + 4*n + (n*n)/10   (tamsayı bölme, yuvarlama yok)
static func cumulative(level: int) -> int   # seviye L'ye ulaşmak için toplam XP = Σ need(1..L−1)
```
Sabit tablo (düzeltilmiş): `need(1..5)=12,16,20,25,30`, `need(10)=58`, `need(20)=128`, `need(30)=218`, `need(40)=328`. `cumulative(10)=276`. Taslaktaki "n=3: 21" yanlıştı (yuvarlamalı formül). Taslağın dakika-seviye modeli kabaca doğrudur (floor, bir seviyeden az fark). Denge görevi yeniden hesaplar.

#### `Difficulty`
`enemy_hp_mult(t)`, `enemy_dmg_mult(t)`, `enemy_speed_mult(t)`, `alive_cap(t)` (`m=t/60`):
- `hp = 1+0.10m+0.004m²`
- `dmg = 1+0.04m`
- `speed = min(1+0.012m, 1.25)`
- `cap = min(400, 40+0.3t)`

Sabit noktalar (5/10/15/20. dk): hp 1,6 / 2,4 / 3,4 / 4,6; dmg 1,2 / 1,4 / 1,6 / 1,8; cap(300 s, 600 s, 900 s, 1200 s) = 130 / 220 / 310 / 400.
`alive_cap` 300'ü aşar t ≥ 867 sn (≈14,5 dk). "300+ düşman" testleri bu yüzden `start_time ≥ 900` ile yapılır.

#### Hasar kuralları
- **Zırh:** `hasar = max(hasar − zırh, hasar × 0,2)` mermi hasarı için. **Alan/patlama/parçacık hasarı zırhı yok sayar.**
- **Temas:** oyuncu hasarı 0,6 sn'de bir tick. Temasta ilk tick **hemen**, sonra her 0,6 sn. Temas yoksa zamanlayıcı hazır (0) bekler. Tick başına en çok 4 temas sayılır. Tick toplamı = Σ(`temas_hasarı × enemy_dmg_mult(t)`).
- **Ad ayrımı:** düşman tarafı `enemy_*_mult` ve `contact_mult`. Oyuncu tarafı `StatBlock.bullet_dmg_mult`. `dmg_mult` adı hiçbir yerde kullanılmaz.

#### Seviye atlama seçimi (`Loadout.roll_choices`)
1. Aday: maks. olmayan sahip olunan beceriler "upgrade", boş yuva varsa sahip olunmayan beceriler "new", evrim hazırsa "evolution".
2. Evrim hazırsa kartlardan biri evrimdir ve **en alta** konur. İki evrim hazırsa yalnız biri gösterilir (öbürü sonraki seviyede). Kalan kartlar upgrade+new havuzundan `rng_choice` ile ağırlık 1/1, tekrarsız.
3. Toplam aday <3 ise o kadar kart. Hiç aday yoksa tek `heal` ("Şifa", +%25 maks. can).
4. Aynı seçimde aynı beceri iki kart olmaz.
5. `debug_force_choices` verildiyse bunlar döner.

**Evrim koşulu:** aktif `max_level` (5) **ve** eşleşen pasif sahip (seviye ≥1). Evrim aktifi yuvada değiştirir (`max_level:1`), pasif kalır.

#### `Settings`, `Sfx`, `AudioDirector`, `MusicPlan`
```gdscript
# Settings (autoload)
var sound_on := true; var vibration_on := true
func load_settings(path: String = "user://settings.cfg") -> void; func save_settings(path: String = "user://settings.cfg") -> void
func vibrate(ms: int) -> void           # vibration_on ve Android ise Input.vibrate_handheld(ms)
# Sfx (scripts/audio/sfx.gd, sözleşmede NO-OP iskelet; C2)
static func play(id: StringName, opts: Dictionary = {}) -> void   # dosya/oyuncu yoksa sessizce çıkar
# MusicPlan (saf)
static func track_for(time: float, flags: Dictionary) -> StringName
  # flags: in_menu, boss_alive, lord_alive, won, lost, paused → "menu"|"savas-1"|"savas-2"|"kale-lordu"|"kazandin"|"kaybettin"|""
```
`Sfx.play` U1'den itibaren çağrılabilir (no-op), derleme kırılmaz.

#### Veri şemaları (`GameData.validate() -> PackedStringArray`, boş = geçerli)
Veri **dosya başına kayıt** biçimindedir (birleşme çakışması yok): `data/skills/<id>.json`, `data/enemies/<id>.json`, `data/characters/<id>.json`, `data/waves.json`.

- `characters/gunslinger.json` (taslaktaki biçim aynen; `shoulders/arm_pivot/muzzle` normalize tahmin, ekranda ayarlanır):
```json
{"id":"gunslinger","name":"Gunslinger","max_hp":100,"move_speed":300,"mag_cap":6,"reload_time":1.0,
 "pickup_radius":110,"collision_radius":22,"starting_skill":"cift_tabanca","range":700,
 "rig":{"body":"gfx/char/gunslinger_body","arm":"gfx/char/gunslinger_arm","display_height":112,
  "native_facing":"right","shoulders":[[0.38,0.195],[0.62,0.20]],"arm_pivot":[0.11,0.47],
  "muzzle":[0.98,0.37],"arm_scale":0.62,
  "sway":{"hem_from_y":0.60,"scarf_rect":[0.10,0.25,0.45,0.70],"amp":6,"lag":0.12}}}
```
- `skills/<id>.json`: `{"id","kind":"active|passive|evolution","name","icon","max_level","tags":[],"behavior","levels":[{…}],"desc":[…],"requires":{"active","active_level","passive","passive_min_level"} (yalnız evrim)}`.
  - **Pasif `levels[i]` o seviyedeki TOPLAM değerdir** (seviye 3 = 3 seviyenin toplamı).
  - Pasif anahtarları **sabit küme**: `bullet_dmg_mult, fire_rate_mult, reload_time_mult, mag_add, area_mult, explosion_dmg_mult, move_speed_mult, max_hp_add, regen, pickup_mult, range_mult`. Bilinmeyen anahtar `validate()` hatasıdır.
  - Çarpan türü pasif değerler `1 + x` ile uygulanır, farklı pasifler toplanır.
- `enemies/<id>.json`: `{"id","name","hp","speed","dmg","radius","armor","xp","ai":"ground|air|ghost|elite|lord","scales_with_time":bool,"sprite","display_height","tint","charge":{…}?,"summon":{…}?}`.
- `waves.json`: `{"rows":[{"kind":"rate","type","from","to","rate":[a,b]} | {"kind":"group","type","from","to","group":[a,b],"every":[a,b]} | {"kind":"burst","type","at":s,"count":n,"ring":bool} | {"kind":"boss","type","at":s,"warn":5}], "after_lord":{"piyade_rate_mult":0.5,"karga_stop":true}}`.
- `ruins.json` (U2): `[{"id","sprite","display_scale","foot":[x,y],"footprint":{"w","h"},"weight"}]`.

**`validate()` kapsamı** (hepsi sözleşmede, sahte veri fixture'larına karşı test edilir, `test/fixtures/data_valid/` ve `data_bad_*/`):
- Benzersiz id.
- `levels` uzunluğu = `max_level`.
- Seviyeler monoton (pasif toplam değerler azalmaz, aktif soğuma azalmaz, hasar azalmaz).
- Sayısal alt/üst sınırlar.
- `requires.passive` gerçekten `kind:"passive"`, `requires.active` gerçekten `kind:"active"`.
- `behavior` `SkillRegistry`'de var ve `SkillBehavior`'dan türer.
- `ai` bilinen küme.
- `icon`/`sprite` yolları var ya da `placeholder:` önekli.
- `waves`: `from<to`, `rate` aralığı sıralı, boss `at` değerleri `end_time` ile uyumlu, `kind` bilinen.
- Evrim `requires` çiftleri var olan beceriler.
- "Ritim" etiketli aktif sayısı ≥2 (içerik tamamlandığında; sözleşme fixture'ında test edilir).
- Beklenen **kayıt sayıları (8 aktif + 8 pasif + 4 evrim, 7 düşman) sözleşmede değil**, kabul testindedir (veri sahibi dilimlerdedir).

#### Denge tabloları (ilk sürüm)
**Oyuncu (Gunslinger):** can 100, hız 300 px/s, şarjör 6 (ortak), doldurma 1,0 sn (min 0,35), mermi hızı 900 px/s, ömrü 1,2 sn, toplama yarıçapı 110 px (mıknatıs 700 px/s), temel menzil 700 px.

**Aktif beceriler** (seviye 1→5):

| id (ad) | Kural | Sv1 | Sv2 | Sv3 | Sv4 | Sv5 |
|---|---|---|---|---|---|---|
| `cift_tabanca` *başlangıç, şarjörden; aralık tabanca başına* | hasar / aralık sn | 15 / 0,30 | 18 / 0,28 | 21 / 0,26 | 24 / 0,24 | 28 / 0,22 |
| `seken_mermi` **[şarjör ritmi]** | her N. şarjör kurşunu: N / sekme / hasar× | 3 / 2 / 1,0 | 3 / 3 / 1,1 | 3 / 3 / 1,2 | 2 / 4 / 1,3 | 2 / 5 / 1,4 |
| `yelpaze_atis` *şarjörsüz, 50° yelpaze, menzil 380* | soğuma / saçma / hasar | 4,0 / 5 / 9 | 3,6 / 6 / 10 | 3,2 / 7 / 11 | 2,8 / 8 / 12 | 2,4 / 9 / 14 |
| `dinamit` *şarjörsüz, 0,8 sn fitil, yay* | soğuma / adet / hasar / yarıçap | 3,5 / 1 / 60 / 130 | 3,2 / 1 / 75 / 140 | 2,9 / 2 / 90 / 150 | 2,6 / 2 / 110 / 165 | 2,2 / 3 / 135 / 180 |
| `son_mermi_patlar` **[şarjör ritmi]** | son kurşun patlar: hasar / yarıçap | 50 / 100 | 70 / 115 | 90 / 130 | 115 / 150 | 150 / 170 |
| `doldurma_sacilmasi` **[şarjör ritmi]** | doldurma başında radyal salvo: adet / hasar | 8 / 10 | 10 / 12 | 12 / 14 | 14 / 16 | 16 / 18 |
| `sarapnel` *öldürmede, menzil 260* | şans / parça / hasar | %25 / 3 / 18 | %30 / 4 / 22 | %35 / 4 / 26 | %40 / 5 / 30 | %50 / 6 / 36 |
| `keskin_nisan` *şarjörsüz, hitscan, en yüksek canlı hedef, menzil 900, hepsini deler* | soğuma / hasar | 3,0 / 90 | 2,8 / 120 | 2,6 / 150 | 2,4 / 190 | 2,0 / 240 |

**Pasifler** (seviye N toplam, 5 seviye):

| id (ad) | Etki |
|---|---|
| `barut_kesesi` | alan +%12·N, patlama hasarı +%8·N |
| `hizli_doldurma` **[ritim]** | doldurma süresi −%10·N (sv5: 0,5 sn; min 0,35) |
| `fazladan_mermi` **[ritim]** | şarjör +N (sv5: 11) |
| `agir_kursun` | mermi hasarı +%10·N |
| `hizli_parmak` | atış hızı +%8·N (aralık = aralık/(1+x)) |
| `cevik_cizme` | hareket hızı +%6·N |
| `saglam_yelek` | maks. can +15·N, yenilenme +0,25·N can/sn |
| `miknatis` | toplama yarıçapı +%25·N |

Menzil pasifi bilinçli yok (`range_mult` alanı vardır ama v1'de hiçbir pasif kullanmaz).

**Evrimler:**

| id | Koşul | Etki |
|---|---|---|
| `zincirleme_patlama` | `seken_mermi` 5 + `barut_kesesi` | her 2. kurşun seker, 8 sekme, her sekmede patlama (hasar 40, yarıçap 90, alan çarpanı uygulanır) |
| `kiyamet_mermisi` **[ritim]** | `son_mermi_patlar` 5 + `hizli_doldurma` | son kurşun devasa patlar (hasar 400, yarıçap 260) **ve** 2 mermi geri yazılır; **doldurma döngüsü başına bir kez** (`refund_used`, `reload_finished`'te sıfırlanır) |
| `mermi_firtinasi` **[ritim]** | `doldurma_sacilmasi` 5 + `fazladan_mermi` | doldurma başında 2×cap salvo (hasar 20); doldurma boyunca 0,15 sn'de bir 6'lı halka |
| `gurleyen_yelpaze` | `yelpaze_atis` 5 + `agir_kursun` | 13 saçma, 2 delme, hasar 20, soğuma 2,0 sn, 160 px geri itme |

**Şarjör ritmiyle etkileşen (kabul ≥2):** `seken_mermi`, `son_mermi_patlar`, `doldurma_sacilmasi`, `hizli_doldurma`, `fazladan_mermi`, `kiyamet_mermisi`, `mermi_firtinasi` (`tags:["rhythm"]`).

**Düşmanlar** (`scales_with_time:false` olanlar çarpandan etkilenmez):

| id | Görsel | Can | Hız | Temas | Yarıçap | Zırh | XP | Davranış |
|---|---|---|---|---|---|---|---|---|
| `curumus_piyade` | `curumus-piyade.png` | 30 | 95 | 6 | 26 | 0 | 1 | kovalar, engelden kayar |
| `les_kargasi` | `les-kargalari.png` (3 poz atlas) | 12 | 210 | 4 | 18 | 0 | 1 | uçar (engel yok sayar), 6–14'lü sürü |
| `sovalye_hayaleti` | `sovalye-hayaleti.png` | 220 | 70 | 18 | 36 | 3 | 5 | engel yok sayar |
| `elit_piyade` (5. dk) | piyade ×2,2 bordo tint | 1800 | 110 | 14 | 60 | 2 | 80 | elit; sabit |
| `elit_sovalye` (10. dk) | şövalye ×1,8 amber tint | 6500 | 85 | 28 | 66 | 5 | 160 | elit; sabit |
| `elit_karga` (15. dk) | karga ×4 kırmızı tint | 9000 | 170 | 30 | 52 | 3 | 260 | elit; her 4 sn 0,8 sn şarj (hız 380) |
| `kale_lordu` (20. dk) | `kale-lordu.png` | 45000 | 80 | 40 | 72 | 6 | 500 | her 8 sn 12 piyade çağırır; %50 canda hız ×1,4 ve çağırma 5 sn; ölümü WON |

**Doğurma çizelgesi** (`waves.json` v1):

| Satır | Kind | Tür | Aralık (sn) | Oran |
|---|---|---|---|---|
| 1 | rate | piyade | 0–1200 | 0,8 → 3,5 /sn doğrusal |
| 2 | group | karga sürüsü | 90–1200 | grup 6 → 14, aralık 26 → 12 sn |
| 3 | rate | şövalye hayaleti | 240–1200 | 0,05 → 0,5 /sn |
| 4 | burst | piyade halka 50 adet | at 480, 720, 960 | tek seferlik (U2) |
| 5 | boss | `elit_piyade` 300, `elit_sovalye` 600, `elit_karga` 900, `kale_lordu` 1200 | warn 5 sn | – |
| 6 | after_lord | ≥1200 | piyade ×0,5, karga durur | – |

Doğma konumu: kamera yarı-köşegeni + 80 px halkası (≈1400 px), düzgün açı (`rng_spawn`). Oyuncudan >1900 px uzaklaşan düşman, hareket yönündeki halkaya taşınır. Eşzamanlı sınır `alive_cap(t)` (boss'lar hariç).

#### Parçalı karakter rig'i (`PlayerView`)
- **Düğüm ağacı:** `Player (Node2D, y_sort_enabled)` → `FarArm (Sprite2D, z_index −1, relative)`, `Body (MeshInstance2D, z_index 0)`, `NearArm (Sprite2D, z_index +1)`, `ReloadRing`, `Shadow`.
- **Kol:** kol görseli sağa bakar. Pivot `arm_pivot`. `rotation = (hedef − omuz).angle()`. `cos(rotation)<0` ise `scale.y=−1`. İki kol aynı doku. `FarArm` %80 koyu tint.
- **Namlu:** mermi **`PlayerRig.muzzle_world(gun, player_pos, aim_angle, facing_left)`** (saf, sim'de) ile çıkar. View çizimde aynı fonksiyonu kullanır (tek kaynak). Sayısal test karakter verisiyle yapılır.
- **Gövde yönü:** sola gidişte `Body.scale.x=−1`. Bob ±4 px, squash %4. Geri tepme: kol 60 ms −0,12 rad ve 6 px.
- **İkincil hareket:** gövde `QuadMesh(8×12)` + canvas_item `vertex()` shader'ı (etek/atkı yatay kayması). Parametreler karakter verisinde.
- **Doğrulama sınırı:** pivot/omuz/namlu **headless'ta görsel doğrulanamaz**, "kullanıcıda doğrulanır (ekran görüntüsü döngüsü)".

#### Sanat işleme aracı (`tools/art/process_art.py`)
`python tools/art/process_art.py [--only <id>] [--preview] [--verify]` ile `art/ref/**` + `tools/art/art_manifest.json` → `assets/gfx/**` (+ `manifest.json`). Algoritma taslaktaki gibi:
1. Küresel anahtar `d = G − max(R,B)`, `alpha = 1 − clamp((d − d_lo)/(d_hi − d_lo), 0, 1)`, `d_lo=30`, `d_hi=110`. Arka plan `d≈145–170`, zeytin bitki `d≤≈20`.
2. Kenar yeşil temizleme (`despill`).
3. Şeffaf piksellerde komşu renk doldurma, premultiplied LANCZOS küçültme.
4. Duman: `smoke_cleanup`, oyunda `GPUParticles2D`.
5. `split:"components"` harabe sayfası (20–30 bileşen, `ruins_manifest.json`).
6. `split:"three_poses"` kargalar → 3 kareli atlas (`INSTANCE_CUSTOM` ya da yedek ayrı MultiMesh).
7. Zemin 1254² → wrap-aware küçültme 768². Dikiş testi: kenar sütunları ortalama farkı <6/255 **ve** tek kenar sütunu başına maks fark ≤40/255.
8. Hedef boyutlar: gövde 320 px boy, kol 240 px en, piyade 192, şövalye 224, lord 384, karga kare 192 en, harabe scale 0,45.

**Test ayrımı:** birimler **sentetik fixture'larla** (pytest, gate'te): zeytin piksel (95,105,35) korunur, saf yeşil (3,157,8) şeffaf, boyut/manifest uyumu. **Gerçek görsele bağlı eşikler** (bitki-ton ≥%95 korunur, kalan opak pikselde `G−max(R,B)>40` yok, bileşen sayısı 20–30, kargalar 3 kare) **"veri sağlık" testi** olarak `tools/art/tests/health/` altındadır; gate'te koşar ama eşik ihlali uyarı değil hata. Her iki grup gate'te çalışır (görseller repoda olduğundan).

#### Ses hattı (`tools/audio/`)
**Müzik (kullanıcıdan, Suno; `audio/muzik/*.wav` kaynak):** `menu`, `savas-1`, `savas-2`, `boss-uyari`, `kale-lordu`, `kazandin`, `kaybettin`. Şu an repoda yalnızca `menu.wav` var (22 kHz, −10,4 LUFS, döngü noktasında genlik sıçraması).
```
python tools/audio/process_audio.py [--only <id>] [--verify]   # audio_manifest.json'a göre
```
- Girdi: WAV (`audio/muzik/`). Çıktı: `assets/audio/music/<id>.ogg` (commit'lenir).
- Adımlar:
  1. 44,1 kHz'e yeniden örnekle (`scipy.signal.resample_poly`).
  2. Integrated loudness **−18 LUFS ±0,5**'e normalize et (`pyloudnorm`).
  3. Tepe > −1 dBFS ise kazancı düşür (limiter yok; hedefin altında kalırsa raporla).
  4. `loop:true` parçalarda (`menu`, `savas-1`, `savas-2`, `kale-lordu`): sondaki 1,5 sn eşit-güç crossfade ile başa bindirilir ve kırpılır. Dikişte genlik sıçraması giderilir.
  5. `boss-uyari`, `kazandin`, `kaybettin` tek seferlik (döngü yok; 150 ms fade-out).
  6. OGG Vorbis yaz (`soundfile`; kodlayıcı yoksa `ffmpeg`).
- **Dikiş testi:** dikişte son/ilk 20 ms RMS farkı ≤1,5 dB ve |ilk örnek − son örnek| ≤0,02. Döngü bayrağı kodda `AudioStreamOggVorbis.loop=true` ile verilir (`.import` elle düzenlenmez).
- **Eksik dosya:** `audio_manifest.json`'daki WAV yoksa araç "bekleyen" listeler (gate'te hata değil), `check_music.py --require` doğrulama fazında 7 dosyanın tamamını şart koşar.

**Ses efektleri:** yalnızca **CC0** kaynaklar (Kenney.nl, Freesound CC0 filtresi). Repo public olduğu için "royalty-free ama yeniden dağıtılamaz" paketler yasak. `LICENSES-audio.md`: dosya, kaynak URL, yazar, lisans (CC0 1.0), tarih. Gate testi (`test_audio_licenses`/pytest): `assets/audio/sfx/` altındaki her dosya tabloda ve lisans `CC0`. Tabloda olmayan ya da CC0 olmayan dosya hata.
- **Yedek:** Kenney/Freesound bulutta indirilemezse (Freesound oturum ister) SFX `tools/audio/synth_sfx.py` ile sentezlenir (numpy; yazarı biziz, CC0 beyanı). Bu bir geçici yedektir, kullanıcı kaynak paketlerle değiştirebilir.
- **Gunslinger imza sesleri:**
  - `shot_right` / `shot_left`: farklı tını ve perde.
  - `reload_spin`: tambur dönüşü.
  - `reload_click`: doldurma bitişinde klik.
  - `dry_fire`: kuru tetik (bkz. aşağıdaki not).
  - `xp_pickup`: yükselen çınlama. Ardışık toplamada `pitch_scale = 1 + 0,06 × min(combo, 12)`, combo 0,6 sn toplama olmazsa sıfırlanır (view tarafı; sim'e girmez).
- **Diğer SFX:** `hit`, `enemy_die`, `explosion`, `dynamite_fuse`, `fan_blast`, `sniper`, `player_hurt`, `level_up`, `ui_click`, `evolution`.

**Bus'lar:** `default_bus_layout.tres`: `Master → Music, SFX, UI`. `Settings.sound_on=false` Master'ı susturur.
**Eşzamanlı ses sınırı:** `Sfx` havuzu 16 oyuncu. Kimlik başına üst sınır: `shot_*` 4, `hit` 3, `explosion` 3, `enemy_die` 3, `xp_pickup` 2. Sınırda en eski çalan kesilir.
**Müzik geçişleri (`AudioDirector`, `MusicPlan` kararı):**
- Menü → `menu`.
- Oyun başı → `savas-1` (1,5 sn crossfade).
- 600. sn → `savas-2` (4 sn crossfade).
- `boss_warning`'de `boss-uyari` tek seferlik üstüne biner (müzik −6 dB duck).
- Lord doğunca `kale-lordu` (2 sn crossfade).
- WON → `kazandin`, LOST → `kaybettin` (döngü yok).
- Duraklatmada Music bus −8 dB.
- `MusicPlan.track_for` birim testlidir. Crossfade'in kulakla duyulan kalitesi "kullanıcıda doğrulanır".
- Dry-fire yorumu: "son mermide kuru tetik" = şarjör boşalıp doldurma sürerken hedef varken tetik çekilirse klik (sim `dry_fire` olayı). Kullanıcı farklı kastettiyse açık nokta.

#### CI, gate ve Godot kurulumu
**Sabit sürümler (varsayım; C0 doğrular, sürüm ve SHA512 `tools/ci/checksums.txt`'e yazılır):**
- Godot `4.7.2-stable` (tek kaynak `.godot-version`; yedek `4.6.3-stable`). Kaynak: https://godotengine.org/download/archive/4.7.2-stable/
- GUT `9.7.1` (Godot 4.7 için uyumlu dal), `addons/gut/` vendor, `addons/gut/VERSION.txt`. Kaynak: https://github.com/bitwes/Gut/releases
- Android (yalnız export): JDK 17, `platform-tools`, `build-tools;35.0.1`, `platforms;android-35`, `cmdline-tools;latest`. Gradle yok, NDK/CMake kurulmaz. Kaynak: https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html
- Python 3.11+: `Pillow`, `numpy`, `scipy`, `soundfile`, `pyloudnorm`, `pytest`, `gdtoolkit==4.*`.
- Godot ≥4.5'e özgü yeni sözdizimi (abstract, variadic argümanlar) **kullanılmaz** (gdtoolkit uyumu). C0 `gdformat/gdlint`'in iskelette ayrıştırdığını doğrular, ayrıştıramazsa lint adımının kapsamı daraltılır ve Açık noktalara yazılır.

**İndirme:**
```
GODOT_BASE=https://github.com/godotengine/godot-builds/releases/download/${V}
${GODOT_BASE}/Godot_v${V}_linux.x86_64.zip
${GODOT_BASE}/Godot_v${V}_export_templates.tpz
https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
```
`godot-builds` yolu varsayım. İndirme `curl -fL --retry 3`, ardından `sha512sum -c tools/ci/checksums.txt`.

**Kurulum betikleri (idempotent, önbellek `~/.cache/ashen-bastion/<V>/`):**
- `tools/ci/ensure_godot.sh`:
  - PATH'teki ya da `GODOT_BIN` sürümü eşleşiyorsa dokunmaz.
  - Dinamik kitaplıklar: root + apt varsa kurar (`libasound2t64` yoksa `libasound2` dener, dağıtıma göre paket adı seçer). Root/apt yoksa gerekli paketleri listeler, `godot --version` çalışıyorsa devam eder.
  - Export şablonlarını yalnız `GATE_EXPORT=1`/CI export'ta `~/.local/share/godot/export_templates/${V/-/.}/` altına açar.
- `tools/ci/ensure_android_sdk.sh` (yalnız export): SDK + `write_editor_settings.sh`. Debug keystore olarak repodaki `tools/ci/debug.keystore` kullanılır.
- **Ağ yoksa:** gate `GATE_NET: <host> erişilemiyor — Godot indirilemedi` yazıp **çıkış kodu 3** ile biter. **Çalışan bu durumda `vlad task ask` ile (ASK) durur, kullanıcıdan ağ iznini ister. Gate'siz ilerlenmez, sahte yeşil yok.**
- **Bulut ağ ihtiyacı** (ortam "Allowed domains"): `github.com`, `objects.githubusercontent.com`, `release-assets.githubusercontent.com`; export için `dl.google.com`, `maven.google.com`; SFX kaynağı için `kenney.nl`. Önerilen: ortamın Setup script'ine `bash tools/ci/ensure_godot.sh`.

**Kart `gate` komutu:** `bash tools/gate.sh`

Adımlar (sırayla, ilk hata çıkış 1; `rm -rf .gate` ile başlar):
1. `bash tools/ci/ensure_godot.sh`
2. `godot --headless --import` (CI'da temiz `.godot`)
3. Lint: `gdformat --check scripts tools test` + `gdlint scripts tools test` (`.gdlintrc`; test dosyaları için gürültülü kurallar kapalı). Türkçe tuzağı: `grep -rnE "to_upper|to_lower" scripts` **boş olmalı**.
4. Veri: `godot --headless -s res://tools/validate_data.gd` (hata = sıfırdan farklı çıkış).
5. Python: `pytest -q tools/art/tests tools/audio/tests`.
6. Birim + kabul: `godot --headless -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json` (`dirs:["res://test/unit","res://test/acceptance"]`, `prefix:"test_"`, `should_exit:true`, JUnit çıktısı).
7. **Sahte yeşil korumaları:**
   - **Günlük taraması:** `^(SCRIPT ERROR|Parse Error|ERROR:)` regex'i. **İzin listesi yok.** Beklenen-hata testi yazılmaz. Üretim kodu hata durumunda `push_error` değil dönüş değeri (`bool`/`PackedStringArray`) kullanır. İskelet gövdeleri `push_error` yerine `Stub.todo(&"Sınıf.yöntem")` çağırır (statik listeye yazar, varsayılan değer döner). Böylece "uygulanmadı" test başarısızlığı olarak görünür, günlük temiz kalır ve ayrıştırma hatasıyla karışmaz.
   - **Asgari test sayısı:** `tools/gate_min_tests.json` dosya başına minimum. Tek yönlü: sayı düşerse hata; otomatik güncellenmez, yalnız `tools/update_min_tests.sh` ile bilinçli güncellenir. JUnit'te `tests` toplamı sıfırsa hata. Çıkış kodu doğrulaması: GUT'ın başarısız testte sıfırdan farklı çıkış verdiği C0'da ölçülür.
   - **Slice işareti:** `tools/slice.txt` (`1` ya da `2`). Uygulama-2 içeriğine ait kabul testleri `Slice.current()<2` iken `pending` döner (başarısızlık değil). Uygulama-2'nin ilk görevi dosyayı `2` yapar.
8. **Deterministik iş sayacı kontrolü:** `test/acceptance/test_acc_perf_counters.gd`: stres senaryosunda (400 düşman + 500 mermi, sabit tohum, 600 adım) `work` sayaçlarının adım başına ortalaması `tools/perf_budget.json` tavanlarının altında. Tavanlar U1-1 ölçümünden +%25 marjla yazılır. Zaman (ms) yalnız bilgi olarak yazdırılır, eşik değil.
9. `GATE_EXPORT=1` ise: şablon + SDK, `godot --headless --export-debug "Android" build/ab-debug.apk`, `apksigner verify`. Bulutta varsayılan kapalı, rapor "APK derlenmedi" der. Kabul kriteri bunu "CI/kullanıcıda doğrulanır" sayar.
10. `GATE_RENDER=1` ise (varsa `xvfb-run`): `godot --rendering-driver opengl3 --quit-after` ile shader/sahne smoke. Yoksa "shader derlemesi doğrulanmadı" raporlanır.
11. `GATE_NIGHTLY=1` ise (gate dışı): 20 dk koşu (3 politika), sızıntı kontrolü (`OBJECT_COUNT`/`MEMORY_STATIC` 5. dk ile 20. dk arasında artış ≤%10), 100 seed × 3 politika denge dağılımı (medyan/p10/p90) → JSON rapor.

**Gate öz-testi:** `tools/ci/selftest_gate.sh` otomatik sınar: (a) bozuk `.gd` eklenince gate 1 döner; (b) boş test dizisi gate'i 1 yapar; (c) asgari sayının altı 1 yapar; (d) `Stub.todo` test başarısızlığı olarak 1 yapar; (e) ağ yok simülasyonu 3 döner. Öz-test CI'da ayrı iş olarak koşar.

**GitHub Actions:**
- `ci.yml`: `on: push, pull_request`, `permissions: contents: read`. İşler: `test` (`bash tools/gate.sh`), `selftest` (`selftest_gate.sh`), `export-debug` (PR'da debug APK, secret yok).
- `nightly.yml`: cron + `workflow_dispatch`, `GATE_NIGHTLY=1`.
- `release.yml` (U2-9): `on: push: branches:[main], tags:["v*"]`, `workflow_dispatch`, `environment: release`, **`pull_request_target` yok**. Keystore'u `printf '%s' "$ANDROID_KEYSTORE_BASE64" | base64 -d > "$RUNNER_TEMP/release.keystore"` ile yazar. `GODOT_ANDROID_KEYSTORE_RELEASE_PATH/USER/PASSWORD` ortam değişkenleriyle `--export-release "Android"`. `apksigner verify --print-certs`. Sürüm: `version/code=github.run_number` (`set_version.sh`). `export_presets.cfg`'ye secret yazılmaz. Secret'lar: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_USER`, `ANDROID_KEYSTORE_PASSWORD`. YAML lint + `set_version.sh` birim testi bulutta yapılır; **imzalı APK üretimi ve kurulumu kullanıcıda doğrulanır**.
- Keystore üretimi kullanıcıda: `keytool -genkeypair -v -keystore ashen-bastion.keystore -alias ashenbastion -keyalg RSA -keysize 2048 -validity 10000`, çıktı `base64 -w0` ile secret'a, anahtar yedeklenir.

**Android export önayarı** (`export_presets.cfg`, Gradle kapalı): `use_gradle_build=false`, `package/unique_name="com.iamhankaya.ashenbastion"`, `package/name="Ashen Bastion"`, yalnız `arm64-v8a`, `min_sdk=24`, `target_sdk=35`, `screen/immersive_mode=true`, `permissions/vibrate=true`, `permissions/internet=false`, çıktı `.apk`. `project.godot`: dikey, `gl_compatibility`, 1080×2400, `canvas_items`/`expand`, `application/run/max_fps=60`, `display/window/vsync/vsync_mode=1`, `emulate_touch_from_mouse=true`, `emulate_mouse_from_touch=false`. Fontlar tek kaynak `assets/fonts/` (`docs/ui/fonts` kopyalanır, tema oradan yüklenir).

### Dosya yapısı

```
.godot-version  .gutconfig.json  .gdlintrc  .gitignore       # .godot/, build/, .gate/
project.godot  export_presets.cfg  icon.svg  default_bus_layout.tres
addons/gut/                                   # vendor + VERSION.txt
data/characters/gunslinger.json  data/waves.json  data/ruins.json (U2)
data/skills/<id>.json  data/enemies/<id>.json  # dosya başına bir kayıt
assets/fonts/  assets/ui/  assets/gfx/ (U2 çıktısı)  assets/shaders/
assets/audio/music/*.ogg  assets/audio/sfx/*.ogg
audio/muzik/*.wav                             # kullanıcının kaynak müziği (elle düzenlenmez)
LICENSES-audio.md
scripts/autoload/ events.gd settings.gd
scripts/sim/ game_sim.gd sim_bus.gd game_data.gd magazine.gd targeting.gd spatial_hash.gd damage_system.gd
             stat_block.gd loadout.gd choice.gd shot_context.gd xp_curve.gd difficulty.gd
             spawn_director.gd enemy_ai.gd map_sim.gd player_rig.gd stub.gd sim_events.gd
scripts/sim/pools/ enemy_pool.gd projectile_pool.gd gem_pool.gd zone_pool.gd
scripts/sim/skills/ skill_registry.gd skill_behavior.gd <12 davranış dosyası>
scripts/view/ enemy_renderer.gd projectile_renderer.gd gem_renderer.gd fx_renderer.gd
              player_view.gd ground_view.gd ruin_view.gd camera_rig.gd placeholder_art.gd
scripts/ctrl/ input_gate.gd pause_logic.gd game_controller.gd
scripts/ui/ virtual_joystick.gd hud.gd level_up_screen.gd pause_screen.gd result_screen.gd main_menu.gd
scripts/audio/ sfx.gd audio_director.gd music_plan.gd
scripts/debug/ stress_run.gd                  # yalnız OS.is_debug_build()
scenes/boot.tscn  scenes/menu/  scenes/game/  scenes/ui/
themes/ashen-bastion-theme.tres
tools/gate.sh  tools/gate_min_tests.json  tools/update_min_tests.sh  tools/slice.txt  tools/perf_budget.json  tools/validate_data.gd
tools/ci/ ensure_godot.sh ensure_android_sdk.sh write_editor_settings.sh set_version.sh selftest_gate.sh checksums.txt debug.keystore
tools/perf/ micro.gd
tools/art/ process_art.py chroma_key.py art_manifest.json tests/ tests/health/
tools/audio/ process_audio.py audio_manifest.json check_music.py synth_sfx.py tests/
tools/balance/ sim_run.gd
test/unit/ test_*.gd        test/acceptance/ test_acc_*.gd        test/fixtures/ data_valid/ data_bad_*/
test/helpers/ kit_dev.gd sim_kit.gd bots.gd expected_tables.gd slice.gd
.github/workflows/ ci.yml nightly.yml release.yml
docs/data-schema.md  docs/dev/ setup.md skill-hooks.md perf.md user-verify.md balance-notes.md
```
`art/ref/`, `audio/muzik/` ve `docs/ui/` kaynak olarak olduğu gibi kalır.

### Paylaşılan dosyalar ve ad alanları

| Dosya | Dokunan fazlar/görevler | Sahip | Kural |
|---|---|---|---|
| `project.godot` | C0, U1-9, U1-11, U2-8 | C0 | Autoload (yalnız `Events`, `Settings`), input ve görüntü ayarı C0'da. Sonrakiler yalnız kendi satırını ekler. Sahne yolu U1-9. |
| `scripts/sim/sim_events.gd`, `scripts/sim/sim_bus.gd`, `scripts/autoload/events.gd` | sözleşme, tüm sim/UI | sözleşme | Sinyal/olay türü **eklemek** serbest (sona). Mevcut imza ve ad değişmez. |
| `scripts/sim/game_sim.gd` | sözleşme (iskelet+kancalar), U1-6, U2-2/3/4/5 | U1-6 | Çekirdek adım sırası değişmez. Diğerleri yalnız kendi alt sistemini `_init` listesine ve `step` içindeki ilgili adım fonksiyonuna ekler. |
| `scripts/sim/skills/skill_registry.gd` | sözleşme (boş), U1-5, U2-2, U2-3 | sözleşme | Her beceri yalnız kendi `id → class` satırını ekler (alfabetik). |
| `data/skills/<id>.json`, `data/enemies/<id>.json`, `data/characters/*` | U1-2/U1-4/U1-5 (U1 alt kümesi), U2-2/3/4 (kalanlar) | **o kaydı uygulayan görev** | Tek veri sahibi: kaydı oluşturan görev yazar. Sayı ayarını yalnız U2-10 (denge) yapar. Başka görev başkasının kaydını değiştirmez. |
| `data/waves.json` | U1-4 (satır 1–3), U2-4 (satır 4–6), U2-10 (ayar) | U1-4 | Satır ekleme sırayla. Sayı ayarı yalnız U2-10. |
| `docs/data-schema.md`, `tools/validate_data.gd` | C1 | C1 | Şema değişirse aynı görevde validate ve fixture testi güncellenir. |
| `docs/dev/skill-hooks.md` | C2 | C2 | Kanca eklemek yalnız sona; mevcut imzaya dokunulmaz. |
| `tools/gate.sh`, `tools/ci/*`, `.gutconfig.json`, `.gdlintrc`, `tools/gate_min_tests.json` | C0 | C0 | Gate adımı eklemek yalnız C0 ya da açıkça gate'e ait görev (U1-10 perf kontrolü, U2-1 pytest yolu). Diğerleri yalnız `gate_min_tests.json`'u `update_min_tests.sh` ile günceller. |
| `tools/slice.txt` | U2 ilk görev | U2-1 | Başka görev dokunmaz. |
| `tools/perf_budget.json` | U1-1 (ilk), U1-10 (doğrulama) | U1-1 | Tavan değişimi gerekçeli ve ölçüm raporuyla. |
| `export_presets.cfg` | U1-10 (debug), U2-9 (release) | U1-10 | Secret asla dosyada yok. |
| `.github/workflows/ci.yml`, `nightly.yml` | C0, U1-10 | C0 | `release.yml` U2-9'a ait. |
| `themes/ashen-bastion-theme.tres`, `scripts/ui/*`, `scenes/ui/*` | U1-8, U2-6 | U1-8 | Token değişirse önce `docs/ui/tokens.json`. U2 yalnız görsel/sonuç ekranı verisi. |
| `default_bus_layout.tres` | U1-11, U2-8 | U1-11 | U2-8 yalnız bus efekti/ses seviyesi ekler. |
| `assets/gfx/manifest.json`, `assets/audio/music/*.ogg` | U2-1, U2-8a | araç | Yalnız araç üretir, elle düzenlenmez. |
| `LICENSES-audio.md` | U2-8b | U2-8b | Her SFX dosyası satırla birlikte eklenir. |
| `test/helpers/kit_dev.gd` | developer | developer | Developer yardımcıları (`kit_` öneki). |
| `test/helpers/sim_kit.gd`, `bots.gd`, `expected_tables.gd` | tester | tester | Developer dokunmaz. `expected_tables.gd` plan tablolarını sabit tutar. |
| **Test ad alanı** | tümü | – | Developer birim: `test/unit/test_<modül>.gd` (`extends GutTest`, dosya başına tek modül, öneksiz). Sözleşme testleri `test_contract_*.gd`. Tester kabul: `test/acceptance/test_acc_<özellik>.gd`. Tester yardımcıları `test/helpers/`. Sahne açma yalnız `test_ui_smoke.gd` (instantiate+`_ready`, shader derlemesi sınanmaz). |

### Görev listesi

Faz yapısı (sabit): **sözleşme → kabul ∥ uygulama-1 → (prova U1-11) → ara denetim → uygulama-2 → doğrulama → denetim.** "Prova" uygulama-1'in son görevi olan kullanıcı provasıdır (yeni faz değildir).

#### Sözleşme fazı (developer)
Bitiş kriterleri (bu fazın kabulü): C0 öz-testleri yeşil; tüm iskelet `--import` ve boş GUT koşusunda ayrıştırma hatasız; sözleşme testleri yeşil; iskelet çağrıları `Stub.todo` ile başarısızlık üretir.

- **C0 Araç zinciri doğrulaması (İLK görev, sıralı).**
  - Dosyalar: `.godot-version`, `tools/ci/{ensure_godot.sh,checksums.txt,selftest_gate.sh,debug.keystore}`, `tools/gate.sh`, `.gutconfig.json`, `.gdlintrc`, `tools/gate_min_tests.json`, `addons/gut/`, `project.godot`, `.github/workflows/ci.yml`, `docs/dev/setup.md`.
  - Adımlar:
    1. Godot ve GUT'ı indir; sürüm ve SHA512'yi doğrulayıp `checksums.txt`'e sabitle (varsayım yanlışsa yedek sürüme düş ve nedenini `docs/dev/setup.md`'ye yaz).
    2. `--import` çalıştır.
    3. Boş bir GUT testi yeşil olsun.
    4. Gate'e günlük taraması, asgari sayı, slice mekanizması ve `to_upper` grep'ini ekle.
    5. `selftest_gate.sh`'yi yaz.
  - Kabul: bozuk `.gd` ve boş test dizisinde gate kırmızı (öz-test otomatik); ağ yoksa çıkış 3 ve **çalışan `vlad task ask` ile durur**; GUT'ın başarısız testte sıfırdan farklı çıkışı ölçülmüş ve `docs/dev/setup.md`'de yazılı.
  - Bu görev geçmeden C1/C2 başlamaz.
- **C1 Veri sözleşmesi (C0 sonrası).** `docs/data-schema.md`, `scripts/sim/game_data.gd` (yükleme + `validate()`), `tools/validate_data.gd`, `test/fixtures/data_valid/`, `data_bad_*/`, `test/unit/test_game_data.gd`. **Yalnız şema + doğrulama + fixture**: gerçek içerik/denge kayıtları yok. Kabul: `validate()` kapsam listesindeki her kural için bozuk fixture hata verir, geçerli fixture boş döner.
- **C2 İskelet + gözlem kancaları (C1 sonrası).**
  - Dosyalar: `scripts/sim/*` (Arayüzler'deki tüm sınıflar; `stub.gd`), `sim_bus.gd`, `sim_events.gd`, `scripts/autoload/{events,settings}.gd`, `scripts/audio/{sfx,audio_director,music_plan}.gd` (no-op iskelet), `docs/dev/skill-hooks.md`, `test/unit/test_contract_*.gd`.
  - Adımlar:
    1. İmzaları tipli yaz.
    2. Gövdeleri `Stub.todo` + varsayılan değerle doldur.
    3. `state_hash`, `event_log`, `check_invariants`, `alive_ids`, `debug_force_choices`, `work`, ayrı RNG akışları, `step(move)`, sıralı `query_circle` gibi gözlem kancalarını **gerçek** (çalışan) yaz.
    4. 12 beceriyi kancalara eşle (doküman + test).
  - Kabul: kanca sözleşme testleri yeşil (imzalar `get_method_list` ile doğrulanır); aynı tohumla iki boş `GameSim` aynı `state_hash` verir; döngüsel `class_name` bağımlılığı yok.

#### Kabul fazı (tester, C2 sonrası, uygulama-1 ile paralel)
Plan tablolarını `test/helpers/expected_tables.gd`'ye **sabit** yazar (veri JSON'u okumadan). `test_acc_tables.gd` tabloları JSON ile karşılaştırır (U1 kayıtları şimdi, U2 kayıtları slice 2'de). Kapsam `### Test stratejisi`'nde.

#### Uygulama-1: ilk oynanabilir dilim (geçici görsellerle)
Kapsam: dikey ekran + joystick, otomatik ateş, 6'lık şarjör/doldurma, 3 düşman, XP taşları, seviye atlama (3 kart, evrim kartı mantığı dahil), 3 aktif (`cift_tabanca`, `seken_mermi`, `son_mermi_patlar`) + 8 pasif, HUD, duraklatma, sonuç, ana menü, `end_mode:"timer"` ile 8 dk demo, debug APK. Boss/lord ve harita yok.
**Bitiş:** gate yeşil; 8 dk oynanabilir; CI debug APK'sı kullanıcıda kurulur ve stres ölçümü alınır.

- **U1-1 Perf mikro-ölçüm (ilk, sıralı).**
  - Dosyalar: `scripts/sim/spatial_hash.gd`, `scripts/sim/pools/*`, `tools/perf/micro.gd`, `tools/perf_budget.json`, `docs/dev/perf.md`, `test/unit/test_spatial_hash.gd`, `test_pools.gd`.
  - Adımlar:
    1. Hash ve havuzları gerçekle.
    2. 400 düşman + 600 mermi için hash kur + çarpışma mikro-ölçümü yaz; deterministik sayaçlar ve (bilgi için) ms yazdır.
    3. Sayaç tavanlarını `perf_budget.json`'a +%25 marjla yaz.
    4. Yedek merdivenini `perf.md`'ye yaz.
  - Unit: nesil kimliği ve sarma, CAP davranışı, `query_circle` sıralı, taş birleşiminde XP korunumu.
- **U1-2 Veri yükleme + U1 içeriği (∥).** `game_data.gd` gövdesi tamamlama; `data/characters/gunslinger.json`; `data/skills/` U1 alt kümesi (3 aktif + 8 pasif); `data/enemies/` (3 düşman). Tüketir: C1 şeması.
- **U1-3 Şarjör, hedefleme, hasar (∥ U1-4/5).** `magazine.gd`, `stat_block.gd`, `targeting.gd`, `damage_system.gd`. Unit: şarjör kuralları (cap değişimi, `refund_used`, `consume` indeksleri), hedef kuralı ve eşitlik, zırh/alan/temas.
- **U1-4 Zorluk, doğurma, AI (∥).** `xp_curve.gd`, `difficulty.gd`, `spawn_director.gd` (satır 1–3), `enemy_ai.gd`, `data/waves.json` (satır 1–3), taş mıknatısı. Unit: `need(n)` tablosu, çarpanlar, `alive_cap`, halka, geri taşıma, spawn kaybı.
- **U1-5 Loadout + U1 becerileri (∥).** `loadout.gd`, `choice.gd`, `skill_registry.gd` satırları, `cift_tabanca.gd`, `seken_mermi.gd`, `son_mermi_patlar.gd`, pasiflerin `StatBlock` etkisi. Unit: `roll_choices` kuralları (evrim en altta, Şifa, tekrarsız), evrim hazırlığı.
- **U1-6 `GameSim` bütünleştirme (sıralı, 3/4/5 sonrası).** Adım sırası ve oyun sonu öncelikleri Arayüzler'deki gibi; `player_rig.gd`. Unit: durum geçişleri, çoklu seviye kuyruğu, WON/LOST öncelikleri, `start_time` semantiği.
- **U1-7 Görünüm (∥ U1-6).**
  - Dosyalar: `enemy_renderer.gd` (+ shader), `projectile_renderer.gd`, `gem_renderer.gd`, `player_view.gd` (geçici şekil rig), `ground_view.gd`, `camera_rig.gd`, `placeholder_art.gd`.
  - İlk adım: **`INSTANCE_CUSTOM` prototipi** (`gl_compatibility`). Çalışmazsa yedek: vurulma parlaması `COLOR` kanalında, karga kareleri 3 ayrı MultiMesh. Karar `docs/dev/perf.md`'ye yazılır.
  - Kural: kare başına bir `buffer` yazımı, `visible_instance_count=alive`.
  - Doğrulama notu: shader derlemesi bulutta "doğrulanmadı", cihazda doğrulanır.
- **U1-8 UI (∥).** Tema açılışı (açılmazsa `tokens.json` esas), fontlar, `virtual_joystick.gd`, `hud.gd`, `level_up_screen.gd`, `pause_screen.gd`, `result_screen.gd`, `main_menu.gd`. Kural: `to_upper` yok (i→I tuzağı). Maket karşılaştırması görsel öz-kontrolle; yapılamazsa "öz-kontrol yapılamadı" raporlanır. HUD çentik taşması riski: U1-8 güvenli kenar boşluğu sabiti (24 px) kullanır, tam `safe_area` U2-11'de.
- **U1-9 Bağlama (sıralı, 6+7+8 sonrası).** `input_gate.gd`, `pause_logic.gd` (saf, birim testli), `game_controller.gd`, sahneler, `Settings`, Android geri tuşu, sonuç akışı. Unit: ilk parmak kuralı, 600 ms kilit, LEVEL_UP'ta sim durması, APPLICATION_PAUSED/FOCUS_OUT kararı.
- **U1-10 Debug stres senaryosu ve debug APK (∥, U1-6/7 sonrası).**
  - `scripts/debug/stress_run.gd`: yalnız `OS.is_debug_build()`, ana menüde gizli giriş (sürüm etiketine 3 dokunuş).
  - Senaryo: 60 sn, 400 düşman (`debug_fill`) + 500 mermi, sabit tohum.
  - Ölçüm: `Performance` monitörlerinden ortalama/p95 kare süresi, draw call, nesne sayısı, bellek. Ekranda gösterir ve `user://perf.json`'a yazar.
  - `export_presets.cfg` (debug), `ci.yml` `export-debug` işi, `test_acc_perf_counters.gd` ile gate'te sayaç kontrolü.
  - Kabul: bulutta sayaç testi ve APK derlemesi (`GATE_EXPORT=1` mümkünse); cihaz FPS **kullanıcıda doğrulanır**.
- **U1-11 Ses iskeleti ve prova (son).** `default_bus_layout.tres` (`Master→Music,SFX,UI`), `Settings.sound_on` Master'a bağlanır, sim olaylarından `Sfx.play` çağrıları (no-op sessiz). `docs/dev/user-verify.md` prova kontrol listesi (APK kurulumu, 8 dk oynanış, stres sonucunu paylaşma).

#### Ara denetim (VLAD)
UI'lı pipeline kuralı: ilk görünen dilim sonrası. Bu fazın tüketeceği girdi: prova sonucu (`perf.json`), ekran görüntüleri.

#### Uygulama-2: içerik, sanat, ses, cila
- **U2-1 Sanat hattı (∥; Python).** `tools/art/*` + testler + `assets/gfx/**`. İlk iş `tools/slice.txt = 2`. Önizleme (`--preview`) gözle onay. Gate'e `pytest tools/art/tests` zaten bağlı.
- **U2-2 Kalan beceriler (∥).** `yelpaze_atis`, `dinamit`, `doldurma_sacilmasi`, `sarapnel`, `keskin_nisan` davranışları + JSON'ları, `zone_pool.gd`, `FxRenderer` halka shader'ı. Unit testler.
- **U2-3 Evrimler (U2-2 sonrası).** 4 evrim davranışı + JSON'ları, `evolved_log`, sonuç ekranı.
- **U2-4 Boss'lar ve Kale Lordu (∥).** Elit/lord davranışları + `enemies/` kayıtları, `waves.json` satır 4–6, uyarı bandı, halka dalgası, `end_mode:"lord"`. Boss ödülü: en yakın XP.
- **U2-5 Harita (∥).** `map_sim.gd` (chunk 1024 px, yarıçap 2, `rng_map`, başlangıç chunk merkezi boş), `ruin_view.gd`, `data/ruins.json`, engel itmesi (mermiler harabeden geçer).
- **U2-6 Gerçek görsellere geçiş (U2-1 sonrası).** Yer tutucuyu PNG ile değiştir, rig pivot/omuz/namlu ayarı (ekran görüntüsü döngüsü; kullanıcıda doğrulanır), `body_sway.gdshader`, düşman atlası, zemin, kargalar.
- **U2-7 Efektler (∥).** Namlu alevi, mermi izi, patlama, XP parlaması, `GPUParticles2D` duman, vurulma parlaması (havuzlu).
- **U2-8 Ses (uygulama-2'ye yerleşik; U2-6/7 ile ∥).** Üç alt görev:
  - **U2-8a Müzik hattı.** `tools/audio/process_audio.py`, `audio_manifest.json`, `check_music.py`, `tools/audio/tests/` (sentetik fixture: LUFS, dikiş, örnek hızı, OGG çözülebilir). `menu.wav` işlenir (hedef −18 LUFS, döngü crossfade). Diğer 6 parça kullanıcıdan gelince aynı araçla işlenir.
  - **U2-8b SFX kaynağı ve lisans.** CC0 SFX seçimi/ indirmesi (yedek: `synth_sfx.py`), `assets/audio/sfx/`, `LICENSES-audio.md`, lisans denetim testi.
  - **U2-8c Çalma katmanı.** `Sfx` havuzu ve eşzamanlı sınır, `AudioDirector` (crossfade, duck, `MusicPlan`), gunslinger imza sesleri (sağ/sol atış, tambur dönüşü, klik, kuru tetik, yükselen XP çınlaması), titreşim. Unit: `MusicPlan.track_for`, polifoni sınırı, XP combo perde formülü.
- **U2-9 Release hattı (U2-1 sonrası).** `release.yml`, `ensure_android_sdk.sh` tamamlama, `set_version.sh` + birim test, YAML lint, `docs/dev/setup.md` anahtar bölümü. **VLAD güvenlik incelemesi bu görevden sonra.** İmzalı APK kullanıcıda doğrulanır.
- **U2-10 Denge ve bot raporu (sıralı, 2–5 sonrası).** `tools/balance/sim_run.gd` (`test/helpers/bots.gd`'yi kullanır), JSON dağılım çıktısı, tabloların ayarı (yalnız bu görev sayı değiştirir), `docs/dev/balance-notes.md`. Gate dışıdır.
- **U2-11 Cila.** `DisplayServer.get_display_safe_area()` ile HUD güvenli alanı, erişilebilir ad rehberi, cihaz kontrol listesi.

#### Doğrulama fazı (tester)
Tam kabul paketi slice 2'de, nightly 20 dk koşu ve sızıntı, 3 politika × ≥100 seed dağılımı, `check_music.py --require`, `docs/dev/user-verify.md` son hali.

#### Denetim (VLAD)
Son kapı: güvenlik incelemesi sonucu, "kullanıcıda doğrulanır" listesi, ana branch'e merge/PR onayı.

### Test stratejisi

**Çerçeve: GUT 9.7.1** (taslaktaki gerekçe aynen: saf GDScript, vendor, CLI + JUnit, sim sahne bağımsız olduğundan sahne runner gerekmez; yedek Godot 4.6.3 + uyumlu GUT dalı).

**Genel kurallar:**
- Testler `GameSim`'i `seed` + `debug_*` kancaları ve `opts.log_events=true` ile kurar (`test/helpers/sim_kit.gd`); gözlem `event_log` üzerindendir.
- Kabul testleri beklenen sayıları **plan tablolarından sabit** yazar (`expected_tables.gd`); `test_acc_tables.gd` tablo–JSON eşleşmesini ayrıca doğrular.
- RNG sürümler arası aynı diziyi vermeyebilir: testler aralık/dağılım ve "aynı ikili, aynı tohum, aynı `state_hash`" ölçer. Sabit "altın hash" yok.
- Gerçek zaman/`Time` kullanılmaz. Bot seçimleri `rng_choice`'a dokunmaz; bot kendi RNG'sini (`seed+1`) kullanır, koşu tekrar oynatılabilir.
- Developer birim kapsamı: her sim sınıfının kuralları ve sınır durumları. Tester: iç yapıya bakmadan `GameSim`, `event_log` ve veri dosyaları.

| Senaryo | Seviye | Dizin |
|---|---|---|
| Şarjör: 6 atış sonra otomatik doldurma 1,0 sn; `hizli_doldurma` sv5 → 0,5 sn; `fazladan_mermi` sv3 → 9; cap artışı count'u anında artırır; doldururken ateş yok | unit | `test/unit/test_magazine.gd` |
| Çift tabanca: toplam hız `2/aralık`, yarım aralık faz farkı; 6 kurşun ≈0,75 sn (sv1) | kabul | `test_acc_pistols.gd` |
| Hedefleme (en yakın, silah 1 ikinci, elit önceliği, eşitlikte en düşük indeks, hedef yok → mermi harcanmaz) | unit | `test_targeting.gd` |
| `seken_mermi`: her N. kurşun, sekme sayısı, hasar×, aynı düşmana tekrar vurmaz | unit + kabul | `test_ricochet.gd`, `test_acc_rhythm.gd` |
| `son_mermi_patlar`: yalnız son kurşun; `explosion` olayı hasar 50 / yarıçap 100 (sv1) | kabul | `test_acc_rhythm.gd` |
| `doldurma_sacilmasi`: doldurma başında `shot` olayları adet=8 (sv1), hasar 10 | kabul | `test_acc_rhythm.gd` |
| Evrimler: koşul → kart çıkar, yuva değişir; `kiyamet_mermisi` geri yazma döngü başına bir; `refund` ile otomatik doldurma etkileşimi | kabul | `test_acc_evolution.gd` (slice 2) |
| `roll_choices`: 3 kart, evrim en altta, tekrarsız, aday yoksa Şifa; `debug_force_choices` | unit | `test_loadout.gd` |
| XP: `need(1..5,10,20,30,40)`, `cumulative(10)=276`; çoklu seviye kuyruğu; level artış anı | unit | `test_xp_curve.gd`, `test_game_sim.gd` |
| Oyun sonu öncelikleri (aynı adım Lord ölümü + hp≤0 → WON; timer + hp≤0 → LOST; WON sonrası `choose` false) | kabul | `test_acc_run_end.gd` |
| `start_time` semantiği: atlanan boss tetiklenmez, ileri olay tetiklenir | kabul | `test_acc_waves.gd` |
| Doğurma: boss zamanları, `alive_cap` sabit noktaları (130/220/310/400), halka yarıçapı, geri taşıma, `spawn_dropped` | unit + kabul | `test_spawn_director.gd`, `test_acc_waves.gd` |
| Zorluk çarpanları 5/10/15/20. dk | unit | `test_difficulty.gd` |
| Zırh formülü; alan hasarı zırhı yok sayar; temas ilk tick hemen sonra 0,6 sn; tick başına ≤4 temas | unit + kabul | `test_damage.gd`, `test_acc_damage.gd` |
| Veri bütünlüğü + tablo–JSON eşleşmesi (8/8/4/7 slice'a göre) | unit + kabul | `test_game_data.gd`, `test_acc_tables.gd` |
| Kısa koşular: 120 sn (3 politika) + `start_time` 300/600/900/1140'a atlayıp 30 sn; her 60 adımda `check_invariants()` boş | kabul | `test_acc_short_runs.gd` |
| Determinizm: aynı tohum iki koşu aynı `state_hash` (her 300 adımda); farklı tohum farklı | kabul | `test_acc_determinism.gd` |
| Pool CAP/spawn -1, `debug_fill` ile 400 düşman, XP korunumu | kabul | `test_acc_caps.gd` |
| İş sayacı tavanları (stres senaryosu) | kabul (gate) | `test_acc_perf_counters.gd` |
| `InputGate`/`PauseLogic` | unit | `test_input_gate.gd`, `test_pause_logic.gd` |
| Joystick matematiği | unit | `test_joystick.gd` |
| Ayarlar kaydet/yükle (geçici yol enjeksiyonu) | unit | `test_settings.gd` |
| `PlayerRig.muzzle_world` karakter verisiyle sayısal | unit | `test_player_rig.gd` |
| `MusicPlan`, SFX polifoni sınırı, XP combo perdesi | unit | `test_music_plan.gd`, `test_sfx.gd` |
| UI sahne açılışı (instantiate + `_ready`, shader derlenmez) | unit (smoke) | `test_ui_smoke.gd` |
| Metin UTF-8, `to_upper` yasağı | gate adımı | `tools/gate.sh` |
| Sanat sentetik / sağlık | pytest | `tools/art/tests/`, `tools/art/tests/health/` |
| Ses: LUFS, dikiş, SFX lisans tablosu | pytest | `tools/audio/tests/` |
| **Gate dışı (nightly/manuel):** 20 dk koşu 3 politika; sızıntı kontrolü; ≥100 seed × 3 politika dağılımı | rapor | `GATE_NIGHTLY=1`, `tools/balance/sim_run.gd` |

**Denge raporu aralıkları (gate dışı, rapor; ihlal gate'i kırmaz, denge görevine girer):**
- `idle` medyan hayatta kalma <180 sn ve p90 <240 sn.
- `kite` medyan 12–20 dk arası ölür ya da kazanır; p10 ≥8 dk.
- `greedy` (taş toplayıcı) medyanı `idle`'ın üstünde, `kite`'ın altında.
- `kite` botunda 10–20 dk arası her 60 sn pencerede `hp` en az bir kez %50 altına iner (tohumların ≥%80'inde).
- `kite` botunda 14,5–20 dk aralığında eşzamanlı düşman ≥300 en az bir kez (tohumların ≥%80'inde). Hedef 300+ düşman kriteridir.

**Kullanıcıda doğrulanır (bulutta doğrulanamayan; kabul kriterleri bunları ayrı tutar):**
- İmzalı release APK üretimi, kurulumu ve güncelleme olarak kurulması.
- Cihaz FPS / p95 kare süresi / ısınma (debug APK stres ölçümü, `perf.json`).
- Rig görünümü (omuz/pivot/namlu, kol kopukluğu) ve genel görsel doğruluk (maket karşılaştırması).
- Shader derlemesi ve `INSTANCE_CUSTOM` davranışı (`GATE_RENDER` yoksa).
- Ses: döngü dikişinin duyulmaması, karışım seviyesi, geçişlerin doğallığı, titreşim.
- Güvenli alan/çentik, dokunma hissi.

### Riskler

| Risk | Olasılık/etki | Azaltma |
|---|---|---|
| Godot/GUT/şablon sürümü ya da URL varsayımı yanlış | orta/yüksek | C0 ilk görev; SHA512 sabitleme; yedek 4.6.3; geçmeden C1 başlamaz |
| Bulut ağı Godot'u indirtmez (proxy) | yüksek/yüksek | gate çıkış 3 + çalışan `ASK` ile durur; izin verilecek hostlar listeli; gate'siz ilerlenmez |
| Sahte yeşil (headless ayrıştırma hatasında 0 çıkış) | orta/yüksek | günlük taraması izin listesiz + asgari sayı + `Stub.todo` + gate öz-testi |
| GDScript'te 400 düşman + 500 mermi cihazda 16 ms'yi aşar | orta/yüksek | erken mikro-ölçüm (U1-1), iş sayaçları gate'te, cihaz içi stres ölçümü, yedek merdiveni; GDExtension bulutta yok |
| Sim ms ≠ FPS (darboğaz render/MultiMesh yazımı) | orta/orta | cihaz içi ölçüm draw call ve kare süresini de içerir; MultiMesh yazımı tek `buffer` |
| `INSTANCE_CUSTOM` `gl_compatibility`'de beklenmedik | düşük/orta | U1-7'de ilk prototip; yedek 3 MultiMesh + `COLOR` |
| Sözleşme kancaları bir beceriye yetmez | orta/orta | 12 beceri kâğıt üstünde eşlendi; kanca yalnız sona eklenir; `SkillApi` geniş tutuldu |
| Belirsiz kurallar kabul testlerini kaydırır | orta/orta | kurallar Arayüzler'de sabit; tablolar `expected_tables.gd`'de; slice işareti |
| Düşman–harabe y-sort yok | kesin/düşük | kasıtlı sınır |
| Tema `.tres` Godot'ta açılmıyor | orta/düşük | U1-8 ilk adım; `tokens.json` esas |
| Yeşil temizleme kenar halkası/duman | orta/orta | `--preview`, taşma doldurma, sağlık testleri |
| Omuz/pivot tahminleri yanlış | yüksek/düşük | veri dosyasında; kullanıcı ekran görüntüsü döngüsü |
| Keystore sızıntısı/kaybı | düşük/yüksek | yalnız secret; `pull_request_target` yok; yedek kullanıcıda; VLAD güvenlik incelemesi |
| Müzik dosyaları eksik/geç gelir | orta/düşük | `AudioDirector` dosya yoksa sessiz; `check_music.py --require` yalnız doğrulama fazında |
| Müzik dosyası döngü sıçraması giderilemez | düşük/orta | crossfade + dikiş testi; olmazsa kullanıcıdan yeniden üretim |
| CC0 SFX bulutta indirilemez | orta/düşük | `synth_sfx.py` yedeği (CC0 beyanıyla) |
| Suno müzik lisansı (ticari kullanım/public repo) | orta/orta | kullanıcı kararı (Açık noktalar) |
| Denge ilk sürümde keyifsiz | yüksek/orta | tüm sayılar JSON; U2-10 bot dağılımı; kullanıcı geri bildirimi |
| 120 Hz ekranda 60 FPS sınırı hissi | düşük/düşük | `max_fps` ayarlanabilir |

### Eleştiriler ve nasıl ele alındı

**Developer eleştirisi**
- **D1 (C1 tam içerik, kanca yetersizliği): uygulandı.**
  - Sözleşme yalnız şema + validate + fixture + iskelet + gözlem kancaları; içerik dilimlere dağıtıldı.
  - Tek veri sahibi kuralı eklendi (dosya başına kayıt: `data/skills/<id>.json`).
  - 12 beceri kancalara kâğıt üstünde eşlendi (`skill-hooks.md`).
  - `on_reload_tick`, EXPLODE_ON_EXPIRE/ON_BOUNCE, `push`, `hitscan` eklendi.
- **D2 (bulut Godot kurulumu): uygulandı.**
  - C0 sözleşme fazının ilk görevi ve kabul kriteri.
  - Ağ yoksa çıkış 3 ve çalışan `ASK` ile durur.
  - `ensure_godot.sh` zorunlu; apt root varsayımı kaldırıldı (yoksa paket listesi, `libasound2t64`/`libasound2` seçimi).
  - Export bulutta kapalıysa rapor "APK derlenmedi" der ve kabul "CI/kullanıcıda doğrulanır".
- **D3 (gate sahte yeşil kırılgan): uygulandı.**
  - İzin listesi yerine "beklenen-hata testi yok, `push_error` yok, `Stub.todo`" kuralı.
  - `gate_min_tests` dosya başına, tek yönlü, bilinçli güncelleme.
  - Çıkış kodu C0'da ölçülür.
  - Bozuk `.gd` ile kırmızı otomatik öz-testte.
- **D4 (GDScript performansı): uygulandı.**
  - 6× varsayımı kaldırıldı.
  - Mikro-ölçüm U1-1'e alındı.
  - Gerçekçi yedek merdiveni (CAP/alive_cap düşürme, hücre boyutu, çarpışma bölme).
  - GDExtension bulutta yok diye açıkça kapsam dışı.
  - 3 adım/kare sınırında yavaş çekim kabul edilen davranış olarak yazıldı.
- **D5 (MultiMesh): uygulandı.**
  - `INSTANCE_CUSTOM` U1-7 ilk adımında prototip, yedeği hazır.
  - Yazım kalıcı Packed dizi ve doğrudan indeks.
  - Sıkıştırma yok; düşman sırası `alive_ids()`, kimlik/nesil kuralı bozulmaz.
- **D6 (rig): uygulandı.**
  - `muzzle_world` tek kaynak (sim saf fonksiyonu, view aynısını kullanır), sayısal test.
  - Görsel doğrulama "kullanıcıda doğrulanır".
  - z_index sıralaması düğüm ağacında yazıldı.
- **D7 (arayüz belirsizlikleri): uygulandı.**
  - `step(move)` sabit STEP.
  - Çoklu seviye kuyruğu `pending_levels`.
  - `Choice` ayrı dosya.
  - `boss_warning` 5 sn, UI bandı 2,4 sn ve süreyi UI tutar.
  - Joystick hareketini tek `InputGate.move()` üretir.
  - `player_damaged` sinyali; ekran sallanması ve vinyet view'ın işidir.
  - `Sfx` no-op iskelet C2'de.
  - `GameData` autoload değil (ad çakışması yok).
  - Mermi başına `hit_ids`.
- **D8 (dilim geniş, U1-10 bulutta doğrulanamaz, U2-6 bağımlılık, 20 dk bot): uygulandı.**
  - U1 daraltıldı (3 aktif, boss/lord/harita yok).
  - İmzalı release hattı U2-9'a taşındı; U1 yalnız debug APK ve commit'li debug keystore.
  - Release kabulü "kullanıcıda doğrulanır"; bulutta YAML lint + `set_version.sh` testi.
  - Görseller repoda, U2-6 tetik koşulu yok (yalnız U2-1 sonrası).
  - 20 dk koşu gate dışı; gate'te kısa koşular.
- **D9 (test altyapısı): uygulandı.**
  - `.gdlintrc` test gürültüsünü kapatır.
  - gdtoolkit uyumu C0'da doğrulanır, yeni sözdizimi yasak.
  - RNG sürüm farkına karşı aralık/`state_hash` eşitliği.
  - UI smoke kapsamı sınırlandı (shader derlemesi sınanmaz, `GATE_RENDER` ile ayrı).
  - `sim_kit.gd` (tester) ve `kit_dev.gd` (developer) ayrıldı.
- **D10 (veri şeması): uygulandı.**
  - `waves.json` satırlarına `kind`.
  - Pasif anahtarlar sabit küme, bilinmeyen anahtar `validate()` hatası.
  - Zırh formülü korundu (tasarım kararı) ve alan hasarının zırhı yok sayması açıkça tasarım kararı olarak Açık noktalara yazıldı. Lord'a karşı erken oyun zayıflığı denge raporunda izlenir.
- **D11 (VSync): uygulandı** (`vsync_mode=1`).
- **D12 (yalnız arm64): kabul edildi,** değişiklik yok.
- **D13 (font tek kaynak): uygulandı** (`assets/fonts/`).
- **D14 (maket karşılaştırması): uygulandı** (görsel öz-kontrol, yapılamazsa "öz-kontrol yapılamadı").
- **D15 (safe_area): kısmen.** U1'de sabit 24 px güvenli kenar boşluğu, tam `safe_area` U2-11'de.

**Tester eleştirisi**
- **T1 (determinizm): uygulandı.**
  - Dört RNG akışı.
  - Dictionary yineleme yasağı, LIFO serbest-liste, sıralı `query_circle`.
  - `step` sabit STEP.
  - `state_hash()`.
- **T2 (gözlem kancaları): uygulandı.**
  - Sim örneği başına `SimBus` ve `event_log` (global autoload sızıntısı yok).
  - `explosion`, `damage`, `shot` vb. olaylar.
  - Hasar olayı ham/net değerli.
- **T3 (sayı kaynağı iki yerde): uygulandı.**
  - Kabul testleri tablolardan sabit yazar (`expected_tables.gd`).
  - Tablo–JSON eşleşme testi `test_acc_tables.gd`'de (slice'a göre).
  - Not: VLAD'ın yönlendirmesiyle JSON içeriği sözleşmede değil dilimlerde olduğu için testin "C1'de" olması yerine "kabul fazında, kayıtlar geldikçe" çalışır.
- **T4 (perf güvenilmez): uygulandı.**
  - Gate'te deterministik iş sayaçları, zaman yalnız bilgi.
  - Debug APK'da 60 sn stres ve `user://perf.json` + ekranda.
  - Sızıntı kontrolü nightly.
- **T5 (20 dk koşu): uygulandı.**
  - Gate'te 120 sn ve `start_time` atlamalı 30 sn koşular.
  - `check_invariants()`.
  - Tam 20 dk nightly.
- **T6 (ölçülebilir tasarım kriterleri): uygulandı.**
  - Üç politika (`idle`, `kite`, `greedy`).
  - Hayatta kalma aralıkları ve ≥300 eşzamanlı kriteri denge raporunda.
  - `start_time` ≥900 gerekliliği belgelendi.
- **T7 (bot dağılımı): uygulandı.**
  - Nightly ≥100 seed × 3 politika (medyan/p10/p90).
  - Bot seçimleri deterministik, kendi RNG'siyle, tekrar oynatılabilir.
  - Kısmen: "bot `choose()` aynı RNG akışını tüketsin" reddedildi, çünkü sim akışını tüketmek bot davranışıyla sim sonucunu birbirine bağlar. Bot kendi RNG'sini kullanır.
- **T8 (GameController test dışı): uygulandı.** `InputGate`/`PauseLogic` saf sınıflar, birim testli.
- **T9 (log taraması, izin listesi, min test): uygulandı.** Bkz. D3. İzin listesi yerine beklenen-hata testi yasağı.
- **T10 (iskelet ayrıştırma): uygulandı.**
  - Sözleşme kabulü: iskelet `--import` ve boş GUT'ta ayrıştırma hatasız.
  - `Stub.todo` ile "uygulanmadı" ayrıştırma hatasından ayırt edilir.
  - Döngüsel `class_name` yok kuralı.
- **T11 (eksik sözleşme noktaları): uygulandı.**
  - Magazine: `is_last`, cap değişimi, `reload_total` anı, `refund` ve otomatik doldurma etkileşimi.
  - Çift tabanca aralığı tabanca başına, yarım aralık faz farkı.
  - `choose()` geçersiz durum davranışı.
  - Seviye artış anı.
  - `debug_grant` evrim davranışı, `debug_force_choices`.
  - `ShotContext.tags`.
  - `alive_cap` ve start_time notu.
  - `spawn` -1 kaybı.
- **T12 (validate kapsamı): uygulandı** (kapsam listesi Arayüzler'de).
- **T13 (`refund_used` sıfırlama): uygulandı** (`reload_finished`'te).
- **T14 (eşitlik kırıcı, sıra): uygulandı** (en düşük indeks; tabanca 0 sonra 1; `query_circle` artan).
- **T15 (`dmg_mult` iki anlam): uygulandı** (`bullet_dmg_mult` / `enemy_dmg_mult` / `contact_mult`; temas ilk tick hemen).
- **T16 (oyun sonu öncelikleri): uygulandı** (Lord ölümü önce; timer'da LOST; WON sonrası `choose` false).
- **T17 (`start_time` atlama semantiği): uygulandı** (atlanan `at` olayları tetiklenmez).
- **T18 (Türkçe): uygulandı** (gate'te `to_upper`/`to_lower` grep, UTF-8 metin testi).
- **T19 (sanat testleri): uygulandı** (sentetik birimler ve gerçek görsele bağlı sağlık testleri ayrı; kenar sütunu başına maks fark eklendi). Sağlık testleri gate'te koşar çünkü görseller repoda; gate dışı olmaları gerekmiyor.
- **T20 (gate hijyeni): uygulandı** (`rm -rf .gate`, CI'da temiz `.godot`, `Settings` yol enjeksiyonu).
- **T21 (gate öz-testi): uygulandı** (`selftest_gate.sh`, C0 kabulünde).
- **T22 (sim_kit çift sahiplik): uygulandı** (`kit_dev.gd` / `sim_kit.gd` ayrı).
- **T23 (UI smoke / shader): uygulandı** (smoke sahne açılışıyla sınırlı; `GATE_RENDER=1` ile xvfb+opengl3, yoksa "shader doğrulanmadı").
- **T24 (XP need(5)): uygulandı.** Tamsayı aritmetik (`8 + 4n + n*n/10`), tablo düzeltildi (`need(3)=20`, `need(4)=25`, `need(5)=30`).
- **T25 (nesil sarma): uygulandı** (birim test ve belge).
- **T26 (GemPool birleştirme): uygulandı** (XP korunum değişmezi; komşu-hücre araması, O(n²) yok).
- **T27 (`alive_ids`): uygulandı** (`PackedInt32Array`, artan sıra).
- **T28 (C0 araç zinciri önce): uygulandı** (sözleşme fazının ilk görevi, kabul kriteri; yeni faz açılmadı).

### Açık noktalar

**Kullanıcı kararı gerektirenler:**
- **Keystore** (U2-9): kullanıcı bir kez üretip `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_USER`, `ANDROID_KEYSTORE_PASSWORD` secret'larına koyar ve yedekler. Kayıp, mevcut kurulumların güncellenmesini engeller. Public repo artefaktındaki imzalı APK herkese indirilebilir görünür; kabul mü?
- **Bulut ağ izni:** `github.com`, `objects.githubusercontent.com`, `release-assets.githubusercontent.com` (Godot + GUT), export için `dl.google.com`, `maven.google.com`, SFX için `kenney.nl`. Eklenmezse C0'da çalışan `ASK` ile durur.
- **Suno müzik lisansı:** üretimde kullanılan Suno planının ticari/yeniden dağıtım hakkı repo public olduğu için kullanıcıya aittir. `LICENSES-audio.md`'ye müzik kaynağı ve plan yazılacak; doğrulama kullanıcıda.
- **Müzik dosyaları:** repoda yalnız `menu.wav` var. Kalan 6 parça kullanıcıdan gelecek; `check_music.py --require` doğrulama fazında 7'sini şart koşar.
- **Performans tabanı:** cihazda 300+ düşman 60 FPS tutmazsa yedek merdiveni ve "300+" hedefinin altına inme kararı kullanıcıya aittir.

**Tasarım yorumu / karar (itiraz edilmezse bu haliyle uygulanır):**
- Kuru tetik yorumu: şarjör boşalıp doldurma sürerken hedef varken tetik çekilince klik (sim `dry_fire` olayı). "Son mermide" başka bir şey kastediliyorsa değişir.
- Çift tabanca atış aralığı tabanca başına; toplam hız `2/aralık`. Tasarım belgesi farklı diyorsa aralık sayıları yeniden ayarlanır.
- Alan/patlama hasarı zırhı yok sayar. Lord'un zırhı (6) mermi hasarına karşı erken oyunda güçlü. Denge raporu izler.
- Kale Lordu ve elitlerin sabit istatistikleri; `ruin` mermi geçirgenliği (mermiler harabeden geçer); temas tick modeli; menzil pasifinin v1'de olmaması.
- `Music/SFX/UI` bus adları İngilizce (kodda), Türkçe etiket UI'da.
- "Prova", uygulama-1'in son görevi (U1-11) olarak yorumlandı: debug APK ve stres ölçümü provası. Farklı bir şey kastediliyorsa VLAD düzeltir.
- Gunslinger'ın v1 sayıları ilk tahmin; U2-10 ayarlar.

**Varsayımlar (doğrulanmadı):**
- Godot 4.7.2 son kararlı; GUT 9.7.1 uyumu; `godot-builds` indirme yolu; `commandlinetools-linux-11076708`; Android paket adları; Gradle'sız export'ta NDK/CMake gerekmediği.
- Bulut konteynerinde root + apt (yoksa gerekli paketler listelenir).
- gdtoolkit 4.x'in iskelet kodunu ayrıştırması (C0 doğrular, olmazsa lint kapsamı daralır).
- `soundfile` ile OGG Vorbis yazımı (olmazsa `ffmpeg`).
- `Performance` monitörlerinin `gl_compatibility`/Android'de beklenen değerleri vermesi.
- 1 dp ≈ 2,75 px; omuz/pivot/namlu normalize koordinatları.
- `docs/ui` maket ekran görüntüleri okunmadı; plan `DESIGN-UI.md` metnine dayanır.

**Kapsam dışı / ileride:** karakter seçimi, ayarlar ekranı (yalnız ses/titreşim anahtarı, ses seviye çubuğu yok), TalkBack, düşman–harabe y-sort, hasar sayıları, interpolasyonlu render, 120 FPS, GDExtension, AAB.

**Dış API:** yok (ağ kullanılmaz); gerçek yanıt örneği gerekmez.

**Görsel not:** kargalar tek görselde 3 poz → 3 kareli atlas; duman görselden temizlenip `GPUParticles2D` ile eklenir; zeytin yeşili bitkiler anahtarlamada korunur (`G − max(R,B)` eşiği; arka plan `d≈145–170`, bitki ≤≈20).