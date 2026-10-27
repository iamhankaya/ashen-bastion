#!/usr/bin/env python3
"""v2.1 maketleri (koşu modu + zorluk). 1080x2400 statik HTML.
Çalıştır: python3 build.py && python3 shoot.py   (shoot.py: headless Chrome/Edge, ek bağımlılık yok)
Yüzey çerçeveleri ve ana sayfa varlıkları v2.0.3'ten gelir (../../v2.0.3/frames, mock/assets)."""
import pathlib, re
HERE = pathlib.Path(__file__).parent
V3 = "../../v2.0.3/"
F = V3 + "frames/"
A = V3 + "mock/assets/"
R = "../../../../"

def page(name, title, body, aria):
    (HERE / f"{name}.html").write_text(
        '<!doctype html><html lang="tr"><head><meta charset="utf-8"><meta name="viewport" content="width=1080">'
        f'<title>{title} — Ashen Bastion v2.1 maketi</title><link rel="stylesheet" href="mock.css"><style>body{{height:2400px}}</style></head>'
        f'<body><main class="screen" style="height:2400px" aria-label="{aria}">{body}</main></body></html>', encoding="utf-8")

def call(x, y, w, h, label, inside=False):
    return f'<div class="call" style="left:{x}px;top:{y}px;width:{w}px;height:{h}px"><b class="{"in" if inside else ""}">{label}</b></div>'

# ---------------------------------------------------------------- glifler (SVG, emoji yok)
def g_mode(kind, c="#D2B47E", s=64):
    d = {"hizli": '<path d="M3 8h12l14 18-14 18H3l14-18z"/><path d="M25 8h12l14 18-14 18H25l14-18z"/>',
         "normal": '<path d="M12 5h28v7c0 8-8 11-8 14s8 6 8 14v7H12v-7c0-8 8-11 8-14s-8-6-8-14z"/>',
         "sonsuz": '<path d="M26 26c-6-9-19-9-19 0s13 9 19 0 19-9 19 0-13 9-19 0z" fill="none" stroke="C" stroke-width="7" stroke-linejoin="round"/>'}[kind].replace('stroke="C"', f'stroke="{c}"')
    return f'<svg width="{s}" height="{s}" viewBox="0 0 52 52" fill="{c}" stroke="#2B0E14" stroke-width="2.5" stroke-linejoin="round">{d}</svg>'

def g_diff(n, c="#D2B47E", w=84):
    """Zorluk = 1–3 kalkan (sayı + ad; renk tek kanal değil)."""
    sh = lambda i, on: (f'<path transform="translate({i*28},0)" d="M1 1h22v14c0 8-11 12-11 12S1 23 1 15z" '
                        + (f'fill="{c}" stroke="#2B0E14"' if on else f'fill="none" stroke="{c}"') + ' stroke-width="3" stroke-linejoin="round"/>')
    return f'<svg width="{w}" height="{int(w*28/84)}" viewBox="0 0 84 28">{"".join(sh(i, i < n) for i in range(3))}</svg>'

def g_check(c="#E8A24A"):
    return f'<img class="tag" src="{F}muhur-dolu.svg" alt="">'

def g_lock(c="#A39883", s=48):
    return (f'<svg width="{s}" height="{s}" viewBox="0 0 48 48" fill="{c}" stroke="#0C0908" stroke-width="3" stroke-linejoin="round"><path d="M14 22V16a10 10 0 0 1 20 0v6" fill="none" stroke="{c}" stroke-width="5"/>'
            '<rect x="9" y="22" width="30" height="22" rx="3"/><rect x="21" y="30" width="6" height="8" rx="2" fill="#0C0908"/></svg>')

def g_bang(c="#E8A24A", s=44):
    return (f'<svg width="{s}" height="{s}" viewBox="0 0 44 44" fill="{c}" stroke="#2B0E14" stroke-width="3" stroke-linejoin="round"><path d="M22 3l19 36H3z"/>'
            '<path d="M22 15v12" stroke="#2B0E14" stroke-width="4" stroke-linecap="round"/><circle cx="22" cy="33" r="2.5" fill="#2B0E14" stroke="none"/></svg>')

