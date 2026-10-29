extends GutTest
## Karakterizasyon (plan Faz 4 madde 13): bölünecek 6 sınıfın public API yüzeyi (metot imzaları, sinyaller, alanlar).
## İmza koruması DAVRANIŞ KANITI DEĞİLDİR; davranış kanıtı olay günlüğü + hash + sahne ağacı + sinyal üçlüsüdür.
## Baz: rf_api_surface.json. Özel (_ ile başlayan) üyeler dahil değil.

const CLASSES := {
	"game_controller": "res://scripts/ctrl/game_controller.gd",
	"game_sim": "res://scripts/sim/game_sim.gd",
	"game_data": "res://scripts/sim/game_data.gd",
	"result_screen": "res://scripts/ui/result_screen.gd",
	"characters_screen": "res://scripts/ui/characters_screen.gd",
	"achievement_tracker": "res://scripts/ctrl/achievement_tracker.gd",
}


func _surface(path: String) -> Dictionary:
	var scr: Script = load(path)
	var methods := []
	for m in scr.get_script_method_list():
		if not String(m["name"]).begins_with("_"):
			var args := []
			for a in m["args"]:
				args.append(str(a["name"]))
			methods.append("%s(%s)" % [m["name"], ",".join(args)])
	methods.sort()
	var signals := []
	for s in scr.get_script_signal_list():
		var args := []
		for a in s["args"]:
			args.append(str(a["name"]))
		signals.append("%s(%s)" % [s["name"], ",".join(args)])
	signals.sort()
	var props := []
	for p in scr.get_script_property_list():
		if (
			int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE
			and not String(p["name"]).begins_with("_")
		):
			props.append(str(p["name"]))
	props.sort()
	var consts := []
	for k in scr.get_script_constant_map():
		if not String(k).begins_with("_"):
			consts.append(str(k))
	consts.sort()
	return {"methods": methods, "signals": signals, "props": props, "consts": consts}


func test_rf_public_api_surface() -> void:
	var out := {}
	for k in CLASSES:
		out[k] = _surface(CLASSES[k])
		assert_gt(out[k]["methods"].size(), 0, "%s: metot listesi boş değil" % k)
	RfBaseline.check(self, "rf_api_surface", out)
