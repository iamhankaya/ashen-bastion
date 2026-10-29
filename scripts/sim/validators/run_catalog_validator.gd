class_name RunCatalogValidator
extends DataValidator
## Mod kataloğu doğrulayıcısı (R7): `<kök>/run_modes/` ve `difficulties/` varsa katalog + run_profiles.json birleşimini
## RunProfiles ile denetler (açık adlar; alan aralıkları, varsayılanlar, zorluk başına başarım kuralı). Dizin yoksa (eski
## fixture kökleri) sessiz geçer. Hata satırları RunCatalog "RUN_CATALOG: <id>: <neden>" ve RunProfiles "[kod] bağlam: ..." biçimindedir.


func validator_order() -> int:
	return 1100


func validator_id() -> StringName:
	return &"run_catalog"


func run(g: GameData, out: PackedStringArray, _complete: bool) -> void:
	if (
		g.root_dir == ""
		or not DirAccess.dir_exists_absolute(g.root_dir.path_join(RunCatalog.MODES_DIR))
	):
		return
	out.append_array(PackedStringArray(RunProfiles.load_dir(g.root_dir)["errors"]))
