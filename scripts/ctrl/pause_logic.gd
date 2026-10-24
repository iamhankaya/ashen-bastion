class_name PauseLogic
extends RefCounted
## Ekran/duraklatma kararları (saf, statik). GameController yalnız bu kararları uygular.
## Kurallar: LEVEL_UP'ta sim donuk; arka plana alınınca/odak kaybında oyun otomatik duraklar;
## Android geri tuşu: oyunda duraklat, duraklatmada devam, diyalogda vazgeç, sonuçta/listelerde ana menü, menüde çık.

enum Screen { MENU, PLAYING, LEVEL_UP, PAUSED, CONFIRM, RESULT, SCORES, CHARACTERS, ACHIEVEMENTS }
enum Back { NONE, PAUSE, RESUME, CANCEL_CONFIRM, TO_MENU, QUIT }

const MAX_STEPS_PER_FRAME := 3
## Seviye atlama ön vurgusu (sn): LEVEL_UP ekranından önce kısa vurgu.
const LEVEL_UP_PREROLL := 0.18


## Bu bildirim (Node.NOTIFICATION_*) bu ekranda oyunu otomatik duraklatmalı mı?
static func should_auto_pause(what: int, screen: int) -> bool:
	if screen != Screen.PLAYING:
		return false
	return (
		what == Node.NOTIFICATION_APPLICATION_PAUSED
		or what == Node.NOTIFICATION_APPLICATION_FOCUS_OUT
	)


## Geri tuşu (NOTIFICATION_WM_GO_BACK_REQUEST / ui_cancel) bu ekranda ne yapar?
static func back_action(screen: int) -> int:
	match screen:
		Screen.PLAYING:
			return Back.PAUSE
		Screen.PAUSED:
			return Back.RESUME
		Screen.CONFIRM:
			return Back.CANCEL_CONFIRM
		Screen.RESULT, Screen.SCORES, Screen.CHARACTERS, Screen.ACHIEVEMENTS:
			return Back.TO_MENU
		Screen.MENU:
			return Back.QUIT
	return Back.NONE  # LEVEL_UP: kart seçilmeden çıkılmaz


## Sim bu karede adım atar mı? Yalnız oyun ekranında ve sim RUNNING iken (LEVEL_UP'ta donuk).
static func sim_should_step(screen: int, sim_state: int) -> bool:
	return screen == Screen.PLAYING and sim_state == GameSim.State.RUNNING


## Adım sonrası sim durumuna göre gidilecek ekran (değişiklik yoksa aynı ekran).
static func screen_after_step(screen: int, sim_state: int) -> int:
	if screen != Screen.PLAYING:
		return screen
	match sim_state:
		GameSim.State.LEVEL_UP:
			return Screen.LEVEL_UP
		GameSim.State.WON, GameSim.State.LOST:
			return Screen.RESULT
	return screen


## Oyun bitince sonuç ekranından önceki gecikme (sn): ölüm 1,3 / kazanma 1,8.
static func result_delay(won: bool) -> float:
	return Motion.sec(Motion.WIN_TOTAL if won else Motion.DEATH_TOTAL)


## Bir ekrandan oyuna dönüşte 600 ms girdi kilidi gerekir mi? (devam / seviye atlama sonrası)
static func needs_input_lock(from_screen: int, to_screen: int) -> bool:
	return (
		to_screen == Screen.PLAYING
		and (from_screen == Screen.PAUSED or from_screen == Screen.LEVEL_UP)
	)


## Zaman biriktiricisinden bu karede atılacak adım sayısı (en çok max_steps; fazlası yavaş çekim).
static func steps_for(accum: float, step: float, max_steps: int = MAX_STEPS_PER_FRAME) -> int:
	if step <= 0.0 or accum < step:
		return 0
	return mini(int(floorf(accum / step)), max_steps)


## Adımlardan sonra kalan birikim; üst sınıra takılınca fazlası atılır (birikim < step kalır).
static func leftover(accum: float, steps: int, step: float) -> float:
	return clampf(accum - float(steps) * step, 0.0, step * 0.999)
