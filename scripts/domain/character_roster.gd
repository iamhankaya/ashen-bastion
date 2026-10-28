class_name CharacterRoster
extends RefCounted
## Karakter listesi mantığı (saf, statik; Node bilmez): sıra, varsayılan, çözümleme, kilit nedeni, komşu.
## Sıra `GameData.character_ids` (dosya adı sırası) — varsayılan seçim sıradan bağımsızdır (DEFAULT_ID).
## S2: bu sınıfın saf yardımcıları sözleşmede GERÇEKTİR (V2Flow.selected_character() ilk koşudan itibaren kullanır; v1
## davranışı `gunslinger` ile korunur). ilerleme görünümü yalnız `unlock`lu karakterde sorulur (B1 gövdesi).

const DEFAULT_ID := &"gunslinger"


static func ids(data: GameData) -> Array[StringName]:
	return data.character_ids


## `unlock` yok => true; ilerleme null ya da corrupt (ve unlock var) => false (güvenli yön).
## `progress`: AchievementProgressView ya da AchievementStore (görünüme indirilir) ya da null.
static func is_unlocked(c: CharacterDef, progress: Variant) -> bool:
	if c.unlock_achievement == &"":
		return true
	return AchievementProgressView.of(progress).is_unlocked(c.unlock_achievement)


## saved geçerli ve kilitsizse o; değilse DEFAULT_ID (geçerli + kilitsiz); değilse ilk kilitsiz; hiçbiri yoksa &"".
static func resolve(saved: String, data: GameData, progress: Variant) -> StringName:
	if saved != "":
		var c := data.get_character(StringName(saved))
		if c != null and is_unlocked(c, progress):
			return c.id
	var d := data.get_character(DEFAULT_ID)
	if d != null and is_unlocked(d, progress):
		return DEFAULT_ID
	for id in ids(data):
		if is_unlocked(data.get_character(id), progress):
			return id
	return &""


## "<başarım adı> başarımını aç" (başarım tanımı yoksa kimlik kullanılır).
static func lock_reason(c: CharacterDef, data: GameData) -> String:
	var a := data.get_achievement(c.unlock_achievement)
	var label := a.display_name if a != null else String(c.unlock_achievement)
	return "%s başarımını aç" % label


## dir ±1; sarmaz (uçta aynı kalır). current listede yoksa ilk eleman; liste boşsa current.
static func step(list: Array[StringName], current: StringName, dir: int) -> StringName:
	if list.is_empty():
		return current
	var i := list.find(current)
	if i < 0:
		return list[0]
	return list[clampi(i + signi(dir), 0, list.size() - 1)]
