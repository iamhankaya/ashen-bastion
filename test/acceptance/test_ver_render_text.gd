extends GutTest
## Doğrulama (T20261023-64): F-ashen-bastion-002 kesme düzeltmesi bağlantıları, yalnız-debug etiketi, menü/kazanma
## metinleri, depo hijyeni (sır yok). Gerçek kesme davranışı (bayat AABB) cihaz GPU'sunda doğrulanır; burada yalnız
## düzeltmenin üç renderer'da kurulduğu, açılıp kapandığı ve etiketin yalnız debug derlemede çalıştığı sınanır.

const RENDERERS := [
	"res://scripts/view/enemy_renderer.gd",
	"res://scripts/view/gem_renderer.gd",
	"res://scripts/view/projectile_renderer.gd",
]
const FORBIDDEN_EXT: Array[String] = ["jks", "p12", "pfx", "pem", "keystore", "env"]
## Standart (herkese açık) Android debug anahtarı; release anahtarı yalnız GitHub secret'ta.
const ALLOWED_KEYSTORE := "res://tools/ci/debug.keystore"

var _saved_cull: bool = true
var _saved_store_path: String = ""
const TMP_SETTINGS := "user://test_render_text_settings.cfg"


func before_each() -> void:
	_saved_cull = RenderFix.enabled
	# v2.0 izolasyon: gerçek user://settings.cfg'ye yazılmaz (S3 Settings.store_path enjeksiyonu)
	_saved_store_path = get_node("/root/Settings").store_path
	get_node("/root/Settings").store_path = TMP_SETTINGS


