class_name ResultFit
extends RefCounted
## Sonuç ekranı sığdırma yardımcıları (v2.1 U6 denetim #5/#9/#15/#2): kademe tablosu, sıra notu sığdırma, TalkBack sıra sözcüğü,
## büyük yazıda sarmalı çip satırı. `result_screen.gd` dosya satır tavanı (1000) için ayrıdır; durum tutmaz.

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
	var scroll := ScrollContainer.new()
	scroll.name = "ResultScroll"
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
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
