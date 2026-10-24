class_name ShotContext
extends RefCounted
## Şarjörden çıkan bir kurşunun değiştirilebilir bağlamı (SkillBehavior.modify_shot / on_last_bullet).

var gun: int = 0
var index_in_mag: int = 1  # 1..cap
var is_last: bool = false
var origin: Vector2 = Vector2.ZERO
var dir: Vector2 = Vector2.RIGHT
var damage: float = 0.0
var pierce: int = 0
var bounces: int = 0
var flags: int = 0
var ex_radius: float = 0.0
var ex_dmg: float = 0.0
var push: float = 0.0
var tags: PackedStringArray = PackedStringArray()
## v2.0.2: 0 => varsayılan (yarıçap DEFAULT_RADIUS, hız BULLET_SPEED, ömür havuz varsayılanı 1,2 sn).
var radius: float = 0.0
var speed: float = 0.0
var life: float = 0.0
