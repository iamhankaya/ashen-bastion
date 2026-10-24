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


## Dokunuş (fare/dokunmatik basma) → kademeyi döndürür.
static func on_input(event: InputEvent) -> void:
	if (
		(event is InputEventMouseButton and event.pressed)
		or (event is InputEventScreenTouch and event.pressed)
	):
		cycle()
