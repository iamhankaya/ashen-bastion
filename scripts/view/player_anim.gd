class_name PlayerAnim
extends RefCounted
## Oyuncu rig durum makinesi ve prosedürel katmanlar (saf: Node bilmez). Çıktı = aşağıdaki poz alanları;
## PlayerView bunları Rig düğümüne uygular. Değerler DESIGN §1.2 (P1–P13), süreler Motion'dan.
## İskelet (S3): alanlar gerçek; gövdeler D1-1'de dolar (şimdilik Stub.todo).

enum Mode { IDLE, WALK, DEAD }

var mode: int = Mode.IDLE
var lean: float = 0.0
var bob_px: float = 0.0
var sx: float = 1.0
var sy: float = 1.0
var turn_x: float = 1.0
var frame_a: int = 0
var frame_b: int = 0
var frame_mix: float = 0.0
var walk_phase: float = 0.0
var hit: float = 0.0
var tint_amt: float = 0.0
var desat: float = 0.0
var scarf_amp: float = 0.0
var arm_rot := PackedFloat32Array([0.0, 0.0])
var arm_back := PackedFloat32Array([0.0, 0.0])
var arm_len := PackedFloat32Array([1.0, 1.0])
var knock_px: float = 0.0
var body_rot: float = 0.0
var sink_px: float = 0.0
var fade: float = 1.0
var halo: float = 0.0
## Seviye halkası ilerlemesi; -1 = yok.
var level_ring: float = -1.0
## Etki aurası: bit0 hasar, bit1 hız, bit2 sınırsız.
var aura_mask: int = 0

@warning_ignore_start("unused_parameter")


## CharacterDef.rig (walk dahil) ile yapılandırır; walk.frames > 0 ise kare modu.
func configure(rig: Dictionary) -> void:
	Stub.todo(&"PlayerAnim.configure")


func reset() -> void:
	Stub.todo(&"PlayerAnim.reset")


## reload_progress: -1 = doldurmuyor.
func update(dt: float, vel: Vector2, facing_left: bool, reload_progress: float) -> void:
	Stub.todo(&"PlayerAnim.update")


func on_shot(gun: int) -> void:
	Stub.todo(&"PlayerAnim.on_shot")


func on_damaged(amount: float, from_dir: Vector2) -> void:
	Stub.todo(&"PlayerAnim.on_damaged")


func on_level_up() -> void:
	Stub.todo(&"PlayerAnim.on_level_up")


func on_buffs(mask: int) -> void:
	Stub.todo(&"PlayerAnim.on_buffs")


func on_died(from_dir: Vector2) -> void:
	Stub.todo(&"PlayerAnim.on_died")


func on_won() -> void:
	Stub.todo(&"PlayerAnim.on_won")


func death_done() -> bool:
	Stub.todo(&"PlayerAnim.death_done")
	return false
