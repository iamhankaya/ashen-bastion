class_name AchievementMigration
extends RefCounted
## v1 -> v2 kayıt göçü ve açılış uzlaştırma (docs/data-schema.md "Kayıt göçü"). Saf: depo dosyası, saat, sinyal yok.


## `clean` = AchievementStore.sanitize çıktısı (v1 alanları; `steps` boş olabilir). Aynı biçimde yeni sözlük döner, girdi değişmez.
## Eski kimlikler `def.legacy` eşlemesiyle ailenin en yüksek kademesine taşınır (alt kademeler örtük açık, tarih korunur),
## kademenin eşiği toplam sayaçlara (`totals`) alt sınır olarak tohumlanır; koşu en iyileri (`best`) tohumlanmaz (kademe `steps`te,
## ekran değeri en az açılan kademenin eşiğidir). Eşlenmeyen kimlikler olduğu gibi kalır.
static func migrate(clean: Dictionary, defs: Array) -> Dictionary:
	var out := clean.duplicate(true)
	var unlocked: Dictionary = out["unlocked"]
	var steps: Dictionary = out["steps"]
	for def: AchievementDef in defs:
		if def.steps.is_empty() or def.legacy.is_empty() or steps.has(def.id):
			continue
		var top := 0
		var at: Dictionary = {}  # kademe -> unix
		for key in def.legacy:
			var old_id := StringName(key)
			if not unlocked.has(old_id):
				continue
			var k := int(def.legacy[key])
			top = maxi(top, k)
			at[k] = mini(int(at.get(k, unlocked[old_id])), int(unlocked[old_id]))
			unlocked.erase(old_id)
		if top == 0:
			continue
		var arr: Array = []
		for k in range(1, top + 1):
			arr.append(_unix_for(at, k, top))
		steps[def.id] = arr
		unlocked[def.id] = arr[0]
		_seed(out, def, def.steps[top - 1])
	return out


## k. kademenin tarihi: kendi eski kimliği açıksa o; değilse üstündeki en yakın kayıtlı kademe (alt kademe daha önce açılmıştır).
static func _unix_for(at: Dictionary, k: int, top: int) -> int:
	for j in range(k, top + 1):
		if at.has(j):
			return int(at[j])
	return 1


## Toplam stat'ın eşiğini `totals` alt sınırı olarak yazar (`run_*` ve `total_chars5` tohumlanmaz).
static func _seed(state: Dictionary, def: AchievementDef, value: int) -> void:
	var key: String = AchievementDef.TOTAL_KEY.get(String(def.stat), "")
	if key != "":
		var t: Dictionary = state["totals"]
		t[key] = maxi(int(t[key]), mini(value, AchievementStore.COUNTER_CAP))


## Sayaçların hak ettiği ama kayıtta olmayan kademeleri SESSİZCE verir (bildirim yok; kademe asla geri alınmaz).
## Göçten ve eşik değişikliklerinden sonra açılışta çağrılır. Dönüş: eklenen kademe sayısı.
static func reconcile(store: AchievementStore, defs: Array, unix: int) -> int:
	var added := 0
	for def: AchievementDef in defs:
		var have := store.step_count(def.id)
		var v := AchievementProgress.of(def, store)
		if v < 0:
			continue
		var n := mini(AchievementStep.reached(def, v), AchievementStep.total(def))
		if n > have and store.unlock_step(def.id, n, unix):
			added += n - have
	return added
