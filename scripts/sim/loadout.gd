class_name Loadout
extends RefCounted
## 6 aktif + 6 pasif yuva, evrim koşulu, seviye atlama kartları.

const ACTIVE_SLOTS := 6
const PASSIVE_SLOTS := 6
const HEAL_ID := &"heal"
const HEAL_FRACTION := 0.25

var data: GameData = null
## Davranışların setup'ına verilen SkillApi (GameSim); zayıf bağ (sim <-> loadout döngüsü sızıntı yapmasın).
## Bağlı değilse davranış kurulmaz (birim testlerde).
var _api_ref: WeakRef = null
var _actives: Array[SkillState] = []
var _passives: Array[SkillState] = []


func _init(p_data: GameData = null) -> void:
	data = p_data


func bind_api(sim: GameSim) -> void:
	_api_ref = weakref(sim)


func actives() -> Array[SkillState]:
	return _actives


func passives() -> Array[SkillState]:
	return _passives


func level_of(skill_id: StringName) -> int:
	var s := state_of(skill_id)
	return s.level if s != null else 0


func state_of(skill_id: StringName) -> SkillState:
	for s in _actives:
		if s.id == skill_id:
			return s
	for s in _passives:
		if s.id == skill_id:
			return s
	return null


## Sahip değilse yeni yuvaya ekler (yuva doluysa yok sayılır), sahipse seviyeyi artırır (max_level'da kalır).
func add_or_upgrade(skill_id: StringName) -> void:
	var def := data.get_skill(skill_id)
	if def == null or def.kind == SkillDef.KIND_EVOLUTION:
		return
	var st := state_of(skill_id)
	if st != null:
		if st.level < def.max_level:
			st.level += 1
			_setup(st)
		return
	var slots := _actives if def.kind == SkillDef.KIND_ACTIVE else _passives
	var limit := ACTIVE_SLOTS if def.kind == SkillDef.KIND_ACTIVE else PASSIVE_SLOTS
	if slots.size() >= limit:
		return
	slots.append(_new_state(def, 1))


## Evrim hazırsa evrim kimliği, değilse &"". Koşul: aktif max_level + eşleşen pasif seviye >= 1.
func evolution_ready() -> StringName:
	for evo in data.skills_of_kind(SkillDef.KIND_EVOLUTION):
		if state_of(evo.id) != null:
			continue
		var rq := evo.requires
		var act := state_of(StringName(str(rq.get("active", ""))))
		var pas := state_of(StringName(str(rq.get("passive", ""))))
		if act == null or pas == null:
			continue
		if (
			act.level >= int(rq.get("active_level", 1))
			and pas.level >= int(rq.get("passive_min_level", 1))
		):
			return evo.id
	return &""


## Ham aktifi yuvada yerinde değiştirir (evrim max_level 1; pasif kalır). Ham aktif yoksa boş yuvaya ekler.
func apply_evolution(evo_id: StringName) -> void:
	var evo := data.get_skill(evo_id)
	if evo == null or evo.kind != SkillDef.KIND_EVOLUTION:
		return
	var raw_id := StringName(str(evo.requires.get("active", "")))
	for i in _actives.size():
		if _actives[i].id == raw_id:
			_actives[i] = _new_state(evo, 1)
			return
	if _actives.size() < ACTIVE_SLOTS:
		_actives.append(_new_state(evo, 1))


## rng: sim buraya rng_choice verir. 1..3 kart; aday yoksa tek "heal".
## Evrim hazırsa kartlardan biri evrimdir ve EN ALTA konur; kalanlar upgrade+new havuzundan tekrarsız çekilir.
func roll_choices(rng: RandomNumberGenerator) -> Array[Choice]:
	var pool: Array[Choice] = []
	for st in _actives + _passives:
		if st.level < st.def.max_level:
			pool.append(_card(Choice.KIND_UPGRADE, st.def, st.level, st.level + 1))
	var consumed := _consumed_actives()
	for def in data.skills_of_kind(SkillDef.KIND_ACTIVE):
		if consumed.has(def.id):
			continue  # evrime dönüşen ham aktif tekrar "yeni" olarak sunulmaz
		if state_of(def.id) == null and _actives.size() < ACTIVE_SLOTS:
			pool.append(_card(Choice.KIND_NEW, def, 0, 1))
	for def in data.skills_of_kind(SkillDef.KIND_PASSIVE):
		if state_of(def.id) == null and _passives.size() < PASSIVE_SLOTS:
			pool.append(_card(Choice.KIND_NEW, def, 0, 1))
	var evo_id := evolution_ready()
	var out: Array[Choice] = []
	var want := 2 if evo_id != &"" else 3
	while out.size() < want and not pool.is_empty():
		out.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	if evo_id != &"":
		out.append(_card(Choice.KIND_EVOLUTION, data.get_skill(evo_id), 0, 1))
	if out.is_empty():
		var heal := Choice.new()
		heal.kind = Choice.KIND_HEAL
		heal.skill_id = HEAL_ID
		heal.title = "Şifa"
		heal.desc = "Azami canın %25'i kadar can yenilenir."
		heal.icon = "placeholder:heal"
		out.append(heal)
	return out


## Sahip olunan evrimlerin yerini aldığı ham aktifler.
func _consumed_actives() -> Dictionary:
	var out := {}
	for st in _actives:
		if st.def.kind == SkillDef.KIND_EVOLUTION:
			out[StringName(str(st.def.requires.get("active", "")))] = true
	return out


func _card(kind: StringName, def: SkillDef, from_level: int, to_level: int) -> Choice:
	var c := Choice.new()
	c.kind = kind
	c.skill_id = def.id
	c.from_level = from_level
	c.to_level = to_level
	c.title = def.display_name
	c.desc = def.desc[to_level - 1] if to_level - 1 < def.desc.size() else ""
	c.icon = def.icon
	return c


func _new_state(def: SkillDef, level: int) -> SkillState:
	var st := SkillState.new()
	st.id = def.id
	st.def = def
	st.level = level
	if def.kind != SkillDef.KIND_PASSIVE and SkillRegistry.BEHAVIORS.has(def.behavior):
		st.behavior = SkillRegistry.BEHAVIORS[def.behavior].new()
	_setup(st)
	return st


func _setup(st: SkillState) -> void:
	if st.behavior == null or _api_ref == null:
		return
	var api: GameSim = _api_ref.get_ref()
	if api != null:
		st.behavior.setup(api, st.def, st.level)
