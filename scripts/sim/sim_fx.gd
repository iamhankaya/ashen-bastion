class_name SimFx
extends RefCounted
## Yalnızca görsel/işitsel efekt bildirimleri (sim kararları buna bağlı değildir). SimBus sözleşmesinden ayrı tutulur:
## SimBus sinyal kümesi sabittir; efekt ihtiyaçları buraya eklenir.

## Keskin nişan çizgisi (hitscan): başlangıç ve bitiş noktası.
signal beam_fired(from: Vector2, to: Vector2)
## Çok mermili beceri salvosu (yelpaze, saçılma, fırtına): kaynak nokta ve mermi sayısı.
signal volley_fired(origin: Vector2, count: int)
## v2.0.2 rüzgar: anlık dalga (Nefes Dalgası, Kasırga Patlaması: big) ve avuçtaki savuruş efekti.
signal wind_wave(origin: Vector2, radius: float, big: bool)
signal wind_cast(origin: Vector2)
## ZonePool dolu/rezerv yüzünden bölge doğurulamadı (sessiz değil: sayaç artar, test okur).
var zone_dropped: int = 0
