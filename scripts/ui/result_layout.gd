class_name ResultLayout
extends RefCounted
## Sonuç ekranı yerleşimi (R5b): tüm bloklar mutlak konumlu, güvenli alan kayması, kademe (TIERS) seçimi, yazı boyutları, büyük
## yazıda kaydırma + (R5b, ayrı commit) eski `ResultFit` yardımcıları (kademe tablosu, not sığdırma, TalkBack sıra sözcüğü, çip sarma,
## kaydırma kabı). Gövdeler `result_screen.gd`/`result_fit.gd`den AYNEN taşındı. `host` ResultScreen'dir ama tipi BİLİNMEZ (class_name döngüsü
## yok; WorldBuilder ile aynı kural): alanlara dinamik erişilir. Durum tutmaz.

const W := 936.0
const SIDE_MIN := 72.0
const Y_TITLE := 170.0
const Y_SUB := 292.0  # v2.1 denetim #10 (DESIGN §11/7): çipler y352'de kalır
## v2.1: koşu çipleri y352'de (48 yüksek); altındaki tüm bloklar +44 kaydı (DESIGN v2.1 §5).
const Y_CHIPS := 352.0
const CHIP_ROW_H := 48.0
const Y_DIV := 424.0
const Y_HERO := 448.0
const Y_HERO_VALUE := 484.0
const Y_RECORD := 634.0
const BAND_H := 96.0
const RECORD_BLOCK_H := 150.0
const Y_BREAKDOWN := 804.0
const ROW_H := 84.0
const BREAKDOWN_PAD := 12.0
const Y_STRIP := 1272.0
const STRIP_H := 170.0
const Y_COMBOS := 1466.0
const GAP := 24.0
const BUTTONS_MIN_Y := 1500.0
const REPLAY_H := 156.0
const MENU_H := 132.0
const BUTTON_GAP := 27.0
## v2.0 (B4) yeni başarım özet çipi: şerit ile kombolar arasında 936×96.
const CHIP_H := 96.0
## v2.1 Kolay notu: şerit ile kombolar arası 96 yüksek satır, amber 6 px sol çizgi.
const NOTE_H := 96.0
const DETAIL_FONT := 26
## Güvenli alan dışında bırakılan alt/üst taban (UiKit varsayılanları).
const TOP_DEFAULT := 96.0
const BOTTOM_DEFAULT := 72.0
const DESIGN_H := 2400.0
## v2.1 U6 (denetim #5): kombo bloğu sığmazsa satır AZALTILMAZ; `TIERS` kademeleri sırayla devreye girer, ilk sığan
## seçilir. (#2) font_scale > 1,3: çip satırı sarar (+56).
const BIG_SCALE := 1.3
const CHIP_WRAP := 56.0
const NOTE_EXTRA := 12.0

## Kombo bloğu sığmazsa satır AZALTILMAZ; bu kademeler sırayla devreye girer, ilk sığan seçilir (hiçbiri sığmazsa sonuncu).
## 0 = tasarım ölçüleri. Sütunlar (T_* dizinleri): gb = not/çip/panel arası boşluk, gbtn = panel→düğme boşluğu,
## bgap = düğmeler arası, rh/mh = Tekrar/Menü yüksekliği, row/more = kombo satırı / "+N" satırı,
## margin/sep = kombo paneli üst-alt kenar boşluğu / başlık altı aralık, note = Kolay notu yüksekliği.
const T_GB := 0
const T_GBTN := 1
const T_BGAP := 2
const T_RH := 3
const T_MH := 4
const T_ROW := 5
const T_MORE := 6
const T_MARGIN := 7
const T_SEP := 8
const T_NOTE := 9
const T_CHIP := 10
const TIERS := [
	[24.0, 24.0, 27.0, 156.0, 132.0, 96.0, 56.0, 27.0, 16.0, 96.0, 96.0],
	[16.0, 24.0, 20.0, 156.0, 132.0, 96.0, 56.0, 22.0, 10.0, 96.0, 96.0],
	[16.0, 24.0, 20.0, 132.0, 112.0, 96.0, 56.0, 22.0, 10.0, 96.0, 96.0],
	[12.0, 12.0, 16.0, 132.0, 112.0, 88.0, 48.0, 20.0, 8.0, 80.0, 96.0],
	[12.0, 8.0, 12.0, 132.0, 112.0, 88.0, 48.0, 16.0, 8.0, 80.0, 88.0],
	[8.0, 8.0, 8.0, 132.0, 112.0, 84.0, 40.0, 12.0, 6.0, 80.0, 80.0],
]
const NOTE_FONT := 30
const NOTE_FONT_MIN := 26
const ORDINALS := "birinci ikinci üçüncü dördüncü beşinci altıncı yedinci sekizinci dokuzuncu onuncu"


