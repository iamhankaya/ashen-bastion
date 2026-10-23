class_name AshGhostRenderer
extends MultiMeshInstance2D
## Ölüm "hayalet" MultiMesh'i (havuz 64, halka tampon) + kül shader'ı. `enemy_killed` olayını dinler.
## İskelet (S3): sabitler gerçek; gövdeler D1-3'te dolar.

const CAP := 64
## Bu kadar canlı düşmandan sonra 150 ms düz solma (LOD).
const LOD_ALIVE := 150

@warning_ignore_start("unused_parameter")


func bind(sim: GameSim, enemy_renderer: EnemyRenderer) -> void:
	Stub.todo(&"AshGhostRenderer.bind")


func update_ghosts(dt: float) -> void:
	Stub.todo(&"AshGhostRenderer.update_ghosts")


func ghost_count() -> int:
	Stub.todo(&"AshGhostRenderer.ghost_count")
	return 0
