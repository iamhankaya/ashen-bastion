class_name SimFx
extends RefCounted
## Yalnızca görsel/işitsel efekt bildirimleri (sim kararları buna bağlı değildir). SimBus sözleşmesinden ayrı tutulur:
## SimBus sinyal kümesi sabittir; efekt ihtiyaçları buraya eklenir.

## Keskin nişan çizgisi (hitscan): başlangıç ve bitiş noktası.
signal beam_fired(from: Vector2, to: Vector2)
## Çok mermili beceri salvosu (yelpaze, saçılma, fırtına): kaynak nokta ve mermi sayısı.
signal volley_fired(origin: Vector2, count: int)