MODES = {"hizli": ("HIZLI", "Kısa koşu. Lord 10. dakikada gelir.", "10 DK"),
         "normal": ("NORMAL", "Klasik koşu. Lord 20. dakikada gelir.", "20 DK"),
         "sonsuz": ("SONSUZ", "Lord devrilince koşu sürer; ölene kadar.", "∞")}
DIFFS = {"kolay": ("KOLAY", 1, "Daha az ve zayıf düşman."),
         "normal": ("NORMAL", 2, "Dengeli koşu."),
         "zor": ("ZOR", 3, "Yoğun ve sert düşman.")}

def bg(top_glow=True):
    b = '<div class="abs" style="inset:0;background:#151110"></div>'
    if top_glow:
        b += '<div class="abs" style="inset:0;background:radial-gradient(ellipse 90% 30% at 50% 0%,rgba(232,162,74,.16),transparent 70%)"></div>'
    b += '<div class="abs" style="left:0;right:0;bottom:0;height:500px;background:linear-gradient(180deg,transparent,#0C0908)"></div>'
    return b

def lento(title, w=520):
    x = (1080 - w) // 2
    return (f'<div class="abs" style="left:{x}px;top:96px;width:{w}px;height:120px;border:solid transparent;border-width:0 60px;border-image:url({F}lento.svg) 0 60 fill/0 60px/0 stretch;'
            f'display:flex;align-items:center;justify-content:center;margin:0 -60px 0 0;box-sizing:content-box"><div class="hd" style="font-size:64px;line-height:74px;text-shadow:0 4px 0 #000">{title}</div></div>')

def back(y=2196, label="GERİ"):
    return f'<div class="abs b" style="left:72px;width:936px;top:{y}px;height:132px;border-width:36px"><div class="in">{label}</div></div>'

# ====================================================================== 1 ANA SAYFA (v2.0.3 maketine koşu şeridi eklenir)
def strip_html(mode="normal", diff="normal", big=False, y=1604):
    mn, _, dur = MODES[mode]
    dn, dc, _ = DIFFS[diff]
    h = 168 if big else 132
    fs1, fs2 = (50, 40) if big else (34, 26)
    return (f'<div class="abs sel" style="left:72px;width:936px;top:{y}px;height:{h}px;border-width:30px;box-sizing:border-box">'
            f'<div style="margin:-12px;height:{h-36}px;display:flex;align-items:center;gap:22px">{g_mode(mode, s=64 if not big else 80)}'
            f'<div style="flex:1;min-width:0"><div style="font:700 {fs1}px/{fs1+6}px Cinzel;letter-spacing:.06em;color:#EFE7D6">{mn} · {dur}</div>'
            f'<div style="display:flex;align-items:center;gap:12px;font:600 {fs2}px/{fs2+6}px Inter;color:#CFC4AE">Zorluk: {dn.capitalize() if False else {"KOLAY":"Kolay","NORMAL":"Normal","ZOR":"Zor"}[dn]} {g_diff(dc, w=70)}</div></div>'
            f'<div style="font:700 {fs2}px Inter;letter-spacing:.08em;color:#D2B47E;flex:none">DEĞİŞTİR ›</div></div></div>')

def home(name, mode="normal", diff="normal", big=False, anat=False):
    s = (pathlib.Path(HERE) / V3 / "mock" / ("01d-ana-sayfa-yazi-2x.html" if big else "01-ana-sayfa.html")).read_text(encoding="utf-8")
    s = s.replace('../frames/', F).replace('src="assets/', f'src="{A}').replace('href="mock.css"', 'href="mock.css"')
    s = s.replace("v2.0.3 maketi", "v2.1 maketi").replace("Sürüm 2.0.3", "Sürüm 2.1.0")
    if not big:
        add = strip_html(mode, diff)
        # karakter / zemin sahnesi aynı; şerit OYNA'nın 27 px üstünde (y 1604–1736)
    else:
        add = strip_html(mode, diff, big=True, y=0)  # 2×: şerit sütunun ilk öğesi (aşağıda sütuna eklenir)
    if anat and not big:
        add += (call(72, 1604, 936, 132, "KOŞU ŞERİDİ 936×132 · y1604 · dokun = Koşu seçimi")
                + call(72, 1763, 936, 180, "OYNA y1763 (değişmedi) · son seçimle başlar"))
    if not big:
        s = s.replace("</main>", add + "</main>")
    else:
        # 2×: sütunun başına şerit (168 yüksek), sahne kırpması ve karakter küçülür (bkz. DESIGN §2.2)
        strip = strip_html(mode, diff, big=True, y=0).replace('class="abs sel"', 'class="sel"').replace("left:72px;width:936px;top:0px;", "width:100%;flex:none;")
        s = s.replace('flex-direction:column;gap:27px">', 'flex-direction:column;gap:27px">' + strip, 1)
        s = re.sub(r'top:1301px', 'top:1106px', s, 1)
    (HERE / f"{name}.html").write_text(s, encoding="utf-8")

