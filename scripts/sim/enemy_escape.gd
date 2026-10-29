class_name EnemyEscape
extends RefCounted
## F-ashen-bastion-021: içbükey harabe cebinde (U kap, L köşe, çok daireli yapı) dolanma tarafı değiştirmenin yetmediği
## "çıkmaz" için kısa kaçış modu. Yer düşmanı dolanma modundayken (F-020) art arda `ESC_AFTER` denetimde (1,5 sn'lik
## aralıklar) hedefe `ESC_PROGRESS` px'ten az yaklaştıysa kaçışa geçer: hedefi yok sayıp son itme normaline dik (teğet)
## yönde, harabe yüzeyine hafifçe yaslanarak (`CONTACT_BIAS`) yüzeyi izler (sağ/sol el kuralı; taraf sabittir) ve hedefe
## giden yol açılınca (ya da `ESC_MAX` sn dolunca) normal harekete döner. Durum EnemyPool.esc_* / push_n / stuck_n alanlarında;
## hepsi tam sayı adım/sabit sürelerle ilerler, RNG kullanmaz (deterministik).

## Anahtar (`sim.enemies.escape_enabled`, debug APK'da kapatılabilir) ve debug sayacı (`escape_begun`) sim örneğindedir;
## controller anahtarı her yeni sim'e uygular ve oturum toplamını `taban + escape_begun` olarak gösterir.

const ESC_AFTER := 2  # ardışık ilerlemesiz denetim sayısı
const ESC_PROGRESS := 40.0  # px; denetim aralığında hedefe bundan az yaklaşma = ilerleme yok
const ESC_MAX := 30.0  # sn (en uzun yüzey izleme; yol açılınca erken biter)
const CONTACT_BIAS := 0.35  # yüzeye doğru yaslanma payı (teğet 1,0'a göre)
const PROBE_STEP := 50.0
const PROBES := 12  # hedefe giden yol en çok PROBES × PROBE_STEP px (600) boyunca denetlenir
const EXIT_EVERY := 4  # adım; hedef yolu açık mı denetimi
const SIDE_PROBE := 40.0


## Kaçışa geçer: taraf yüzey boyunca serbest olan yöndür; ikisi de serbest/kapalıysa hedefe hizalı olan, eşitlikte indeks paritesi.
static func begin(sim: GameSim, i: int, to: Vector2) -> void:
	var e := sim.enemies
	var n := e.push_n[i]
	if n.length_squared() < 0.25:
		n = -to.normalized() if to.length_squared() > 1.0 else Vector2.UP
		e.push_n[i] = n
	var tang := Vector2(-n.y, n.x)
	var reach := e.radius[i] * 0.8
	var free_p := not blocked(sim, e.pos[i] + tang * SIDE_PROBE, reach)
	var free_m := not blocked(sim, e.pos[i] - tang * SIDE_PROBE, reach)
	var side := 1.0 if (i & 1) == 0 else -1.0
	if free_p != free_m:
		side = 1.0 if free_p else -1.0
	elif to.length_squared() > 1.0 and absf(tang.dot(to.normalized())) > 0.05:
		side = 1.0 if tang.dot(to) > 0.0 else -1.0
	e.esc_side[i] = side
	e.esc_left[i] = ESC_MAX
	e.stuck_n[i] = 0
	e.escape_begun += 1


## Kaçış yönü: yüzeye teğet (taraf sabit) + yüzeye hafif yaslanma.
static func move_dir(sim: GameSim, i: int) -> Vector2:
	var e := sim.enemies
	var n := e.push_n[i]
	var tang := Vector2(-n.y, n.x) * e.esc_side[i]
	return (tang - n * CONTACT_BIAS).normalized()


## Her kaçış adımında (hareket + resolve sonrası) çağrılır: itme normalini güncelle, süreyi düşür, yol açıldıysa bitir.
static func after_move(sim: GameSim, i: int, push: Vector2, to: Vector2, dt: float) -> void:
	var e := sim.enemies
	if push.length_squared() > 0.0001:
		e.push_n[i] = push.normalized()
	e.esc_left[i] = maxf(0.0, e.esc_left[i] - dt)
	if e.esc_left[i] > 0.0 and (sim.step_count + i) % EXIT_EVERY == 0 and path_clear(sim, i, to):
		e.esc_left[i] = 0.0
	if e.esc_left[i] <= 0.0:
		e.ai_timer[i] = 0.0  # normal harekete dön; yeniden itilirse F-020 dolanması baştan başlar
		e.ai_dir[i] = e.pos[i]
		e.stuck_n[i] = 0


## Hedefe giden doğru (en çok PROBES × PROBE_STEP px) boyunca engelsiz mi.
static func path_clear(sim: GameSim, i: int, to: Vector2) -> bool:
	var d2 := to.length_squared()
	if d2 < 1.0:
		return true
	var dir := to / sqrt(d2)
	var reach := sim.enemies.radius[i] * 0.8
	var p0 := sim.enemies.pos[i]
	var n := mini(PROBES, ceili(sqrt(d2) / PROBE_STEP))
	for k in range(1, n + 1):
		if blocked(sim, p0 + dir * minf(PROBE_STEP * float(k), sqrt(d2)), reach):
			return false
	return true


static func blocked(sim: GameSim, p: Vector2, reach: float) -> bool:
	return sim.map.resolve(p, reach).distance_squared_to(p) > 0.25


## Denetimde ilerleme sayacı: dolanma sürüyor ve hedefe yeterince yaklaşılmadıysa +1, aksi halde 0. Eşik dolduysa kaçışa geçer.
static func check(sim: GameSim, i: int, to: Vector2, target: Vector2) -> void:
	var e := sim.enemies
	if not e.escape_enabled or e.esc_left[i] > 0.0:
		return
	if e.ai_timer[i] <= 0.0:
		e.stuck_n[i] = 0
		return
	var progress := e.ai_dir[i].distance_to(target) - e.pos[i].distance_to(target)
	if progress < ESC_PROGRESS:
		e.stuck_n[i] = mini(int(e.stuck_n[i]) + 1, 255)
	else:
		e.stuck_n[i] = 0
	if e.stuck_n[i] >= ESC_AFTER:
		begin(sim, i, to)


## Debug etiketi için: şu an kaçışta olan yer düşmanı sayısı.
static func escaping_count(sim: GameSim) -> int:
	var n := 0
	for i in EnemyPool.CAP:
		if sim.enemies.alive[i] == 1 and sim.enemies.esc_left[i] > 0.0:
			n += 1
	return n
