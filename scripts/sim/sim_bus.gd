class_name SimBus
extends RefCounted
## Sim örneği başına sinyal veriyolu. Sim bunları yalnızca bildirim için yayınlar; mantık sinyale bağlı değildir.
## View/UI/ses `sim.bus`'a bağlanır. Sinyal EKLEMEK serbest (sona); mevcut imza değişmez.

signal magazine_changed(count: int, cap: int)
signal reload_started(duration: float)
signal reload_finished
signal shot_fired(gun: int, origin: Vector2, dir: Vector2)
signal last_bullet_fired(origin: Vector2)
signal dry_fire(gun: int)
signal enemy_killed(type_id: StringName, pos: Vector2)
signal gem_collected(value: int)
signal player_damaged(amount: float, hp: float)
signal level_up(level: int)
signal choice_made(skill_id: StringName)
signal evolution_gained(evo_id: StringName)
signal boss_warning(kind: StringName)  # olaydan 5 sn önce; UI bandı 2,4 sn (süreyi UI tutar)
signal boss_spawned(type_id: StringName)
signal explosion(pos: Vector2, radius: float)
signal run_ended(won: bool, stats: Dictionary)

# --- v1.1 (eklentiler ve skor) ---
signal pickup_spawned(kind_id: StringName, pos: Vector2)
signal pickup_collected(kind_id: StringName, pos: Vector2)
signal pickup_expired(kind_id: StringName)
signal buff_started(kind: StringName, duration: float)  # kind: &"damage"|&"fire_rate"|&"unlimited"; yenilemede de yayınlanır
signal buff_ended(kind: StringName)
signal bomb_planted(pos: Vector2, radius: float, fuse: float)
signal bomb_exploded(pos: Vector2, radius: float)
signal score_changed(score: int, mult: int, gain: int)
signal streak_changed(mult: int, left: float)

# --- v2.0 ---
## PickupSystem.blast: bomb_exploded'ten hemen sonra. YALNIZ Kara Bomba (dinamit mermi havuzundan patlar, blast çağırmaz).
## Sim durumunu etkilemez; dinleyicisiz de aynı state_hash (başarım #22 için; bomb_exploded imzası değişmez).
signal bomb_hits(pos: Vector2, radius: float, hits: int)

# --- v2.0.1 ---
## Mermi düşmana isabet etti ve öldürmedi (ölüm `enemy_killed` ile duyulur). Yalnız bildirim: sim durumunu ve RNG'yi etkilemez.
signal enemy_hit(pos: Vector2)