# ====================================================================== 2 KOŞU SEÇİMİ
def mode_row(key, sel, y, big=False, locked=False):
    nm, ds, du = MODES[key]
    h = 184 if not big else 336
    nfs, dfs = (44, 28) if not big else (64, 44)
    mk = f'<img class="tag" style="right:-8px;top:-8px" src="{F}muhur-dolu.svg" alt="">' if sel else ""
    lock = f'<div style="position:absolute;right:150px;top:50px">{g_lock()}</div>' if locked else ""
    return (f'<div class="abs sel mrow{" on" if sel else ""}" style="left:72px;width:936px;top:{y}px;height:{h}px;box-sizing:border-box">{mk}'
            f'<div class="in2" style="height:{h-56+24}px;margin:-12px;gap:{26 if not big else 30}px">'
            f'<div style="flex:none">{g_mode(key, "#D2B47E" if sel else "#A88A5C", 84 if not big else 112)}</div>'
            f'<div style="flex:1;min-width:0"><div style="font:700 {nfs}px/{nfs+6}px Cinzel;letter-spacing:.06em;color:#EFE7D6">{nm}</div>'
            f'<div style="font:400 {dfs}px/{dfs+6}px Inter;color:#CFC4AE">{ds}</div></div>'
            f'<div class="du" style="{"font-size:56px;min-width:190px" if big else ""}{"font:700 56px Inter" if key == "sonsuz" else ""}">{du}</div></div>{lock}</div>')

def diff_card(key, sel, x, y, w=296, h=272, row=False):
    nm, n, ds = DIFFS[key]
    mk = f'<img class="tag" style="right:-8px;top:-8px" src="{F}muhur-dolu.svg" alt="">' if sel else ""
    if not row:
        inner = (f'<div style="margin:-12px;height:{h-56+24}px;display:flex;flex-direction:column;align-items:flex-start;gap:6px">'
                 f'{g_diff(n, "#D2B47E" if sel else "#A88A5C", 84)}<div style="font:700 40px/46px Cinzel;letter-spacing:.06em;color:#EFE7D6;margin-top:4px">{nm}</div>'
                 f'<div style="font:400 26px/32px Inter;color:#CFC4AE">{ds}</div></div>')
        pos = f'left:{x}px;width:{w}px;top:{y}px;height:{h}px'
    else:
        inner = (f'<div style="margin:-12px;height:{h-56+24}px;display:flex;align-items:center;gap:30px">{g_diff(n, "#D2B47E" if sel else "#A88A5C", 120)}'
                 f'<div style="flex:1"><div style="font:700 64px/72px Cinzel;letter-spacing:.06em;color:#EFE7D6">{nm}</div><div style="font:400 44px/52px Inter;color:#CFC4AE">{ds}</div></div></div>')
        pos = f'left:72px;width:936px;top:{y}px;height:{h}px'
    return f'<div class="abs sel dcard{" on" if sel else ""}" style="{pos};box-sizing:border-box">{mk}{inner}</div>'

