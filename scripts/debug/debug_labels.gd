class_name DebugLabels
extends RefCounted
## Debug etiketleri (yalnız debug derleme; S-04/M6): ekranın üst kenarında tek satır (y 6–40; 24 px: 26 px'te satır
## yüksekliği 36 olup 34 px'lik banda sığmıyor). Etiketin kendisi
## dokunmayı yutmaz (`mouse_filter = IGNORE`); bayrak çevirme dokunuşu yalnız oyun sırasında (duraklatma/sonuçta değil)
## yanındaki küçük "dokun" alanındadır. Hiçbir düğme/ok dikdörtgeniyle kesişmez (HUD üst bandı y<84 boş).
## Etiket metni iki satırdır: 1. satır sayaç (etikette görünür), 2. satır "<ad>: AÇIK|KAPALI (dokun)" (dokunma alanında).

const Y := 6.0
const H := 34.0
const FONT_SIZE := 24
const RENDER_X := 36.0
const RENDER_W := 280.0
const RENDER_TAP_X := 320.0
const ESCAPE_X := 456.0
const ESCAPE_W := 280.0
const ESCAPE_TAP_X := 742.0
const TAP_W := 130.0
const TAP_GROUP := &"debug_tap"
const BOUNCE_X := 878.0
const BOUNCE_W := 166.0


static func build_render(parent: Node, on_input: Callable) -> Label:
	return _build(parent, &"RenderDebug", [RENDER_X, RENDER_W, RENDER_TAP_X], on_input)


static func build_escape(parent: Node, on_input: Callable) -> Label:
	return _build(parent, &"EscapeDebug", [ESCAPE_X, ESCAPE_W, ESCAPE_TAP_X], on_input)


## Sekme kademesi etiketi (v1.1.1): üst satırın sağ ucu; etiket dokunmayı yutmaz, üstündeki saydam çocuk
## Control dokunma alanıdır (TAP_GROUP dışında; yalnız etiket görünürken görünür).
static func build_bounce(parent: Node, on_input: Callable) -> Label:
	var label := Label.new()
	label.name = &"BounceDebug"
	label.position = Vector2(BOUNCE_X, Y)
	label.size = Vector2(BOUNCE_W, H)
	label.max_lines_visible = 1
	label.clip_text = true
	_style(label)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.visible = false
	var tap := Control.new()
	tap.name = &"BounceTap"
	tap.size = label.size
	tap.mouse_filter = Control.MOUSE_FILTER_STOP
	tap.gui_input.connect(on_input)
	label.add_child(tap)
	parent.add_child(label)
	return label


static func _build(parent: Node, label_name: StringName, xs: Array, on_input: Callable) -> Label:
	var label := Label.new()
	label.name = label_name
	label.position = Vector2(xs[0], Y)
	label.size = Vector2(xs[1], H)
	label.max_lines_visible = 1
	label.clip_text = true
	_style(label)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.visible = false
	parent.add_child(label)
	var tap := Label.new()
	tap.name = StringName(str(label_name) + "Tap")
	tap.position = Vector2(xs[2], Y)
	tap.size = Vector2(TAP_W, H)
	tap.clip_text = true
	_style(tap)
	tap.mouse_filter = Control.MOUSE_FILTER_STOP
	tap.gui_input.connect(on_input)
	tap.visible = false
	tap.add_to_group(TAP_GROUP)
	tap.set_meta(&"source", label)
	parent.add_child(tap)
	return label


static func _style(l: Label) -> void:
	l.add_theme_font_size_override(&"font_size", FONT_SIZE)
	l.add_theme_color_override(&"font_color", Color(1, 1, 1, 0.75))
	l.add_theme_color_override(&"font_outline_color", Color.BLACK)
	l.add_theme_constant_override(&"outline_size", 6)


## Dokunma alanlarının yazısı: kaynak etiketin 2. satırındaki durum ("AÇIK"/"KAPALI").
static func tap_text(source_text: String) -> String:
	if not source_text.contains("\n"):
		return "dokun"
	var line := source_text.get_slice("\n", 1)
	var state := line.get_slice(": ", 1).replace(" (dokun)", "").strip_edges()
	return "dokun: %s" % state if state != "" else "dokun"


## Dokunma alanları: yalnız `active` (oyun sırasında) ve kaynak etiket görünürken görünür; yazıyı eşler.
static func sync_taps(root: Node, active: bool) -> void:
	if root == null or not root.is_inside_tree():
		return
	for tap: Node in root.get_tree().get_nodes_in_group(TAP_GROUP):
		if not root.is_ancestor_of(tap):
			continue
		var src: Label = tap.get_meta(&"source", null)
		var shown := active and src != null and is_instance_valid(src) and src.visible
		(tap as Label).visible = shown
		if shown:
			(tap as Label).text = tap_text(src.text)