## Yerleşim: tüm bloklar mutlak konumlu (Y_* sabitleri). Güvenli alan üst payı kadar aşağı kayar.
static func layout(host) -> void:
	if host.title_label == null:
		return
	host._x0 = maxf(SIDE_MIN, UiKit.SAFE_EDGE + host._extra.x)
	var x1 := 1080.0 - maxf(SIDE_MIN, UiKit.SAFE_EDGE + host._extra.z)
	host._w = minf(W, x1 - host._x0)
	host._x0 = (1080.0 - host._w) * 0.5 if host._w >= W else host._x0
	host._dy = maxf(0.0, host._extra.y - (Y_TITLE - TOP_DEFAULT))
	host._bdy = CHIP_WRAP if host._big else 0.0
	put_top(host, host.title_label, 0.0, Y_TITLE, 1080.0, 130.0)
	host.title_label.position.x = 0.0
	put_top(host, host.sub_label, 0.0, Y_SUB, 1080.0, 50.0)
	host.sub_label.position.x = 0.0
	put_top(host, host.chip_holder, host._x0, Y_CHIPS, host._w, chip_h(host))
	if host._run_chips != null:
		host._run_chips.size = Vector2(host._w, chip_h(host))
	put(host, host.divider, host._x0, Y_DIV, host._w, 20.0)
	put(host, host.score_caption, 0.0, Y_HERO, 1080.0, 44.0)
	put(host, host.score_value, 0.0, Y_HERO_VALUE, 1080.0, 130.0)
	put(host, host.record_band, host._x0, Y_RECORD, host._w, BAND_H)
	host.record_band.pivot_offset = Vector2(host._w * 0.5, BAND_H * 0.5)
	host.record_band.queue_redraw()
	host.record_label.position = Vector2(0, 0)
	host.record_label.size = host.record_band.size
	for i in host.record_stars.size():
		var sx: float = 70.0 if i == 0 else host._w - 70.0 - 48.0
		host.record_stars[i].position = Vector2(sx, (BAND_H - 48.0) * 0.5)
		host.record_stars[i].size = Vector2(48.0, 48.0)
	put(host, host.record_pill, host._x0 + 40.0, Y_RECORD + 20.0, host._w - 80.0, 76.0)
	host.record_pill.pivot_offset = Vector2((host._w - 80.0) * 0.5, 38.0)
	var note_y := (
		Y_RECORD + BAND_H + 8.0 if host.record_kind in [&"record", &"top10"] else Y_RECORD + 54.0
	)
	var note_extra := NOTE_EXTRA if host._big else 0.0
	var note_h := fit_note(
		host.record_note, host._w - 16.0, host._big, Y_BREAKDOWN + note_extra - note_y
	)
	put(host, host.record_note, host._x0, note_y, host._w, note_h)
	host._bdy += note_extra  # büyük yazıda sıra notu 2 satıra sarabilir: döküm ve altı 12 px daha kayar
	var bh := ROW_H * float(host.breakdown_rows.size()) + 2.0 * BREAKDOWN_PAD
	put(host, host.breakdown_panel, host._x0, Y_BREAKDOWN, host._w, bh)
	for i in host.breakdown_rows.size():
		var row: Control = host.breakdown_rows[i]
		put(
			host,
			row,
			host._x0 + 36.0,
			Y_BREAKDOWN + BREAKDOWN_PAD + float(i) * ROW_H,
			host._w - 72.0,
			ROW_H
		)
		var rw: float = host._w - 72.0
		var det := row.get_node("Detail") as Label
		var val := row.get_node("Value") as Label
		# büyük yazıda değer 300 px, ayrıntı onun solunda 260 px (Ad 72..~362 ile çakışmaz)
		var val_w := 300.0 if host._big else 260.0
		var det_w := 260.0 if host._big else 230.0
		det.position = Vector2(rw - val_w - (20.0 if host._big else 10.0) - det_w, 0)
		det.size = Vector2(det_w, ROW_H)
		val.position = Vector2(rw - val_w, 0)
		val.size = Vector2(val_w, ROW_H)
	put(host, host.strip_panel, host._x0, Y_STRIP, host._w, STRIP_H)
	var cw: float = host._w / 3.0
	for i in host._strip_nodes.size():
		var col: Control = host._strip_nodes[i]
		put(host, col, host._x0 + cw * i, Y_STRIP, cw, STRIP_H)
		(col.get_node("Icon") as Control).position = Vector2(cw * 0.5 - 22.0, 18.0)
		(col.get_node("Icon") as Control).size = Vector2(44, 44)
		(col.get_node("Value") as Control).position = Vector2(0, 58.0 if host._big else 62.0)
		(col.get_node("Value") as Control).size = Vector2(cw, 70.0 if host._big else 64.0)
		(col.get_node("Caption") as Control).position = Vector2(0, 130.0 if host._big else 126.0)
		(col.get_node("Caption") as Control).size = Vector2(cw, 36.0 if host._big else 34.0)
	# Kombo bloğu ve düğmeler: satır sayısı sabit; ilk sığan kademe (TIERS) seçilir (denetim #5).
	var limit: float = DESIGN_H - BOTTOM_DEFAULT - host._extra.w
	var tail_bottom := 0.0
	for ti in TIERS.size():
		set_tier(host, ti)
		tail_bottom = layout_tail(host)
		if tail_bottom <= limit + 0.01:
			break
	# sığmayan durum (yalnız büyük yazıda ya da aritmetiği imkânsız en kötü durumlarda): içerik kayar
	set_scroll(
		host,
		(
			tail_bottom + BOTTOM_DEFAULT + host._extra.w - DESIGN_H
			if host._big and tail_bottom > limit
			else 0.0
		)
	)


