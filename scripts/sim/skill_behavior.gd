class_name SkillBehavior
extends RefCounted
## Bir becerinin kancaları. Varsayılan gövdeler boş (no-op). Kanca imzası değişmez, yalnız sona eklenir.
## Kanca eşlemesi: docs/dev/skill-hooks.md


func setup(api: GameSim, def: SkillDef, level: int) -> void:
	pass


## Şarjörden çıkan her kurşun.
func modify_shot(ctx: ShotContext) -> void:
	pass


func on_last_bullet(ctx: ShotContext) -> void:
	pass


func on_reload_start() -> void:
	pass


## Doldurma süresince her adım (mermi_firtinasi halkaları).
func on_reload_tick(dt: float) -> void:
	pass


func on_reload_end() -> void:
	pass


func on_kill(enemy_id: int, pos: Vector2) -> void:
	pass


func on_hit(enemy_id: int, proj_id: int) -> void:
	pass


## Şarjörsüz, soğumalı silahlar.
func tick(dt: float) -> void:
	pass
