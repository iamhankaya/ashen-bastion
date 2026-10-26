#!/usr/bin/env python3
"""v2.0.3 maketleri (yeniden tasarım turu). 1080x2400 statik HTML. python3 make_assets.py && python3 build.py && node shoot.js"""
import pathlib, random
HERE = pathlib.Path(__file__).parent
R = "../../../../"
F = "../frames/"
A = "assets/"
ACH = R + "assets/ui/achievements/"
ORB = R + "art/source/gem-orbs/"

def page(name, title, body, aria):
    (HERE / f"{name}.html").write_text(
        '<!doctype html><html lang="tr"><head><meta charset="utf-8"><meta name="viewport" content="width=1080">'
        f'<title>{title} — Ashen Bastion v2.0.3 maketi</title><link rel="stylesheet" href="mock.css"><style>body{{height:2400px}}</style></head>'
        f'<body><main class="screen" style="height:2400px" aria-label="{aria}">{body}</main></body></html>', encoding="utf-8")
def call(x, y, w, h, label, inside=False):
    return f'<div class="call" style="left:{x}px;top:{y}px;width:{w}px;height:{h}px"><b class="{"in" if inside else ""}">{label}</b></div>'
def img(src, x, y, w=None, h=None, extra=""):
    st = f"left:{x}px;top:{y}px;" + (f"width:{w}px;" if w else "") + (f"height:{h}px;" if h else "") + extra
    return f'<img class="abs" src="{src}" alt="" style="{st}">'
def glyph(kind, c="#D2B47E", s=52):
    d = {"user": '<circle cx="26" cy="16" r="9"/><path d="M8 46c0-11 8-18 18-18s18 7 18 18z"/>',
         "cup": '<path d="M14 6H38V22C38 30 32 35 26 35C20 35 14 30 14 22Z"/><path d="M14 10H6C6 20 10 24 15 25M38 10H46C46 20 42 24 37 25" fill="none" stroke="C" stroke-width="4"/><rect x="22" y="35" width="8" height="8"/><rect x="14" y="43" width="24" height="6"/>',
         "gear": '<path d="M22 3h8l1.5 6.5 4.5 1.9 5.7-3.5 5.6 5.6-3.5 5.7 1.9 4.5L50 22v8l-6.3 1.5-1.9 4.5 3.5 5.7-5.6 5.6-5.7-3.5-4.5 1.9L30 50h-8l-1.5-6.3-4.5-1.9-5.7 3.5-5.6-5.6 3.5-5.7-1.9-4.5L2 30v-8l6.3-1.5 1.9-4.5-3.5-5.7 5.6-5.6 5.7 3.5 4.5-1.9z"/><circle cx="26" cy="26" r="8" fill="#1F1917"/>',
         "star": '<path d="M26 4l6.5 14.5 15.5 1.7-11.6 10.6 3.3 15.7L26 38.6 12.3 46.5l3.3-15.7L4 20.2l15.5-1.7z"/>',
         "lock": '<path d="M14 22V16a10 10 0 0 1 20 0v6" fill="none" stroke="C" stroke-width="5"/><rect x="9" y="22" width="30" height="22" rx="4"/><rect x="21" y="30" width="6" height="8" rx="2" fill="#2B0E14"/>'}[kind].replace('stroke="C"', f'stroke="{c}"')
    vb = "0 0 48 48" if kind == "lock" else "0 0 52 52"
    return f'<svg width="{s}" height="{s}" viewBox="{vb}" fill="{c}" stroke="#2B0E14" stroke-width="3" stroke-linejoin="round">{d}</svg>'
SPK = lambda on: ('<svg class="spk" viewBox="0 0 48 48" fill="#D2B47E" stroke="#2B0E14" stroke-width="2.5" stroke-linejoin="round"><path d="M6 18h8l10-8v28l-10-8H6z"/>' + ('<path d="M31 17c4 4 4 10 0 14M36 12c7 7 7 17 0 24" fill="none" stroke="#D2B47E" stroke-width="3.5" stroke-linecap="round"/>' if on else '<path d="M30 16l14 16M44 16L30 32" fill="none" stroke="#E0584F" stroke-width="4.5" stroke-linecap="round"/>') + '</svg>')

