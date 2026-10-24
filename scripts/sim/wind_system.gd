class_name WindSystem
extends RefCounted
## Rüzgar bölgeleri adımı (GameSim.wind; `_phase_skills` sonunda `step(self)`). S1: iskelet — bölge yokken hemen döner,
## bölge varsa yalnız ömrünü işletir. Gövde (hareket, tik, çekme/itme, ömür sonu) U3'tedir.
##
## U3 algoritması (plan "Arayüzler/5"):
## 1. `n := zones.count`; i = n-1 → 0 geriye gez. Yeni bölgeler `_pending` listesine yazılır, döngü sonunda sona
##    eklenir (CAP/RESERVE uygulanır; dolu ise `fx.zone_dropped` artar). `remove(i)` yalnız ömrü bitenler için.
## 2. Her bölge: `life -= dt`; hareket; `tick_left -= dt`, `<= 0` iken tik: aday = `grid.query_circle(pos, radius +
##    sim._max_enemy_radius)`, mesafe kuralı `dist <= radius + enemies.radius[i]`; hasar `&"dot"` (elit/Lord için
##    hasar × boss_mult), çekme (`pull` px/sn × dt, merkeze), itme `WindUtil.displace` (elit/Lord yer değiştirmez).
## 3. Hava Cebi tik hasarı `&"pocket_dot"` ile verilir; `on_kill` imzası etiket TAŞIMAZ (enemy_id, pos), bu yüzden
##    cep tiki sırasında `in_pocket_tick` true tutulur ve `hava_cebi.on_kill` bu bayrağa bakar (zincir yok).
## 4. Ömür sonu: Hortum ve Tufan savurma (`fling` px, displace, elit hariç) + 2x tik hasarı, sonra `remove`.
## 5. Hortum/Tufan hareketi: doğuş oyuncudan 250 px, açı `rng_combat.randf() * TAU` (count > 1 ise `+ i * TAU / count`);
##    `retarget_every` sn'de bir hedef (`grid.query_circle(player_pos, 600)` sıralı kimlikler, boş değilse
##    `ids[int(rng_combat.randf() * ids.size())]`, boşsa oyuncu + sabit ofset). Yeniden hedefleme başına tam 1
##    `randf()` (liste boş da olsa). Hız `speed`; oyuncudan `max_dist` aşılırsa hedef oyuncuya çevrilir.
## 6. Izgara aşama 3'te kurulur, WindSystem aşama 5'te: savrulan düşman mermi fazında (6) bayat hücrede olabilir;
##    U3 ölçümü gerekirse bölge sorgusuna +`fling` payı ekler.

## Hava Cebi tik hasarı sürerken true (on_kill etiket taşımadığı için örnek bayrağı).
var in_pocket_tick: bool = false


func step(sim: GameSim) -> void:
	var zones := sim.zones
	if zones.count == 0:
		return
	var i := zones.count - 1
	while i >= 0:
		zones.life[i] -= GameSim.STEP
		if zones.life[i] <= 0.0:
			zones.remove(i)
		i -= 1


## Bölge doğurur; -1 (dolu/rezerv) ise `sim.fx.zone_dropped` artar (kayıp sessiz değildir).
static func spawn_zone(sim: GameSim, kind: int, p: Vector2, o: Dictionary = {}) -> int:
	var i := sim.zones.spawn(kind, p, o)
	if i < 0:
		sim.fx.zone_dropped += 1
	return i
