class_name XpCurve
extends RefCounted
## Tamsayı XP eğrisi. Sabit noktalar: need(1..5)=12,16,20,25,30; need(10)=58; cumulative(10)=276.


## need(n) = 8 + 4*n + (n*n)/10 (tamsayı bölme)
static func need(n: int) -> int:
	Stub.todo(&"XpCurve.need")
	return 0


## Seviye L'ye ulaşmak için toplam XP = Σ need(1..L-1)
static func cumulative(level: int) -> int:
	Stub.todo(&"XpCurve.cumulative")
	return 0