# ====================================================================== 1 ANA SAYFA
def home(name="01-ana-sayfa", ach="31/53", calm=False, big=False, anat=False):
    rnd = random.Random(7)
    top = 1763 if not big else 1301
    hero_top = 600 if not big else 520
    s = 0.625 if not big else 0.5         # karakter ölçeği (kaynak 1024x1492)
    cw, chh = int(1024 * s), int(1492 * s)
    cx = (1080 - cw) // 2
    b = f'<div class="abs" style="inset:0;background:linear-gradient(180deg,#0C0908 0,#151110 30%,#151110 70%,#0C0908 100%)"></div>'
    # kapının arkasından gelen sıcak ışık (additive radyal doku; Godot: PointLight2D/Sprite2D add)
    b += f'<div class="abs" style="left:100px;top:{hero_top-60}px;width:880px;height:900px;background:radial-gradient(ellipse at 50% 55%,rgba(232,162,74,{.10 if calm else .30}),rgba(143,42,54,.12) 45%,transparent 70%)"></div>'
    ar = 1.62 if not big else 1.2
    b += img(A + "kule.png", -90, hero_top + 10, 330, None, "opacity:.38")
    b += img(A + "sur.png", 650, hero_top + 150, 470, None, "opacity:.32")
    aw = int(440 * ar); ah = int(402 * ar)
    b += img(A + "kemer.png", (1080 - aw) // 2, hero_top + 40, aw, None, "opacity:.78")
    b += img(A + "sancak1.png", 28, hero_top + 20, 128, None, "opacity:.9")
    b += img(A + "sancak2.png", 906, hero_top + 40, 144, None, "opacity:.9")
    ground = hero_top + chh - 60
    # zemin yaması + kül halkası + sert gölge
    b += img(A + "zemin-yama.png", 40, ground - 150, 1000, 400)
    b += f'<div class="abs" style="left:150px;top:{ground-60}px;width:780px;height:240px;border-radius:50%;border:3px solid rgba(207,196,174,.16)"></div>'
    b += f'<div class="abs" style="left:240px;top:{ground-30}px;width:600px;height:150px;border-radius:50%;background:radial-gradient(ellipse,rgba(0,0,0,.85),transparent 70%)"></div>'
    b += img(A + "karakter-eritme.png", cx, hero_top, cw, chh)
    # namlu alevi kenar kesiğini örten ışıma (additive)
    for fx, fy in ((cx + 6, hero_top + int(221 * s)), (cx + cw - 6, hero_top + int(470 * s))):
        b += f'<div class="abs" style="left:{fx-70}px;top:{fy-70}px;width:140px;height:140px;border-radius:50%;background:radial-gradient(circle,rgba(255,222,140,.65),rgba(232,162,74,.25) 45%,transparent 70%)"></div>'
    b += img(A + "mesale.png", 120, ground + 4, 130)
    if not calm:
        b += f'<div class="abs" style="left:100px;top:{ground-70}px;width:200px;height:200px;border-radius:50%;background:radial-gradient(circle,rgba(232,162,74,.38),transparent 65%)"></div>'
        for _ in range(26):    # kül/kor (≤40 parçacık)
            x = rnd.randint(60, 1020); y = rnd.randint(hero_top - 20, ground + 60); r = rnd.choice((3, 4, 5, 6)); warm = rnd.random() < .6
            b += f'<div class="abs" style="left:{x}px;top:{y}px;width:{r}px;height:{r}px;border-radius:50%;background:{"#E8A24A" if warm else "#CFC4AE"};opacity:{rnd.choice((.35,.55,.8)) if warm else .3}"></div>'
    b += f'<div class="abs" style="left:0;right:0;top:{ground+150}px;bottom:0;background:linear-gradient(180deg,transparent,#0C0908 78%)"></div>'
    b += '<div class="abs" style="left:0;right:0;top:0;height:560px;background:linear-gradient(180deg,#0C0908 30%,transparent)"></div>'
    # başlık
    b += ('<div class="abs" style="left:0;right:0;top:128px;display:flex;justify-content:center;align-items:center;gap:26px">'
          f'<img src="{F}ayrac.svg" style="width:150px;height:20px"><div style="font:700 34px Cinzel;letter-spacing:.5em;color:#D2B47E;margin-right:-.5em">ASH AND STEEL</div><img src="{F}ayrac.svg" style="width:150px;height:20px;transform:scaleX(-1)"></div>'
          '<div class="abs engr" style="left:0;right:0;top:186px;text-align:center;font:900 132px/1.0 Cinzel;letter-spacing:.08em">ASHEN<br>BASTION</div>')
    # düğmeler
    if not big:
        col = (f'<div class="b p" style="height:180px;border-width:42px"><img class="crest" src="{F}oyna-tepe.svg" alt=""><div class="in">OYNA</div></div>'
               '<div style="display:flex;gap:27px">'
               f'<div class="b" style="flex:1;height:132px"><div class="in" style="gap:14px"><div style="width:68px;height:68px;border-radius:50%;border:4px solid #A88A5C;overflow:hidden;background:#1F1917;flex:none"><img src="{R}docs/ui/mockups/assets/gunslinger-atis-keyed.png" style="width:150px;margin:-6px 0 0 -40px"></div><div style="text-align:left"><div style="font:700 32px/36px Cinzel;letter-spacing:.05em">KARAKTERLER</div><div style="font:600 26px/30px Inter;letter-spacing:0;color:#CFC4AE;text-shadow:none">Gunslinger</div></div></div></div>'
               f'<div class="b" style="flex:1;height:132px"><div class="in" style="gap:14px"><div style="width:68px;height:68px;border-radius:50%;background:conic-gradient(#E8A24A 58%,#2B0E14 0);display:flex;align-items:center;justify-content:center;flex:none"><div style="width:52px;height:52px;border-radius:50%;background:#2D2422;display:flex;align-items:center;justify-content:center">{glyph("star","#D2B47E",32)}</div></div><div style="text-align:left"><div style="font:700 32px/36px Cinzel;letter-spacing:.05em">BAŞARIMLAR</div><div style="font:600 26px/30px Inter;letter-spacing:0;color:#CFC4AE;text-shadow:none">{ach}</div></div></div></div></div>'
               '<div style="display:flex;gap:27px">'
               f'<div class="b g" style="flex:1;height:132px;font-size:32px"><div class="in">{glyph("cup","#D2B47E",48)}EN İYİ SKORLAR</div></div>'
               f'<div class="b g" style="flex:1;height:132px;font-size:32px"><div class="in">{glyph("gear","#D2B47E",48)}AYARLAR</div></div></div>')
    else:
        def r(ic, t, sub=""):
            sb = f'<div style="font:600 52px/56px Inter;letter-spacing:0;color:#CFC4AE;text-shadow:none">{sub}</div>' if sub else ""
            return f'<div class="b" style="height:168px;justify-content:flex-start;border-width:30px"><div class="in" style="gap:22px;font-size:56px;letter-spacing:.04em">{ic}<div style="text-align:left"><div style="line-height:60px">{t}</div>{sb}</div></div></div>'
        col = (f'<div class="b p" style="height:180px;border-width:42px"><img class="crest" src="{F}oyna-tepe.svg" alt=""><div class="in" style="font-size:80px">OYNA</div></div>'
               + r(glyph("user", "#D2B47E", 64), "KARAKTERLER", "Gunslinger") + r(glyph("star", "#D2B47E", 64), "BAŞARIMLAR", ach) + r(glyph("cup", "#D2B47E", 64), "EN İYİ SKORLAR") + r(glyph("gear", "#D2B47E", 64), "AYARLAR"))
    b += f'<div class="abs" style="left:72px;right:72px;top:{top}px;display:flex;flex-direction:column;gap:27px">{col}</div>'
    b += f'<div class="abs" style="left:0;right:0;top:2288px;height:40px;text-align:center;font:600 26px/40px Inter;color:#A39883">Sürüm 2.0.3</div>'
    if calm:
        b += call(40, 40, 1000, 70, "hareket_azalt AÇIK: kül/kor, meşale titremesi, sancak, nefes durur — sahne statik", True)
    if anat:
        b += (call(72, 1763, 936, 180, "OYNA 936×180 · y1763 · tepe süsü")+call(72, 1970, 454, 132, "KARAKTERLER 454×132 · dolu + mini portre")+call(554, 1970, 454, 132, "BAŞARIMLAR · dolu + ilerleme halkası")
              +call(72, 2129, 454, 132, "SKORLAR · hayalet (aynı hedef)")+call(554, 2129, 454, 132, "AYARLAR · hayalet")+call(72, 2288, 936, 40, "sürüm (karakter adı yok) · alt güvenli y2328")
              +call(cx, hero_top, cw, chh, f"karakter {cw}×{chh} · y{hero_top} · kenarlar 56 px eritilmiş", True)+call(60, 128, 960, 280, "başlık: ayraç + taş oyma harf"))
    page(name, "Ana sayfa", b, "Ana sayfa")

# ====================================================================== 2 AYARLAR
def stone_bg(warm=True):
    pat = ('<svg xmlns="http://www.w3.org/2000/svg" width="240" height="160"><g fill="none" stroke="#2D2422" stroke-width="3" opacity=".55"><rect x="2" y="2" width="116" height="76"/><rect x="122" y="2" width="116" height="76"/><rect x="62" y="82" width="116" height="76"/><path d="M0 82h60M180 82h60"/></g></svg>')
    import urllib.parse
    u = "data:image/svg+xml;utf8," + urllib.parse.quote(pat)
    return (f'<div class="abs" style="inset:0;background:#151110"></div><div class="abs" style="inset:0;background:url(\'{u}\');opacity:.55"></div>'
            '<div class="abs" style="inset:0;background:radial-gradient(ellipse 90% 30% at 50% 0%,rgba(232,162,74,.16),transparent 70%)"></div>'
            '<div class="abs" style="left:0;right:0;bottom:0;height:500px;background:linear-gradient(180deg,transparent,#0C0908)"></div>')
def sw(on): return f'<div class="swc"><em style="color:{"#EFE7D6" if on else "#A39883"}">{"AÇIK" if on else "KAPALI"}</em><img src="{F}anahtar-{"ac" if on else "kapali"}.svg" alt=""></div>'
def slider(lbl, pct, mute, big=False):
    fs = 'style="font-size:72px;line-height:80px"' if big else ""
    return (f'<div style="padding-top:14px"><div class="rw" style="min-height:{96 if big else 64}px"><div class="tx"><div class="lb" {fs}>{lbl}</div></div><div class="vl" style="{"color:#A39883;" if mute else ""}{"font-size:72px" if big else ""}">%{pct}</div></div>'
            f'<div class="sl{" mute" if mute else ""}"><div class="rail"><i style="width:calc({pct}% + 24px)"></i></div><img class="kn" src="{F}tutamak{"-sessiz" if mute else ""}.svg" style="left:{pct}%" alt=""></div></div>')
def settings(name="02-ayarlar", master=True, motion=False, vib=True, big=False, anat=False):
    mute = not master
    b = stone_bg()
    b += f'<div class="abs" style="left:280px;top:96px;width:520px;height:120px;border:solid transparent;border-width:0 60px;border-image:url({F}lento.svg) 0 60 fill/0 60px/0 stretch;display:flex;align-items:center;justify-content:center;margin:0 -60px 0 0;box-sizing:content-box"><div class="hd" style="font-size:64px;line-height:74px;text-shadow:0 4px 0 #000">AYARLAR</div></div>'
    y = 250
    def sec(t):
        nonlocal y
        s = f'<div class="sec" style="top:{y}px">{t}</div>'; y += 80; return s
    def card(inner, h):
        nonlocal y
        s = f'<div class="abs lev" style="left:72px;width:936px;top:{y}px;height:{h}px;display:flex;flex-direction:column;justify-content:center;box-sizing:border-box;padding:0 6px"><div style="margin:-8px 0">{inner}</div></div>'; y += h + 30; return s
    if not big:
        b += sec("SES")
        note = f'<div class="rw" style="min-height:76px;padding:0;gap:14px">{SPK(False)}<div class="ds" style="font:600 26px/30px Inter;color:#CFC4AE">Ses kapalı. Bir kaydırıcıya dokunmak sesi açar.</div></div>' if mute else ''
        b += card(f'<div class="rw"><div style="display:flex;align-items:center;gap:18px;flex:1">{SPK(master)}<div class="lb" style="font:700 36px Cinzel;letter-spacing:.06em">TÜM SESLER</div></div>{sw(master)}</div>{note}{slider("MÜZİK",70,mute)}{slider("EFEKT",85,mute)}', 548 + (76 if mute else 0))
        b += sec("DOKUNUŞ")
        b += card(f'<div class="rw" style="padding:16px 0"><div class="tx"><div class="lb">TİTREŞİM</div><div class="ds">Doldurma ve vuruşlarda hafif titreşim.</div></div>{sw(vib)}</div>', 196)
        b += sec("GÖRÜNÜM")
        b += card(f'<div class="rw" style="padding:16px 0"><div class="tx"><div class="lb">HAREKETİ AZALT</div><div class="ds">Hareketli portreleri ve ekran efektlerini durdurur.</div></div>{sw(motion)}</div>', 232)
        b += sec("HAKKINDA")
        b += card(f'<div class="rw"><div class="tx"><div class="lb">SÜRÜM</div></div><div class="vl" style="font:600 32px Inter">2.0.3</div></div><div class="rw"><div class="tx"><div class="lb">LİSANSLAR</div><div class="ds">Yazı tipleri, ses ve müzik.</div></div><div class="chev">›</div></div>', 308)
    else:
        b += sec("SES")
        b += card(f'<div class="rw" style="min-height:168px;flex-wrap:wrap;padding:12px 0"><div style="display:flex;align-items:center;gap:18px;flex-basis:100%">{SPK(True)}<div class="lb" style="font:700 72px/80px Cinzel">TÜM SESLER</div></div>{sw(True)}</div>{slider("MÜZİK",70,False,True)}', 520)
        b += sec("DOKUNUŞ")
        b += card(f'<div class="rw" style="flex-wrap:wrap;padding:16px 0"><div class="tx" style="flex-basis:100%"><div class="lb" style="font:700 72px/80px Cinzel">TİTREŞİM</div><div class="ds" style="font-size:56px;line-height:64px">Doldurma ve vuruşlarda hafif titreşim.</div></div>{sw(True)}</div>', 420)
        b += '<div class="abs" style="right:30px;top:260px;width:8px;height:300px;background:#A88A5C"></div>'
    b += '<div class="abs" style="left:0;right:0;top:2090px;height:100px;background:linear-gradient(180deg,transparent,#0C0908)"></div>'
    b += f'<div class="abs" style="left:72px;right:72px;top:2196px"><div class="b" style="height:132px"><div class="in">GERİ</div></div></div>'
    if anat:
        b += (call(72, 250, 936, 72, "bölüm başlığı + ayraç")+call(72, 330, 936, 548, "SES levhası: 9-slice margin 40 · satırlar ≥132")+call(72, 880, 936, 0, "")
              +call(72, 2196, 936, 132, "GERİ y2196 sabit · alt güvenli 72")+call(280, 96, 520, 120, "lento 520×120")+call(72, 1005, 936, 200, "TİTREŞİM: tüm satır dokunur")
              +call(700, 400, 308, 120, "anahtar 156×84 + sözcük", True)+call(72, 560, 936, 130, "kaydırıcı bandı 132 (yatay>12 px = tutamak)", True))
    page(name, "Ayarlar", b, "Ayarlar")
def lisans():
    rows = "".join(f'<div class="rw" style="padding:14px 0"><div class="tx"><div class="lb">{a}</div><div class="ds">{c}</div></div></div>' for a, c in (("CINZEL", "Yazı tipi · SIL Open Font License 1.1"), ("INTER", "Yazı tipi · SIL Open Font License 1.1"), ("SES VE MÜZİK", "Kaynaklar ve lisanslar: LICENSES-audio.md")))
    b = stone_bg() + f'<div class="abs" style="left:280px;top:96px;width:520px;height:120px;border:solid transparent;border-width:0 60px;border-image:url({F}lento.svg) 0 60 fill/0 60px/0 stretch;display:flex;align-items:center;justify-content:center;margin:0 -60px 0 0;box-sizing:content-box"><div class="hd" style="font-size:60px;line-height:74px">LİSANSLAR</div></div>'
    b += f'<div class="abs lev" style="left:72px;width:936px;top:260px;height:430px;box-sizing:border-box;display:flex;flex-direction:column;justify-content:center"><div style="margin:-6px 0">{rows}</div></div>'
    b += f'<div class="abs" style="left:72px;right:72px;top:2196px"><div class="b" style="height:132px"><div class="in">GERİ</div></div></div>'
    page("02d-lisanslar", "Lisanslar", b, "Lisanslar")

# ====================================================================== 3 BAŞARIMLAR
TIERC = {0: "#4C3E38", 1: "#8C8379", 2: "#D2B47E", 3: "#E8A24A", 4: "#E8A24A"}
ROM = ["", "I", "II", "III", "IV"]
def plate(icon, n, tier, lock=False, size=108):
    c = TIERC[tier] if not lock else "#4C3E38"
    fr = f"plaka-{tier}.svg" if (tier and not lock) else "plaka-kilitli.svg"
    pp = "".join(f'<i class="{"on" if k < tier else ""}"></i>' for k in range(n))
    rn = f'<span class="rn">{ROM[tier]}</span>' if tier else ""
    lk = '<span style="position:absolute;right:-12px;bottom:-12px;z-index:2">' + glyph("lock", "#CFC4AE", 48) + "</span>" if lock else ""
    return f'<div class="plate{" lk" if lock else ""}" style="--c:{c}"><img class="fr" src="{F}{fr}" alt="" {'style="top:-14px;height:122px"' if (tier == 4 and not lock) else ''}><img class="ic" src="{ACH}{icon}.png" alt="">{rn}{lk}</div>'
def segs(n, got, frac, c, done=False):
    out = ""
    for k in range(n):
        w = 100 if (k < got or done) else (int(frac * 100) if k == got else 0)
        out += f'<i><b style="width:{w}%"></b></i>'
    return f'<div class="seg" style="--c:{"#E8A24A" if done else c}">{out}</div>'
def num(x):
    x = str(x)
    if ":" in x: m, s = x.split(":"); return int(m) * 60 + int(s)
    d = "".join(ch for ch in x if ch.isdigit()); return int(d or 0) * (60 if "sa" in x else 1)
def fam(y, nm, icon, n, got, val, tgt, desc, done=False, dt="", openrow=False):
    tier = got if not done else n
    lock = got == 0 and not done
    tcl = TIERC[min(max(tier, 1), 4)] if tier else "#4C3E38"
    pl = plate(icon, n, tier, lock)
    if done:
        right = f'<div class="rt"><span class="done">TAMAM</span>{segs(n, n, 0, "#E8A24A", True)}</div>'; dd = "Tüm kademeler açıldı. " + dt
    elif openrow:
        right = '<div class="rt"><div class="chev" style="margin-left:auto">˄</div></div>'; dd = desc
    else:
        fr = min(1, num(val) / max(1, num(tgt)))
        right = f'<div class="rt"><div class="v">{val}/{tgt}</div>{segs(n, got, fr, tcl)}</div>'; dd = desc
    hi = " hi" if openrow else ""
    return f'<div class="fam lev{hi}" style="top:{y}px"><div class="in">{pl}<div class="mid"><div class="nm">{nm}</div><div class="dd">{dd}</div></div>{right}</div></div>'
def ghead(y, t, c, tot, amber=False):
    return f'<div class="sec" style="top:{y}px">{t}<span class="ct" style="{"color:#E8A24A" if amber else ""}">{c} / {tot}</span></div>'
GROUPS = ["THE WATCH", "THE CULLING", "THE CROWNED", "THE ARMORY", "THE ROAD"]
CAP = ["WATCH", "CULLING", "CROWNED", "ARMORY", "ROAD"]
def chronicle(opened, total, state):   # 5 grup mühürü; state: 'dolu'|'aktif'|'sonuk'
    cells = ""
    for i, s in enumerate(state):
        cells += (f'<div style="width:187px;text-align:center"><img src="{F}muhur-{s}.svg" style="width:84px;height:84px" alt=""><div style="font:700 26px/30px Inter;letter-spacing:.06em;color:{"#E8A24A" if s=="dolu" else "#CFC4AE" if s=="aktif" else "#A39883"}">{CAP[i]}</div></div>')
    chain = "".join(f'<img src="{F}zincir-halka{"" if i < state.count("dolu")+state.count("aktif") else "-sonuk"}.svg" style="width:24px;height:40px" alt="">' for i in range(0))
    return (f'<div class="abs" style="left:72px;top:240px;font:700 56px/66px Cinzel;color:{"#E8A24A" if opened==total else "#EFE7D6"}">{opened} / {total}<span style="font:600 32px Inter;color:#CFC4AE;margin-left:14px">kademe</span></div>'
            f'<div class="abs" style="left:72px;right:72px;top:332px;height:12px;border-top:6px solid #7A6045;border-bottom:3px solid #3B302C;top:372px;opacity:.9"></div>'
            f'<div class="abs" style="left:72px;right:72px;top:318px;display:flex">{cells}</div>')
def ach(name="03-basarimlar", mode="default", anat=False):
    b = stone_bg()
    b += '<div class="abs" style="left:0;right:0;top:96px;text-align:center" ><span class="hd" style="text-shadow:0 5px 0 #000">BAŞARIMLAR</span></div>'
    if mode == "default":
        b += chronicle(31, 53, ["dolu", "aktif", "aktif", "aktif", "sonuk"])
        y = 470
        b += ghead(y, GROUPS[0], 5, 10); y += 78
        b += fam(y, "HAYATTA KALMA", "on_dakika", 4, 2, "13:32", "15:00", "Tek koşuda 15 dakika hayatta kal."); y += 162
        b += fam(y, "DOKUNULMAZ", "dokunulmaz", 3, 1, "4:01", "5:00", "Tek koşuda 5 dk hasar almadan kal."); y += 162
        b += fam(y, "NÖBET", "yerlesik", 3, 0, "40 dk", "1 sa", "Toplam 1 saat oyna."); y += 162
        b += ghead(y, GROUPS[1], 7, 15); y += 78
        b += fam(y, "ÖLDÜRME", "kalabalik_kesici", 4, 2, "2.940", "5.000", "Toplam 5.000 düşman öldür."); y += 162
        b += fam(y, "KIRIM", "kirim", 4, 1, "812", "1.000", "Tek koşuda 1.000 düşman öldür."); y += 162
        b += ghead(y, GROUPS[2], 3, 8); y += 78
        b += fam(y, "ÜÇ ELİT", "uc_elit", 1, 1, 0, 0, "", done=True, dt="23.10.2026"); y += 162
        b += fam(y, "BOSS AVCISI", "piyade_avcisi", 3, 0, "0", "1", "Bir boss'u devir."); y += 162
    elif mode == "empty":
        b += chronicle(0, 53, ["sonuk"] * 5)
        b += f'<div class="abs lev" style="left:72px;width:936px;top:470px;height:108px;box-sizing:border-box;display:flex;align-items:center;justify-content:center;font:600 30px Inter;color:#CFC4AE;padding:0"><div style="margin:-6px">Henüz kademe açılmadı. Bir koşuya başla.</div></div>'
        y = 612
        b += ghead(y, GROUPS[0], 0, 10); y += 78
        b += fam(y, "HAYATTA KALMA", "on_dakika", 4, 0, "0:00", "5:00", "Tek koşuda 5 dakika hayatta kal."); y += 162
        b += fam(y, "DOKUNULMAZ", "dokunulmaz", 3, 0, "0:00", "3:00", "Tek koşuda 3 dk hasar almadan kal."); y += 162
        b += ghead(y, GROUPS[1], 0, 15); y += 78
        b += fam(y, "ÖLDÜRME", "kalabalik_kesici", 4, 0, "0", "100", "Toplam 100 düşman öldür."); y += 162
    elif mode == "all":
        b += chronicle(53, 53, ["dolu"] * 5)
        b += f'<div class="abs lev" style="left:72px;width:936px;top:470px;height:108px;box-sizing:border-box;display:flex;align-items:center;justify-content:center;font:600 30px Inter;color:#E8A24A;padding:0"><div style="margin:-6px">Tüm başarımlar açıldı.</div></div>'
        y = 612
        b += ghead(y, GROUPS[0], 10, 10, True); y += 78
        for nm, ic, n in (("HAYATTA KALMA", "on_dakika", 4), ("DOKUNULMAZ", "dokunulmaz", 3), ("NÖBET", "yerlesik", 3)):
            b += fam(y, nm, ic, n, n, 0, 0, "", done=True, dt="26.10.2026"); y += 162
    elif mode == "open":
        b += chronicle(31, 53, ["dolu", "aktif", "aktif", "aktif", "sonuk"])
        y = 470
        b += ghead(y, GROUPS[1], 7, 15); y += 78
        steps = [("I", "100", "12.10.2026", "dolu"), ("II", "1.000", "23.10.2026", "dolu"), ("III", "5.000", "2.940 / 5.000", "aktif"), ("IV", "25.000", "Hedef 25.000", "sonuk")]
        rows = ""
        for i, (r, t, st_, st) in enumerate(steps):
            col = "#EFE7D6" if st != "sonuk" else "#A39883"
            rows += (f'<div class="step" style="position:absolute;left:0;right:0;top:{i*96}px"><img class="mh" src="{F}muhur-{st}.svg" alt=""><b style="color:{col};white-space:nowrap;width:210px">{r} · {t}</b><span style="color:{"#E8A24A" if st=="aktif" else "#CFC4AE" if st=="dolu" else "#A39883"}">{("✓ " if st=="dolu" else "")+st_}</span></div>')
        line = '<div class="abs" style="left:33px;top:48px;width:6px;height:288px;background:linear-gradient(180deg,#D2B47E 0 62%,#4C3E38 62% 100%)"></div>'
        hdr = f'<div class="in" style="display:flex;align-items:center;gap:28px;height:150px;margin:-26px 0 0 -2px">{plate("kalabalik_kesici",4,2)}<div class="mid" style="flex:1"><div class="nm" style="font:700 38px/46px Cinzel;color:#EFE7D6">ÖLDÜRME</div><div class="dd" style="font:400 28px/34px Inter;color:#CFC4AE">Toplam 5.000 düşman öldür.</div></div><div class="chev">˄</div></div>'
        b += f'<div class="abs lev hi" style="left:72px;width:936px;top:{y}px;height:{150+384+44}px;box-sizing:border-box;border-width:20px;border-image-width:20px"><div style="position:relative;margin:0 0 0 0">{hdr}<div style="position:relative;height:384px;margin:2px 14px 0 20px">{line}{rows}</div></div></div>'
        y += 150 + 384 + 44 + 14
        b += fam(y, "KIRIM", "kirim", 4, 1, "812", "1.000", "Tek koşuda 1.000 düşman öldür."); y += 162
    b += f'<div class="abs" style="left:0;right:0;top:2100px;height:90px;background:linear-gradient(180deg,transparent,#0C0908)"></div>'
    b += f'<div class="abs" style="left:72px;right:72px;top:2196px"><div class="b" style="height:132px"><div class="in">GERİ</div></div></div>'
    if anat:
        b += (call(72, 318, 936, 130, "kroniği şeridi: 5 mühür (dokun → gruba kay) · kademe sayısı 31/53")+call(72, 470, 936, 72, "sticky grup başlığı + ayraç + açılan/toplam")
              +call(72, 548, 936, 150, "satır 936×150: plaka(≤108)+ad+tek satır hedef+değer/segmentli çubuk")
              +call(80, 556, 120, 128, "plaka: çerçeve silüeti + Roma rozeti + baklava", True)+call(790, 590, 190, 60, "4 eşik çentikli çubuk", True)+call(72, 2196, 936, 132, "GERİ y2196"))
    page(name, "Başarımlar", b, "Başarımlar")

# ====================================================================== 4 KADEME DİLİ
def tiers():
    b = stone_bg() + '<div class="abs" style="left:0;right:0;top:96px;text-align:center"><span class="hd" style="font-size:64px">KADEME DİLİ</span></div>'
    cells = [("KİLİTLİ", 0, 0, True), ("I", 1, 1, False), ("II", 2, 2, False), ("III", 3, 3, False), ("IV", 4, 4, False)]
    for i, (lbl, n, t, lk) in enumerate(cells):
        x = 72 + (i % 3) * 320; y = 250 + (i // 3) * 330
        pl = plate("kirim", 4, t, lk).replace('style="--c', 'style="transform:scale(1.4);transform-origin:50% 0;--c')
        b += f'<div class="abs" style="left:{x}px;top:{y}px;width:296px;text-align:center"><div style="display:flex;justify-content:center;padding-top:24px">{pl}</div><div style="margin-top:96px;font:700 28px Cinzel;color:{"#E8A24A" if t>=3 else "#D2B47E" if t==2 else "#8C8379" if t==1 else "#A39883"};letter-spacing:.1em">{lbl}</div></div>'
    cx = 72 + 2 * 320; y = 250 + 330
    b += f'<div class="abs" style="left:{cx}px;top:{y}px;width:296px;text-align:center"><div style="display:flex;justify-content:center;padding-top:24px;margin-bottom:4px">{plate("kirim",4,4).replace("<div class=\"plate\"", "<div class=\"plate\"",1).replace("style=\"--c","style=\"transform:scale(1.4);transform-origin:50% 0;--c")}</div><div style="margin-top:96px"><span class="done">TAMAM</span></div></div>'
    b += '<div class="sec" style="top:960px">KOŞU İÇİ BİLDİRİM</div>'
    b += (f'<div class="abs lev" style="left:150px;width:780px;top:1050px;height:140px;box-sizing:border-box;padding:0;border-width:24px"><div style="display:flex;align-items:center;gap:20px;margin:-10px -4px"><div class="plate" style="--c:#E8A24A;transform:scale(.8);margin:-12px"><img class="fr" src="{F}plaka-3.svg"><img class="ic" src="{ACH}kalabalik_kesici.png"></div>'
          '<div style="flex:1"><div style="font:700 26px Inter;letter-spacing:.14em;color:#D2B47E">BAŞARIM AÇILDI · KADEME III</div><div style="font:700 38px Cinzel;color:#EFE7D6">ÖLDÜRME III</div></div></div></div>')
    b += '<div class="sec" style="top:1250px">SONUÇ ÖZETİ</div>'
    b += f'<div class="abs lev" style="left:72px;width:936px;top:1334px;height:104px;box-sizing:border-box;padding:0;border-width:24px;display:flex;align-items:center"><div style="display:flex;gap:18px;align-items:center;margin:0 6px"><span style="font:700 30px Cinzel;color:#E8A24A">YENİ KADEME · 2</span><span style="font:600 28px Inter;color:#CFC4AE">Öldürme III, Hayatta Kalma II</span></div></div>'
    b += '<div class="sec" style="top:1490px">KURALLAR</div>'
    rules = ["Kademe = plaka silüeti (yalın · perçin · köşebent · taç) + Roma rozeti + baklava; renk yardımcıdır, tek kanal değildir.",
             "Gri tonlama sınaması: 04b — dört plaka yalnız silüetle ayrışır.",
             "Kademe başına yeni ikon yok: aile ikonu + plaka (modulate ile kilitli silüet).",
             "IV: bordo plaka + amber halo + taç; tamam: TAMAM çipi + tüm segmentler amber.",
             "Çoklu eşik aynı karede aşılırsa tek bildirim, en yüksek kademe."]
    b += f'<div class="abs lev" style="left:72px;width:936px;top:1574px;height:560px;box-sizing:border-box;display:flex;align-items:center"><div style="margin:0 -6px;display:flex;flex-direction:column;gap:14px">' + "".join(f'<div style="font:400 29px/38px Inter;color:#EFE7D6">• {r}</div>' for r in rules) + '</div></div>'
    page("04-kademe-dili", "Kademe dili", b, "Kademe dili")

# ====================================================================== 5 KÜRELER
def orbs():
    sv = ('<svg width="0" height="0" style="position:absolute"><defs><filter id="pro"><feColorMatrix type="matrix" values=".152 1.053 -.205 0 0  .115 .786 .099 0 0  -.004 -.048 1.052 0 0  0 0 0 1 0"/></filter>'
          '<filter id="deu"><feColorMatrix type="matrix" values=".367 .861 -.228 0 0  .280 .673 .047 0 0  -.012 .043 .969 0 0  0 0 0 1 0"/></filter>'
          '<filter id="tri"><feColorMatrix type="matrix" values="1.256 -.077 -.179 0 0  -.078 .931 .148 0 0  .005 .691 .304 0 0  0 0 0 1 0"/></filter>'
          '<filter id="gry"><feColorMatrix type="saturate" values="0"/></filter></defs></svg>')
    b = stone_bg() + sv + '<div class="abs" style="left:0;right:0;top:96px;text-align:center"><span class="hd" style="font-size:60px">RUH KÜRELERİ</span></div>'
    names = [("normal", "NORMAL", "xp < 5", "#BFE6F2"), ("elit", "ELİT", "5 ≤ xp < 80", "#A24ED0"), ("ara_boss", "ARA BOSS", "xp ≥ 80", "#E8A24A")]
    szs = {"normal": 258, "elit": 296, "ara_boss": 328}
    for i, (f, t, e, c) in enumerate(names):
        x = 72 + i * 320
        b += f'<div class="abs" style="left:{x}px;top:220px;width:296px;height:300px;background:#0C0908;border:3px solid #3B302C;display:flex;align-items:center;justify-content:center"><img src="{ORB}{f}.png" style="width:{szs[f]}px" alt=""></div>'
        b += f'<div class="abs" style="left:{x}px;top:536px;width:296px;text-align:center"><div style="font:700 32px Cinzel;color:{c};letter-spacing:.1em">{t}</div><div style="font:600 26px Inter;color:#CFC4AE">{e}</div></div>'
    b += '<div class="sec" style="top:640px">OYUN ÖLÇEĞİ ×2 (34 / 48 / 68 px) · ZEMİN</div>'
    b += f'<div class="abs" style="left:72px;top:728px;width:936px;height:300px;overflow:hidden;border:4px solid #7A6045"><img src="{A}zemin-yama.png" style="position:absolute;left:-40px;top:-30px;width:1020px;opacity:.95" alt=""><div class="abs" style="inset:0;background:rgba(12,9,8,.35)"></div></div>'
    pos = [(110, 140, "normal"), (210, 90, "normal"), (300, 170, "normal"), (392, 110, "normal"), (470, 60, "elit"), (560, 160, "elit"), (700, 90, "ara_boss"), (830, 150, "normal"), (900, 70, "normal")]
    ps = {"normal": 68, "elit": 96, "ara_boss": 136}
    for x, y, f in pos:
        s = ps[f]; b += f'<img class="abs" src="{ORB}{f}.png" style="left:{72+x-s//2}px;top:{728+y-s//2}px;width:{s}px" alt="">'
    b += '<div class="sec" style="top:1060px">RENK KÖRLÜĞÜ SİMÜLASYONU (YAKLAŞIK)</div>'
    for r, (flt, lbl) in enumerate([("none", "NORMAL"), ("url(#pro)", "PROTAN"), ("url(#deu)", "DEUTAN"), ("url(#tri)", "TRITAN"), ("url(#gry)", "GRİ")]):
        y = 1150 + r * 150
        b += f'<div class="abs" style="left:72px;top:{y+44}px;width:150px;font:700 26px Inter;color:#D2B47E;letter-spacing:.08em">{lbl}</div>'
        for i, f in enumerate(("normal", "elit", "ara_boss")):
            s = {"normal": 68, "elit": 96, "ara_boss": 136}[f]
            b += f'<div class="abs" style="left:{250+i*260}px;top:{y+75-s//2-8}px;width:240px;display:flex;justify-content:center"><img src="{ORB}{f}.png" style="width:{s}px;filter:{flt}" alt=""></div>'
    b += '<div class="sec" style="top:1910px">ÖLÇÜM (128 px, opak çekirdek)</div>'
    rows = [("", "L* normal", "protan", "deutan", "tritan", "alan"), ("NORMAL", "79,0", "80,4", "78,0", "79,1", "%11"), ("ELİT", "36,2", "36,9", "38,0", "37,4", "%25"), ("ARA BOSS", "74,1", "70,6", "76,0", "73,1", "%23")]
    t = "".join('<div style="display:flex;height:48px;align-items:center;font:600 26px Inter;color:#EFE7D6">' + "".join(f'<span style="width:{190 if i==0 else 150}px;{"font-weight:700;color:#D2B47E" if i==0 or ri==0 else ""}">{c}</span>' for i, c in enumerate(r)) + '</div>' for ri, r in enumerate(rows))
    b += f'<div class="abs lev" style="left:72px;width:936px;top:1996px;height:250px;box-sizing:border-box;display:flex;align-items:center"><div style="margin:0 -6px">{t}</div></div>'
    b += '<div class="abs" style="left:72px;top:2258px;font:600 26px/32px Inter;color:#CFC4AE;width:936px">IoU: normal–elit 0,37 · normal–boss 0,46 · elit–boss 0,51 (≤0,6). ΔL* normal–boss 4,9 → ayrım boyut 1:2 + taç silüeti. hareket_azalt açıkken süzülme durur.</div>'
    page("05-kure-gorsel-yonu", "Küre yönü", b, "Küre görsel yönü")

# ====================================================================== 6 İSİM ÖNERİLERİ
def names():
    b = stone_bg() + '<div class="abs" style="left:0;right:0;top:96px;text-align:center"><span class="hd" style="font-size:56px">İSİM ÖNERİLERİ</span></div>'
    sets = [("A · THE …", ["THE WATCH", "THE CULLING", "THE CROWNED", "THE ARMORY", "THE ROAD"], True), ("B · eylem", ["LAST STAND", "BODY COUNT", "THRONE BREAKERS", "MASTERY", "PILGRIMAGE"], False), ("C · yalın", ["SURVIVAL", "CARNAGE", "WARLORDS", "CRAFT", "JOURNEY"], False)]
    tr = ["SAĞ KALIM", "KIRIM", "BOSS", "USTALIK", "YOLCULUK"]
    y = 230
    for t, lst, rec in sets:
        b += f'<div class="sec" style="top:{y}px">{t}{"  ·  ÖNERİLEN" if rec else ""}</div>'; y += 80
        rows = "".join(f'<div class="rw" style="min-height:54px;padding:0"><div class="tx" style="font:700 36px Cinzel;letter-spacing:.1em;color:#EFE7D6">{n}</div><div style="font:600 26px Inter;color:#A39883">{tr[i]}</div></div>' for i, n in enumerate(lst))
        b += f'<div class="abs lev" style="left:72px;width:936px;top:{y}px;height:330px;box-sizing:border-box;display:flex;align-items:center"><div style="margin:0 -6px;width:100%">{rows}</div></div>'; y += 360
    b += f'<div class="sec" style="top:{y}px">AİLE ADLARI (TR → EN, ilki önerilen)</div>'; y += 80
    fam_en = [("Hayatta Kalma", "Endure / Last Light"), ("Seviye", "Ascendant / Rise"), ("Kırım", "Rampage / Onslaught"), ("Öldürme", "Reaper / Slayer"), ("Boss Avcısı", "Bossbane / Giant Slayer"), ("Üç Elit", "Elite Trio / Triple Crown"),
              ("Evrim", "Ascension / Rebirth"), ("Tambur Ustası", "Quick Hands / Spinner"), ("Seri Ustası", "Unbroken / Streak"), ("Skor", "Renown / Tally"), ("Bomba Ustası", "Demolisher / Bombardier"),
              ("Eklenti Avcısı", "Scavenger / Relic Hunter"), ("Dokunulmaz", "Untouched / Ghostwalk"), ("Yerleşik", "Garrison / Returning"), ("Tam Kadro", "Full Arsenal / Loaded"), ("Sınırsız Kırım", "Unbound / Limitless"),
              ("Kale Lordu", "Lordslayer / Usurper"), ("Nöbet", "Vigil / Night Watch"), ("Çifte Yol", "Two Roads / Dual Path")]
    half = (len(fam_en) + 1) // 2
    cols = ""
    for lo, hi in ((0, half), (half, len(fam_en))):
        cols += '<div style="flex:1">' + "".join(f'<div style="height:50px;display:flex;flex-direction:column;justify-content:center"><div style="font:600 24px/26px Inter;color:#A39883">{a}</div><div style="font:700 25px/28px Cinzel;color:#EFE7D6;letter-spacing:.03em">{e}</div></div>' for a, e in fam_en[lo:hi]) + '</div>'
    b += f'<div class="abs lev" style="left:72px;width:936px;top:{y}px;height:600px;box-sizing:border-box;display:flex;align-items:center"><div style="margin:0 -6px;display:flex;gap:30px;width:100%">{cols}</div></div>'
    b += '<div class="abs" style="left:72px;top:2290px;font:600 24px/30px Inter;color:#CFC4AE;width:936px">İngilizce metin sabit büyük harfle yazılır (UiKit.upper_tr KULLANILMAZ: "i" → "İ" olur).</div>'
    page("06-isim-onerileri", "İsim önerileri", b, "İsim önerileri")

home(); home("01b-ana-sayfa-anatomi", anat=True); home("01c-ana-sayfa-hareket-azalt", calm=True); home("01d-ana-sayfa-yazi-2x", big=True); home("01e-ana-sayfa-ilk-acilis", ach="0/53")
settings(); settings("02a-ayarlar-anatomi", anat=True); settings("02b-ayarlar-sessiz-hareket-azalt", master=False, motion=True, vib=False); settings("02c-ayarlar-yazi-2x", big=True); lisans()
ach(); ach("03a-basarimlar-anatomi", anat=True); ach("03b-basarimlar-bos", "empty"); ach("03c-basarimlar-hepsi-acik", "all"); ach("03d-basarimlar-satir-acik", "open")
tiers(); orbs(); names()