func after_each() -> void:
	RenderFix.enabled = _saved_cull
	var s := get_node("/root/Settings")
	s.cull_fix = _saved_cull
	s.save_settings()
	s.store_path = _saved_store_path
	for p in [TMP_SETTINGS, TMP_SETTINGS + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func _src(path: String) -> String:
	return FileAccess.get_file_as_string(path)


## Bir fonksiyonun gövde metni (sonraki üst düzey `func`a kadar).
func _body(src: String, signature: String) -> String:
	var i := src.find(signature)
	if i < 0:
		return ""
	var j := src.find("\nfunc ", i + signature.length())
	return src.substr(i, (j if j >= 0 else src.length()) - i)


func test_all_three_multimesh_renderers_install_the_cull_fix_at_construction() -> void:
	for path in RENDERERS:
		var src := _src(path)
		assert_true(src.contains("func apply_cull_fix()"), "%s: apply_cull_fix tanımlı" % path)
		assert_true(
			_body(src, "func _init()").contains("apply_cull_fix()"),
			"%s: _init içinde kuruluyor (ilk kareden önce)" % path
		)
		assert_true(
			_body(src, "func apply_cull_fix()").contains("RenderFix.apply(self)"),
			"%s: RenderFix.apply(self)" % path
		)


func test_render_fix_uses_a_fixed_world_covering_rect() -> void:
	assert_true(_src("res://scripts/view/render_fix.gd").contains("canvas_item_set_custom_rect"))
	var r := RenderFix.HUGE_RECT
	# oyun dünyası ±1e5 px'in çok altında kalır; sabit dikdörtgen tüm koşuyu kapsar
	assert_true(r.has_point(Vector2(0, 0)))
	assert_true(r.has_point(Vector2(250000, -250000)))
	assert_true(r.has_point(Vector2(-250000, 250000)))


func test_controller_toggle_flips_the_fix_for_all_three_renderers_and_persists() -> void:
	var c := GameController.new()
	c.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(c)
	c.start_run()
	RenderFix.enabled = true
	get_node("/root/Settings").cull_fix = true
	assert_true(c.render_debug_text().contains("kesme düzeltmesi: AÇIK (dokun)"))
	c.toggle_cull_fix()
	assert_false(RenderFix.enabled)
	assert_false(get_node("/root/Settings").cull_fix, "ayar saklanır")
	assert_true(c.render_debug_text().contains("kesme düzeltmesi: KAPALI (dokun)"))
	c.toggle_cull_fix()
	assert_true(RenderFix.enabled)
	assert_true(c.render_debug_text().contains("AÇIK"))


func test_debug_label_shows_visible_vs_live_counts_in_a_debug_build() -> void:
	assert_true(OS.is_debug_build(), "test koşusu debug derleme")
	var c := GameController.new()
	c.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(c)
	assert_not_null(c._render_label, "debug derlemede etiket kurulur")
	assert_false(c._render_label.visible, "menüde gizli")
	c.start_run()
	assert_true(c._render_label.visible, "oyunda görünür")
	c.sim.debug_fill(&"curumus_piyade", 120, 400.0)
	for i in 90:
		c.sim.step(Vector2(0.2, 0.0))
	c._update_views(0.016)
	var text := c._render_label.text
	assert_true(text.contains("düşman %d/%d" % [c.sim.enemies.count, c.sim.enemies.count]), text)
	assert_true(text.contains("taş %d/%d" % [c.sim.gems.count, c.sim.gems.count]), text)
	assert_eq(c.enemy_renderer.visible_count(), c.sim.enemies.count, "görünür = canlı")
	c.pause_game()
	assert_true(c._render_label.visible, "duraklatmada da görünür (dokunup açıp kapatılır)")
	c.go_menu()
	assert_false(c._render_label.visible)


func test_debug_only_features_are_gated_in_code_for_release_builds() -> void:
	var gc := _src("res://scripts/ctrl/game_controller.gd")
	var body := _body(gc, "func _build_render_debug()")
	var first := (
		body.get_slice("\n", 1).strip_edges() + "\n" + body.get_slice("\n", 2).strip_edges()
	)
	assert_eq(first, "if not OS.is_debug_build():\nreturn", "release derlemede etiket kurulmaz")
	assert_true(
		_body(_src("res://scripts/debug/stress_run.gd"), "static func available()").contains(
			"OS.is_debug_build()"
		),
		"stres koşusu yalnız debug"
	)
	assert_true(
		(
			_body(_src("res://scripts/ui/main_menu.gd"), "func _gui_input").contains(
				"OS.is_debug_build()"
			)
			or _src("res://scripts/ui/main_menu.gd").contains("and OS.is_debug_build()")
		),
		"sürüm etiketi 3 dokunuş yalnız debug"
	)
	# _render_label yalnız etiket kuruluysa kullanılır (release'te null güvenli)
	assert_true(gc.contains("if _render_label != null"))


func test_no_old_menu_tag_anywhere_in_game_code_and_new_tag_present() -> void:
	for path in ["res://scripts/ui/main_menu.gd", "res://scripts/ctrl/game_controller.gd"]:
		assert_false(_src(path).contains("KÜL VE ÇELİK"), path)
	assert_true(_src("res://scripts/ui/main_menu.gd").contains('"ASH AND STEEL"'))
	assert_eq(GameController.WON_SUB, "Şafak söktü; kale seni yutamadı.")
	assert_eq(ResultScreen.LOST_SUB, "Kale seni yuttu.")


func _walk(dir: String, out: PackedStringArray) -> void:
	for f in DirAccess.get_files_at(dir):
		out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		if d in [".git", ".godot", ".gate", "gut_temp_directory"]:
			continue
		_walk(dir.path_join(d), out)


func test_repo_contains_no_signing_keys_or_env_files_other_than_the_debug_keystore() -> void:
	var files := PackedStringArray()
	_walk("res://", files)
	assert_gt(files.size(), 200, "depo gezildi")
	for f in files:
		if f == ALLOWED_KEYSTORE:
			continue
		assert_false(
			f.get_extension().to_lower() in FORBIDDEN_EXT,
			"imza/sır dosyası commit'lenmemeli: %s" % f
		)
	assert_true(FileAccess.file_exists(ALLOWED_KEYSTORE))
	var preset := _src("res://export_presets.cfg")
	assert_true(preset.contains('keystore/release_password=""'), "release parolası ön ayarda yok")
	assert_true(preset.contains('keystore/release=""'), "release anahtar yolu ön ayarda yok")
