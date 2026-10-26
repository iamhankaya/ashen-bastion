class_name SettingsSections
extends RefCounted
## v2.0.3 ayarlar ekranı bölüm kimlikleri ve düğüm ad alanı (D fazı; docs/design/v2.0.3/DESIGN.md). Sıra ekran sırasıdır.

const IDS: Array[StringName] = [&"ses", &"dokunus", &"gorunum", &"hakkinda"]
const NODE_PREFIX := "settings_"


## Bölüm düğümlerinin adı (`settings_<kimlik>`); D'nin düğümleri bu ad alanında kalır.
static func node_name(id: StringName) -> String:
	return NODE_PREFIX + String(id)