DELTAS = {  # ÖRNEK değerler (spec K1 başlangıç TAHMİN'i); gerçek sayı data/difficulty.json'dan okunur
    "kolay": [("Düşman canı", "−%30"), ("Düşman hasarı", "−%45"), ("Düşman sayısı", "−%30"), ("Kazanılan XP", "+%25")],
    "normal": [("Düşman canı", "−%15"), ("Düşman hasarı", "−%25"), ("Düşman sayısı", "−%15"), ("Kazanılan XP", "aynı")],
    "zor": [("Düşman canı", "tam"), ("Düşman hasarı", "tam"), ("Düşman sayısı", "tam"), ("Kazanılan XP", "aynı")]}

def delta_plate(diff, y, big=False):
    rows = DELTAS[diff]
    rh = 76 if not big else 110
    fs = (32, 36) if not big else (46, 50)
    inner = "".join(f'<div style="display:flex;justify-content:space-between;height:{rh}px;align-items:center;{"border-top:3px solid #3B302C;" if i else ""}">'
                    f'<span style="font:600 {fs[0]}px Inter;color:#CFC4AE">{l}</span><b style="font:700 {fs[1]}px Cinzel;color:#EFE7D6">{v}</b></div>' for i, (l, v) in enumerate(rows))
    h = 56 + 8 + rh * 4 + 8
    return (f'<div class="abs lev" style="left:72px;width:936px;top:{y}px;height:{h}px;box-sizing:border-box"><div style="margin:-8px 0">{inner}</div></div>'), h

def rule_plate(mode, diff, y, big=False):
    lines = [(False, "Skorun bu mod ve zorluğun kendi listesine yazılır.")]
    if diff == "kolay":
        lines.append((True, "Kolay'da Lord başarımları ve toplam sayaçlar ilerlemez."))
    if mode == "sonsuz":
        lines.append((True, "İlk Lord'u devirmek zaferdir; koşu sen ölene kadar sürer."))
    fs = 28 if not big else 44
    inner = "".join(f'<div class="rl" style="padding:{10 if not big else 16}px 0">{g_bang(s=40 if not big else 60) if w else g_mode("normal", "#A88A5C", 40 if not big else 60)}'
                    f'<div style="font:{"600" if w else "400"} {fs}px/{fs+8}px Inter;color:{"#EFE7D6" if w else "#CFC4AE"}">{t}</div></div>' for w, t in lines)
    h = 56 + (len(lines) * ((fs + 8) * (1 if not big else 2) + (20 if not big else 32))) + 8
    return (f'<div class="abs lev" style="left:72px;width:936px;top:{y}px;height:{h}px;box-sizing:border-box"><div style="margin:-8px 0">{inner}</div></div>'), h

def sec(t, y):
    return f'<div class="sec" style="top:{y}px">{t}</div>'

def select_screen(name, mode="normal", diff="normal", anat=False, big=False, locked_demo=False):
    b = bg() + lento("KOŞU")
    if not big:
        y = 250
        b += sec("MOD", y); y += 84
        for k in MODES:
            b += mode_row(k, k == mode, y, locked=(locked_demo and k == "sonsuz")); y += 184 + 16
        y += 14
        b += sec("ZORLUK", y); y += 84
        for i, k in enumerate(DIFFS):
            b += diff_card(k, k == diff, 72 + i * 320, y);
        y += 272 + 30
        d, dh = delta_plate(diff, y); b += d; y += dh + 24
        r, rh = rule_plate(mode, diff, y); b += r; y += rh
        if anat:
            b += (call(72, 338, 936, 184, "MOD satırı 936×184 · tek dokunma hedefi · seçili = bordo + mühür ✓")
                  + call(72, 954, 296, 272, "ZORLUK kartı 296×272 · 3 yan yana · kalkan sayısı = zorluk")
                  + call(72, 1252, 936, 404, "seçili zorluğun ayrıntı levhası (4 satır, veriden)")
                  + call(72, 1680, 936, 240, "kural levhası: !'li satır yalnız uyarı gerektirirse")
                  + call(72, 2196, 936, 132, "GERİ 936×132 y2196 (sabit)"))
    else:
        y = 250
        b += sec("MOD", y); y += 84
        for k in MODES:
            b += mode_row(k, k == mode, y, big=True); y += 336 + 16
        y += 14
        b += sec("ZORLUK", y); y += 84
        for k in DIFFS:
            b += diff_card(k, k == diff, 0, y, h=260, row=True); y += 260 + 16
        b += '<div class="abs" style="left:0;right:0;top:2060px;height:136px;background:linear-gradient(180deg,transparent,#0C0908)"></div>'
        b += call(72, 2040, 936, 100, "2× yazı: liste kayar (y250–2172), GERİ sabit; zorluk kartları dikey sıraya düşer", True)
    b += back()
    page(name, "Koşu seçimi", b, "Koşu seçimi")

