class_name GroundView
extends Sprite2D
## Döşenen koyu zemin (prosedürel, dikişsiz). Kamerayı döşeme adımıyla izler; bölge görünür alanı + bir döşeme kaplar.

const MARGIN_TILES := 2

var _tile: float = float(PlaceholderArt.GROUND_SIZE)


func _init() -> void:
	texture = PlaceholderArt.ground_texture()
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	region_enabled = true
	centered = true
	z_index = -100
	_tile = texture.get_size().x


## Döşeme hizasına oturtulmuş merkez (saf; dünya kayması bölge ofsetinde değil konumda tutulur).
static func snapped_center(center: Vector2, tile: float) -> Vector2:
	if tile <= 0.0:
		return center
	return Vector2(floorf(center.x / tile) * tile, floorf(center.y / tile) * tile)


## center: kamera merkezi; view_size: görünür alan (dünya birimi).
func follow(center: Vector2, view_size: Vector2) -> void:
	position = snapped_center(center, _tile)
	var w := (ceilf(view_size.x / _tile) + MARGIN_TILES * 2) * _tile
	var h := (ceilf(view_size.y / _tile) + MARGIN_TILES * 2) * _tile
	region_rect = Rect2(0, 0, w, h)
