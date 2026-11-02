class_name DateText
extends RefCounted
## Tarih metni (saf): skor ve başarım ekranları ortak kullanır.


## Yerel saat = UTC + tz_bias_min; "GG.AA.YYYY".
static func local_date(unix: int, tz_bias_min: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(unix + tz_bias_min * 60)
	return "%02d.%02d.%04d" % [d["day"], d["month"], d["year"]]