# ====================================================================== 3 SONUÇ
def result(name, kind="lost", mode="normal", diff="zor", rank="3. sıra", note_kolay=False, lords=None, anat=False):
    won = kind == "won"
    b = '<div class="abs" style="inset:0;background:#0C0908"></div>'
    b += f'<div class="abs" style="left:0;right:0;top:0;height:1100px;background:radial-gradient(ellipse 80% 50% at 50% 0%,{"rgba(232,162,74,.30)" if won else "rgba(143,42,54,.35)"},transparent 75%)"></div>'
    title = "KAZANDIN" if won else "OYUN BİTTİ"
    sub = {"won": "Düşmüş Kale Lordu devrildi.", "lost": "Kale seni yuttu."}[kind]
    if kind == "won" and mode == "sonsuz":
        sub = "Lord'u devirdin; sonra 7:48 daha dayandın."
    b += f'<div class="abs" style="left:0;right:0;top:170px;text-align:center;font:900 104px/110px Cinzel;letter-spacing:.06em;color:#EFE7D6;text-shadow:0 5px 0 #000">{title}</div>'
    b += f'<div class="abs" style="left:0;right:0;top:300px;text-align:center;font:400 34px/42px Inter;color:#CFC4AE">{sub}</div>'
    mn, _, dur = MODES[mode]; dn = DIFFS[diff][0]; dc = DIFFS[diff][1]
    chips = (f'<span class="chip">{g_mode(mode, "#D2B47E", 30)}{mn}{'' if mode == 'sonsuz' else ' · ' + dur}</span><span class="chip">{g_diff(dc, w=60)}{dn}</span>')
    if lords:
        chips += f'<span class="chip">{g_mode("sonsuz", "#E8A24A", 30)}LORD ×{lords}</span>'
    b += f'<div class="abs" style="left:0;right:0;top:356px;display:flex;justify-content:center;gap:16px">{chips}</div>'
    b += '<div class="abs" style="left:150px;right:150px;top:432px;height:4px;background:linear-gradient(90deg,transparent,#A88A5C,transparent)"></div>'
    b += '<div class="abs" style="left:0;right:0;top:460px;text-align:center;font:700 34px Cinzel;letter-spacing:.14em;color:#D2B47E">SKOR</div>'
    b += f'<div class="abs" style="left:0;right:0;top:496px;text-align:center;font:900 120px/130px Cinzel;color:#EFE7D6;text-shadow:0 5px 0 #000">{"482.150" if won else "128.940"}</div>'
    b += ('<div class="abs" style="left:72px;right:72px;top:640px;height:96px;background:#2B0E14;border-top:4px solid #E8A24A;border-bottom:4px solid #E8A24A;display:flex;align-items:center;justify-content:center;gap:24px;font:900 56px Cinzel;color:#E8A24A">★ YENİ REKOR ★</div>')
    MN = {"HIZLI": "Hızlı", "NORMAL": "Normal", "SONSUZ": "Sonsuz"}[mn]; DN = {"KOLAY": "Kolay", "NORMAL": "Normal", "ZOR": "Zor"}[dn]
    b += f'<div class="abs" style="left:0;right:0;top:752px;text-align:center;font:600 30px/38px Inter;color:#CFC4AE">{MN} · {DN} listesinde {rank}</div>'
    # döküm (özet) levhası
    rows = [("Öldürme", "58.200"), ("Seri çarpanı", "×3,4"), ("Evrim bonusu", "6.000"), ("Hayatta kalma", "36.000" if won else "26.100")] + ([("Lord bonusu", "25.000")] if won else [])
    inner = "".join(f'<div style="display:flex;justify-content:space-between;align-items:center;height:84px;{"border-top:3px solid #3B302C;" if i else ""}"><span style="font:600 32px Inter;color:#EFE7D6">{l}</span><b style="font:700 44px Cinzel;color:#EFE7D6">{v}</b></div>' for i, (l, v) in enumerate(rows))
    bh = 56 + 84 * len(rows)
    b += f'<div class="abs lev" style="left:72px;width:936px;top:830px;height:{bh+16}px;box-sizing:border-box"><div style="margin:-8px 0">{inner}</div></div>'
    y = 830 + bh + 16 + 24
    b += (f'<div class="abs lev" style="left:72px;width:936px;top:{y}px;height:170px;box-sizing:border-box"><div style="margin:-6px 0;display:flex;height:112px;align-items:center">'
          f'<div class="stat"><b>{"27:48" if mode == "sonsuz" and won else "20:00" if won else "14:32"}</b><span>Süre</span></div><div class="stat"><b>{19 if won else 17}</b><span>Seviye</span></div><div class="stat"><b>{"2.644" if won else "1.482"}</b><span>Öldürme</span></div></div></div>')
    y += 170 + 20
    if note_kolay:
        b += (f'<div class="abs rl" style="left:72px;width:936px;top:{y}px;padding:14px 8px;gap:18px;align-items:center;background:rgba(43,14,20,.55);border-left:6px solid #E8A24A;height:96px;box-sizing:border-box">{g_bang(s=44)}'
              '<div style="font:600 28px/34px Inter;color:#EFE7D6">Kolay: bu koşu Lord başarımlarına ve toplam sayaçlara yazılmadı.</div></div>')
        y += 96 + 20
    b += (f'<div class="abs lev" style="left:72px;width:936px;top:{y}px;height:250px;box-sizing:border-box"><div style="margin:-8px 0">'
          '<div style="font:700 32px Cinzel;letter-spacing:.14em;color:#D2B47E;margin-bottom:12px">KURULAN KOMBOLAR</div><div style="font:700 36px Cinzel;color:#EFE7D6">Zincirleme Patlama</div><div style="font:400 28px Inter;color:#CFC4AE">Seken Mermi + Barut Kesesi</div></div></div>')
    by = max(y + 250 + 24, 1500)
    b += f'<div class="abs b p" style="left:72px;width:936px;top:{by}px;height:156px;border-width:42px"><div class="in" style="font-size:52px">TEKRAR OYNA</div></div>'
    b += f'<div class="abs b" style="left:72px;width:936px;top:{by+183}px;height:132px;border-width:36px"><div class="in">ANA MENÜ</div></div>'
    if anat:
        b += (call(210, 348, 660, 56, "koşu şeridi: 2–3 çip, 48 yüksek, y352", True)
              + call(72, 740, 936, 56, "sıra satırı: Mod · Zorluk listesinde N. sıra", True))
    page(name, "Sonuç", b, "Sonuç ekranı")

