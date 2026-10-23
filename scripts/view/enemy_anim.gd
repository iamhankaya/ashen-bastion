class_name EnemyAnim
extends RefCounted
## Düşman hareket tabloları: tür başına `anim` verisi, 256'lık sinüs LUT, slot başına faz/son konum ve iş sayaçları.
## Çizmez; EnemyRenderer pozu okur. Zaman = sim.time (görünüm saati değil).
## İskelet (S3): sabit ve sayaçlar gerçek; gövdeler D1-2'de dolar (şimdilik Stub.todo).

const LUT_SIZE := 256

var last_anim_instances: int = 0
var last_frame_selects: int = 0

@warning_ignore_start("unused_parameter")


func bind(data: GameData, atlas: EnemyAtlas) -> void:
	Stub.todo(&"EnemyAnim.bind")


## gen değiştiyse phase0/walk/last_pos ilklenir (slot yeniden kullanımı yeni faz alır).
func sync_slot(i: int, gen: int, pos: Vector2) -> void:
	Stub.todo(&"EnemyAnim.sync_slot")


## (theta, sx, sy, bob_px). İskelet kimlik pozu döndürür.
static func pose_of(
	kind: int, hz: float, bob: float, rot_rad: float, sq: float, t: float, phase0: float
) -> Vector4:
	Stub.todo(&"EnemyAnim.pose_of")
	return Vector4(0.0, 1.0, 1.0, 0.0)
