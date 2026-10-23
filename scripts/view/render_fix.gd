class_name RenderFix
extends RefCounted
## F-ashen-bastion-002: MultiMeshInstance2D canvas öğesinin kesme dikdörtgeni her kare değişen AABB'den türer;
## bayat önbellek düşmanları/XP taşlarını bir iki kare görünmez yapabilir. Düzeltme: sabit, dünyayı kaplayan
## özel dikdörtgen. Debug APK'da `enabled` ayarı (Settings.cull_fix) ile açılıp kapanır; cihazda karşılaştırılır.

const HUGE_RECT := Rect2(-1.0e6, -1.0e6, 2.0e6, 2.0e6)

static var enabled: bool = true


## `item` için özel kesme dikdörtgenini `enabled` durumuna göre kurar (kapalıysa motorun AABB'si kullanılır).
static func apply(item: CanvasItem) -> void:
	RenderingServer.canvas_item_set_custom_rect(item.get_canvas_item(), enabled, HUGE_RECT)