# ====================================================================== 4 SKORLAR
def tabs(items, sel, y, glyph_fn):
    cells = "".join(f'<div class="tab{" on" if k == sel else ""}"><div class="in3">{glyph_fn(k, k == sel)}{lab}</div>{"<div class=korline></div>" if k == sel else ""}</div>' for k, lab in items)
    return f'<div class="abs tabs" style="left:72px;width:936px;top:{y}px">{cells}</div>'

def scores(name, mode="normal", diff="normal", empty=False, anat=False, hl=None):
    b = bg() + '<div class="abs" style="left:0;right:0;top:150px;text-align:center;font:900 96px/104px Cinzel;letter-spacing:.06em;color:#EFE7D6;text-shadow:0 5px 0 #000">EN İYİ SKORLAR</div>'
    mt = tabs([(k, v[0]) for k, v in MODES.items()], mode, 290, lambda k, s: g_mode(k, "#D2B47E" if s else "#A88A5C", 40))
    dt = tabs([(k, v[0]) for k, v in DIFFS.items()], diff, 434, lambda k, s: g_diff(DIFFS[k][1], "#D2B47E" if s else "#A88A5C", 60))
    b += mt + dt
    if not empty:
        data = [("482.150", True, "20:00", "27 Eki"), ("311.420", False, "18:14", "26 Eki"), ("128.940", False, "14:32", "27 Eki"), ("96.300", False, "12:10", "25 Eki"), ("71.880", False, "11:02", "24 Eki"),
                ("55.200", False, "9:47", "24 Eki"), ("40.115", False, "8:30", "23 Eki"), ("22.760", False, "6:21", "22 Eki"), ("14.090", False, "4:55", "22 Eki"), ("6.440", False, "2:12", "21 Eki")]
        top = 590
        for i, (sc, w, tm, dt_) in enumerate(data):
            ring = ["#D2B47E", "#CFC4AE", "#A88A5C"][i] if i < 3 else "#7A6045"
            chip = ('<span style="display:inline-flex;align-items:center;height:40px;padding:0 14px;border:3px solid #E8A24A;color:#E8A24A;font:700 26px Inter">✓ KAZANDI</span>' if w else
                    '<span style="display:inline-flex;align-items:center;height:40px;padding:0 14px;background:#5C1D26;border:2px solid #8F2A36;color:#EFE7D6;font:700 26px Inter">YENİLDİ</span>')
            new = ('<span style="position:absolute;right:270px;top:56px;height:34px;padding:0 12px;background:#E8A24A;color:#2B0E14;font:700 26px/34px Inter">YENİ</span>' if hl == i else "")
            b += (f'<div class="abs lev hrow" style="top:{top + i * 158}px;height:146px;box-sizing:border-box">{new}'
                  f'<div style="position:absolute;left:0;top:0;width:100%;height:100%"><div class="rk" style="border-color:{ring};top:19px;left:14px">{i+1}</div>'
                  f'<div class="sc" style="top:6px">{sc}</div><div class="mt" style="top:72px">{chip}<span>{tm}</span></div><div class="dt" style="top:48px">{dt_}</div></div></div>')
        pass
    else:
        mn, dn = MODES[mode][0].capitalize(), DIFFS[diff][0].capitalize()
        b += ('<div class="abs" style="left:72px;width:936px;top:760px;text-align:center">'
              f'<div style="opacity:.55;height:160px">{g_mode(mode, "#7A6045", 160)}</div>'
              '<div style="font:700 56px/64px Cinzel;color:#EFE7D6;margin-top:34px">HENÜZ SKOR YOK</div>'
              f'<div style="font:400 32px/42px Inter;color:#CFC4AE;margin-top:18px">{mn} · {dn} listesinde kayıt yok.<br>Bu ayarla oynayıp ilk skoru yaz.</div></div>')
        b += f'<div class="abs b p" style="left:72px;width:936px;top:1800px;height:180px;border-width:42px"><div class="in" style="font-size:46px;letter-spacing:.1em">BU AYARLA OYNA</div></div>'
    b += back()
    if anat:
        b += (call(72, 290, 936, 132, "MOD sekmeleri 3×(306×132), aralık 12", False)
              + call(72, 434, 936, 132, "ZORLUK sekmeleri 3×(306×132)", False)
              + call(72, 590, 936, 146, "satır 936×146 (pitch 158) · 10 satır y590–2168"))
    page(name, "Skorlar", b, "En iyi skorlar")

