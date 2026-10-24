class_name WalkCycle
extends RefCounted
## Mesafe tabanlı yürüme fazı ve kare seçimi (saf, statik). Faz 0..1 döngüdür; N kare = N temas aralığı.


## faz + dist/stride, 0..1'e sarılır. stride <= 0 ise faz değişmez.
static func advance(phase: float, dist: float, stride: float) -> float:
	if stride <= 0.0:
		return fposmod(phase, 1.0)
	return fposmod(phase + dist / stride, 1.0)


## floor(faz × N) % N; N <= 0 ise 0.
static func frame_at(phase: float, frames: int) -> int:
	if frames <= 0:
		return 0
	return floori(fposmod(phase, 1.0) * frames) % frames


## Durmada hedef kare: en yakın temas karesi (0 ya da frames/2).
static func nearest_contact(phase: float, frames: int) -> int:
	if frames <= 0:
		return 0
	var p := fposmod(phase, 1.0)
	return 0 if (p < 0.25 or p >= 0.75) else floori(frames * 0.5)


## Kare başına ayak kayması = stride / frames (N=6, 136 -> 22,67 px).
static func foot_shift_per_frame(stride: float, frames: int) -> float:
	if frames <= 0:
		return 0.0
	return stride / float(frames)
