class_name V21Runs
extends RefCounted
## v2.1 koşu köprüsü: controller'ın ayardan bağımsız yardımcıları (kazanma/müzik kararı, başarım kuralı). Seçim ve profiller
## `RunSelection`'dadır (Settings enjekte edilir); controller örneği ekranlarla paylaşır.


## Kazanma: Lord/Zamanlayıcı'da sim WON; Sonsuz'da ilk Lord ölümü (`milestone_won`, sim LOST kalır).
static func run_won(sim: GameSim) -> bool:
	return sim != null and (sim.state == GameSim.State.WON or sim.milestone_won)


# --- U3 (kayıt/başarım) ----------------------------------------------------------------------


## Zorluğa bağlı başarım kuralı (run_profiles.json "achievements"); profil dosyası hatalıysa kısıtsız.
static func achievement_rules() -> AchievementRules:
	return AchievementRules.new(RunSelection.load_profiles())


## Sim'in koşu zorluğu; profilsiz sim = Zor (sonuç sözlüğüyle aynı varsayılan).
static func diff_of(sim: GameSim) -> StringName:
	return sim.run_profile.diff if sim != null and sim.run_profile != null else &"hard"


# --- U4b (skor/sonuç/bant) ----------------------------------------------------------------------


## Müzik kararı: koşu sürerken (Sonsuz kilometre taşından sonra da) savaş müziği devam eder; bitince kilometre taşı
## kazanıldıysa kazanma müziği çalar (sonuç ekranı "KAZANDIN" gösterir), aksi halde kayıp müziği.
static func music_won(sim: GameSim) -> bool:
	return (
		sim != null
		and (
			sim.state == GameSim.State.WON
			or (sim.state == GameSim.State.LOST and sim.milestone_won)
		)
	)


static func music_lost(sim: GameSim) -> bool:
	return sim != null and sim.state == GameSim.State.LOST and not sim.milestone_won