## Kademe: kombo satırı/"+N"/panel boşlukları yeniden kurulur (değiştiyse), Kolay notu yüksekliği.
static func set_tier(host, ti: int) -> void:
	var t: Array = TIERS[ti]
	host._panel_sb.content_margin_top = float(t[T_MARGIN])
	host._panel_sb.content_margin_bottom = float(t[T_MARGIN])
	host.combo_cv.add_theme_constant_override(&"separation", int(t[T_SEP]))
	if ti != host._tier:
		host._tier = ti
		if host.combo_box != null:
			host._render_combos()


## Kombo paneli + not/çip + düğmeler (geçerli kademede); düğme bloğunun alt kenarını döndürür.
static func layout_tail(host) -> float:
	var t: Array = TIERS[host._tier]
	var gb := float(t[T_GB])
	var note_h := float(t[T_NOTE])
	var combos_y := Y_COMBOS
	if host.easy_note.visible:
		put(host, host.easy_note, host._x0, combos_y, host._w, note_h)
		var bar := host.easy_note.get_child(0) as Control
		bar.size = Vector2(6.0, note_h)
		(host.easy_note.get_child(1) as Control).position.y = (note_h - 40.0) * 0.5
		size_note_text(host.easy_note.get_node("Text") as Label, host._w, note_h)
		combos_y += note_h + gb
	host._chip_y = combos_y
	if not host._new_names.is_empty():
		var chip_h := float(t[T_CHIP])
		put(host, host.achievement_chip, host._x0, combos_y, host._w, chip_h)
		place_chip_parts(host.chip_star, host.chip_title, host.chip_names, host._w, chip_h)
		combos_y += chip_h + gb
	host.combo_panel.custom_minimum_size = Vector2(host._w, 0)
	host.combo_panel.size = Vector2(host._w, 0)
	host.combo_panel.position = Vector2(host._x0, combos_y + host._dy + host._bdy)
	host.combo_panel.size = Vector2(host._w, host.combo_panel.get_combined_minimum_size().y)
	var by := maxf(
		host.combo_panel.position.y + host.combo_panel.size.y + float(t[T_GBTN]), BUTTONS_MIN_Y
	)
	var rh := float(t[T_RH])
	var mh := float(t[T_MH])
	host.replay_button.custom_minimum_size.y = rh
	host.menu_button.custom_minimum_size.y = mh
	put_abs(host, host.replay_button, host._x0, by, host._w, rh)
	put_abs(host, host.menu_button, host._x0, by + rh + float(t[T_BGAP]), host._w, mh)
	return host.menu_button.position.y + host.menu_button.size.y


