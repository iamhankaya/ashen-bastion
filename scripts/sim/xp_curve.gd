class_name XpCurve
extends RefCounted
## Tamsayı XP eğrisi. Sabit noktalar: need(1..5)=12,16,20,25,30; need(10)=58; cumulative(10)=276.


## need(n) = 8 + 4*n + (n*n)/10 (tamsayı bölme)
static func need(n: int) -> int:
	return 8 + 4 * n + (n * n) / 10


## Seviye L'ye ulaşmak için toplam XP = Σ need(1..L-1)
static func cumulative(level: int) -> int:
	var t := 0
	for n in range(1, level):
		t += need(n)
	return t
