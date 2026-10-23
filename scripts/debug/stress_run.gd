class_name StressRun
extends Node
## Cihaz içi stres koşusu (yalnız debug derlemede): 60 sn, StressScenario (400 düşman + ~500 mermi, sabit tohum).
## Kare süresi (ortalama / p95), draw call, nesne sayısı ve bellek ölçülür; ekranda gösterilir ve user://perf.json'a yazılır.

signal finished(result: Dictionary)

const DURATION := 60.0
const RESULT_PATH := "user://perf.json"

var scenario: StressScenario
var _frames: PackedFloat32Array = PackedFloat32Array()
## Görünüm güncelleme süresi (ms/kare): GameController._update_views ölçümü (D1-4); sim adımı ve render hariç.
var _view_ms: PackedFloat32Array = PackedFloat32Array()
var _elapsed: float = 0.0
var _accum: float = 0.0
var _step_i: int = 0
var _draw_calls_max: int = 0
var _done: bool = false


func _init() -> void:
	scenario = StressScenario.new({}, true)  # periyodik ölüm yükü açık


static func available() -> bool:
	return OS.is_debug_build()


func is_done() -> bool:
	return _done


## Controller her karede çağırır; sim adımlarını bu sınıf sürer (kare başına en çok 3 adım).
func advance(delta: float) -> void:
	if _done:
		return
	_elapsed += delta
	_frames.append(delta)
	_draw_calls_max = maxi(
		_draw_calls_max, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	)
	_accum += delta
	var n := mini(int(_accum / GameSim.STEP), 3)
	for i in n:
		scenario.step(_step_i)
		_step_i += 1
	_accum = 0.0 if n == 3 else fmod(_accum, GameSim.STEP)
	if _elapsed >= DURATION:
		_finish()


## Denetleyici her kare `_update_views` süresini (ms) bildirir.
func record_view(ms: float) -> void:
	if not _done:
		_view_ms.append(ms)


## Anlık özet (ekranda gösterim).
func status_text() -> String:
	var avg := _avg_ms()
	return (
		"STRES %02d/%d sn\nort %.1f ms  p95 %.1f ms\ngörünüm %.2f ms\ndüşman %d  mermi %d  çizim %d"
		% [
			int(_elapsed),
			int(DURATION),
			avg,
			_p95_ms(),
			_mean(_view_ms),
			scenario.sim.enemies.count,
			scenario.sim.projectiles.count,
			_draw_calls_max,
		]
	)


func build_result() -> Dictionary:
	var avg := _avg_ms()
	return {
		"seconds": snappedf(_elapsed, 0.1),
		"frames": _frames.size(),
		"avg_frame_ms": snappedf(avg, 0.01),
		"p95_frame_ms": snappedf(_p95_ms(), 0.01),
		"avg_fps": snappedf(1000.0 / maxf(avg, 0.001), 0.1),
		"view_ms_avg": snappedf(_mean(_view_ms), 0.01),
		"view_ms_p95": snappedf(_p95(_view_ms), 0.01),
		"draw_calls_max": _draw_calls_max,
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"static_memory_mb":
		snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1),
		"sim_steps": scenario.sim.step_count,
		"enemies": scenario.sim.enemies.count,
		"projectiles": scenario.sim.projectiles.count,
		"seed": StressScenario.SEED,
		"engine": Engine.get_version_info().get("string", ""),
		"renderer": str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")),
	}


func _finish() -> void:
	_done = true
	var result := build_result()
	var f := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(result, "  "))
	finished.emit(result)


static func _mean(a: PackedFloat32Array) -> float:
	if a.is_empty():
		return 0.0
	var t := 0.0
	for x in a:
		t += x
	return t / a.size()


static func _p95(a: PackedFloat32Array) -> float:
	if a.is_empty():
		return 0.0
	var sorted := a.duplicate()
	sorted.sort()
	return sorted[mini(sorted.size() - 1, int(sorted.size() * 0.95))]


func _avg_ms() -> float:
	if _frames.is_empty():
		return 0.0
	var t := 0.0
	for x in _frames:
		t += x
	return t / _frames.size() * 1000.0


func _p95_ms() -> float:
	if _frames.is_empty():
		return 0.0
	var sorted := _frames.duplicate()
	sorted.sort()
	return sorted[mini(sorted.size() - 1, int(sorted.size() * 0.95))] * 1000.0