## Büyük yazıda sığmayan içerik için dikey kaydırma (`extra_h` <= 0 kapatır); tembel kurulur, 1× düğüm ağacı değişmez.
static func set_scroll(host, extra_h: float) -> void:
	if host._scroll == null:
		if extra_h <= 0.0:
			return
		host._scroll = wrap_in_scroll(host, [host._bg, host.glow])
		host._content = host._scroll.get_child(0) as Control
	host._content.custom_minimum_size = Vector2(1080.0, DESIGN_H + maxf(extra_h, 0.0))
	host._scroll.vertical_scroll_mode = (
		ScrollContainer.SCROLL_MODE_AUTO if extra_h > 0.0 else ScrollContainer.SCROLL_MODE_DISABLED
	)
	if extra_h <= 0.0:
		host._scroll.scroll_vertical = 0


## Yazı boyutları (büyükte DESIGN §5/§9: Ad 40, ayrıntı 34, şerit 54/30, kombo/düğme büyür); 1× değerleri ilk kuruluşla aynı.
static func apply_fonts(host) -> void:
	if host.title_label == null:
		return
	fs(host, host.sub_label, 34, 38)
	fs(host, host.record_pill, 38, 42)
	for row in host.breakdown_rows:
		fs(host, row.get_node("Name"), 32, 40)
		fs(host, row.get_node("Detail"), DETAIL_FONT, 34)
		fs(host, row.get_node("Value"), 44, 44)
	for col in host._strip_nodes:
		fs(host, col.get_node("Value"), 48, 54)
		fs(host, col.get_node("Caption"), 26, 30)
	fs(host, host.combo_title, 32, 38)
	fs(host, host.replay_button, 52, 60)
	if host._big:
		host.menu_button.add_theme_font_size_override(&"font_size", 52)
	else:
		host.menu_button.remove_theme_font_size_override(&"font_size")
	fs(host, host.chip_title, 30, 32)
	fs(host, host.chip_names, 28, 30)
	fs(host, host.easy_note.get_node("Text"), 28, 32)


static func fs(host, c: Node, small: int, big: int) -> void:
	(c as Control).add_theme_font_size_override(&"font_size", big if host._big else small)


static func put(host, c: Control, x: float, y: float, w: float, h: float) -> void:
	put_abs(host, c, x, y + host._dy + host._bdy, w, h)


## Çip satırının üstündeki bloklar (başlık, altyazı, çipler): yalnız güvenli alan kayması.
static func put_top(host, c: Control, x: float, y: float, w: float, h: float) -> void:
	put_abs(host, c, x, y + host._dy, w, h)


static func put_abs(host, c: Control, x: float, y: float, w: float, h: float) -> void:
	c.anchor_left = 0.0
	c.anchor_top = 0.0
	c.anchor_right = 0.0
	c.anchor_bottom = 0.0
	c.position = Vector2(x, y)
	c.size = Vector2(w, h)


static func chip_h(host) -> float:
	return CHIP_ROW_H + CHIP_WRAP if host._big else CHIP_ROW_H


## TalkBack sıra sözcüğü (denetim #15, DESIGN §9): 1-10 "üçüncü"; sonrası rakamlı "11.".
static func spoken_rank(rank: int) -> String:
	var words := ORDINALS.split(" ")
	return words[rank - 1] if rank >= 1 and rank <= words.size() else "%d." % rank