# ====================================================================== 5 SONUSUZ ZAFER ANI (oyun içi)
def endless_moment():
    b = '<div class="abs field" style="inset:0"></div>'
    for x, y, c in [(180, 900, "z"), (700, 1100, "z"), (420, 1400, ""), (860, 1500, "k"), (260, 1600, "k"), (620, 800, "")]:
        b += f'<div class="foe {c}" style="left:{x}px;top:{y}px"></div>'
    b += ('<div class="abs" style="left:72px;right:72px;top:300px;height:204px;border:solid transparent;border-width:36px;border-image:url(' + F + 'dugme-birincil.svg) 40 fill/36px/0 stretch;box-sizing:border-box">'
          '<div style="margin:-18px;text-align:center"><div style="font:900 54px/62px Cinzel;letter-spacing:.1em;color:#EFE7D6">KALE LORDU DÜŞTÜ</div>'
          '<div style="font:600 32px/40px Inter;color:#E8A24A;margin-top:4px">ZAFER SAYILDI · Koşu sürüyor</div></div></div>')
    b += '<div class="abs" style="left:0;right:0;top:524px;text-align:center;font:600 28px Inter;color:#CFC4AE">Lord 5:00 sonra daha güçlü döner.</div>'
    b += ('<div class="abs" style="left:0;right:0;top:96px;text-align:center;font:700 64px Cinzel;color:#EFE7D6;text-shadow:0 4px 0 #000">20:00</div>')
    b += call(72, 300, 936, 204, "Kilometre taşı bandı 936×204 · y300 · 3,2 sn · dokunmayı engellemez", False)
    page("05-sonsuz-zafer-ani", "Sonsuz zafer anı", b, "Oyun içi: Sonsuz modda Lord devrildi")

