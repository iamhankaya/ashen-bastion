class_name Atmosphere
extends ColorRect
## Sis + vinyet + oyuncu ışığı (ekran uzayı, UI'nin altında). Yalnız görsel; kamera konumu shader'a verilir.

const SHADER_PATH := "res://assets/shaders/atmosphere.gdshader"


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	color = Color.WHITE
	if ResourceLoader.exists(SHADER_PATH):
		var mat := ShaderMaterial.new()
		mat.shader = load(SHADER_PATH)
		material = mat


## Kamera merkezini ve görünür alanı güncelle.
func follow(cam_pos: Vector2, view_size: Vector2) -> void:
	if material is ShaderMaterial:
		(material as ShaderMaterial).set_shader_parameter("cam_pos", cam_pos)
		(material as ShaderMaterial).set_shader_parameter("view_size", view_size)