## Sıra notu: 30 px tek satıra sığmazsa 26'ya kadar küçülür, yine sığmazsa 2 satıra sarar (denetim #9).
## Büyük yazıda 34'ten 30'a. Kutu yüksekliği döner (sarmada en çok `avail_h`).
static func fit_note(note: Label, width: float, big: bool, avail_h: float) -> float:
	var grow := 4 if big else 0
	var fs := NOTE_FONT + grow
	var font := note.get_theme_font(&"font")
	var text := note.text
	while (
		fs > NOTE_FONT_MIN + grow
		and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x > width
	):
		fs -= 2
	note.add_theme_font_size_override(&"font_size", fs)
	var wide := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x > width
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wide else TextServer.AUTOWRAP_OFF
	if wide:
		return minf(avail_h, 2.0 * ceilf(font.get_height(fs)))
	return maxf(40.0, ceilf(font.get_height(fs)))


## Taş/kahve yüzey (DESIGN v2.1 §5: `levha` rengi): tema `PanelRaised` mordur (v2.0.3 kalıntısı); iç boşluklar temadan alınır.
static func stone_box() -> StyleBox:
	var theme_sb := UiKit.theme().get_stylebox(&"panel", &"PanelRaised")
	var sb := UiKit.stylebox(UiKit.TAS_800, UiKit.BRONZ_700, 3, 14)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		sb.set_content_margin(side, theme_sb.get_content_margin(side))
	return sb


## Kolay notu metni: autowrap'lı Label'ın en küçük yüksekliği ekranda dar genişlikte hesaplanıp (CI: 2163 px) metni panel dışına
## itiyordu (not boş görünüyordu); sarma kapatılır, sığmayan metin boşlukta elle iki satıra bölünür.
static func size_note_text(text: Label, width: float, height: float) -> void:
	var avail := width - 92.0 - 28.0
	var raw := text.text.replace("\n", " ")
	var font := text.get_theme_font(&"font")
	var fs := text.get_theme_font_size(&"font_size")
	text.autowrap_mode = TextServer.AUTOWRAP_OFF
	text.text = raw
	if font.get_string_size(raw, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x > avail:
		var cut := raw.rfind(" ", int(raw.length() * 0.5) + 4)
		if cut > 0:
			text.text = raw.substr(0, cut) + "\n" + raw.substr(cut + 1)
	text.custom_minimum_size = Vector2(avail, 0.0)
	text.size = Vector2(avail, height)


## Çip giriş kayması blok arası boşluktan (sıkı kademelerde <24) büyük olamaz; yoksa çip kombo paneline biner.
static func chip_slide(tier: int, slide: float) -> float:
	return minf(slide, float(TIERS[tier][T_GB]))


## Başarım çipinin iç parçaları çip yüksekliğine (96 / en sıkı kademede 88) göre dizilir; adlar çip genişliğine kırpılır.
static func place_chip_parts(
	star: Control, title: Control, names: Control, width: float, height: float
) -> void:
	var top := (height - 80.0) * 0.5
	star.position.y = (height - 44.0) * 0.5
	title.position.y = top
	names.position.y = top + 40.0
	names.size = Vector2(width - 92.0 - 28.0, 40.0)


## Büyük yazıda sığmayan içerik için: `host`un `keep` dışındaki tüm çocukları, host'u dolduran bir ScrollContainer'ın
## içerik düğümüne (ilk çocuk) taşır; tembel kurulur, böylece 1× düğüm ağacı değişmez. Kaydırma tıklamaları host'a geçirir (PASS).
static func wrap_in_scroll(host: Control, keep: Array) -> ScrollContainer:
	var scroll := UiKit.make_scroll(
		UiKit.SCROLL_AXIS_VERTICAL,
		{"name": "ResultScroll", "mouse_filter": Control.MOUSE_FILTER_PASS}
	)
	UiKit.fill(scroll)
	var content := Control.new()
	content.name = "ResultContent"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(content)
	for c in host.get_children():
		if not keep.has(c):
			host.remove_child(c)
			content.add_child(c)
	host.add_child(scroll)
	return scroll


## Büyük yazı: çipler (yazı 30) HFlowContainer'da sığmazsa iki satıra sarar; çipler ve adları aynı kalır.
static func wrap_chips(row: HBoxContainer) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.name = row.name
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flow.add_theme_constant_override(&"h_separation", 16)
	flow.add_theme_constant_override(&"v_separation", 8)
	for c in row.get_children():
		row.remove_child(c)
		flow.add_child(c)
		for l in c.find_children("*", "Label", true, false):
			(l as Label).add_theme_font_size_override(&"font_size", 30)
	row.queue_free()
	return flow