# ====================================================================== 6 DURUM SAYFASI
def states():
    b = bg(False) + lento("DURUMLAR", 560)
    y = 250
    b += sec("MOD SATIRI", y); y += 84
    labs = [("varsayılan", False, False), ("seçili", True, False), ("kilitli (rezerve)", False, True)]
    for lab, sel, lk in labs:
        b += mode_row("sonsuz" if lk else "hizli", sel, y, locked=lk)
        b += f'<div class="abs" style="left:72px;top:{y+190}px;font:600 26px Inter;color:#A39883">{lab}</div>'
        y += 184 + 44
    b += sec("ZORLUK KARTI", y); y += 84
    for i, (lab, sel) in enumerate([("varsayılan", False), ("seçili", True)]):
        b += diff_card("kolay" if not sel else "zor", sel, 72 + i * 320, y)
        b += f'<div class="abs" style="left:{72+i*320}px;top:{y+278}px;font:600 26px Inter;color:#A39883">{lab}</div>'
    y += 272 + 80
    b += sec("SEKME", y); y += 84
    b += tabs([("hizli", "HIZLI"), ("normal", "NORMAL"), ("sonsuz", "SONSUZ")], "normal", y, lambda k, s: g_mode(k, "#D2B47E" if s else "#A88A5C", 40))
    b += f'<div class="abs" style="left:72px;top:{y+138}px;font:600 26px Inter;color:#A39883">seçili: bordo + kor çizgisi + kalın yazı · diğerleri: taş + soluk</div>'
    y += 220
    b += sec("GRİ TONLAMA SINAMASI", y); y += 84
    b += f'<div style="position:absolute;left:0;right:0;top:{y}px;height:132px;filter:grayscale(1)">' + tabs([("hizli", "HIZLI"), ("normal", "NORMAL"), ("sonsuz", "SONSUZ")], "normal", 0, lambda k, s: g_mode(k, "#D2B47E" if s else "#A88A5C", 40)) + '</div>'
    page("06-durumlar", "Durumlar", b, "Bileşen durumları")

home("01-ana-sayfa")
home("01a-ana-sayfa-anatomi", anat=True)
home("01b-ana-sayfa-yazi-2x", big=True)
select_screen("02-kosu-secimi")
select_screen("02a-kosu-secimi-anatomi", anat=True)
select_screen("02b-kosu-secimi-hizli-kolay", "hizli", "kolay")
select_screen("02c-kosu-secimi-sonsuz-zor", "sonsuz", "zor")
select_screen("02d-kosu-secimi-yazi-2x", big=True)
result("03-sonuc-yenildi", "lost", "normal", "zor", "3. sıra", anat=True)
result("03b-sonuc-kazandi-hizli", "won", "hizli", "normal", "1. sıra")
result("03c-sonuc-sonsuz-zafer", "won", "sonsuz", "zor", "1. sıra", lords=2)
result("03d-sonuc-kolay", "lost", "normal", "kolay", "5. sıra", note_kolay=True)
scores("04-skorlar", hl=2)
scores("04a-skorlar-anatomi", anat=True)
scores("04b-skorlar-bos", "sonsuz", "zor", empty=True)
endless_moment()
states()
print("ok")
