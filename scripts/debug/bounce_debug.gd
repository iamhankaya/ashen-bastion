class_name BounceDebug
extends RefCounted
## v1.1.1 (yalnız debug derleme): yürüme sekmesi kademesi etiketi; dokunmak ESKİ v1.1 → YUMUŞAK → SAKİN arasında döndürür
## (değerler PlayerAnim.BOUNCE_TIERS; cihazda karşılaştırılır). Oturum boyunca geçerli, kalıcı değil. Etiket
## DebugLabels üst satırının sağ ucundadır; koşu/duraklatmada görünür.


## Etiketi yoksa kurar (release derlemede kurulmaz); `on_input` dokunuş işleyicisi (ctrl).
static func ensure(label: Label, parent: Node, on_input: Callable) -> Label:
	if label != null or not OS.is_debug_build():
		return label
	return DebugLabels.build_bounce(parent, on_input)


static func text() -> String:
	var n: int = PlayerAnim.BOUNCE_TIERS.size()
	var i := clampi(PlayerAnim.bounce_tier, 0, n - 1)
	return "%s %d/%d" % [PlayerAnim.BOUNCE_TIERS[i]["name"], i + 1, n]


static func cycle() -> void:
	PlayerAnim.bounce_tier = (PlayerAnim.bounce_tier + 1) % PlayerAnim.BOUNCE_TIERS.size()


static func sync(label: Label, shown: bool) -> void:
	if label == null:
		return
	label.visible = shown
	if shown:
		label.text = text()
		fit_font(label)


## Uzun kademe adı ("ESKİ v1.1 1/3") 166 px'e sığmazsa yazıyı küçültür (kırpılmasın); alt sınır 16.
static func fit_font(label: Label) -> void:
	var f := label.get_theme_default_font()
	var base := DebugLabels.FONT_SIZE
	var w := f.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, base).x
	var avail := label.size.x - 8.0
	var fs := base if w <= avail else maxi(16, int(floor(base * avail / w)))
	label.add_theme_font_size_override(&"font_size", fs)


## Dokunuş (fare/dokunmatik basma) → kademeyi döndürür.
static func on_input(event: InputEvent) -> void:
	if (
		(event is InputEventMouseButton and event.pressed)
		or (event is InputEventScreenTouch and event.pressed)
	):
		cycle()
