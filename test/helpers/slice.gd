class_name Slice
extends RefCounted
## tools/slice.txt okuyucusu. Uygulama-2 içeriğine ait kabul testleri `Slice.current() < 2` iken pending döner.

const PATH := "res://tools/slice.txt"


static func current() -> int:
	return int(FileAccess.get_file_as_string(PATH).strip_edges())


static func is_content_complete() -> bool:
	return current() >= 2
